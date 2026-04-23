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

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = true;
  bool _purchasing = false;
  bool _restoring = false;
  bool _subscribed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _subscribed = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final data = await api.fetchSubscriptionStatus();
      if (!mounted) return;
      setState(() {
        _subscribed = data['hasAccess'] == true;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  Future<void> _purchase(_SubscriptionPack pack) async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      context.go('/login');
      return;
    }
    if (_purchasing) return;

    setState(() {
      _purchasing = true;
      _error = null;
    });
    try {
      final ok = await NativeMonetizationBridge.startSubscriptionPurchase(pack.id);
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'Native purchase baslatilamadi.');
      } else {
        await _refreshStatus();
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) {
        setState(() => _purchasing = false);
      }
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() {
      _restoring = true;
      _error = null;
    });
    try {
      final ok = await NativeMonetizationBridge.restoreSubscriptionPurchase();
      if (!mounted) return;
      if (!ok) {
        setState(() => _error = 'Restore islemi basarisiz oldu.');
      } else {
        await _refreshStatus();
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: GlassHeaderShell(
                    backgroundColor: const Color(0xCCFFFFFF),
                    borderColor: const Color(0x33FFB8A5),
                    child: Row(
                      children: [
                        ActionButton(
                          label: 'Back',
                          variant: ActionButtonVariant.pillSoftPurple,
                          fontSize: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: const Icon(
                            Icons.arrow_back_rounded,
                            size: 15,
                            color: Color(0xFF3F2B66),
                          ),
                          onPressed: () => context.go('/'),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Get Premium',
                          style: TextStyle(
                            color: Color(0xFF3B2363),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        if (_subscribed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7D6),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x66F59E0B),
                              ),
                            ),
                            child: const Text(
                              'Premium Member',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
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
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0x40948BAF)),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Premium Features',
                                    style: TextStyle(
                                      color: Color(0xFF3B2363),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  _FeatureLine('Unlimited cats and saves'),
                                  _FeatureLine('Premium accessories and themes'),
                                  _FeatureLine('Higher FPS exports'),
                                  _FeatureLine('Ad-free premium workflow'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (!auth.isSignedIn)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0x40948BAF)),
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Subscription satin almak icin login ol.',
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
                              )
                            else ...[
                              for (final pack in _packs) ...[
                                _PackCard(
                                  pack: pack,
                                  purchasing: _purchasing,
                                  subscribed: _subscribed,
                                  onPurchase: () => _purchase(pack),
                                ),
                                const SizedBox(height: 10),
                              ],
                              ActionButton(
                                label: _restoring ? 'Restoring...' : 'Restore Purchases',
                                variant: ActionButtonVariant.pillSoftPurple,
                                onPressed: _restoring ? null : _restore,
                                fullWidth: true,
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
          CatBottomNav(
            currentPath: '/subscription',
            onTap: (path) => context.go(path),
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.purchasing,
    required this.subscribed,
    required this.onPurchase,
  });

  final _SubscriptionPack pack;
  final bool purchasing;
  final bool subscribed;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pack.popular ? const Color(0xFF8B5CF6) : const Color(0x40948BAF),
          width: pack.popular ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pack.name,
                  style: const TextStyle(
                    color: Color(0xFF3B2363),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  pack.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF876BBD),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ActionButton(
            label: subscribed
                ? 'Active'
                : (purchasing ? '...' : '\$${pack.price.toStringAsFixed(pack.price % 1 == 0 ? 0 : 2)}'),
            variant: subscribed ? ActionButtonVariant.pillSoftPurple : ActionButtonVariant.pillPrimary,
            onPressed: (subscribed || purchasing) ? null : onPurchase,
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF22C55E)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF4A2F73),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionPack {
  const _SubscriptionPack({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.price,
    this.popular = false,
  });

  final String id;
  final String name;
  final String subtitle;
  final double price;
  final bool popular;
}

const List<_SubscriptionPack> _packs = <_SubscriptionPack>[
  _SubscriptionPack(
    id: 'weekly',
    name: 'Weekly Pro',
    subtitle: '1 week premium access',
    price: 2.99,
  ),
  _SubscriptionPack(
    id: 'monthly',
    name: 'Monthly Pro',
    subtitle: '1 month premium access',
    price: 9.99,
    popular: true,
  ),
  _SubscriptionPack(
    id: 'annual',
    name: 'Yearly Pro',
    subtitle: '1 year premium access',
    price: 59.99,
  ),
];
