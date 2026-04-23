import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/widgets/nav_primitives.dart';
import '../shared/widgets/page_gradient.dart';

class RankedScreen extends StatefulWidget {
  const RankedScreen({super.key});

  @override
  State<RankedScreen> createState() => _RankedScreenState();
}

class _RankedScreenState extends State<RankedScreen> {
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  Map<String, dynamic>? _state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final data = await api.fetchRanked();
      if (!mounted) return;
      setState(() {
        _state = data;
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

  Future<void> _joinQueue() async {
    setState(() => _actionLoading = true);
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      await api.rankedAction('join_queue');
      await _load();
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _leaveQueue() async {
    setState(() => _actionLoading = true);
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      await api.rankedAction('leave_queue');
      await _load();
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state ?? const <String, dynamic>{};
    final loggedIn = state['loggedIn'] == true;
    final profile = (state['profile'] as Map?)?.cast<String, dynamic>();
    final tierInfo = (state['tierInfo'] as Map?)?.cast<String, dynamic>();
    final activeMatch = (state['activeMatch'] as Map?)?.cast<String, dynamic>();
    final inQueue = state['inQueue'] == true;
    final queueCount = (state['queueCount'] as num?)?.toInt() ?? 0;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PageGradient()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
              children: [
                GlassHeaderShell(
                  backgroundColor: const Color(0xCCFFFFFF),
                  borderColor: const Color(0x33FFB8A5),
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
                        onPressed: () => context.go('/'),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ranked',
                        style: TextStyle(
                          color: Color(0xFF3B2363),
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    ),
                  )
                else ...[
                  if (!loggedIn)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x40948BAF)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ranked icin giris yapman gerekiyor.',
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
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x40948BAF)),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tier: ${tierInfo?['label'] ?? 'Iron I'}',
                            style: const TextStyle(
                              color: Color(0xFF3B2363),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'RP: ${profile?['rank_points'] ?? 0}   Queue: $queueCount',
                            style: const TextStyle(
                              color: Color(0xFF63408F),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (activeMatch != null) ...[
                            Text(
                              'Aktif mac #${activeMatch['id']} (${activeMatch['phase']})',
                              style: const TextStyle(
                                color: Color(0xFF7A4DDD),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ActionButton(
                              label: 'Create Cat',
                              variant: ActionButtonVariant.purple,
                              onPressed: () => context.go('/create'),
                            ),
                          ] else if (inQueue) ...[
                            const Text(
                              'Queue durumundasin. Eslesme bekleniyor...',
                              style: TextStyle(
                                color: Color(0xFF7A4DDD),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ActionButton(
                              label: _actionLoading ? '...' : 'Queue Cik',
                              variant: ActionButtonVariant.pillPink,
                              onPressed: _actionLoading ? null : _leaveQueue,
                            ),
                          ] else ...[
                            const Text(
                              'Queueya girerek ranked maca katil.',
                              style: TextStyle(
                                color: Color(0xFF63408F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ActionButton(
                              label: _actionLoading ? '...' : 'Queue Gir',
                              variant: ActionButtonVariant.pillPrimary,
                              onPressed: _actionLoading ? null : _joinQueue,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          CatBottomNav(
            currentPath: '/ranked',
            onTap: (path) => context.go(path),
          ),
        ],
      ),
    );
  }
}
