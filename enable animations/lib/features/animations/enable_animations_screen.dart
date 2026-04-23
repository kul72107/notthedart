import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/monetization/native_monetization_bridge.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../shared/widgets/nav_primitives.dart';
import '../shared/widgets/page_gradient.dart';

class EnableAnimationsScreen extends StatefulWidget {
  const EnableAnimationsScreen({super.key});

  @override
  State<EnableAnimationsScreen> createState() => _EnableAnimationsScreenState();
}

class _EnableAnimationsScreenState extends State<EnableAnimationsScreen> {
  static const String _shortAdsKey = 'anim_short_ads_v2';
  static const String _weeklyAdsKey = 'anim_weekly_ads_v2';
  static const String _shortUntilKey = 'anim_short_until_v2';
  static const String _weeklyUntilKey = 'anim_weekly_until_v2';

  bool _loading = true;
  bool _watchingAd = false;
  bool _processingPurchase = false;
  String _mode = 'short';
  String? _error;

  int _shortAdsWatched = 0;
  int _weeklyAdsWatched = 0;
  DateTime? _shortEnabledUntil;
  DateTime? _weeklyEnabledUntil;

  bool get _shortEnabled =>
      _shortEnabledUntil != null && _shortEnabledUntil!.isAfter(DateTime.now());
  bool get _weeklyEnabled =>
      _weeklyEnabledUntil != null && _weeklyEnabledUntil!.isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final shortUntilRaw = prefs.getString(_shortUntilKey);
    final weeklyUntilRaw = prefs.getString(_weeklyUntilKey);
    setState(() {
      _shortAdsWatched = prefs.getInt(_shortAdsKey) ?? 0;
      _weeklyAdsWatched = prefs.getInt(_weeklyAdsKey) ?? 0;
      _shortEnabledUntil = shortUntilRaw == null ? null : DateTime.tryParse(shortUntilRaw);
      _weeklyEnabledUntil = weeklyUntilRaw == null ? null : DateTime.tryParse(weeklyUntilRaw);
      _loading = false;
    });
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shortAdsKey, _shortAdsWatched);
    await prefs.setInt(_weeklyAdsKey, _weeklyAdsWatched);
    if (_shortEnabledUntil != null) {
      await prefs.setString(_shortUntilKey, _shortEnabledUntil!.toIso8601String());
    } else {
      await prefs.remove(_shortUntilKey);
    }
    if (_weeklyEnabledUntil != null) {
      await prefs.setString(_weeklyUntilKey, _weeklyEnabledUntil!.toIso8601String());
    } else {
      await prefs.remove(_weeklyUntilKey);
    }
  }

  Future<void> _watchAd() async {
    if (_watchingAd) return;
    setState(() {
      _watchingAd = true;
      _error = null;
    });
    try {
      final completed = await NativeMonetizationBridge.showRewardedAd();
      if (!mounted) return;
      if (!completed) {
        setState(() => _error = 'Rewarded ad tamamlanmadi.');
        return;
      }

      final now = DateTime.now();
      if (_mode == 'weekly') {
        _weeklyAdsWatched += 1;
        if (_weeklyAdsWatched >= 80) {
          _weeklyEnabledUntil = now.add(const Duration(days: 7));
          _weeklyAdsWatched = 0;
        }
      } else {
        _shortAdsWatched += 1;
        if (_shortAdsWatched >= 3) {
          _shortEnabledUntil = now.add(const Duration(minutes: 5));
          _shortAdsWatched = 0;
        }
      }
      await _persistState();
      if (!mounted) return;
      setState(() {});
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _watchingAd = false);
    }
  }

  Future<void> _subscribeNow() async {
    if (_processingPurchase) return;
    setState(() {
      _processingPurchase = true;
      _error = null;
    });
    try {
      final ok = await NativeMonetizationBridge.startSubscriptionPurchase('1weekanimation');
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'Subscription baslatilamadi.');
      } else {
        context.go('/subscription');
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _processingPurchase = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    backgroundColor: const Color(0x1FFFFFFF),
                    borderColor: const Color(0x40FFB8A5),
                    child: Row(
                      children: [
                        ActionButton(
                          label: 'Enable Animations',
                          variant: ActionButtonVariant.pillPink,
                          fontSize: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          onPressed: null,
                        ),
                        const Spacer(),
                        ActionButton(
                          label: 'Back',
                          variant: ActionButtonVariant.pillDark,
                          fontSize: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: const Icon(
                            Icons.arrow_back_rounded,
                            size: 15,
                            color: Color(0xFFF7E7F9),
                          ),
                          onPressed: () => context.go('/'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 128),
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '1 Week Animations',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Unlock advanced animation controls and premium export flow.',
                                    style: TextStyle(
                                      color: Color(0xE8FFFFFF),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ActionButton(
                                    label: _processingPurchase ? 'Processing...' : 'Subscribe (\$4.99/week)',
                                    variant: ActionButtonVariant.pillPink,
                                    onPressed: _processingPurchase ? null : _subscribeNow,
                                    fullWidth: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Or unlock with ads:',
                              style: TextStyle(
                                color: Color(0xFF4A2F73),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _AdModeCard(
                                    title: 'Quick',
                                    subtitle: '3 ads => 5 min',
                                    progressLabel: '$_shortAdsWatched/3',
                                    progress: _shortAdsWatched / 3,
                                    active: _mode == 'short',
                                    unlocked: _shortEnabled,
                                    onTap: () => setState(() => _mode = 'short'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _AdModeCard(
                                    title: 'Weekly',
                                    subtitle: '80 ads => 7 days',
                                    progressLabel: '$_weeklyAdsWatched/80',
                                    progress: _weeklyAdsWatched / 80,
                                    active: _mode == 'weekly',
                                    unlocked: _weeklyEnabled,
                                    onTap: () => setState(() => _mode = 'weekly'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ActionButton(
                              label: _watchingAd
                                  ? 'Loading...'
                                  : (_mode == 'weekly' ? 'Watch Weekly Ad' : 'Watch Quick Ad'),
                              variant: _mode == 'weekly'
                                  ? ActionButtonVariant.pillPink
                                  : ActionButtonVariant.pillPrimary,
                              onPressed: _watchingAd ? null : _watchAd,
                              fullWidth: true,
                            ),
                            if (_shortEnabledUntil != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Quick unlock until: ${_shortEnabledUntil!.toLocal()}',
                                  style: const TextStyle(
                                    color: Color(0xFF6D28D9),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            if (_weeklyEnabledUntil != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Weekly unlock until: ${_weeklyEnabledUntil!.toLocal()}',
                                  style: const TextStyle(
                                    color: Color(0xFFBE185D),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
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
              ],
            ),
          ),
          CatBottomNav(
            currentPath: '/enable-animations',
            onTap: (path) => context.go(path),
          ),
        ],
      ),
    );
  }
}

class _AdModeCard extends StatelessWidget {
  const _AdModeCard({
    required this.title,
    required this.subtitle,
    required this.progressLabel,
    required this.progress,
    required this.active,
    required this.unlocked,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String progressLabel;
  final double progress;
  final bool active;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? const Color(0xFF8B5CF6) : const Color(0x40948BAF),
              width: active ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3B2363),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF876BBD),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                unlocked ? 'Unlocked' : progressLabel,
                style: TextStyle(
                  color: unlocked ? const Color(0xFF15803D) : const Color(0xFF6D28D9),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: unlocked ? 1 : progress.clamp(0.0, 1.0).toDouble(),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE5E7EB),
                  color: unlocked ? const Color(0xFF22C55E) : const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
