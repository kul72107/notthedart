import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_settings.dart';
import '../../core/network/api_client.dart';
import '../shared/widgets/nav_primitives.dart';
import '../avatar/animated_cat_avatar.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/models.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final PageController _controller = PageController();
  final Set<int> _viewedIds = <int>{};

  bool _loading = true;
  bool _loadingMore = false;
  bool _didInit = false;
  String? _error;
  int _index = 0;
  double _catloveBalance = 0;
  List<AvatarRecord> _cats = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final settings = context.read<AppSettings>();
    final api = MeowverseApi(context.read<ApiClient>());
    final auth = context.read<AuthController>();

    try {
      final cats = await api.fetchExplore(limit: 20, offset: 0);
      double cl = 0;
      if (auth.isSignedIn) {
        try {
          cl = (await api.fetchCatloveBalance()).balance;
        } catch (_) {
          // CL bakiye endpoint'i fail etse bile explore kedileri gosterilmeli.
          cl = 0;
        }
      }
      if (!mounted) return;
      setState(() {
        _cats = cats;
        _catloveBalance = cl;
        _index = 0;
        _loading = false;
      });
      if (_cats.isNotEmpty) {
        _markViewed(_cats.first.id);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = 'Explore yuklenemedi (${settings.apiBaseUrl}): $err';
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    if (_loadingMore) return;
    if (_index < _cats.length - 3) return;
    _loadingMore = true;
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final next = await api.fetchExplore(limit: 10, offset: _cats.length);
      if (!mounted || next.isEmpty) return;
      setState(() {
        _cats = [..._cats, ...next];
      });
    } catch (_) {
      // Silent fallback.
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _markViewed(int avatarId) async {
    if (_viewedIds.contains(avatarId)) return;
    _viewedIds.add(avatarId);
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      await api.sendView(avatarId);
    } catch (_) {
      // Ignore view errors.
    }
  }

  void _updateCurrent(AvatarRecord next) {
    setState(() {
      _cats = _cats.map((cat) => cat.id == next.id ? next : cat).toList();
    });
  }

  Future<void> _handleLike() async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      context.go('/login');
      return;
    }
    if (_cats.isEmpty) return;

    final cat = _cats[_index];
    final api = MeowverseApi(context.read<ApiClient>());

    try {
      if (cat.userLiked) {
        await api.removeLike(cat.id);
        _updateCurrent(
          cat.copyWith(
            likes: (cat.likes ?? 0) > 0 ? (cat.likes ?? 0) - 1 : 0,
            userLiked: false,
            userDisliked: false,
            userRating: null,
          ),
        );
      } else {
        final result = await api.likeAvatar(cat.id);
        _updateCurrent(
          cat.copyWith(
            likes: _toInt(result['likes']) ?? ((cat.likes ?? 0) + 1),
            userLiked: true,
            userDisliked: false,
            userRating: 5,
          ),
        );
      }
    } catch (_) {
      // Keep current UI state on failure.
    }
  }

  Future<void> _handleDislike() async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      context.go('/login');
      return;
    }
    if (_cats.isEmpty) return;

    final cat = _cats[_index];
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      if (cat.userDisliked) {
        await api.removeLike(cat.id);
        _updateCurrent(
          cat.copyWith(userDisliked: false, userLiked: false, userRating: null),
        );
      } else {
        await api.dislikeAvatar(cat.id);
        _updateCurrent(
          cat.copyWith(
            likes: cat.userLiked && (cat.likes ?? 0) > 0 ? (cat.likes ?? 0) - 1 : cat.likes,
            userDisliked: true,
            userLiked: false,
            userRating: 1,
          ),
        );
      }
    } catch (_) {
      // Silent fallback.
    }
  }

  Future<void> _handleRate(int rating) async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      context.go('/login');
      return;
    }
    if (_cats.isEmpty) return;
    final cat = _cats[_index];
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final result = await api.rateAvatar(cat.id, rating);
      final bonus = _toDouble(result['bonusEarned']) ?? 0;
      _updateCurrent(
        cat.copyWith(
          likes: rating >= 3
              ? (cat.userLiked ? cat.likes : (cat.likes ?? 0) + 1)
              : (cat.userLiked && (cat.likes ?? 0) > 0 ? (cat.likes ?? 0) - 1 : cat.likes),
          userRating: rating,
          userLiked: rating >= 3,
          userDisliked: rating < 3,
        ),
      );
      if (bonus > 0 && mounted) {
        setState(() {
          _catloveBalance += bonus;
        });
      }
    } catch (_) {
      // Silent fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_cats.isEmpty) {
      final settings = context.read<AppSettings>();
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFE6F4), Color(0xFFEAC9FF), Color(0xFFE0BCFF)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Henuz kedi yok',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF3E295F)),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7A2E2E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aktif API: ${settings.apiBaseUrl}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6E4A95),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: _loadInitial,
                      child: const Text('Tekrar Dene'),
                    ),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Ana Sayfaya Don'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final current = _cats[_index];
    final displayName = current.userUsername?.isNotEmpty == true
        ? current.userUsername!
        : (current.userEmail?.split('@').first ?? 'anonim');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0514), Color(0xFF1A0A2E), Color(0xFF2A0F3D), Color(0xFF0B0514)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _controller,
                scrollDirection: Axis.vertical,
                itemCount: _cats.length,
                onPageChanged: (index) {
                  setState(() => _index = index);
                  _markViewed(_cats[index].id);
                  _loadMoreIfNeeded();
                },
                itemBuilder: (context, index) {
                  final cat = _cats[index];
                  return _ExploreCard(
                    record: cat,
                    canAnimate: index == _index,
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: GlassHeaderShell(
                  borderRadius: 999,
                  blurSigma: 20,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  backgroundColor: const Color(0x1A000000),
                  borderColor: const Color(0x22000000),
                  boxShadow: const <BoxShadow>[],
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => context.go('/'),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TopPillRow(
                        children: [
                          TextButton.icon(
                            onPressed: () => context.go('/leaderboard'),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0x66000000),
                              foregroundColor: const Color(0xFFFACC15),
                            ),
                            icon: const Icon(Icons.emoji_events_rounded, size: 16),
                            label: const Text('Liderlik'),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x66000000),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_catloveBalance.toStringAsFixed(1)} CL',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 130,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionCircleButton(
                    icon: current.userLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_off_alt_rounded,
                    active: current.userLiked,
                    label: '${current.likes ?? 0}',
                    onTap: _handleLike,
                  ),
                  const SizedBox(width: 12),
                  _ActionCircleButton(
                    icon: Icons.thumb_down_alt_rounded,
                    active: current.userDisliked,
                    onTap: _handleDislike,
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      final active = (current.userRating ?? 0) >= star;
                      return IconButton(
                        onPressed: () => _handleRate(star),
                        icon: Icon(
                          active ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFFBBF24),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 32,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Color(0x66000000)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@$displayName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if ((current.description ?? '').isNotEmpty)
                      Text(
                        current.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFFC4C4), fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.record,
    required this.canAnimate,
  });

  final AvatarRecord record;
  final bool canAnimate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 360,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (record.level != null && (record.level ?? 0) > 0)
              Positioned(
                top: 78,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Lv.${record.level}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x668B5CF6), width: 2),
                color: const Color(0x22FFFFFF),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: AnimatedCatAvatar(
                  avatarData: record.avatarData,
                  backgroundColor: Colors.transparent,
                  animationsEnabled: canAnimate,
                  effectsEnabled: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCircleButton extends StatelessWidget {
  const _ActionCircleButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: active ? const Color(0xFFEC4899) : const Color(0x66000000),
            side: const BorderSide(color: Color(0x66000000), width: 2),
          ),
          icon: Icon(icon, color: Colors.white),
        ),
        if (label != null)
          Text(
            label!,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}
