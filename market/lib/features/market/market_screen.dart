import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/monetization/native_monetization_bridge.dart';
import '../../core/network/api_client.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/widgets/nav_primitives.dart';
import '../shared/widgets/page_gradient.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  static const List<_CpPackage> _cpPackages = <_CpPackage>[
    _CpPackage(key: '2', cp: 2, usd: 1, label: 'Starter'),
    _CpPackage(key: '12', cp: 12, usd: 5, label: 'Value', bonus: 2),
    _CpPackage(key: '25', cp: 25, usd: 10, label: 'Popular', bonus: 5),
    _CpPackage(key: '65', cp: 65, usd: 25, label: 'Pro', bonus: 15),
    _CpPackage(key: '140', cp: 140, usd: 50, label: 'Ultra', bonus: 40),
    _CpPackage(key: '300', cp: 300, usd: 100, label: 'Mega', bonus: 100),
  ];

  static const List<_ClFallbackOffer> _fallbackOffers = <_ClFallbackOffer>[
    _ClFallbackOffer(key: '1', catlove: 25, usd: 1, label: 'Starter'),
    _ClFallbackOffer(key: '5', catlove: 150, usd: 5, label: 'Popular', bonusPercent: 5),
    _ClFallbackOffer(key: '10', catlove: 350, usd: 10, label: 'Pro', bonusPercent: 10),
    _ClFallbackOffer(key: '25', catlove: 1000, usd: 25, label: 'Ultimate', bonusPercent: 20),
  ];

  bool _didInit = false;
  bool _loading = true;
  bool _watchingAd = false;
  String _tab = 'cl';
  String? _busyKey;
  String? _error;

  double _clBalance = 0;
  double _cpBalance = 0;
  int _watchedToday = 0;
  List<_ClUiOffer> _clOffers = _fallbackOffers
      .map(
        (offer) => _ClUiOffer(
          key: offer.key,
          catlove: offer.catlove,
          usd: offer.usd,
          label: offer.label,
          bonusPercent: offer.bonusPercent,
        ),
      )
      .toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final results = await Future.wait<dynamic>([
        api.fetchCatloveBalance(),
        api.fetchCatpoisonBalance(),
        api.fetchCatloveOffers(),
      ]);
      if (!mounted) return;
      final clBalance = results[0] as CatloveBalance;
      final cpBalance = results[1] as CatpoisonBalance;
      final offers = results[2] as CatloveOffersResponse;

      setState(() {
        _clBalance = clBalance.balance;
        _cpBalance = cpBalance.balance;
        _watchedToday = cpBalance.watchedToday;
        if (offers.offers.isNotEmpty) {
          _clOffers = offers.offers
              .map(
                (offer) => _ClUiOffer(
                  key: offer.key,
                  catlove: offer.catlove,
                  usd: offer.usd,
                  label: _labelForClKey(offer.key),
                  bonusPercent: offer.bonusPercent,
                ),
              )
              .toList();
        }
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _buyCl(_ClUiOffer offer) async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      context.go('/login');
      return;
    }
    setState(() {
      _busyKey = 'cl_${offer.key}';
      _error = null;
    });

    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final result = await api.purchaseCatlove(offer.key);
      if (!mounted) return;
      final next = _toDouble(result['newBalance']) ?? _clBalance;
      setState(() => _clBalance = next);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _buyCp(_CpPackage pkg) async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      context.go('/login');
      return;
    }
    setState(() {
      _busyKey = 'cp_${pkg.key}';
      _error = null;
    });
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final result = await api.buyCpPack(pkg.key);
      if (!mounted) return;
      final next = _toDouble(result['newBalance']) ?? _cpBalance;
      setState(() => _cpBalance = next);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _watchAdForCp() async {
    final auth = context.read<AuthController>();
    final api = MeowverseApi(context.read<ApiClient>());
    if (!auth.isSignedIn) {
      context.go('/login');
      return;
    }
    if (_watchingAd) return;
    setState(() {
      _watchingAd = true;
      _error = null;
    });

    try {
      final adCompleted = await NativeMonetizationBridge.showRewardedAd();
      if (!adCompleted) {
        if (!mounted) return;
        setState(() => _error = 'Rewarded ad tamamlanamadi.');
        return;
      }

      final result = await api.watchAdForCp();
      if (!mounted) return;
      setState(() {
        _cpBalance = _toDouble(result['newBalance']) ?? _cpBalance;
        _watchedToday = _toInt(result['watchedToday']) ?? _watchedToday;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) {
        setState(() => _watchingAd = false);
      }
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
                _MarketHeader(
                  clBalance: _clBalance,
                  cpBalance: _cpBalance,
                  selectedTab: _tab,
                  onBack: () => context.go('/'),
                  onTabChanged: (next) => setState(() => _tab = next),
                ),
                if (_loading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    ),
                  )
                else if (!auth.isSignedIn)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'CL Shop icin giris yapman gerekiyor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF4A2F73),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ActionButton(
                              label: 'Login',
                              variant: ActionButtonVariant.pillPrimary,
                              onPressed: () => context.go('/login'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _tab == 'cl' ? _buildClList() : _buildCpList(),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
            currentPath: '/market',
            onTap: (path) => context.go(path),
          ),
        ],
      ),
    );
  }

  Widget _buildClList() {
    return ListView.builder(
      key: const ValueKey<String>('cl-list'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 128),
      itemCount: _clOffers.length,
      itemBuilder: (context, index) {
        final offer = _clOffers[index];
        final busy = _busyKey == 'cl_${offer.key}';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x40948BAF)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF9A8D4), Color(0xFFEC4899)],
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'CL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.label,
                      style: const TextStyle(
                        color: Color(0xFF3B2363),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${offer.catlove.toStringAsFixed(0)} CL',
                      style: const TextStyle(
                        color: Color(0xFF7A4DDD),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (offer.bonusPercent > 0)
                      Text(
                        '+%${offer.bonusPercent} bonus',
                        style: const TextStyle(
                          color: Color(0xFFBE185D),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              ActionButton(
                label: busy ? '...' : '\$${offer.usd.toStringAsFixed(offer.usd % 1 == 0 ? 0 : 2)}',
                variant: ActionButtonVariant.pillPrimary,
                onPressed: busy ? null : () => _buyCl(offer),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCpList() {
    return ListView(
      key: const ValueKey<String>('cp-list'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 128),
      children: [
        for (final pkg in _cpPackages)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x40948BAF)),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF86EFAC), Color(0xFF16A34A)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'CP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pkg.label,
                        style: const TextStyle(
                          color: Color(0xFF3B2363),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${pkg.cp.toStringAsFixed(0)} CP',
                        style: const TextStyle(
                          color: Color(0xFF166534),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if (pkg.bonus > 0)
                        Text(
                          '+${pkg.bonus.toStringAsFixed(0)} bonus',
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                ActionButton(
                  label: _busyKey == 'cp_${pkg.key}'
                      ? '...'
                      : '\$${pkg.usd.toStringAsFixed(pkg.usd % 1 == 0 ? 0 : 2)}',
                  variant: ActionButtonVariant.pillSuccess,
                  onPressed: _busyKey == 'cp_${pkg.key}' ? null : () => _buyCp(pkg),
                ),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xD6F7EFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x47634995)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Free CP: Gunluk 5 reklam = 1 CP',
                      style: TextStyle(
                        color: Color(0xFF14532D),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '$_watchedToday/5',
                      style: const TextStyle(
                        color: Color(0xFF166534),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ActionButton(
                label: _watchingAd ? '...' : 'Watch',
                variant: ActionButtonVariant.pillSuccess,
                onPressed: _watchingAd || _watchedToday >= 5 ? null : _watchAdForCp,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MarketHeader extends StatelessWidget {
  const _MarketHeader({
    required this.clBalance,
    required this.cpBalance,
    required this.selectedTab,
    required this.onBack,
    required this.onTabChanged,
  });

  final double clBalance;
  final double cpBalance;
  final String selectedTab;
  final VoidCallback onBack;
  final ValueChanged<String> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          GlassHeaderShell(
            backgroundColor: const Color(0x1FFFFFFF),
            borderColor: const Color(0x40FFB8A5),
            child: Row(
              children: [
                ActionButton(
                  label: 'Home',
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
                  onPressed: onBack,
                ),
                const SizedBox(width: 8),
                ActionButton(
                  label: 'CL Shop',
                  variant: ActionButtonVariant.pillPink,
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: null,
                ),
                const Spacer(),
                _BalanceChip(
                  label: '${clBalance.toStringAsFixed(1)} CL',
                  color: const Color(0xFF38243F),
                ),
                const SizedBox(width: 6),
                _BalanceChip(
                  label: '${cpBalance.toStringAsFixed(1)} CP',
                  color: const Color(0xFF38243F),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GlassHeaderShell(
            borderRadius: 999,
            blurSigma: 12,
            backgroundColor: const Color(0xEAFFFFFF),
            borderColor: const Color(0x6B462C71),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x24462C71),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ActionButton(
                  label: 'CL Marketi',
                  variant: selectedTab == 'cl'
                      ? ActionButtonVariant.pillPinkSoft
                      : ActionButtonVariant.pillSoftPurple,
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  onPressed: () => onTabChanged('cl'),
                ),
                const SizedBox(width: 6),
                ActionButton(
                  label: 'CP Marketi',
                  variant: selectedTab == 'cp'
                      ? ActionButtonVariant.pillSoft
                      : ActionButtonVariant.pillSoftPurple,
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  onPressed: () => onTabChanged('cp'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ClFallbackOffer {
  const _ClFallbackOffer({
    required this.key,
    required this.catlove,
    required this.usd,
    required this.label,
    this.bonusPercent = 0,
  });

  final String key;
  final double catlove;
  final double usd;
  final String label;
  final int bonusPercent;
}

class _ClUiOffer {
  const _ClUiOffer({
    required this.key,
    required this.catlove,
    required this.usd,
    required this.label,
    required this.bonusPercent,
  });

  final String key;
  final double catlove;
  final double usd;
  final String label;
  final int bonusPercent;
}

class _CpPackage {
  const _CpPackage({
    required this.key,
    required this.cp,
    required this.usd,
    required this.label,
    this.bonus = 0,
  });

  final String key;
  final double cp;
  final double usd;
  final String label;
  final double bonus;
}

String _labelForClKey(String key) {
  switch (key) {
    case '1':
      return 'Starter';
    case '5':
      return 'Popular';
    case '10':
      return 'Pro';
    case '25':
      return 'Ultimate';
    default:
      return 'Pack $key';
  }
}

double? _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}
