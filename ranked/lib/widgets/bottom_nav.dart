// Web'deki src/components/BottomNav.jsx'in Flutter karsiligi.
// Iki mod: normal (pink shell) ve market (purple shell). Route'a gore aktif
// sekme degisir; market modda 3. secenek (Satislarim) /my-listings'e goturur.
//
// Web'de backdrop-filter: blur(18-20px) kullaniliyor. Flutter'da BackdropFilter
// + ImageFilter.blur ile birebir.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../editor/editable_widget.dart';
import '../editor/variants/navbar_variants.dart';
import '../core/config/nav_visibility_policy.dart';
import '../theme/app_colors.dart';

enum BottomNavMode { home, market }

enum MarketSubTab { explore, list }

class BottomNavItem {
  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.route,
    required this.matches,
  });

  final String label;
  final IconData icon;
  final String route;

  /// Bu sekmenin aktif sayildigi route prefix'leri.
  final List<String> matches;
}

const _mainNav = <BottomNavItem>[
  BottomNavItem(
    label: 'Home',
    icon: Icons.home_rounded,
    route: '/',
    matches: ['/', '/create'],
  ),
  BottomNavItem(
    label: 'Market',
    icon: Icons.storefront_rounded,
    route: '/market-cats',
    matches: ['/market-cats'],
  ),
  BottomNavItem(
    label: 'Explore',
    icon: Icons.explore_rounded,
    route: '/explore',
    matches: ['/explore'],
  ),
  BottomNavItem(
    label: 'CL Shop',
    icon: Icons.shopping_bag_rounded,
    route: '/market',
    matches: ['/market'],
  ),
  BottomNavItem(
    label: 'Premium',
    icon: Icons.star_rounded,
    route: '/enable-animations',
    matches: ['/enable-animations', '/subscription'],
  ),
];

class CatBottomNav extends StatelessWidget {
  const CatBottomNav({
    super.key,
    required this.currentPath,
    required this.onTap,
    this.marketMode,
    this.onMarketModeChange,
  });

  final String currentPath;
  final void Function(String route) onTap;

  /// Eger non-null verilirse bottom nav market moda gecer ve MarketSubTab
  /// segment secici olur (explore/list). onMarketModeChange de gerekli.
  final MarketSubTab? marketMode;
  final ValueChanged<MarketSubTab>? onMarketModeChange;

  bool get _isMarket =>
      currentPath.startsWith('/market-cats') ||
      currentPath.startsWith('/my-listings') ||
      marketMode != null;

  @override
  Widget build(BuildContext context) {
    if (!NavVisibilityPolicy.shouldShowBottomNav(currentPath)) {
      return const SizedBox.shrink();
    }
    final isMarket = _isMarket;
    final defaults = _defaultEditorProps(isMarket);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Center(
        child: EditableWidget(
          id: 'bottom-nav-main',
          typeName: 'CatBottomNav',
          initialProps: defaults,
          builder: (ctx, props, variant) {
            final style = Map<String, dynamic>.from(defaults)..addAll(props);
            return _buildShell(ctx, style, isMarket);
          },
        ),
      ),
    );
  }

  Map<String, dynamic> _defaultEditorProps(bool isMarket) {
    return Map<String, dynamic>.from(
      isMarket ? NavbarVariants.marketPurple : NavbarVariants.classicPink,
    );
  }

  Color _color(Map<String, dynamic> style, String key, Color fallback) {
    final raw = style[key];
    if (raw is int) return Color(raw);
    if (raw is num) return Color(raw.toInt());
    return fallback;
  }

  double _number(Map<String, dynamic> style, String key, double fallback) {
    final raw = style[key];
    if (raw is num) return raw.toDouble();
    return fallback;
  }

  Widget _buildShell(
    BuildContext context,
    Map<String, dynamic> style,
    bool isMarket,
  ) {
    final mq = MediaQuery.of(context);
    final maxW = 430.0;
    final w = mq.size.width > maxW ? maxW : mq.size.width;

    final mode = (style['mode']?.toString() ?? (isMarket ? 'purple' : 'pink'))
        .toLowerCase();
    final cornerRadius = _number(style, 'cornerRadius', 0);
    final borderWidth = _number(style, 'borderWidth', 1);
    final shellColor = _color(
      style,
      'shellColor',
      isMarket ? AppColors.navShellPurple : AppColors.navShellPink,
    );
    final borderColor = _color(
      style,
      'borderColor',
      isMarket ? AppColors.navBorderPurple : AppColors.navBorderPink,
    );
    final shadowColor = _color(
      style,
      'shadowColor',
      isMarket ? const Color(0x384C2D7F) : const Color(0x19C0648C),
    );
    final shadowY = _number(style, 'shadowOffsetY', isMarket ? -6 : -4);
    final shadowBlur = _number(style, 'shadowBlur', 20);
    final blurSigma = _number(style, 'blurSigma', isMarket ? 18 : 20);

    final activeColor = _color(
      style,
      'activeColor',
      isMarket ? AppColors.navMarketActive : AppColors.navActive,
    );
    final idleColor = _color(
      style,
      'idleColor',
      isMarket ? AppColors.navMarketIdle : AppColors.navIdle,
    );
    final indicatorStart = _color(
      style,
      'indicatorStart',
      isMarket ? AppColors.indicatorPurpleA : AppColors.indicatorPinkA,
    );
    final indicatorEnd = _color(
      style,
      'indicatorEnd',
      isMarket ? AppColors.indicatorPurpleB : AppColors.indicatorPinkB,
    );
    final iconSize = _number(style, 'iconSize', isMarket ? 20 : 19);
    final labelSize = _number(style, 'labelSize', 11);
    final indicatorWidth = _number(style, 'indicatorWidth', 16);
    final indicatorHeight = _number(style, 'indicatorHeight', 2);
    final bubbleMode = indicatorWidth > 24 && indicatorHeight > 24;

    final shellDecoration = BoxDecoration(
      color: shellColor,
      borderRadius: cornerRadius > 0
          ? BorderRadius.circular(cornerRadius)
          : null,
      border: borderWidth <= 0
          ? null
          : (mode == 'pink' && cornerRadius == 0
                ? Border(
                    top: BorderSide(color: borderColor, width: borderWidth),
                  )
                : Border.all(color: borderColor, width: borderWidth)),
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          offset: Offset(0, shadowY),
          blurRadius: shadowBlur,
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: cornerRadius > 0 ? 12 : 0),
      child: SizedBox(
        width: w,
        child: ClipRRect(
          borderRadius: cornerRadius > 0
              ? BorderRadius.circular(cornerRadius)
              : BorderRadius.zero,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: DecoratedBox(
              decoration: shellDecoration,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      color: Colors.white.withValues(
                        alpha: isMarket ? 0.32 : 0.24,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: (cornerRadius > 0 ? 8 : 0) + mq.padding.bottom,
                    ),
                    child: isMarket && onMarketModeChange != null
                        ? _buildMarket(
                            context,
                            activeColor: activeColor,
                            idleColor: idleColor,
                            indicatorStart: indicatorStart,
                            indicatorEnd: indicatorEnd,
                            iconSize: iconSize,
                            labelSize: labelSize,
                            indicatorWidth: indicatorWidth,
                            indicatorHeight: indicatorHeight,
                            bubbleMode: bubbleMode,
                          )
                        : _buildMain(
                            context,
                            activeColor: activeColor,
                            idleColor: idleColor,
                            indicatorStart: indicatorStart,
                            indicatorEnd: indicatorEnd,
                            iconSize: iconSize,
                            labelSize: labelSize,
                            indicatorWidth: indicatorWidth,
                            indicatorHeight: indicatorHeight,
                            bubbleMode: bubbleMode,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMain(
    BuildContext context, {
    required Color activeColor,
    required Color idleColor,
    required Color indicatorStart,
    required Color indicatorEnd,
    required double iconSize,
    required double labelSize,
    required double indicatorWidth,
    required double indicatorHeight,
    required bool bubbleMode,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: _mainNav.map((item) {
          final active = _isActive(item);
          return Expanded(
            child: _NavTile(
              icon: item.icon,
              label: item.label,
              active: active,
              activeColor: activeColor,
              idleColor: idleColor,
              indicatorColors: [indicatorStart, indicatorEnd],
              iconSize: iconSize,
              labelSize: labelSize,
              indicatorWidth: indicatorWidth,
              indicatorHeight: indicatorHeight,
              bubbleMode: bubbleMode,
              onTap: () => onTap(item.route),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMarket(
    BuildContext context, {
    required Color activeColor,
    required Color idleColor,
    required Color indicatorStart,
    required Color indicatorEnd,
    required double iconSize,
    required double labelSize,
    required double indicatorWidth,
    required double indicatorHeight,
    required bool bubbleMode,
  }) {
    final indicatorColors = [indicatorStart, indicatorEnd];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _NavTile(
              icon: Icons.explore_rounded,
              label: 'Explore',
              active: marketMode == MarketSubTab.explore,
              activeColor: activeColor,
              idleColor: idleColor,
              indicatorColors: indicatorColors,
              iconSize: iconSize,
              labelSize: labelSize,
              indicatorWidth: indicatorWidth,
              indicatorHeight: indicatorHeight,
              bubbleMode: bubbleMode,
              onTap: () => onMarketModeChange?.call(MarketSubTab.explore),
            ),
          ),
          Expanded(
            child: _NavTile(
              icon: Icons.list_rounded,
              label: 'List',
              active: marketMode == MarketSubTab.list,
              activeColor: activeColor,
              idleColor: idleColor,
              indicatorColors: indicatorColors,
              iconSize: iconSize,
              labelSize: labelSize,
              indicatorWidth: indicatorWidth,
              indicatorHeight: indicatorHeight,
              bubbleMode: bubbleMode,
              onTap: () => onMarketModeChange?.call(MarketSubTab.list),
            ),
          ),
          Expanded(
            child: _NavTile(
              icon: Icons.list_alt_rounded,
              label: 'Satislarim',
              active: currentPath.startsWith('/my-listings'),
              activeColor: activeColor,
              idleColor: idleColor,
              indicatorColors: indicatorColors,
              iconSize: iconSize,
              labelSize: labelSize,
              indicatorWidth: indicatorWidth,
              indicatorHeight: indicatorHeight,
              bubbleMode: bubbleMode,
              onTap: () => onTap('/my-listings'),
            ),
          ),
        ],
      ),
    );
  }

  bool _isActive(BottomNavItem item) {
    // Home: '/' veya '/create' prefix
    if (item.matches.contains('/') && item.matches.contains('/create')) {
      return currentPath == '/' || currentPath.startsWith('/create');
    }
    return item.matches.any((p) => currentPath.startsWith(p));
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.idleColor,
    required this.indicatorColors,
    required this.iconSize,
    required this.labelSize,
    required this.indicatorWidth,
    required this.indicatorHeight,
    required this.bubbleMode,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color idleColor;
  final List<Color> indicatorColors;
  final double iconSize;
  final double labelSize;
  final double indicatorWidth;
  final double indicatorHeight;
  final bool bubbleMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : idleColor;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bubbleMode && active)
          Container(
            width: indicatorWidth,
            height: indicatorHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: indicatorColors),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: iconSize, color: color),
          )
        else
          Icon(icon, size: iconSize, color: color),
        if (labelSize > 0) ...[
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: labelSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (!bubbleMode) ...[
          const SizedBox(height: 2),
          SizedBox(
            height: indicatorHeight,
            width: indicatorWidth,
            child: active
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        indicatorHeight > 5 ? indicatorHeight / 2 : 2,
                      ),
                      gradient: LinearGradient(
                        colors: indicatorColors,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: body,
        ),
      ),
    );
  }
}
