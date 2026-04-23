// Web'deki .cat-home-action-button ve .cat-home-pill-button'larin Flutter
// karsiligi. Tum varyantlar AppGradients'tan beslenir.
//
// Web'de ortak:
//   - border: solid #462c71 (action 5px, pill 3px)
//   - box-shadow: dis lila golge + ic beyaz 1px highlight
//   - ::after overlay: yukari beyaz sheen (mix-blend-mode: screen)
//   - hover: translateY(-1px) + saturate 1.05 brightness 1.02
//
// Flutter'da hover mobilde karsilik bulmadigindan onTap basinca kucuk
// scale-down (daha native hissi) uygulaniyor. Gorsel olarak degisen bir sey yok;
// sadece basma feedback'i.

import 'package:flutter/material.dart';

import '../editor/editable_widget.dart';
import '../theme/app_colors.dart';

enum ActionButtonVariant {
  // --- Action (buyuk) varyantlari ---
  pink,
  purple,
  white,
  amber,
  // --- Pill (kucuk) varyantlari ---
  pillDark,
  pillPink,
  pillSoft,
  pillPrimary,
  pillSuccess,
  pillMuted,
  pillSoftPurple,
  pillPinkSoft,
  // --- Action extra (rank, CTA) ---
  actionPrimary,
  actionSoft,
  actionSuccess,
  actionDanger,
}

enum ActionButtonSize { action, pill }

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.variant,
    this.size,
    this.onPressed,
    this.leading,
    this.trailing,
    this.fullWidth = false,
    this.padding,
    this.fontSize,
    this.borderRadius,
    this.editorId,
  });

  final String label;
  final ActionButtonVariant variant;

  /// Size belirtilmezse variant'tan cikartilir (action* -> action, pill* -> pill).
  final ActionButtonSize? size;

  final VoidCallback? onPressed;
  final Widget? leading;
  final Widget? trailing;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final double? borderRadius;
  final String? editorId;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _pressed = false;
  late final String _editorId;

  @override
  void initState() {
    super.initState();
    _editorId =
        widget.editorId ??
        'action-button-${_normalize(widget.label)}-${identityHashCode(this)}';
  }

  String _normalize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  ActionButtonSize get _effectiveSize {
    if (widget.size != null) return widget.size!;
    switch (widget.variant) {
      case ActionButtonVariant.pillDark:
      case ActionButtonVariant.pillPink:
      case ActionButtonVariant.pillSoft:
      case ActionButtonVariant.pillPrimary:
      case ActionButtonVariant.pillSuccess:
      case ActionButtonVariant.pillMuted:
      case ActionButtonVariant.pillSoftPurple:
      case ActionButtonVariant.pillPinkSoft:
        return ActionButtonSize.pill;
      default:
        return ActionButtonSize.action;
    }
  }

  List<Color> get _gradient {
    switch (widget.variant) {
      case ActionButtonVariant.pink:
        return AppGradients.gradActionPinkWeb;
      case ActionButtonVariant.purple:
        return AppGradients.gradActionPurpleWeb;
      case ActionButtonVariant.white:
        return AppGradients.gradActionWhiteWeb;
      case ActionButtonVariant.amber:
        return AppGradients.gradActionAmberWeb;
      case ActionButtonVariant.pillDark:
        return AppGradients.gradPillDark;
      case ActionButtonVariant.pillPink:
        return AppGradients.gradPillPink;
      case ActionButtonVariant.pillSoft:
        return AppGradients.gradPillSoftPurple;
      case ActionButtonVariant.pillPrimary:
        return AppGradients.gradPillPrimary;
      case ActionButtonVariant.pillSuccess:
        return AppGradients.gradPillSuccess;
      case ActionButtonVariant.pillMuted:
        return AppGradients.gradPillMuted;
      case ActionButtonVariant.pillSoftPurple:
        return AppGradients.gradPillSoftPurple;
      case ActionButtonVariant.pillPinkSoft:
        return AppGradients.gradPillPinkSoft;
      case ActionButtonVariant.actionPrimary:
        return AppGradients.gradActionPrimary;
      case ActionButtonVariant.actionSoft:
        return AppGradients.gradActionSoft;
      case ActionButtonVariant.actionSuccess:
        return AppGradients.gradActionSuccess;
      case ActionButtonVariant.actionDanger:
        return AppGradients.gradActionDanger;
    }
  }

  Color get _textColor {
    switch (widget.variant) {
      case ActionButtonVariant.white:
      case ActionButtonVariant.actionSoft:
      case ActionButtonVariant.pillSoft:
      case ActionButtonVariant.pillSoftPurple:
      case ActionButtonVariant.pillMuted:
      case ActionButtonVariant.pillPinkSoft:
        return AppColors.textPillSoft;
      case ActionButtonVariant.pillDark:
        return AppColors.textPillDark;
      case ActionButtonVariant.pillSuccess:
        return AppColors.textPillSuccess;
      default:
        return AppColors.textOnDark;
    }
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

  List<Color> _gradientFrom(dynamic raw, List<Color> fallback) {
    if (raw is List) {
      final out = <Color>[];
      for (final v in raw) {
        if (v is int) out.add(Color(v));
        if (v is num) out.add(Color(v.toInt()));
      }
      if (out.length >= 2) return out;
    }
    return fallback;
  }

  EdgeInsets _paddingFrom(dynamic raw, EdgeInsets fallback) {
    if (raw is Map) {
      final top = _number(raw['top'], fallback.top);
      final right = _number(raw['right'], fallback.right);
      final bottom = _number(raw['bottom'], fallback.bottom);
      final left = _number(raw['left'], fallback.left);
      return EdgeInsets.fromLTRB(left, top, right, bottom);
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isAction = _effectiveSize == ActionButtonSize.action;
    final baseBorderW = isAction ? 5.0 : 3.0;
    final baseRadius = widget.borderRadius ?? (isAction ? 26.0 : 9999.0);
    final basePad =
        (widget.padding ??
                (isAction
                    ? const EdgeInsets.symmetric(horizontal: 22, vertical: 14)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 10)))
            .resolve(Directionality.of(context));
    final baseFontS = widget.fontSize ?? (isAction ? 18.0 : 14.0);
    final baseGradient = _gradient;
    final baseTextColor = _textColor;
    final baseShadowSpecs = isAction
        ? AppShadows.actionButton
        : AppShadows.pillButton;
    final baseShadow = baseShadowSpecs.isNotEmpty
        ? baseShadowSpecs.first
        : ShadowSpec(
            color: Colors.transparent,
            blur: 0,
            spread: 0,
            offsetX: 0,
            offsetY: 0,
          );

    return EditableWidget(
      id: _editorId,
      typeName: 'ActionButton',
      initialProps: <String, dynamic>{
        'gradient': baseGradient.map((c) => c.toARGB32()).toList(),
        'borderColor': AppColors.textPurpleDeep.toARGB32(),
        'borderWidth': baseBorderW,
        'textColor': baseTextColor.toARGB32(),
        'fontSize': baseFontS,
        'borderRadius': baseRadius,
        'padding': <String, dynamic>{
          'top': basePad.top,
          'right': basePad.right,
          'bottom': basePad.bottom,
          'left': basePad.left,
        },
        'shadowColor': baseShadow.color.toARGB32(),
        'shadowOffsetY': baseShadow.offsetY,
        'shadowBlur': baseShadow.blur,
        'hasSheen': true,
      },
      builder: (ctx, props, variant) {
        final gradient = _gradientFrom(props['gradient'], baseGradient);
        final borderColor = _color(
          props['borderColor'],
          AppColors.textPurpleDeep,
        );
        final borderWidth = _number(props['borderWidth'], baseBorderW);
        final textColor = _color(props['textColor'], baseTextColor);
        final fontS = _number(props['fontSize'], baseFontS);
        final radius = _number(props['borderRadius'], baseRadius);
        final pad = _paddingFrom(props['padding'], basePad);
        final shadowColor = _color(props['shadowColor'], baseShadow.color);
        final shadowY = _number(props['shadowOffsetY'], baseShadow.offsetY);
        final shadowBlur = _number(props['shadowBlur'], baseShadow.blur);
        final hasSheen = props['hasSheen'] is bool
            ? props['hasSheen'] as bool
            : true;

        final child = Stack(
          children: [
            Padding(
              padding: pad,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: textColor,
                  fontSize: fontS,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  height: 1.15,
                ),
                child: Row(
                  mainAxisSize: widget.fullWidth
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.leading != null) ...[
                      widget.leading!,
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(widget.label, textAlign: TextAlign.center),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 8),
                      widget.trailing!,
                    ],
                  ],
                ),
              ),
            ),
            if (hasSheen)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x42FFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );

        final decorated = AnimatedScale(
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: gradient,
              ),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  offset: Offset(0, shadowY),
                  blurRadius: shadowBlur,
                  spreadRadius: baseShadow.spread,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: child,
            ),
          ),
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            borderRadius: BorderRadius.circular(radius),
            splashColor: Colors.white.withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: SizedBox(
              width: widget.fullWidth ? double.infinity : null,
              child: decorated,
            ),
          ),
        );
      },
    );
  }
}
