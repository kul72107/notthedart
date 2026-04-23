import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../widgets/bottom_nav.dart';
import '../avatar/animated_cat_avatar.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/models.dart';
import '../shared/widgets/nav_primitives.dart';
import '../shared/widgets/page_gradient.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  List<AvatarRecord> _cats = const [];
  List<AvatarRecord> _myCats = const [];
  bool _showPicker = false;

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
      final data = await api.fetchProfile(widget.userId);
      final profile = (data['profile'] as Map?)?.cast<String, dynamic>();
      final rawCats = (data['cats'] as List?) ?? const [];
      final cats = rawCats
          .whereType<Map>()
          .map((item) => AvatarRecord.fromJson(item.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _cats = cats;
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

  Future<void> _loadMyCats() async {
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      final cats = await api.fetchMyCats();
      if (!mounted) return;
      setState(() => _myCats = cats);
    } catch (_) {
      // Silent fallback.
    }
  }

  Future<void> _setProfileAvatar(AvatarRecord cat) async {
    final api = MeowverseApi(context.read<ApiClient>());
    try {
      await api.setProfileAvatar(widget.userId, cat.id);
      if (!mounted) return;
      setState(() => _showPicker = false);
      await _load();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isOwnProfile = auth.user?.id == widget.userId;

    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: PageGradient()),
            Center(
              child: Text(
                _error ?? 'Profil bulunamadi',
                style: const TextStyle(color: Color(0xFF5B3B85)),
              ),
            ),
          ],
        ),
      );
    }

    final username = profile['username']?.toString().trim();
    final email = profile['email']?.toString().trim();
    final displayName = (username != null && username.isNotEmpty && username != email)
        ? username
        : (email?.split('@').first ?? 'anonim');
    final profileAvatar = (profile['profileAvatar'] as Map?)?.cast<String, dynamic>();
    final profileAvatarData = _asJsonMap(profileAvatar?['avatar_data']);
    final totalLikes = _cats.fold<int>(0, (sum, cat) => sum + (cat.likes ?? 0));

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
                    blurSigma: 16,
                    backgroundColor: const Color(0xCCFFFFFF),
                    borderColor: const Color(0x1F000000),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => context.go('/'),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Profile',
                          style: TextStyle(
                            color: Color(0xFF3B2363),
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GridView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.2,
                    ),
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x40948BAF)),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: isOwnProfile
                                  ? () async {
                                      await _loadMyCats();
                                      if (!mounted) return;
                                      setState(() => _showPicker = true);
                                    }
                                  : null,
                              child: Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0xFF8B5CF6), width: 3),
                                  color: const Color(0x22FFFFFF),
                                ),
                                clipBehavior: Clip.hardEdge,
                                child: profileAvatarData.isNotEmpty
                                    ? AnimatedCatAvatar(
                                        avatarData: profileAvatarData,
                                        backgroundColor: const Color(0xFFF3E8FF),
                                      )
                                    : Center(
                                        child: Text(
                                          displayName.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 30,
                                            color: Color(0xFF7A4DDD),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '@$displayName',
                                    style: const TextStyle(
                                      color: Color(0xFF3B2363),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_cats.length} Cats   ❤ $totalLikes',
                                    style: const TextStyle(
                                      color: Color(0xFF63408F),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (isOwnProfile)
                                    const Text(
                                      'Profil resmini degistirmek icin avatarina dokun.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF876BBD)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._cats.map((cat) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x40948BAF)),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 98,
                                height: 98,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedCatAvatar(
                                    avatarData: cat.avatarData,
                                    backgroundColor: const Color(0xFFFFB8A5),
                                    animationsEnabled: false,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '❤ ${cat.likes ?? 0}   ⭐ ${cat.totalRatings ?? 0}',
                                      style: const TextStyle(
                                        color: Color(0xFF63408F),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if ((cat.level ?? 0) > 0)
                                      Text(
                                        'Level ${cat.level}',
                                        style: const TextStyle(
                                          color: Color(0xFF8B5CF6),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if ((cat.description ?? '').isNotEmpty)
                                      Text(
                                        cat.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF876BBD),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CatBottomNav(
            currentPath: '/profile/${widget.userId}',
            onTap: (path) => context.go(path),
          ),
          if (_showPicker)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showPicker = false),
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 320,
                        constraints: const BoxConstraints(maxHeight: 500),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
                              child: Row(
                                children: [
                                  Text(
                                    'Profil Resmi Sec',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF3B2363),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: GridView.builder(
                                padding: const EdgeInsets.all(10),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: _myCats.length,
                                itemBuilder: (context, index) {
                                  final cat = _myCats[index];
                                  return GestureDetector(
                                    onTap: () => _setProfileAvatar(cat),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: AnimatedCatAvatar(
                                        avatarData: cat.avatarData,
                                        backgroundColor: const Color(0xFFF3E8FF),
                                        animationsEnabled: false,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _showPicker = false),
                              child: const Text('Kapat'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asJsonMap(dynamic value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map) {
        return parsed.map((key, item) => MapEntry(key.toString(), item));
      }
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  return <String, dynamic>{};
}
