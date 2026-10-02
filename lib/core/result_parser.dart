import 'dart:math' as math;

import 'models.dart';
import 'text_piece.dart';

sealed class ParseResult {
  const ParseResult();
}

/// No stage totals at all: not a result screen.
class NoResultScreen extends ParseResult {
  const NoResultScreen();
}

/// Some totals found, but not exactly three.
class IncompleteScreen extends ParseResult {
  const IncompleteScreen(this.totalsFound);

  final int totalsFound;
}

class ParsedRun extends ParseResult {
  const ParsedRun(this.draft);

  final RunDraft draft;
}

enum _Kind { total, bonus, number }

class _Token {
  const _Token(this.kind, this.value, this.piece);

  final _Kind kind;
  final int value;
  final TextPiece piece;

  double get centerX => piece.centerX;
  double get centerY => piece.centerY;
}

/// Reads a rehearsal result screen from OCR pieces by their positions.
abstract final class ResultParser {
  static final _ptSuffix = RegExp(r'^(.*?)\s*[Pp][Tt]\.?$');
  static final _ptAlone = RegExp(r'^[Pp][Tt]\.?$');
  static final _bonus = RegExp(r'\+\s*([^+]+)$');
  static final _digitLike = RegExp(r'^[\dOolI|,.]+$');
  static final _anyDigit = RegExp(r'\d');
  static final _separators = RegExp(r'[,.]');
  static const _lookalikes = {'O': '0', 'o': '0', 'l': '1', 'I': '1', '|': '1'};

  /// Smallest plain number kept; below this are badges and stage labels.
  static const _minPlainNumber = 100;

  static const _slots = 3;

  /// Parses [raw] as a number, tolerating separators and lookalike letters.
  static int? number(String raw) {
    final s = raw.trim();
    if (!_digitLike.hasMatch(s) || !_anyDigit.hasMatch(s)) return null;
    final digits =
        s.split('').map((c) => _lookalikes[c] ?? c).join().replaceAll(_separators, '');
    return digits.isEmpty ? null : int.parse(digits);
  }

  static ParseResult parse(List<TextPiece> pieces) {
    final tokens = _classify(pieces);
    final totals = tokens.where((t) => t.kind == _Kind.total).toList()
      ..sort((a, b) => a.centerY.compareTo(b.centerY));
    if (totals.isEmpty) return const NoResultScreen();
    if (totals.length != RunScores.stageCount) return IncompleteScreen(totals.length);

    final tolerance = _median([for (final t in tokens) t.piece.height]) / 2;
    final memberRows = <List<_Token>>[];
    final bonuses = <_Token?>[];
    for (var i = 0; i < totals.length; i++) {
      final top = totals[i].centerY + tolerance;
      final bottom =
          i + 1 < totals.length ? totals[i + 1].centerY - tolerance : double.infinity;
      final band = tokens.where((t) => t.centerY > top && t.centerY < bottom).toList();
      final bonus = _topmost(band.where((t) => t.kind == _Kind.bonus));
      final limit = bonus == null ? bottom : bonus.centerY - tolerance;
      final rows = _groupRows(
        band.where((t) => t.kind == _Kind.number && t.centerY < limit),
        tolerance,
      );
      memberRows.add(rows.isEmpty ? const [] : rows.first);
      bonuses.add(bonus);
    }

    final anchors = _slotAnchors(memberRows);
    return ParsedRun(RunDraft([
      for (var i = 0; i < totals.length; i++)
        _stage(memberRows[i], anchors, bonuses[i]?.value, totals[i].value),
    ]));
  }

  static List<_Token> _classify(List<TextPiece> pieces) {
    final words = pieces.expand(_splitWords).toList();
    final ptMarks = words.where((w) => _ptAlone.hasMatch(w.text.trim())).toList();
    final tokens = <_Token>[];
    for (final word in words) {
      final text = word.text.trim();

      final suffix = _ptSuffix.firstMatch(text);
      if (suffix != null && suffix.group(1)!.isNotEmpty) {
        final value = number(suffix.group(1)!);
        if (value != null) {
          tokens.add(_Token(_Kind.total, value, word));
          continue;
        }
      }

      final bonus = _bonus.firstMatch(text);
      if (bonus != null) {
        final value = number(bonus.group(1)!);
        if (value != null) {
          tokens.add(_Token(_Kind.bonus, value, word));
          continue;
        }
      }

      final value = number(text);
      if (value == null || value < _minPlainNumber) continue;
      final isTotal = ptMarks.any((pt) => _isRightNeighbor(word, pt));
      tokens.add(_Token(isTotal ? _Kind.total : _Kind.number, value, word));
    }
    return tokens;
  }

  /// Splits a piece containing spaces into words, sharing its width by length.
  static Iterable<TextPiece> _splitWords(TextPiece piece) sync* {
    final words = piece.text.trim().split(RegExp(r'\s+'));
    if (words.length <= 1) {
      yield piece;
      return;
    }
    final chars = words.fold<int>(0, (n, w) => n + w.length) + words.length - 1;
    final charWidth = (piece.right - piece.left) / chars;
    var x = piece.left;
    for (final word in words) {
      final width = word.length * charWidth;
      yield TextPiece(word, x, piece.top, x + width, piece.bottom);
      x += width + charWidth;
    }
  }

  static bool _isRightNeighbor(TextPiece number, TextPiece pt) {
    final h = math.max(number.height, pt.height);
    return (pt.centerY - number.centerY).abs() < h / 2 &&
        pt.left >= number.right - h / 2 &&
        pt.left - number.right < h * 1.5;
  }

  static List<List<_Token>> _groupRows(Iterable<_Token> tokens, double tolerance) {
    final sorted = tokens.toList()..sort((a, b) => a.centerY.compareTo(b.centerY));
    final rows = <List<_Token>>[];
    for (final t in sorted) {
      if (rows.isNotEmpty && (t.centerY - rows.last.first.centerY).abs() < tolerance) {
        rows.last.add(t);
      } else {
        rows.add([t]);
      }
    }
    for (final row in rows) {
      row.sort((a, b) => a.centerX.compareTo(b.centerX));
    }
    return rows;
  }

  /// Average x of each slot across stages whose member row read completely.
  static List<double>? _slotAnchors(List<List<_Token>> rows) {
    final complete = rows.where((r) => r.length == _slots).toList();
    if (complete.isEmpty) return null;
    return [
      for (var s = 0; s < _slots; s++)
        complete.map((r) => r[s].centerX).reduce((a, b) => a + b) / complete.length,
    ];
  }

  static StageDraft _stage(List<_Token> row, List<double>? anchors, int? bonus, int total) {
    final slots = List<int?>.filled(_slots, null);
    if (row.length == _slots) {
      for (var s = 0; s < _slots; s++) {
        slots[s] = row[s].value;
      }
    } else if (anchors != null && row.length < _slots) {
      final claimed = <int>{};
      for (final t in row) {
        final slot = _nearest(anchors, t.centerX);
        slots[slot] = claimed.add(slot) ? t.value : null;
      }
    }
    return StageDraft(
      left: slots[0],
      middle: slots[1],
      right: slots[2],
      bonus: bonus,
      total: total,
    );
  }

  static int _nearest(List<double> anchors, double x) {
    var best = 0;
    for (var i = 1; i < anchors.length; i++) {
      if ((anchors[i] - x).abs() < (anchors[best] - x).abs()) best = i;
    }
    return best;
  }

  static _Token? _topmost(Iterable<_Token> tokens) {
    _Token? best;
    for (final t in tokens) {
      if (best == null || t.centerY < best.centerY) best = t;
    }
    return best;
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
