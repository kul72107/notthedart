import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../avatar/animated_cat_avatar.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/models.dart';
import '../shared/widgets/nav_primitives.dart';
import '../shared/widgets/page_gradient.dart';

class MyCatsScreen extends StatefulWidget {
  const MyCatsScreen({super.key});

  @override
  State<MyCatsScreen> createState() => _MyCatsScreenState();
}

class _MyCatsScreenState extends State<MyCatsScreen> {
  bool _didInit = false;
  bool _loading = true;
  String? _error;
  List<AvatarRecord> _cats = const [];
  double _catloveBalance = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final cats = await api.fetchMyCats();
      double clBalance = 0;
      try {
        clBalance = (await api.fetchCatloveBalance()).balance;
      } catch (_) {
        clBalance = 0;
      }
      if (!mounted) return;
      setState(() {
        _cats = cats;
        _catloveBalance = clBalance;
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

  Future<void> _deleteCat(AvatarRecord cat) async {
    final api = MeowverseApi(context.read<ApiClient>());
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Kediyi Sil'),
            content: const Text('Bu kediyi silmek istiyor musun?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Iptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;

    try {
      await api.deleteMyCat(cat.id);
      if (!mounted) return;
      setState(() {
        _cats = _cats.where((item) => item.id != cat.id).toList();
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isOwnerTools =
        auth.user?.email?.toLowerCase() == 'anan61326@gmail.com';

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PageGradient()),
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: PinnedHeaderFade(
              color: Color(0xFFFFD1E3),
              height: 84,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: GlassHeaderShell(
                    backgroundColor: const Color(0x1FFFFFFF),
                    borderColor: const Color(0x40FFB8A5),
                    child: TopPillRow(
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
                        ActionButton(
                          label: '+ Create Cat',
                          variant: ActionButtonVariant.pillPink,
                          fontSize: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          onPressed: () => context.go('/create'),
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
                            trailing: const Text(
                              'CL',
                              style: TextStyle(
                                color: Color(0xFF38243F),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            onPressed: () => context.go('/market'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isOwnerTools)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: ActionButton(
                            label: 'Card Tuner',
                            variant: ActionButtonVariant.pillPrimary,
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Card Tuner v2 tasinma asamasinda.')),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ActionButton(
                            label: 'Cheat',
                            variant: ActionButtonVariant.pillPink,
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cheat paneli sadece owner hesabinda aktif.')),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                      : _cats.isEmpty
                          ? const Center(
                              child: Text(
                                'Henuz kedin yok',
                                style: TextStyle(
                                  color: Color(0xFF5B3B85),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 120),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: _cats.length,
                              itemBuilder: (context, index) {
                                final cat = _cats[index];
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0x40948BAF)),
                                  ),
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(
                                            top: Radius.circular(15),
                                          ),
                                          child: AnimatedCatAvatar(
                                            avatarData: cat.avatarData,
                                            backgroundColor: const Color(0xFFFFB8A5),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '❤ ${cat.likes ?? 0}  ⭐ ${cat.totalRatings ?? 0}',
                                              style: const TextStyle(
                                                color: Color(0xFF876BBD),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                IconButton(
                                                  onPressed: () => context.go('/create'),
                                                  style: IconButton.styleFrom(
                                                    minimumSize: const Size(30, 30),
                                                    maximumSize: const Size(30, 30),
                                                    padding: EdgeInsets.zero,
                                                    backgroundColor: const Color(0xFF7A4DDD),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.edit_rounded,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () => context.go('/create'),
                                                  style: IconButton.styleFrom(
                                                    minimumSize: const Size(30, 30),
                                                    maximumSize: const Size(30, 30),
                                                    padding: EdgeInsets.zero,
                                                    backgroundColor: const Color(0xFF46AB53),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.upload_rounded,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: () => _deleteCat(cat),
                                                  style: IconButton.styleFrom(
                                                    minimumSize: const Size(30, 30),
                                                    maximumSize: const Size(30, 30),
                                                    padding: EdgeInsets.zero,
                                                    backgroundColor: const Color(0xFFE7396E),
                                                  ),
                                                  icon: const Icon(
                                                    Icons.delete_outline_rounded,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          CatBottomNav(
            currentPath: '/my-cats',
            onTap: (path) => context.go(path),
          ),
        ],
      ),
    );
  }
}
