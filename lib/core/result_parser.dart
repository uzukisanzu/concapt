import 'dart:math' as math;

import 'models.dart';
import 'pixel_rect.dart';
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
  const ParsedRun(this.draft, this.stageBounds, this.totalLines);

  final RunDraft draft;

  /// Each stage's total, members, and bonus in frame pixels, top to bottom.
  final List<PixelRect> stageBounds;

  /// Each stage's total line across its strip, in frame pixels, even where
  /// OCR dropped the total.
  final List<PixelRect> totalLines;
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
  static final _bonus = RegExp(r'\+\s*([^+]+?)[^\w|]*$');
  static final _digitLike = RegExp(r'^[\dOolI|Aó,.]+$');

  /// A comma-grouped number with up to three trailing chars, like `1,014,622Pr`.
  static final _grouped = RegExp(r'^([\dOolI|Aó]{1,3}(?:[,.][\dOolI|Aó]{3})+)\D{0,3}$');
  static final _threeDigits = RegExp(r'\d{3}');
  static final _endsNumeric = RegExp(r'\d[,.]?$');
  static final _startsDigit = RegExp(r'^\d');
  static final _anyDigit = RegExp(r'\d');
  static final _separators = RegExp(r'[,.]');
  static final _bonusGap = RegExp(r'(?<=\+)\s+');
  static const _lookalikes = {'O': '0', 'o': '0', 'l': '1', 'I': '1', '|': '1', 'A': '4', 'ó': '6'};

  /// Smallest plain number kept; below this are badges and stage labels.
  static const _minPlainNumber = 100;

  static const _slots = 3;

  /// Totals print about twice the height of member scores; 総合力 about 1.3×.
  static const _totalHeightRatio = 1.4;

  /// Parses [raw] as a number, tolerating separators and lookalike letters.
  static int? number(String raw) {
    final s = raw.trim();
    if (!_digitLike.hasMatch(s) || !_anyDigit.hasMatch(s)) return null;
    final digits = s.split('').map((c) => _lookalikes[c] ?? c).join().replaceAll(_separators, '');
    return int.tryParse(digits);
  }

  static ParseResult parse(List<TextPiece> pieces) {
    final tokens = _classify(pieces);
    final totals = tokens.where((t) => t.kind == _Kind.total).toList()
      ..sort((a, b) => a.centerY.compareTo(b.centerY));
    if (totals.isEmpty) return const NoResultScreen();

    final tolerance = _median([for (final t in tokens) t.piece.height]) / 2;
    final stages = totals.length == RunScores.stageCount
        ? [for (final t in totals) (total: t, y: t.centerY)]
        : _recoverStages(tokens, totals, tolerance);
    if (stages == null) return IncompleteScreen(totals.length);

    final bands = <List<_Token>>[];
    final bonuses = <_Token?>[];
    for (var i = 0; i < stages.length; i++) {
      final top = stages[i].y + tolerance;
      final bottom = i + 1 < stages.length ? stages[i + 1].y - tolerance : double.infinity;
      final band = tokens.where((t) => t.centerY > top && t.centerY < bottom).toList();
      bands.add(band);
      bonuses.add(_topmost(band.where((t) => t.kind == _Kind.bonus)));
    }

    final bonusOffset = _median([
      for (var i = 0; i < stages.length; i++)
        if (bonuses[i] != null) bonuses[i]!.centerY - stages[i].y,
    ]);
    final memberRows = <List<_Token>>[];
    for (var i = 0; i < stages.length; i++) {
      final bonus = bonuses[i];
      final limit = bonus != null
          ? bonus.centerY - tolerance
          : bonusOffset > 0
          ? stages[i].y + bonusOffset - tolerance
          : double.infinity;
      final band = bands[i];
      final rows = _groupRows(
        band.where((t) => t.kind == _Kind.number && t.centerY < limit),
        tolerance,
      );
      memberRows.add(rows.isEmpty ? const [] : rows.first);
    }

    final anchors = _slotAnchors(memberRows);
    final halfLine = _median([for (final t in totals) t.piece.height]) * 0.75;
    final bounds = [
      for (var i = 0; i < stages.length; i++)
        _bounds(stages[i].total?.piece.top ?? stages[i].y - halfLine, [
          ?stages[i].total,
          ...memberRows[i],
          ?bonuses[i],
        ], tolerance),
    ];
    // Stages share one column layout, so every stage spans the widest one;
    // a member OCR missed stays inside the strip.
    final left = bounds.map((b) => b.left).reduce(math.min);
    final right = bounds.map((b) => b.right).reduce(math.max);
    return ParsedRun(
      RunDraft([
        for (var i = 0; i < stages.length; i++)
          _stage(memberRows[i], anchors, stages[i].total?.value),
      ]),
      [for (final b in bounds) PixelRect(left, b.top, right, b.bottom)],
      [for (final s in stages) PixelRect(left, s.y - halfLine, right, s.y + halfLine)],
    );
  }

  /// Finds the stages from their member rows when OCR dropped a total line:
  /// three rows of two or more plain numbers, with each total found above a
  /// different one. A dropped total sits where the others do relative to
  /// their rows. Null when the rows don't line up that way.
  static List<({_Token? total, double y})>? _recoverStages(
    List<_Token> tokens,
    List<_Token> totals,
    double tolerance,
  ) {
    if (totals.length > RunScores.stageCount) return null;
    final rows = _groupRows(
      tokens.where((t) => t.kind == _Kind.number),
      tolerance,
    ).where((r) => r.length >= 2).toList();
    if (rows.length != RunScores.stageCount) return null;

    final owners = [for (final t in totals) rows.indexWhere((r) => r.first.centerY > t.centerY)];
    if (owners.contains(-1) || owners.toSet().length != owners.length) return null;
    final offset = _median([
      for (var i = 0; i < totals.length; i++) rows[owners[i]].first.centerY - totals[i].centerY,
    ]);
    return [
      for (var r = 0; r < rows.length; r++)
        owners.contains(r)
            ? (total: totals[owners.indexOf(r)], y: totals[owners.indexOf(r)].centerY)
            : (total: null, y: rows[r].first.centerY - offset),
    ];
  }

  /// From [top] down through [pieces], widened by [margin].
  static PixelRect _bounds(double top, List<_Token> pieces, double margin) => PixelRect(
    pieces.map((t) => t.piece.left).reduce(math.min) - margin,
    top - margin,
    pieces.map((t) => t.piece.right).reduce(math.max) + margin,
    pieces.map((t) => t.piece.bottom).reduce(math.max) + margin,
  );

  static List<_Token> _classify(List<TextPiece> pieces) {
    final words = _joinSplitNumbers(pieces).expand(_splitWords).toList();
    final scoreHeight = _median([
      for (final w in words)
        if (_threeDigits.hasMatch(w.text)) w.height,
    ]);
    final ptMarks = words.where((w) => _ptAlone.hasMatch(w.text.trim())).toList();
    final tokens = <_Token>[];
    for (final word in words) {
      final text = word.text.trim();

      final grouped = _grouped.firstMatch(text);
      if (grouped != null && word.height >= scoreHeight * _totalHeightRatio) {
        final value = number(grouped.group(1)!);
        if (value != null) {
          tokens.add(_Token(_Kind.total, value, word));
          continue;
        }
      }

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

  /// Joins a number OCR broke in two, like `181,22` + `1Pt`, and a bonus
  /// marker read apart from its number, like `+` + `46150`.
  static List<TextPiece> _joinSplitNumbers(List<TextPiece> words) {
    final sorted = [...words]..sort((a, b) => a.left.compareTo(b.left));
    final joined = <TextPiece>[];
    for (final w in sorted) {
      final i = joined.lastIndexWhere((j) => _continues(j, w));
      if (i < 0) {
        joined.add(w);
      } else {
        final j = joined[i];
        joined[i] = TextPiece(
          '${j.text.trim()}${w.text.trim()}',
          j.left,
          math.min(j.top, w.top),
          w.right,
          math.max(j.bottom, w.bottom),
        );
      }
    }
    return joined;
  }

  static bool _continues(TextPiece left, TextPiece right) {
    final h = math.max(left.height, right.height);
    final text = left.text.trim();
    final marker = text.endsWith('+');

    // A marker read as its own word sits a space away from its number.
    final gap = marker ? h : h / 2;
    return (right.centerY - left.centerY).abs() < h / 2 &&
        right.left >= left.right - h / 2 &&
        right.left - left.right < gap &&
        (marker || _endsNumeric.hasMatch(text)) &&
        _startsDigit.hasMatch(right.text.trim());
  }

  /// Splits a piece containing spaces into words, sharing its width by length.
  /// A lone `+` stays with the number after it.
  static Iterable<TextPiece> _splitWords(TextPiece piece) sync* {
    final words = piece.text.trim().replaceAll(_bonusGap, '').split(RegExp(r'\s+'));
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

  static StageDraft _stage(List<_Token> row, List<double>? anchors, int? total) {
    final slots = List<int?>.filled(_slots, null);
    if (row.length == _slots) {
      for (var s = 0; s < _slots; s++) {
        slots[s] = row[s].value;
      }
    } else if (anchors != null) {
      final claimed = <int>{};
      for (final t in row) {
        final slot = _nearest(anchors, t.centerX);
        slots[slot] = claimed.add(slot) ? t.value : null;
      }
    }
    return StageDraft(left: slots[0], middle: slots[1], right: slots[2], total: total);
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
