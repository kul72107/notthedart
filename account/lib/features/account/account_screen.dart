import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../widgets/action_button.dart';
import '../../widgets/bottom_nav.dart';
import '../shared/widgets/page_gradient.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final signedIn = auth.isSignedIn;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: PageGradient()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 128),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Account',
                      style: TextStyle(
                        color: Color(0xFF3B2363),
                        fontWeight: FontWeight.w900,
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
                      Text(
                        signedIn
                            ? 'Signed in as ${auth.user?.email ?? auth.user?.id}'
                            : 'No active session',
                        style: const TextStyle(
                          color: Color(0xFF4A2F73),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionButton(
                            label: signedIn ? 'My Profile' : 'Login',
                            variant: ActionButtonVariant.pillPrimary,
                            onPressed: () => signedIn
                                ? context.go('/profile/${auth.user?.id}')
                                : context.go('/login'),
                          ),
                          ActionButton(
                            label: 'Settings',
                            variant: ActionButtonVariant.pillSoftPurple,
                            onPressed: () => context.go('/settings'),
                          ),
                          ActionButton(
                            label: 'Subscription',
                            variant: ActionButtonVariant.pillSoftPurple,
                            onPressed: () => context.go('/subscription'),
                          ),
                          ActionButton(
                            label: 'Themes',
                            variant: ActionButtonVariant.pillSoftPurple,
                            onPressed: () => context.go('/themes'),
                          ),
                          ActionButton(
                            label: 'Animations',
                            variant: ActionButtonVariant.pillSoftPurple,
                            onPressed: () => context.go('/enable-animations'),
                          ),
                          ActionButton(
                            label: 'Sign Out',
                            variant: ActionButtonVariant.pillPink,
                            onPressed: signedIn
                                ? () async {
                                    await auth.signOut();
                                    if (!context.mounted) return;
                                    context.go('/login');
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
            currentPath: '/account',
            onTap: (path) => context.go(path),
          ),
        ],
      ),
    );
  }
}
