import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_settings.dart';
import '../../core/network/api_client.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/widgets/page_gradient.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _status;

  Future<void> _openGoogleMobileLogin() async {
    final settings = context.read<AppSettings>();
    final base = settings.apiBaseUrl;
    final redirectUri = 'catavatarcreator://google-callback';
    final mobileCallback =
        '$base/api/auth/mobile-callback?redirectUri=${Uri.encodeComponent(redirectUri)}';
    final googleSigninUrl =
        '$base/api/auth/signin/google?callbackUrl=${Uri.encodeComponent(mobileCallback)}';

    final uri = Uri.parse(googleSigninUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _status = 'Tarayici acilamadi.');
    }
  }

  Future<void> _openSigninPage() async {
    final base = context.read<AppSettings>().apiBaseUrl;
    final uri = Uri.parse('$base/account/signin');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _syncSession() async {
    setState(() {
      _loading = true;
      _status = null;
    });
    final settings = context.read<AppSettings>();
    final baseUrl = settings.apiBaseUrl;
    final api = MeowverseApi(context.read<ApiClient>());
    final auth = context.read<AuthController>();
    try {
      final explore = await api.fetchExplore(limit: 1, offset: 0);
      final data = await api.fetchAuthToken();
      await auth.applyAuthPayload(data);
      if (!mounted) return;
      setState(
        () => _status =
            'API OK ($baseUrl) | Explore: ${explore.length} | Session alindi: ${auth.user?.email ?? auth.user?.id}',
      );
    } catch (err) {
      if (!mounted) return;
      final raw = err.toString().toLowerCase();
      final isTimeout =
          raw.contains('connecttimeout') ||
          raw.contains('connection took longer') ||
          raw.contains('timed out');
      final hint = isTimeout
          ? ' Baglanti timeout. Telefon testinde localhost yerine LAN IP veya public https domain kullan.'
          : '';
      setState(() => _status = 'Session alinamadi ($baseUrl): $err$hint');
    } finally {
      if (mounted) setState(() => _loading = false);
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF3B2363),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x40948BAF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.isSignedIn
                            ? 'Aktif hesap: ${auth.user?.email ?? auth.user?.id}'
                            : 'Su an giris yapilmamis.',
                        style: const TextStyle(
                          color: Color(0xFF4A2F73),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ActionButton(
                        label: 'Google ile Giris (Deep Link)',
                        variant: ActionButtonVariant.purple,
                        onPressed: _openGoogleMobileLogin,
                        fullWidth: true,
                      ),
                      const SizedBox(height: 8),
                      ActionButton(
                        label: 'Web Sign-In Sayfasini Ac',
                        variant: ActionButtonVariant.white,
                        onPressed: _openSigninPage,
                        fullWidth: true,
                      ),
                      const SizedBox(height: 8),
                      ActionButton(
                        label: _loading ? 'Kontrol Ediliyor...' : 'Session Senkronla',
                        variant: ActionButtonVariant.pillPrimary,
                        onPressed: _loading ? null : _syncSession,
                        fullWidth: true,
                      ),
                      if (_status != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _status!,
                          style: const TextStyle(
                            color: Color(0xFF63408F),
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
            currentPath: '/login',
            onTap: (path) => context.go(path),
          ),
        ],
      ),
    );
  }
}
