import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/farm/farm_model.dart';
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
      appBar: AppBar(title: const Text('Farms & plots')),
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
            return const Center(child: Text('No farms yet. Add your first farm.'));
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
    WidgetRef ref,
  ) async {
    final name = TextEditingController();
    final location = TextEditingController();
    final size = TextEditingController();
    final water = TextEditingController(text: 'Borewell');
    final method = TextEditingController(text: 'Drip');
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create farm'),
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
                    decoration:
                        const InputDecoration(labelText: 'Size (acres)'),
                    validator: (value) =>
                        double.tryParse(value ?? '') == null
                            ? 'Enter a valid size'
                            : null,
                  ),
                  TextFormField(
                    controller: water,
                    decoration:
                        const InputDecoration(labelText: 'Water source'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: method,
                    decoration:
                        const InputDecoration(labelText: 'Irrigation method'),
                    validator: _required,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final user = ref.read(authControllerProvider).user;
                if (user == null) return;

                await ref.read(farmRepositoryProvider).saveFarm(
                      FarmModel(
                        id: 'farm_${DateTime.now().microsecondsSinceEpoch}',
                        userId: user.uid,
                        name: name.text.trim(),
                        location: location.text.trim(),
                        sizeAcres: double.parse(size.text),
                        waterSource: water.text.trim(),
                        irrigationMethod: method.text.trim(),
                        createdAt: DateTime.now(),
                      ),
                    );

                ref.invalidate(farmsProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
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
          '${farm.location} • ${farm.sizeAcres} acres\n'
          '${farm.waterSource} • ${farm.irrigationMethod}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          ref.read(selectedFarmProvider.notifier).state = farm.id;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => FarmDetailsScreen(farm: farm)),
          );
          ref.invalidate(farmsProvider);
        },
      ),
    );
  }
}

class FarmDetailsScreen extends ConsumerStatefulWidget {
  final FarmModel farm;

  const FarmDetailsScreen({super.key, required this.farm});

  @override
  ConsumerState<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends ConsumerState<FarmDetailsScreen> {
  final _plotName = TextEditingController();
  final _plotArea = TextEditingController();
  final _soil = TextEditingController(text: 'Loamy');
  DateTime _plantingDate = DateTime.now();

  @override
  void dispose() {
    _plotName.dispose();
    _plotArea.dispose();
    _soil.dispose();
    super.dispose();
  }

  Future<void> _addPlot() async {
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add plot'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _plotName,
                    decoration: const InputDecoration(labelText: 'Plot name'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Required'
                            : null,
                  ),
                  TextFormField(
                    controller: _plotArea,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Area (acres)'),
                    validator: (value) =>
                        double.tryParse(value ?? '') == null
                            ? 'Enter a valid area'
                            : null,
                  ),
                  TextFormField(
                    controller: _soil,
                    decoration: const InputDecoration(labelText: 'Soil type'),
                  ),
                  ListTile(
                    title: Text(
                      'Planting date: ${_plantingDate.day}/'
                      '${_plantingDate.month}/${_plantingDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogContext,
                        firstDate: DateTime(1980),
                        lastDate: DateTime.now(),
                        initialDate: _plantingDate,
                      );
                      if (date != null && mounted) {
                        setState(() => _plantingDate = date);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                await ref.read(farmRepositoryProvider).savePlot(
                      PlotModel(
                        id: 'plot_${DateTime.now().microsecondsSinceEpoch}',
                        farmId: widget.farm.id,
                        name: _plotName.text.trim(),
                        areaAcres: double.parse(_plotArea.text),
                        soilType: _soil.text.trim(),
                        plantingDate: _plantingDate,
                      ),
                    );

                _plotName.clear();
                _plotArea.clear();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.farm.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlot,
        icon: const Icon(Icons.add),
        label: const Text('Add plot'),
      ),
      body: FutureBuilder<List<PlotModel>>(
        future: ref.read(farmRepositoryProvider).getPlots(widget.farm.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load plots.\n${snapshot.error}'));
          }

          final plots = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.farm.location,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.farm.sizeAcres} acres • '
                        '${widget.farm.irrigationMethod}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Plots', style: Theme.of(context).textTheme.titleLarge),
              if (plots.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('No plots yet. Add a plot to track crop age.'),
                ),
              ...plots.map(
                (plot) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.grass),
                    title: Text(plot.name),
                    subtitle: Text(
                      '${plot.areaAcres} acres • ${plot.soilType}\n'
                      'Age: ${plot.cropAgeDays} days • ${plot.growthStage}',
                    ),
                    isThreeLine: true,
                    trailing: plot.deviceId == null
                        ? const Icon(Icons.sensors_off)
                        : const Icon(Icons.sensors),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
