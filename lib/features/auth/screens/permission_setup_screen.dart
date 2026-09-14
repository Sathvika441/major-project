import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/permissions/permission_service.dart';

class PermissionSetupScreen extends ConsumerStatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  ConsumerState<PermissionSetupScreen> createState() =>
      _PermissionSetupScreenState();
}

class _PermissionSetupScreenState
    extends ConsumerState<PermissionSetupScreen> {
  bool _requesting = false;
  bool _completed = false;
  bool _permanentlyDenied = false;

  Future<void> _continue() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final service = ref.read(permissionServiceProvider);
    final result = await service.requestGalleryAndCamera();
    if (!mounted) return;

    setState(() {
      _requesting = false;
      _completed = true;
      _permanentlyDenied = result.anyPermanentlyDenied;
    });

    await service.markFlowCompleted();
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('App permissions')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.photo_camera_back_rounded,
                size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 20),
            Text('Help ArecaSmart use images safely',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Before onboarding, please review why ArecaSmart needs access to photos and the camera.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _PurposeCard(
              icon: Icons.photo_library_outlined,
              title: 'Gallery access',
              text:
                  'Required to upload farm and crop photos for records and diagnostics',
            ),
            const SizedBox(height: 12),
            _PurposeCard(
              icon: Icons.camera_alt_outlined,
              title: 'Camera access',
              text:
                  'Required to scan documents and capture live farm/crop images',
            ),
            const SizedBox(height: 24),
            if (_completed && _permanentlyDenied) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Permissions denied',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text(
                        'You can continue using the app. Image-dependent features will ask you to enable access later.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(permissionServiceProvider).openAppSettings(),
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Open App Settings'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              onPressed: _requesting ? null : _continue,
              icon: _requesting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_requesting ? 'Requesting...' : 'Continue'),
            ),
            const SizedBox(height: 12),
            Text(
              'You can continue even if you deny either permission.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PurposeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _PurposeCard({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(text),
        ),
      ),
    );
  }
}
