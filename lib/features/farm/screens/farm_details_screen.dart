import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/validators/auth_validators.dart';
import '../../../models/farm/farm_model.dart';
import '../../../models/farm/farm_profile_model.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../../repositories/profile/profile_repository.dart';
import '../../auth/controllers/auth_controller.dart';

const cultivationTypes = <String>[
  'Mangala',
  'Sumangala',
  'Sreemangala',
  'SAS-1',
  'Mohitnagar',
  'Hirehalli Dwarf',
  'Other',
];

const soilTypes = <String>[
  'Red Sandy',
  'Red Loamy',
  'Black Cotton',
  'Laterite',
  'Alluvial',
  'Clay',
];

class FarmDetailsScreen extends ConsumerStatefulWidget {
  const FarmDetailsScreen({super.key});

  @override
  ConsumerState<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends ConsumerState<FarmDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _survey;
  String? _cultivation;
  String? _soil;
  FarmProfileModel? _existingProfile;
  FarmModel? _existingFarm;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _survey = TextEditingController();
    _loadExisting();
  }

  @override
  void dispose() {
    _survey.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final profileRepo = ref.read(profileRepositoryProvider);
    final farmRepo = ref.read(farmRepositoryProvider);
    final profile = profileRepo.load(user.uid);
    final farms = await farmRepo.getFarms(user.uid);

    if (!mounted) return;
    setState(() {
      _existingProfile = profile;
      _existingFarm = farms.isNotEmpty ? farms.first : null;
      _survey.text = profile?.landSurveyNumber ?? _existingFarm?.landSurveyNumber ?? '';
      _cultivation = _pickOption(
        profile?.arecanutCultivationType ?? _existingFarm?.arecanutCultivationType,
        cultivationTypes,
      );
      _soil = _pickOption(
        profile?.soilType ?? _existingFarm?.soilType,
        soilTypes,
      );
      _loading = false;
    });
  }

  String? _pickOption(String? value, List<String> options) {
    if (value == null || value.isEmpty) return null;
    return options.contains(value) ? value : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    if (_cultivation == null || _soil == null) return;

    setState(() => _saving = true);
    final storage = ref.read(localStorageServiceProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    final farmRepo = ref.read(farmRepositoryProvider);

    try {
      final base = _existingProfile ??
          FarmProfileModel(
            userId: user.uid,
            name: user.name,
            phone: user.phone,
            location: '',
            language: 'English',
            notificationsEnabled: true,
            farmName: '',
            farmSizeAcres: 0,
            waterSource: 'Borewell',
            irrigationMethod: 'Drip',
            crop: 'Arecanut',
            plantingDate: DateTime.now(),
          );

      final profile = base.copyWith(
        landSurveyNumber: _survey.text.trim(),
        arecanutCultivationType: _cultivation!,
        soilType: _soil!,
      );
      await profileRepo.save(profile);

      final farm = _existingFarm == null
          ? FarmModel(
              id: 'farm_${DateTime.now().microsecondsSinceEpoch}',
              userId: user.uid,
              name: profile.farmName,
              location: profile.location,
              sizeAcres: profile.farmSizeAcres,
              waterSource: profile.waterSource,
              irrigationMethod: profile.irrigationMethod,
              createdAt: DateTime.now(),
              landSurveyNumber: profile.landSurveyNumber,
              arecanutCultivationType: profile.arecanutCultivationType,
              soilType: profile.soilType,
              villageCode: profile.villageCode,
            )
          : _existingFarm!.copyWith(
              landSurveyNumber: profile.landSurveyNumber,
              arecanutCultivationType: profile.arecanutCultivationType,
              soilType: profile.soilType,
              villageCode: profile.villageCode,
              updatedAt: DateTime.now(),
            );
      await farmRepo.saveFarm(farm);

      await storage.setCompletedPhaseB(true);
      await storage.setOnboardingCompleted(true);
      await storage.setPhaseBMigrated(true);

      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save farm details: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Farm Details — Phase B')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Farm details',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text('Step 2 of 2 • Farm-specific details'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _survey,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Land survey number',
                  hintText: 'Example: 12/3A',
                  prefixIcon: Icon(Icons.pin_drop_outlined),
                ),
                validator: AuthValidators.validateSurveyNumber,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _cultivation,
                decoration: const InputDecoration(
                  labelText: 'Arecanut cultivation type',
                  prefixIcon: Icon(Icons.spa_outlined),
                ),
                items: cultivationTypes
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _cultivation = value),
                validator: (value) =>
                    value == null ? 'Please select cultivation type' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _soil,
                decoration: const InputDecoration(
                  labelText: 'Soil type',
                  prefixIcon: Icon(Icons.grass_outlined),
                ),
                items: soilTypes
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _soil = value),
                validator: (value) =>
                    value == null ? 'Please select soil type' : null,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_saving ? 'Saving...' : 'Complete setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
