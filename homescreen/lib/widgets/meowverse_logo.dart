// Web'deki .cat-home-logo __glow / __stroke / __text katmanlarinin Flutter
// karsiligi. Particles ve flames siralamaya alinmadi - onlar dekoratif animasyon
// katmanlari (radyal gradient + clip-path + keyframes), ayri bir gecis gerekir.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MeowVerseLogo extends StatelessWidget {
  const MeowVerseLogo({
    super.key,
    this.text = 'MeowVerse',
    this.fontSize = 82,
    this.outlineWidth = 8,
    this.glowStroke = 14,
    this.scale = 1,
  });

  final String text;

  /// Web: clamp(54px, 11vw, 82px). Mobilde ekran genisligine gore LayoutBuilder
  /// ile disaridan ayarlamak icin parametre.
  final double fontSize;

  /// Web: --cat-home-logo-outline-width (default 8px).
  final double outlineWidth;

  /// Web: --cat-home-logo-glow-stroke clamp(10px, 1.5vw, 18px).
  final double glowStroke;

  /// Web: --cat-home-logo-scale.
  final double scale;

  static const _fontFamily = 'Big Dazzle';
  static const _heightFactor = 0.82; // line-height: 0.82

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      letterSpacing: fontSize * 0.01,
      height: _heightFactor,
    );

    // Layer 1: glow - blurlu mor stroke.
    // Web: color rgba(220,169,255,0.95), stroke rgba(142,70,210,0.82), opacity 0.68,
    // text-shadow rgba(179,104,255,0.9) cevresinde.
    final glow = Opacity(
      opacity: 0.68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Stroke + subtle blur
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
            child: Text(
              text,
              style: baseStyle.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = glowStroke
                  ..color = const Color(0xD18E46D2), // rgba(142,70,210,0.82)
                shadows: const [
                  Shadow(
                    color: Color(0xE6B368FF), // rgba(179,104,255,0.9)
                    offset: Offset(-2, 0),
                  ),
                  Shadow(color: Color(0xE6B368FF), offset: Offset(2, 0)),
                  Shadow(color: Color(0xE6B368FF), offset: Offset(0, -2)),
                  Shadow(
                    color: Color(0xC27039AC), // rgba(112,57,172,0.76)
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
          // Fill rgba(220,169,255,0.95) - blurred
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 0.6, sigmaY: 0.6),
            child: Text(
              text,
              style: baseStyle.copyWith(
                color: const Color(0xF2DCA9FF), // rgba(220,169,255,0.95)
              ),
            ),
          ),
        ],
      ),
    );

    // Layer 2: stroke - 8px solid mor (#462c71) outline.
    final stroke = Text(
      text,
      style: baseStyle.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF462C71),
        shadows: const [
          Shadow(
            color: Color(0x333A2161), // rgba(58,33,97,0.2)
            offset: Offset(0, 3),
          ),
          Shadow(
            color: Color(0x2E5F3892), // rgba(95,56,146,0.18)
            offset: Offset(0, 7),
          ),
        ],
      ),
    );

    // Layer 3: gradient fill - beyaz -> pembe dikey gradient.
    // Web: linear-gradient(180deg, #fffdfd 0%, #ffd6f4 100%).
    final gradientFill = ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFDFD), Color(0xFFFFD6F4)],
      ).createShader(rect),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        style: baseStyle.copyWith(
          color: Colors.white,
          shadows: const [
            Shadow(
              color: Color(0x24FFFFFF), // rgba(255,255,255,0.14)
              offset: Offset(0, 2),
            ),
            Shadow(
              color: Color(0x2E5F3892), // rgba(95,56,146,0.18)
              offset: Offset(0, 6),
            ),
          ],
        ),
      ),
    );

    return Transform.scale(
      scale: scale,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 30, 12, 26),
        child: Stack(
          alignment: Alignment.center,
          children: [glow, stroke, gradientFill],
        ),
      ),
    );
  }
}
