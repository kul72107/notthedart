import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PinnedHeaderFade extends StatelessWidget {
  const PinnedHeaderFade({
    super.key,
    required this.color,
    this.height = 68,
  });

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color,
              color.withValues(alpha: 0.86),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassHeaderShell extends StatelessWidget {
  const GlassHeaderShell({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.all(0),
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 10),
    this.blurSigma = 20,
    this.borderRadius = 18,
    this.backgroundColor = const Color(0x1FFFFFFF),
    this.borderColor = const Color(0x40FFB8A5),
    this.boxShadow = const <BoxShadow>[
      BoxShadow(
        color: Color(0x29462C71),
        blurRadius: 16,
        offset: Offset(0, 8),
      ),
    ],
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final List<BoxShadow> boxShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor),
              boxShadow: boxShadow,
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class TopPillRow extends StatelessWidget {
  const TopPillRow({
    super.key,
    required this.children,
    this.spacing = 8,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}
