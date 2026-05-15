import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DocumentLogo extends StatefulWidget {
  const DocumentLogo({
    super.key,
    this.size = 32,
    this.color,
    this.background,
    this.rounded = true,
    this.assetPath = 'assets/icon.png',
    this.assetPathDark = 'assets/icon_dark.png',
  });

  final double size;
  final Color? color;
  final Color? background;
  final bool rounded;
  final String assetPath;
  final String assetPathDark;

  @override
  State<DocumentLogo> createState() => _DocumentLogoState();
}

class _DocumentLogoState extends State<DocumentLogo> {
  final Map<String, bool> _assetAvailability = {};

  @override
  void initState() {
    super.initState();
    _probeAsset(widget.assetPath);
    _probeAsset(widget.assetPathDark);
  }

  @override
  void didUpdateWidget(covariant DocumentLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _assetAvailability.remove(widget.assetPath);
      _probeAsset(widget.assetPath);
    }
    if (oldWidget.assetPathDark != widget.assetPathDark) {
      _assetAvailability.remove(widget.assetPathDark);
      _probeAsset(widget.assetPathDark);
    }
  }

  Future<void> _probeAsset(String path) async {
    try {
      await rootBundle.load(path);
      if (mounted) {
        setState(() => _assetAvailability[path] = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _assetAvailability[path] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = widget.color ?? scheme.onSurface;
    final bg = widget.background ?? scheme.surface;
    final radius =
        widget.rounded ? BorderRadius.circular(widget.size * 0.235) : null;

    final preferredPath = isDark ? widget.assetPathDark : widget.assetPath;
    final fallbackPath = isDark ? widget.assetPath : widget.assetPathDark;
    String? selectedPath;
    if (_assetAvailability[preferredPath] == true) {
      selectedPath = preferredPath;
    } else if (_assetAvailability[fallbackPath] == true) {
      selectedPath = fallbackPath;
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      clipBehavior: radius != null ? Clip.antiAlias : Clip.none,
      child: selectedPath != null
          ? Image.asset(selectedPath, fit: BoxFit.contain)
          : Center(
              child: CustomPaint(
                size: Size.square(widget.size * 0.56),
                painter: _DocumentPainter(color: foreground),
              ),
            ),
    );
  }
}

class _DocumentPainter extends CustomPainter {
  _DocumentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.13;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final foldSize = w * 0.30;
    final r = stroke * 0.9;

    final outline = Path()
      ..moveTo(r, 0)
      ..lineTo(w - foldSize, 0)
      ..lineTo(w, foldSize)
      ..lineTo(w, h - r)
      ..arcToPoint(
        Offset(w - r, h),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(r, h)
      ..arcToPoint(
        Offset(0, h - r),
        radius: Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(0, r)
      ..arcToPoint(
        Offset(r, 0),
        radius: Radius.circular(r),
        clockwise: true,
      );
    canvas.drawPath(outline, paint);

    final fold = Path()
      ..moveTo(w - foldSize, 0)
      ..lineTo(w - foldSize, foldSize)
      ..lineTo(w, foldSize);
    canvas.drawPath(fold, paint);

    final lineLeft = w * 0.24;
    final lineY1 = h * 0.58;
    final lineY2 = h * 0.74;
    final lineY3 = h * 0.88;
    canvas
      ..drawLine(Offset(lineLeft, lineY1), Offset(w * 0.86, lineY1), paint)
      ..drawLine(Offset(lineLeft, lineY2), Offset(w * 0.78, lineY2), paint)
      ..drawLine(Offset(lineLeft, lineY3), Offset(w * 0.62, lineY3), paint);
  }

  @override
  bool shouldRepaint(_DocumentPainter oldDelegate) => oldDelegate.color != color;
}
