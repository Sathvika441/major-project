import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/farm/farm_model.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import 'farm_details_screen.dart';

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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FarmDetailsScreen(
          farmId: farmId,
          startNew: startNew,
        ),
      ),
    );
    ref.invalidate(farmsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(farmsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farm Management'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openFarm(context, ref, startNew: true),
        icon: const Icon(Icons.add_business),
        label: const Text('Add farm'),
      ),
      body: farms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load farms.\n$error'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: FilledButton.icon(
                onPressed: () => _openFarm(context, ref, startNew: true),
                icon: const Icon(Icons.add_business),
                label: const Text('Add your first farm'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final farm = items[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.agriculture),
                  ),
                  title: Text(farm.name),
                  subtitle: Text(
                    '${farm.location}\n'
                    '${farm.sizeAcres} acres • ${farm.waterSource} • ${farm.irrigationMethod}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ref.read(selectedFarmProvider.notifier).state = farm.id;
                    _openFarm(context, ref, farmId: farm.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
