import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/pixel_rect.dart';
import '../l10n/app_localizations.dart';

/// Decodes the captured frame, or returns null if it can't be read.
Future<ui.Image?> decodeFrame(String path) async {
  try {
    final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

/// One stage cropped from the captured frame, at full width. Tapping it
/// folds it to a one-line row that brings it back.
class CaptureStrip extends StatefulWidget {
  const CaptureStrip({super.key, required this.image, required this.rect, this.collapsed = false});

  final ui.Image image;
  final PixelRect rect;
  final bool collapsed;

  @override
  State<CaptureStrip> createState() => _CaptureStripState();
}

class _CaptureStripState extends State<CaptureStrip> {
  late bool _collapsed = widget.collapsed;

  void _toggle() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (_collapsed) {
      return InkWell(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.image_outlined, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(l.showCapture, style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final src = widget.rect.clamp(widget.image.width.toDouble(), widget.image.height.toDouble());
    return Semantics(
      button: true,
      label: l.hideCapture,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('strip'),
        onTap: _toggle,
        child: AspectRatio(
          aspectRatio: src.width / src.height,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant)),
            child: CustomPaint(painter: _StripPainter(widget.image, src)),
          ),
        ),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.image, this.src);

  final ui.Image image;
  final PixelRect src;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTRB(src.left, src.top, src.right, src.bottom),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_StripPainter old) => old.image != image || old.src != src;
}
