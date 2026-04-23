import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_settings.dart';
import '../../core/network/api_client.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../shared/api/meowverse_api.dart';
import '../shared/widgets/page_gradient.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _localController;
  late final TextEditingController _prodController;
  bool _testing = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _localController = TextEditingController();
    _prodController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<AppSettings>();
    _localController.text = settings.localBaseUrl;
    _prodController.text = settings.productionBaseUrl;
  }

  @override
  void dispose() {
    _localController.dispose();
    _prodController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final local = _localController.text.trim();
    final prod = _prodController.text.trim();
    if (local.isNotEmpty &&
        (AppSettings.isDatabaseConnectionString(local) ||
            !AppSettings.isHttpUrl(local))) {
      setState(() {
        _status =
            'Local URL gecersiz. Sadece http/https API adresi gir (DB URL degil).';
      });
      return;
    }
    if (prod.isNotEmpty &&
        (AppSettings.isDatabaseConnectionString(prod) ||
            !AppSettings.isHttpUrl(prod))) {
      setState(() {
        _status =
            'Production URL gecersiz. Sadece http/https API adresi gir (DB URL degil).';
      });
      return;
    }

    final settings = context.read<AppSettings>();
    await settings.setLocalBaseUrl(_localController.text);
    await settings.setProductionBaseUrl(_prodController.text);
    if (!mounted) return;
    setState(() => _status = 'Kaydedildi. DB baglantisi backend tarafinda gizli kalir.');
  }

  Future<void> _testAuth() async {
    setState(() {
      _testing = true;
      _status = null;
    });
    final settings = context.read<AppSettings>();
    final api = MeowverseApi(context.read<ApiClient>());
    final auth = context.read<AuthController>();
    try {
      final explore = await api.fetchExplore(limit: 1, offset: 0);
      final apiPart =
          'API OK (${settings.apiBaseUrl}) - Explore count: ${explore.length}';
      try {
        final tokenData = await api.fetchAuthToken();
        await auth.applyAuthPayload(tokenData);
        if (!mounted) return;
        setState(() {
          _status =
              '$apiPart | Session alindi: ${auth.user?.email ?? auth.user?.id}';
        });
      } catch (authErr) {
        if (!mounted) return;
        setState(() {
          _status =
              '$apiPart | Session alinmadi (web cross-origin/cookie normal olabilir): $authErr';
        });
      }
    } catch (err) {
      if (!mounted) return;
      setState(() => _status = 'API ulasilamadi (${settings.apiBaseUrl}): $err');
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PageGradient()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Color(0xFF3B2363),
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x40948BAF)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'API Environment',
                        style: TextStyle(
                          color: Color(0xFF4A2F73),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ActionButton(
                            label: 'Local',
                            variant: settings.apiEnvironment == ApiEnvironment.local
                                ? ActionButtonVariant.pillPrimary
                                : ActionButtonVariant.pillSoftPurple,
                            onPressed: () => settings.setApiEnvironment(ApiEnvironment.local),
                          ),
                          const SizedBox(width: 8),
                          ActionButton(
                            label: 'Production',
                            variant: settings.apiEnvironment == ApiEnvironment.production
                                ? ActionButtonVariant.pillPrimary
                                : ActionButtonVariant.pillSoftPurple,
                            onPressed: () => settings.setApiEnvironment(ApiEnvironment.production),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _localController,
                        decoration: const InputDecoration(
                          labelText: 'Local Base URL',
                          hintText: 'http://10.0.2.2:3000',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _prodController,
                        decoration: const InputDecoration(
                          labelText: 'Production Base URL',
                          hintText: 'https://your-createanything-app-domain',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Not: Buraya sadece API domaini girilir. postgresql:// gibi DB URL girilmez.',
                        style: TextStyle(
                          color: Color(0xFF7A5A9D),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ActionButton(
                            label: 'Save',
                            variant: ActionButtonVariant.pillSuccess,
                            onPressed: _save,
                          ),
                          const SizedBox(width: 8),
                          ActionButton(
                            label: _testing ? 'Testing...' : 'Sync Session',
                            variant: ActionButtonVariant.pillPrimary,
                            onPressed: _testing ? null : _testAuth,
                          ),
                        ],
                      ),
                      if (_status != null) ...[
                        const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x40948BAF)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account',
                        style: TextStyle(
                          color: Color(0xFF4A2F73),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        auth.isSignedIn
                            ? 'Signed in as ${auth.user?.email ?? auth.user?.id}'
                            : 'Signed out',
                        style: const TextStyle(
                          color: Color(0xFF63408F),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ActionButton(
                            label: auth.isSignedIn ? 'Go Profile' : 'Login',
                            variant: ActionButtonVariant.pillPrimary,
                            onPressed: () => auth.isSignedIn
                                ? context.go('/profile/${auth.user?.id}')
                                : context.go('/login'),
                          ),
                          const SizedBox(width: 8),
                          ActionButton(
                            label: 'Sign Out',
                            variant: ActionButtonVariant.pillPink,
                            onPressed: auth.isSignedIn
                                ? () async {
                                    await auth.signOut();
                                    if (!context.mounted) return;
                                    setState(() => _status = 'Signed out.');
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CatBottomNav(
            currentPath: '/settings',
            onTap: (path) => context.go(path),
          ),
        ],
      ),
    );
  }
}
