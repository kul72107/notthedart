// Her "edit edilebilir" widget bunun icinde sarilir.
// - Right-click (web/desktop) veya long-press (mobile) ile secim
// - Hover highlight (dashed border)
// - Editor modu kapaliysa tamamen transparan, sadece child'i gosterir
//
// Kullanim:
//   EditableWidget(
//     id: 'bottom-nav-main',
//     typeName: 'CatBottomNav',
//     builder: (ctx, props, variant) {
//       return CatBottomNav(
//         currentPath: '...',
//         shellColor: props['shellColor'] ?? defaultShellColor,
//         ...
//       );
//     },
//   )
//
// builder: controller'dan gelen property'leri widget'a yansitmaniz icin
// kullanilir. Editor kapaliyken props bos map gelir, default'lar kullanilmali.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'editor_controller.dart';

typedef EditableBuilder =
    Widget Function(
      BuildContext context,
      Map<String, dynamic> props,
      String? variant,
    );

class EditableWidget extends StatelessWidget {
  const EditableWidget({
    super.key,
    required this.id,
    required this.typeName,
    required this.builder,
    this.initialProps,
  });

  final String id;
  final String typeName;
  final EditableBuilder builder;
  final Map<String, dynamic>? initialProps;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EditorController>();
    ctrl.registerWidget(id: id, typeName: typeName, initialProps: initialProps);
    final props = ctrl.propsOf(id);
    final variant = ctrl.variantOf(id);

    final child = builder(context, props, variant);

    if (!ctrl.enabled) return child;

    final isSelected = ctrl.selectedId == id;
    final isHovered = ctrl.hoveredId == id;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => ctrl.setHovered(id),
      onExit: (_) {
        if (ctrl.hoveredId == id) ctrl.setHovered(null);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () => ctrl.select(id),
        onSecondaryTapDown: (details) {
          ctrl.select(id);
        },
        onLongPress: () => ctrl.select(id),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (isSelected || isHovered)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _OutlinePainter(
                      color: isSelected
                          ? const Color(0xFFEF1679)
                          : const Color(0x80EF1679),
                      dashed: !isSelected,
                    ),
                  ),
                ),
              ),
            if (isSelected)
              Positioned(
                top: -20,
                left: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF1679),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$typeName · $id',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = Offset.zero & size;
    if (!dashed) {
      canvas.drawRect(rect, paint);
      return;
    }
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRect(rect);
    final dashedPath = Path();
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        dashedPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _OutlinePainter old) =>
      old.color != color || old.dashed != dashed;
}
