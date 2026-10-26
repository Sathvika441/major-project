import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/farm/farm_model.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../../widgets/asset_glass_panel.dart';
import '../../../widgets/app_navigation_scaffold.dart';
import '../../auth/controllers/auth_controller.dart';
import 'farm_details_screen.dart';
import 'farm_workspace_screen.dart';

final selectedFarmProvider = StateProvider<String?>((ref) => null);

final farmsProvider = FutureProvider.autoDispose<List<FarmModel>>((ref) async {
  final userId = ref.watch(authControllerProvider).user?.uid;
  if (userId == null) return [];
  return ref.watch(farmRepositoryProvider).getFarms(userId);
});

class FarmManagementScreen extends ConsumerWidget {
  const FarmManagementScreen({super.key});

  Future<void> _openFarm(
    BuildContext context,
    WidgetRef ref, {
    String? farmId,
    bool startNew = false,
  }) async {
    if (farmId != null && !startNew) {
      final farms = await ref.read(farmsProvider.future);
      final matches = farms.where((farm) => farm.id == farmId);
      if (matches.isNotEmpty && context.mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FarmWorkspaceScreen(farm: matches.first),
          ),
        );
        if (!context.mounted) return;
        ref.invalidate(farmsProvider);
        return;
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FarmDetailsScreen(farmId: farmId, startNew: startNew),
      ),
    );
    if (!context.mounted) return;
    ref.invalidate(farmsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(farmsProvider);

    return AppNavigationScaffold(
      title: 'Farm management',
      subtitle: 'Organize fields, crops and irrigation details',
      selectedIndex: 2,
      actions: [
        IconButton(
          tooltip: 'Refresh farms',
          onPressed: () => ref.invalidate(farmsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFarm(context, ref, startNew: true),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add farm'),
      ),
      body: farms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _FarmError(
          message: 'Could not load your farms.\n$error',
          onRetry: () => ref.invalidate(farmsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return _EmptyFarms(
              onAdd: () => _openFarm(context, ref, startNew: true),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1200
                  ? 3
                  : constraints.maxWidth >= 720
                  ? 2
                  : 1;
              const gap = 18.0;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - gap * (columns - 1)) / columns;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                children: [
                  _PortfolioHeader(
                    farmCount: items.length,
                    totalAcres: items.fold<double>(
                      0,
                      (sum, farm) => sum + farm.sizeAcres,
                    ),
                    onAdd: () => _openFarm(context, ref, startNew: true),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: items
                        .map(
                          (farm) => SizedBox(
                            width: width,
                            child: _FarmCard(
                              farm: farm,
                              onTap: () {
                                ref.read(selectedFarmProvider.notifier).state =
                                    farm.id;
                                _openFarm(context, ref, farmId: farm.id);
                              },
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PortfolioHeader extends StatelessWidget {
  final int farmCount;
  final double totalAcres;
  final VoidCallback onAdd;

  const _PortfolioHeader({
    required this.farmCount,
    required this.totalAcres,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AssetGlassPanel(
      imagePath: 'assets/images/25_Areca-nut-trees_Rao_s-plantation_Sharmila-V-768x512.jpg.jpeg',
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your farm portfolio',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Text(
                  'Keep every field and crop detail in one place.',
                style: TextStyle(
                  color: scheme.onPrimary.withValues(alpha: 0.86),
                  ),
                ),
              ),
            ],
          );

          final stats = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Stat(
                value: farmCount.toString(),
                label: farmCount == 1 ? 'Farm' : 'Farms',
                color: scheme.onPrimary,
              ),
              const SizedBox(width: 28),
              _Stat(
                value: totalAcres.toStringAsFixed(1),
                label: 'Acres',
                color: scheme.onPrimary,
              ),
            ],
          );

          final button = FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add farm'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.onPrimary,
              foregroundColor: scheme.primary,
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 18),
                stats,
                const SizedBox(height: 18),
                button,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: intro),
              stats,
              const SizedBox(width: 30),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w800),
        ),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.78))),
      ],
    );
  }
}

class _FarmCard extends StatelessWidget {
  final FarmModel farm;
  final VoidCallback onTap;

  const _FarmCard({required this.farm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = [
      farm.village,
      farm.taluk,
      farm.district,
    ].where((value) => value.trim().isNotEmpty).join(', ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.agriculture_rounded,
                      color: scheme.primary,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      farm.name.isEmpty ? 'Unnamed farm' : farm.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: location.isEmpty ? farm.location : location,
              ),
              const SizedBox(height: 9),
              _InfoRow(
                icon: Icons.eco_outlined,
                text: farm.crop.isEmpty ? 'Crop not specified' : farm.crop,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(
                    icon: Icons.square_foot_outlined,
                    text: farm.sizeAcres.toStringAsFixed(1) + ' acres',
                  ),
                  _Tag(
                    icon: Icons.water_drop_outlined,
                    text: farm.irrigationMethod.isEmpty
                        ? 'Irrigation not set'
                        : farm.irrigationMethod,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Open smart workspace',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyFarms extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyFarms({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.agriculture_rounded,
                      size: 36,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Start with your first farm',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your farm details to unlock weather, irrigation insights and AI crop health tools.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Add your first farm'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FarmError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FarmError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
