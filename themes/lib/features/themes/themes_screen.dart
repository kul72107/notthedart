import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/widgets/nav_primitives.dart';
import '../shared/widgets/page_gradient.dart';

class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  static const String _themeKey = 'meowverse_theme_key_v2';

  bool _didInit = false;
  bool _loading = true;
  String? _error;
  String _activeTheme = 'none';
  double _cpBalance = 0;
  Set<String> _ownedThemes = <String>{'none'};
  String? _buying;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    final api = MeowverseApi(context.read<ApiClient>());
    setState(() {
      _loading = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final selectedTheme = prefs.getString(_themeKey) ?? 'none';

    if (!auth.isSignedIn) {
      if (!mounted) return;
      setState(() {
        _activeTheme = selectedTheme;
        _loading = false;
      });
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        api.fetchCatpoisonBalance(),
        api.fetchThemes(),
      ]);
      if (!mounted) return;

      final cp = results[0] as CatpoisonBalance;
      final themesPayload = results[1] as Map<String, dynamic>;
      final rawThemes = (themesPayload['themes'] as List?) ?? const [];

      setState(() {
        _activeTheme = selectedTheme;
        _cpBalance = cp.balance;
        _ownedThemes = <String>{
          'none',
          ...rawThemes.map((item) => item.toString()),
        };
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _activeTheme = selectedTheme;
        _loading = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _activateTheme(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, key);
    if (!mounted) return;
    setState(() => _activeTheme = key);
  }

  Future<void> _buyTheme(_ThemeDef theme) async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      context.go('/login');
      return;
    }
    if (_cpBalance < theme.price) {
      setState(() => _error = 'Yetersiz CP bakiyesi.');
      return;
    }

    setState(() {
      _buying = theme.key;
      _error = null;
    });

    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final result = await api.buyTheme(theme.key);
      if (!mounted) return;
      final newBalance = _toDouble(result['newBalance']) ?? _cpBalance;
      setState(() {
        _cpBalance = newBalance;
        _ownedThemes = <String>{..._ownedThemes, theme.key};
      });
      await _activateTheme(theme.key);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PageGradient()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: GlassHeaderShell(
                    backgroundColor: const Color(0xCCFFFFFF),
                    borderColor: const Color(0x33FFB8A5),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => context.go('/my-cats'),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Temalar',
                          style: TextStyle(
                            color: Color(0xFF3B2363),
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                          ),
                        ),
                        const Spacer(),
                        if (auth.isSignedIn)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: const Color(0xD6F7EFFF),
                              border: Border.all(
                                color: const Color(0x47634995),
                              ),
                            ),
                            child: Text(
                              '${_cpBalance.toStringAsFixed(1)} CP',
                              style: const TextStyle(
                                color: Color(0xFF184D2D),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 128),
                      children: [
                        _CurrentThemeCard(activeTheme: _activeTheme),
                        const SizedBox(height: 10),
                        _ThemeCard(
                          label: 'Default',
                          emoji: 'CAT',
                          subtitle: 'Free',
                          active: _activeTheme == 'none',
                          owned: true,
                          onActivate: () => _activateTheme('none'),
                        ),
                        const SizedBox(height: 10),
                        for (final theme in _themeDefs) ...[
                          _ThemeCard(
                            label: theme.name,
                            emoji: theme.shortCode,
                            subtitle: '${theme.price.toStringAsFixed(0)} CP',
                            active: _activeTheme == theme.key,
                            owned: _ownedThemes.contains(theme.key),
                            buying: _buying == theme.key,
                            swatchA: theme.colorA,
                            swatchB: theme.colorB,
                            onBuy: () => _buyTheme(theme),
                            onActivate: () => _activateTheme(theme.key),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (!auth.isSignedIn)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0x40948BAF)),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Tema satin almak icin login ol.',
                                  style: TextStyle(
                                    color: Color(0xFF4A2F73),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ActionButton(
                                  label: 'Login',
                                  variant: ActionButtonVariant.pillPrimary,
                                  onPressed: () => context.go('/login'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          CatBottomNav(
            currentPath: '/themes',
            onTap: (path) => context.go(path),
          ),
        ],
      ),
    );
  }
}

class _CurrentThemeCard extends StatelessWidget {
  const _CurrentThemeCard({required this.activeTheme});

  final String activeTheme;

  @override
  Widget build(BuildContext context) {
    final match = _themeDefs.where((theme) => theme.key == activeTheme).toList();
    final name = activeTheme == 'none' || match.isEmpty ? 'Default' : match.first.name;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x40948BAF)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.palette_rounded, color: Color(0xFF7A4DDD)),
          const SizedBox(width: 8),
          Text(
            'Active Theme: $name',
            style: const TextStyle(
              color: Color(0xFF3E295F),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.label,
    required this.emoji,
    required this.subtitle,
    required this.active,
    required this.owned,
    required this.onActivate,
    this.onBuy,
    this.buying = false,
    this.swatchA = const Color(0xFFE9D5FF),
    this.swatchB = const Color(0xFFFBCFE8),
  });

  final String label;
  final String emoji;
  final String subtitle;
  final bool active;
  final bool owned;
  final bool buying;
  final Color swatchA;
  final Color swatchB;
  final VoidCallback onActivate;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? const Color(0xFF8B5CF6) : const Color(0x40948BAF),
          width: active ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [swatchA, swatchB],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: const TextStyle(
                color: Color(0xFF3B2363),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF3B2363),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF876BBD),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (owned)
            ActionButton(
              label: active ? 'Active' : 'Use',
              variant: active ? ActionButtonVariant.pillPrimary : ActionButtonVariant.pillSoftPurple,
              onPressed: onActivate,
            )
          else
            ActionButton(
              label: buying ? '...' : subtitle,
              variant: ActionButtonVariant.pillSuccess,
              onPressed: buying ? null : onBuy,
            ),
        ],
      ),
    );
  }
}

class _ThemeDef {
  const _ThemeDef({
    required this.key,
    required this.name,
    required this.price,
    required this.shortCode,
    required this.colorA,
    required this.colorB,
  });

  final String key;
  final String name;
  final double price;
  final String shortCode;
  final Color colorA;
  final Color colorB;
}

const List<_ThemeDef> _themeDefs = <_ThemeDef>[
  _ThemeDef(
    key: 'ocean',
    name: 'Deep Ocean',
    price: 200,
    shortCode: 'OCE',
    colorA: Color(0xFF0EA5E9),
    colorB: Color(0xFF06B6D4),
  ),
  _ThemeDef(
    key: 'haunted',
    name: 'Haunted Castle',
    price: 250,
    shortCode: 'HNT',
    colorA: Color(0xFF4C1D95),
    colorB: Color(0xFF7C3AED),
  ),
  _ThemeDef(
    key: 'sakura',
    name: 'Sakura Dream',
    price: 250,
    shortCode: 'SAK',
    colorA: Color(0xFFF9A8D4),
    colorB: Color(0xFFEC4899),
  ),
  _ThemeDef(
    key: 'galaxy',
    name: 'Galaxy Nebula',
    price: 500,
    shortCode: 'GLX',
    colorA: Color(0xFF312E81),
    colorB: Color(0xFF7C3AED),
  ),
];

double? _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
