import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../editor/editable_widget.dart';
import '../../../editor/variants/background_variants.dart';
import '../../../theme/app_colors.dart';

class PageGradient extends StatelessWidget {
  const PageGradient({super.key, this.market = false, this.editorId});

  final bool market;
  final String? editorId;

  @override
  Widget build(BuildContext context) {
    final id =
        editorId ?? (market ? 'page-gradient-market' : 'page-gradient-home');
    final defaults = Map<String, dynamic>.from(
      market
          ? BackgroundVariants.marketPurple
          : BackgroundVariants.homePinkPurple,
    );
    final fallbackStops = market
        ? AppGradients.marketPurple
        : AppGradients.homePinkPurple;

    return EditableWidget(
      id: id,
      typeName: 'PageGradient',
      initialProps: defaults,
      builder: (ctx, props, variant) {
        final style = Map<String, dynamic>.from(defaults)..addAll(props);
        final stops = _toColors(style['stops'], fallbackStops);
        final type = (style['type']?.toString() ?? 'linear').toLowerCase();
        final angle = _toDouble(style['angle'], 180.0);

        Gradient gradient;
        if (type == 'solid') {
          gradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [stops.isNotEmpty ? stops.first : Colors.white],
          );
        } else if (type == 'radial') {
          gradient = RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: stops,
          );
        } else {
          gradient = LinearGradient(
            begin: _beginForAngle(angle),
            end: _endForAngle(angle),
            colors: stops,
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(gradient: gradient),
          child: _PatternOverlay(
            type: style['patternType']?.toString() ?? 'none',
          ),
        );
      },
    );
  }

  double _toDouble(dynamic raw, double fallback) {
    if (raw is num) return raw.toDouble();
    return fallback;
  }

  List<Color> _toColors(dynamic raw, List<Color> fallback) {
    if (raw is List) {
      final out = <Color>[];
      for (final item in raw) {
        if (item is int) out.add(Color(item));
        if (item is num) out.add(Color(item.toInt()));
      }
      if (out.isNotEmpty) return out;
    }
    return fallback;
  }

  Alignment _beginForAngle(double angleDeg) {
    final rad = angleDeg * math.pi / 180.0;
    final x = math.cos(rad);
    final y = math.sin(rad);
    return Alignment(-x, -y);
  }

  Alignment _endForAngle(double angleDeg) {
    final begin = _beginForAngle(angleDeg);
    return Alignment(-begin.x, -begin.y);
  }
}

class _PatternOverlay extends StatelessWidget {
  const _PatternOverlay({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final t = type.toLowerCase();
    if (t == 'none') return const SizedBox.expand();

    return CustomPaint(
      painter: _PatternPainter(t),
      child: const SizedBox.expand(),
    );
  }
}

class _PatternPainter extends CustomPainter {
  const _PatternPainter(this.type);

  final String type;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.06);
    if (type == 'dots') {
      for (double y = 6; y < size.height; y += 16) {
        for (double x = 6; x < size.width; x += 16) {
          canvas.drawCircle(Offset(x, y), 1.2, paint);
        }
      }
      return;
    }
    if (type == 'grid') {
      for (double y = 0; y < size.height; y += 20) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      for (double x = 0; x < size.width; x += 20) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      return;
    }
    if (type == 'lines') {
      for (double x = -size.height; x < size.width; x += 18) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x + size.height, size.height),
          paint,
        );
      }
      return;
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}
