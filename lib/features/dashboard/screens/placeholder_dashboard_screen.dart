import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../../auth/controllers/auth_controller.dart';

class PlaceholderDashboardScreen extends ConsumerWidget {
  const PlaceholderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ArecaSmart Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Greeting Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.primaryColor, const Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${user?.name ?? 'Farmer'}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'Authenticated Session Active',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Phase 0 & 1 Verification Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 24),
                        const SizedBox(width: 10),
                        Text(
                          'System Architecture Status',
                          style: theme.textTheme.titleLarge?.copyWith(fontSize: 16),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildStatusRow('Phase 0 Architecture', 'Completed', Colors.green),
                    const SizedBox(height: 10),
                    _buildStatusRow('Phase 1 Authentication', 'Verified', Colors.green),
                    const SizedBox(height: 10),
                    _buildStatusRow('Navigation Guards & Routing', 'Active', Colors.blue),
                    const SizedBox(height: 10),
                    _buildStatusRow('Local Storage & Session Caching', 'Active', Colors.blue),
                    const SizedBox(height: 10),
                    _buildStatusRow('Phase 2 Onboarding & Profile', 'Ready to Start', Colors.orange),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Session Action Button
              AppButton(
                text: 'Sign Out (Test Session Clear)',
                type: AppButtonType.outline,
                icon: Icons.logout_rounded,
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String title, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
