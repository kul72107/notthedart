import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/meowverse_logo.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/models.dart';
import '../shared/widgets/nav_primitives.dart';
import '../shared/widgets/page_gradient.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  bool _didLoad = false;
  bool _perfMode = false;
  String? _error;
  List<AvatarRecord> _gallery = const [];
  Map<String, dynamic>? _ranked;
  double _catloveBalance = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = MeowverseApi(context.read<ApiClient>());
    final auth = context.read<AuthController>();

    try {
      final tasks = <Future<dynamic>>[
        api.fetchGallery(limit: 8),
        api.fetchRanked(),
      ];
      if (auth.isSignedIn) {
        tasks.add(api.fetchCatloveBalance());
      }
      final results = await Future.wait(tasks);
      if (!mounted) return;
      setState(() {
        _gallery = results[0] as List<AvatarRecord>;
        _ranked = results[1] as Map<String, dynamic>;
        _catloveBalance = auth.isSignedIn && results.length > 2
            ? (results[2] as CatloveBalance).balance
            : 0;
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profileRoute = auth.isSignedIn
        ? '/profile/${auth.user?.id}'
        : '/login';
    final rankInfo =
        (_ranked?['tierInfo'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rankLabel = rankInfo['label']?.toString() ?? 'Unranked';
    final rankColor = _rankOutlineColor(rankLabel);
    final displayName = auth.user?.name?.trim().isNotEmpty == true
        ? auth.user!.name!
        : 'Guest';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PageGradient()),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 108),
                children: [
                  GlassHeaderShell(
                    margin: const EdgeInsets.only(bottom: 10),
                    backgroundColor: const Color(0x1FFFFFFF),
                    borderColor: const Color(0x40FFB8A5),
                    child: Row(
                      children: [
                        Expanded(
                          child: TopPillRow(
                            children: [
                              ActionButton(
                                label: _perfMode ? 'Perf Acik' : 'Perf Kapali',
                                variant: _perfMode
                                    ? ActionButtonVariant.pillPink
                                    : ActionButtonVariant.pillDark,
                                fontSize: 12,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                onPressed: () =>
                                    setState(() => _perfMode = !_perfMode),
                              ),
                              ActionButton(
                                label: 'Ayarlar',
                                variant: ActionButtonVariant.pillDark,
                                fontSize: 12,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                onPressed: () => context.go('/settings'),
                                leading: const Icon(
                                  Icons.settings_rounded,
                                  size: 14,
                                  color: Color(0xFFF7E7F9),
                                ),
                              ),
                              ActionButton(
                                label: 'My Cats',
                                variant: ActionButtonVariant.pillPink,
                                fontSize: 12,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                onPressed: () => context.go('/my-cats'),
                              ),
                              if (auth.isSignedIn)
                                ActionButton(
                                  label: _catloveBalance.toStringAsFixed(1),
                                  variant: ActionButtonVariant.pillSoft,
                                  fontSize: 12,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  onPressed: () => context.go('/market'),
                                  trailing: const Text(
                                    'CL',
                                    style: TextStyle(
                                      color: Color(0xFF38243F),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '',
                          onSelected: (value) {
                            if (value == 'profile') context.go(profileRoute);
                            if (value == 'login') context.go('/login');
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: auth.isSignedIn ? 'profile' : 'login',
                              child: Text(
                                auth.isSignedIn ? 'Profili Goster' : 'Sign In',
                              ),
                            ),
                          ],
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0x66FFFFFF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x33644D9D),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              auth.isSignedIn
                                  ? Icons.account_circle_rounded
                                  : Icons.login_rounded,
                              color: const Color(0xFF3B2363),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const MeowVerseLogo(fontSize: 78),
                  const SizedBox(height: 4),
                  Text(
                    'Hos geldin, $displayName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF63408F),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ActionButton(
                        label: 'Create',
                        variant: ActionButtonVariant.pink,
                        onPressed: () => context.go('/create'),
                        leading: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                        ),
                      ),
                      ActionButton(
                        label: 'Explore',
                        variant: ActionButtonVariant.purple,
                        onPressed: () => context.go('/explore'),
                        leading: const Icon(
                          Icons.explore_rounded,
                          color: Colors.white,
                        ),
                      ),
                      ActionButton(
                        label: 'Market',
                        variant: ActionButtonVariant.white,
                        onPressed: () => context.go('/market-cats'),
                        leading: const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFF38243F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: rankColor, width: 8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24462C71),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.military_tech_rounded,
                          color: Color(0xFF5D34A5),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ranked: $rankLabel',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF3E295F),
                            ),
                          ),
                        ),
                        ActionButton(
                          label: 'Open',
                          variant: ActionButtonVariant.pillPrimary,
                          onPressed: () => context.go('/ranked'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  if (_error != null && !_loading)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0x22EF4444),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x66EF4444)),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7F1D1D),
                        ),
                      ),
                    ),
                  if (!_loading && _gallery.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Latest Cats',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A2F73),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 155,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _gallery.length.clamp(0, 8).toInt(),
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final avatar = _gallery[index];
                          return GestureDetector(
                            onTap: () =>
                                context.go('/profile/${avatar.userId ?? ''}'),
                            child: Container(
                              width: 126,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0x40948BAF),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(15),
                                      ),
                                      child: ColoredBox(
                                        color: const Color(0xFFFFB8A5),
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Image.network(
                                            avatar.imageUrl ?? '',
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.pets_rounded,
                                                  color: Color(0xFF7A4DDD),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.favorite_rounded,
                                          size: 13,
                                          color: Color(0xFFEC4899),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${avatar.likes ?? 0}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF5D34A5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          CatBottomNav(currentPath: '/', onTap: (path) => context.go(path)),
        ],
      ),
    );
  }

  Color _rankOutlineColor(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('diamond')) {
      return const Color(0xFF3B82F6);
    }
    if (lower.contains('gold') || lower.contains('altin')) {
      return const Color(0xFFFACC15);
    }
    if (lower.contains('iron') || lower.contains('demir')) {
      return const Color(0xFF9CA3AF);
    }
    if (lower.contains('silver') || lower.contains('gumus')) {
      return const Color(0xFFCBD5E1);
    }
    if (lower.contains('bronze') || lower.contains('bronz')) {
      return const Color(0xFFB7794A);
    }
    return const Color(0xFF8B8B8B);
  }
}
