import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../editor/editable_widget.dart';

class MarketBackground extends StatefulWidget {
  const MarketBackground({super.key, this.child});

  final Widget? child;

  @override
  State<MarketBackground> createState() => _MarketBackgroundState();
}

class _MarketBackgroundState extends State<MarketBackground>
    with TickerProviderStateMixin {
  late final AnimationController _forwardDrift;
  late final AnimationController _reverseDrift;

  @override
  void initState() {
    super.initState();
    _forwardDrift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 32),
    )..repeat();
    _reverseDrift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 42),
    )..repeat();
  }

  @override
  void dispose() {
    _forwardDrift.dispose();
    _reverseDrift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const defaults = <String, dynamic>{
      'baseColor': 0xFFBE9BFF,
      'primaryColor': 0xFF805ECF,
      'secondaryColor': 0xFF805ECF,
      'primaryOpacity': 0.24,
      'secondaryOpacity': 0.14,
    };

    return AnimatedBuilder(
      animation: Listenable.merge([_forwardDrift, _reverseDrift]),
      builder: (context, _) {
        return EditableWidget(
          id: 'market-background-main',
          typeName: 'MarketBackground',
          initialProps: defaults,
          builder: (ctx, props, variant) {
            final baseColor = _color(props['baseColor'], const Color(0xFFBE9BFF));
            final primaryColor = _color(
              props['primaryColor'],
              const Color(0xFF805ECF),
            );
            final secondaryColor = _color(
              props['secondaryColor'],
              const Color(0xFF805ECF),
            );
            final primaryOpacity = _number(
              props['primaryOpacity'],
              0.24,
            ).clamp(0, 1).toDouble();
            final secondaryOpacity = _number(
              props['secondaryOpacity'],
              0.14,
            ).clamp(0, 1).toDouble();

            return DecoratedBox(
              decoration: BoxDecoration(color: baseColor),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BasketPatternPainter(
                        dx: _forwardDrift.value * _BasketPatternPainter.kTileSize,
                        dy: _forwardDrift.value * _BasketPatternPainter.kTileSize,
                        opacity: primaryOpacity,
                        baseShiftX: 0,
                        baseShiftY: 0,
                        strokeColor: primaryColor,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BasketPatternPainter(
                        dx:
                            -(_reverseDrift.value *
                                _BasketPatternPainter.kTileSize),
                        dy:
                            -(_reverseDrift.value *
                                _BasketPatternPainter.kTileSize),
                        opacity: secondaryOpacity,
                        baseShiftX: -44,
                        baseShiftY: -44,
                        strokeColor: secondaryColor,
                      ),
                    ),
                  ),
                  if (widget.child != null) widget.child!,
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _color(dynamic raw, Color fallback) {
    if (raw is int) return Color(raw);
    if (raw is num) return Color(raw.toInt());
    if (raw is Color) return raw;
    return fallback;
  }

  double _number(dynamic raw, double fallback) {
    if (raw is num) return raw.toDouble();
    return fallback;
  }
}

class _BasketPatternPainter extends CustomPainter {
  static const double kTileSize = 88;
  static const double _kSvgViewport = 24;
  static const double _kSvgStroke = 1.5;
  static const double _kPatternInset = 220;
  static const double _kScale = kTileSize / _kSvgViewport;
  static final Path _kBasketPathScaled = _buildScaledBasketPath();

  const _BasketPatternPainter({
    required this.dx,
    required this.dy,
    required this.opacity,
    required this.baseShiftX,
    required this.baseShiftY,
    required this.strokeColor,
  });

  final double dx;
  final double dy;
  final double opacity;
  final double baseShiftX;
  final double baseShiftY;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kSvgStroke * _kScale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..color = strokeColor.withValues(alpha: opacity);

    final shiftX = _normalizeShift(baseShiftX + dx, kTileSize);
    final shiftY = _normalizeShift(baseShiftY + dy, kTileSize);
    final startX = -_kPatternInset + shiftX - kTileSize;
    final startY = -_kPatternInset + shiftY - kTileSize;
    final endX = size.width + _kPatternInset + kTileSize;
    final endY = size.height + _kPatternInset + kTileSize;

    for (double y = startY; y <= endY; y += kTileSize) {
      for (double x = startX; x <= endX; x += kTileSize) {
        final ox = x;
        final oy = y;

        canvas.save();
        canvas.translate(ox, oy);
        canvas.drawPath(_kBasketPathScaled, stroke);
        canvas.restore();
      }
    }
  }

  static Path _buildScaledBasketPath() {
    final basketPath = Path()
      ..moveTo(5, 11)
      ..lineTo(7, 20)
      ..lineTo(17, 20)
      ..lineTo(19, 11)
      ..close()
      ..moveTo(9, 11)
      ..lineTo(9, 8)
      ..quadraticBezierTo(12, 5, 15, 8)
      ..lineTo(15, 11);
    return basketPath.transform(Float64List.fromList(<double>[
      _kScale,
      0,
      0,
      0,
      0,
      _kScale,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]));
  }

  static double _normalizeShift(double value, double spacing) {
    final remainder = value % spacing;
    return remainder < 0 ? remainder + spacing : remainder;
  }

  @override
  bool shouldRepaint(_BasketPatternPainter oldDelegate) {
    return oldDelegate.dx != dx ||
        oldDelegate.dy != dy ||
        oldDelegate.opacity != opacity ||
        oldDelegate.baseShiftX != baseShiftX ||
        oldDelegate.baseShiftY != baseShiftY ||
        oldDelegate.strokeColor != strokeColor;
  }
}
