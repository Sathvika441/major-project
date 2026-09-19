import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/farm/farm_model.dart';
import 'farm_details_screen.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../auth/controllers/auth_controller.dart';

final selectedFarmProvider = StateProvider<String?>((ref) => null);

final farmsProvider = FutureProvider.autoDispose<List<FarmModel>>((ref) async {
  final userId = ref.watch(authControllerProvider).user?.uid;
  if (userId == null) return [];
  return ref.watch(farmRepositoryProvider).getFarms(userId);
});

class FarmManagementScreen extends ConsumerWidget {
  const FarmManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(farmsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFarmDialog(context, ref),
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
            return const Center(
              child: Text('No farms yet. Add your first farm.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) => _FarmTile(farm: items[index]),
          );
        },
      ),
    );
  }

  static Future<void> _showFarmDialog(
    BuildContext context,
    WidgetRef ref, {
    FarmModel? existing,
  }) async {
    final isEdit = existing != null;
    final name = TextEditingController(text: existing?.name ?? '');
    final location = TextEditingController(text: existing?.location ?? '');
    final size = TextEditingController(
      text: existing != null ? existing.sizeAcres.toString() : '',
    );
    final water = TextEditingController(
      text: existing?.waterSource ?? 'Borewell',
    );
    final method = TextEditingController(
      text: existing?.irrigationMethod ?? 'Drip',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit farm' : 'Create farm'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Farm name'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: location,
                    decoration: const InputDecoration(labelText: 'Location'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: size,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Size (acres)',
                    ),
                    validator: (value) => double.tryParse(value ?? '') == null
                        ? 'Enter a valid size'
                        : null,
                  ),
                  TextFormField(
                    controller: water,
                    decoration: const InputDecoration(
                      labelText: 'Water source',
                    ),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: method,
                    decoration: const InputDecoration(
                      labelText: 'Irrigation method',
                    ),
                    validator: _required,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (isEdit)
              TextButton(
                onPressed: () async {
                  final user = ref.read(authControllerProvider).user;
                  if (user == null) return;
                  await ref
                      .read(farmRepositoryProvider)
                      .deactivateFarm(user.uid, existing.id);
                  ref.invalidate(farmsProvider);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    Navigator.pop(dialogContext);
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final user = ref.read(authControllerProvider).user;
                if (user == null) return;

                final farm = isEdit
                    ? existing.copyWith(
                        name: name.text.trim(),
                        location: location.text.trim(),
                        sizeAcres: double.parse(size.text),
                        waterSource: water.text.trim(),
                        irrigationMethod: method.text.trim(),
                        updatedAt: DateTime.now(),
                      )
                    : FarmModel(
                        id: 'farm_${DateTime.now().microsecondsSinceEpoch}',
                        userId: user.uid,
                        name: name.text.trim(),
                        location: location.text.trim(),
                        sizeAcres: double.parse(size.text),
                        waterSource: water.text.trim(),
                        irrigationMethod: method.text.trim(),
                        createdAt: DateTime.now(),
                      );

                await ref.read(farmRepositoryProvider).saveFarm(farm);

                ref.invalidate(farmsProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  static String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }
}

class _FarmTile extends ConsumerWidget {
  final FarmModel farm;

  const _FarmTile({required this.farm});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.agriculture)),
        title: Text(farm.name),
        subtitle: Text(
          '${farm.location} â€¢ ${farm.sizeAcres} acres\n'
          '${farm.waterSource} â€¢ ${farm.irrigationMethod}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              onPressed: () => FarmManagementScreen._showFarmDialog(
                context,
                ref,
                existing: farm,
              ),
              icon: const Icon(Icons.edit),
              tooltip: 'Edit farm',
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          ref.read(selectedFarmProvider.notifier).state = farm.id;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FarmDetailsScreen()),
          );
          ref.invalidate(farmsProvider);
        },
      ),
    );
  }
}



