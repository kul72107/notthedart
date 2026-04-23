import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../widgets/bottom_nav.dart';
import '../avatar/animated_cat_avatar.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/widgets/nav_primitives.dart';
import '../shared/widgets/page_gradient.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

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
      final list = await api.fetchLeaderboard();
      if (!mounted) return;
      setState(() {
        _items = list;
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
                    backgroundColor: const Color(0xE6FFFFFF),
                    borderColor: const Color(0x33FACC15),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => context.go('/explore'),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Liderlik Tablosu',
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
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Text(
                                _error ?? 'Liderlik tablosu bos.',
                                style: const TextStyle(color: Color(0xFF5B3B85)),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 6, 12, 120),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final row = _items[index];
                                final rank = index + 1;
                                final username = row['user_username']?.toString();
                                final email = row['user_email']?.toString();
                                final name = (username != null && username.isNotEmpty)
                                    ? username
                                    : (email?.split('@').first ?? 'anonim');
                                final likes = row['total_likes']?.toString() ?? '0';
                                final avatarData = _asJsonMap(row['avatar_data']);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0x40948BAF)),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 34,
                                        child: Text(
                                          '#$rank',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF63408F),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 64,
                                        height: 64,
                                        clipBehavior: Clip.hardEdge,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0x33462C71)),
                                        ),
                                        child: avatarData.isNotEmpty
                                            ? AnimatedCatAvatar(
                                                avatarData: avatarData,
                                                backgroundColor: const Color(0xFFFFB8A5),
                                                animationsEnabled: false,
                                              )
                                            : const Center(child: Icon(Icons.pets_rounded)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '@$name',
                                          style: const TextStyle(
                                            color: Color(0xFF3E295F),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '❤ $likes',
                                        style: const TextStyle(
                                          color: Color(0xFFEC4899),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          CatBottomNav(
            currentPath: '/leaderboard',
            onTap: (path) => context.go(path),
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
