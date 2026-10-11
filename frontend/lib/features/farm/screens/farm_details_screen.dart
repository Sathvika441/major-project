import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/local_storage_service.dart';
import '../../../core/constants/karnataka_locations.dart';
import '../../../core/services/location_master_service.dart';
import '../../../core/services/crop_growth_stage_service.dart';
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

const waterSources = <String>[
  'Borewell',
  'Open well',
  'River / canal',
  'Rainwater harvesting',
  'Other',
];

const irrigationMethods = <String>[
  'Drip',
  'Sprinkler',
  'Flood irrigation',
  'Rainfed',
  'Other',
];

class FarmDetailsScreen extends ConsumerStatefulWidget {
  final String? farmId;
  final bool startNew;

  const FarmDetailsScreen({super.key, this.farmId, this.startNew = false});

  @override
  ConsumerState<FarmDetailsScreen> createState() => _FarmDetailsScreenState();
}

class _FarmDetailsScreenState extends ConsumerState<FarmDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  static const String _defaultState = 'Karnataka';

  late final TextEditingController _farmName;
  late final TextEditingController _survey;
  late final TextEditingController _size;

  String _state = _defaultState;
  String? _district;
  String? _taluk;
  VillageEntry? _village;
  List<String> _districts = [];
  List<String> _taluks = [];
  List<VillageEntry> _villages = [];

  String? _cultivation;
  String? _soil;
  String? _waterSource;
  String? _irrigationMethod;
  DateTime? _plantingDate;

  FarmProfileModel? _existingProfile;
  FarmModel? _editingFarm;
  int _savedFarmCount = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _farmName = TextEditingController();
    _survey = TextEditingController();
    _size = TextEditingController();
    _loadExisting();
  }

  @override
  void dispose() {
    _farmName.dispose();
    _survey.dispose();
    _size.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final locationMaster = ref.read(locationMasterServiceProvider);
      await locationMaster.load();
      _districts = locationMaster.districts.isNotEmpty
          ? locationMaster.districts
          : KarnatakaLocations.districts;
      final profile = await ref.read(profileRepositoryProvider).load(user.uid);
      final farms = await ref.read(farmRepositoryProvider).getFarms(user.uid);

      if (!mounted) return;
      setState(() {
        _existingProfile = profile;
        _savedFarmCount = farms.length;
        _loading = false;
      });

      if (widget.farmId != null) {
        final match = farms.where((farm) => farm.id == widget.farmId).toList();
        if (match.isNotEmpty) _loadFarmIntoForm(match.first);
      } else if (!widget.startNew && farms.length == 1) {
        _loadFarmIntoForm(farms.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load farm details: $e')),
      );
    }
  }

  void _loadFarmIntoForm(FarmModel farm) {
    final locationMaster = ref.read(locationMasterServiceProvider);
    final district = farm.district.isNotEmpty
        ? farm.district
        : (_existingProfile?.district ?? '');
    final taluk = farm.taluk.isNotEmpty
        ? farm.taluk
        : (_existingProfile?.taluk ?? '');
    final villageName = farm.village.isNotEmpty
        ? farm.village
        : (_existingProfile?.village ?? '');

    _state = farm.state.isNotEmpty ? farm.state : _defaultState;
    _district = _districts.contains(district) ? district : null;
    _taluks = _district == null ? [] : locationMaster.taluksFor(_district!);
    _taluk = _taluks.contains(taluk) ? taluk : null;
    _villages = _taluk == null ? [] : locationMaster.villagesFor(_taluk!);
    _village = _villages.cast<VillageEntry?>().firstWhere(
      (entry) =>
          entry?.name.trim().toLowerCase() == villageName.trim().toLowerCase(),
      orElse: () => null,
    );

    setState(() {
      _editingFarm = farm;
      _farmName.text = farm.name;
      _survey.text = farm.landSurveyNumber;
      _size.text = farm.sizeAcres > 0 ? farm.sizeAcres.toString() : '';
      _cultivation = _pickOption(
        farm.arecanutCultivationType,
        cultivationTypes,
      );
      _soil = _pickOption(farm.soilType, soilTypes);
      _waterSource = _pickOption(farm.waterSource, waterSources);
      _irrigationMethod = _pickOption(farm.irrigationMethod, irrigationMethods);
      _plantingDate = farm.plantingDate;
    });
  }

  String? _pickOption(String value, List<String> options) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return options.contains(trimmed) ? trimmed : null;
  }

  void _clearFormForNewFarm() {
    _formKey.currentState?.reset();
    setState(() {
      _editingFarm = null;
      _farmName.clear();
      _state = _defaultState;
      _district = null;
      _taluk = null;
      _village = null;
      _taluks = [];
      _villages = [];
      _survey.clear();
      _size.clear();
      _cultivation = null;
      _soil = null;
      _waterSource = null;
      _irrigationMethod = null;
      _plantingDate = null;
    });
  }

  Future<void> _pickPlantingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate ?? now,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: 'Select planting date',
    );

    if (picked != null && mounted) {
      setState(() => _plantingDate = picked);
    }
  }

  Future<void> _saveCurrentFarm({required bool addAnother}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_district == null ||
        _taluk == null ||
        _village == null ||
        _cultivation == null ||
        _soil == null ||
        _waterSource == null ||
        _irrigationMethod == null ||
        _plantingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete every farm detail.')),
      );
      return;
    }

    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    try {
      const CropGrowthStageService().validatePlantingDate(_plantingDate!);
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message?.toString() ?? 'Invalid planting date.'),
        ),
      );
      return;
    }

    final size = double.tryParse(_size.text.trim());
    if (size == null || size <= 0) return;

    setState(() => _saving = true);

    try {
      final farm = _editingFarm == null
          ? FarmModel(
              id: 'farm_${DateTime.now().microsecondsSinceEpoch}',
              userId: user.uid,
              name: _farmName.text.trim(),
              location: KarnatakaLocations.formatLocation(
                state: _state,
                district: _district!,
                taluk: _taluk!,
                village: _village!.name,
              ),
              sizeAcres: size,
              waterSource: _waterSource!,
              irrigationMethod: _irrigationMethod!,
              createdAt: DateTime.now(),
              landSurveyNumber: _survey.text.trim(),
              villageCode: _village!.code,
              state: _state,
              district: _district!,
              taluk: _taluk!,
              village: _village!.name,
              arecanutCultivationType: _cultivation!,
              soilType: _soil!,
              crop: 'Arecanut',
              plantingDate: _plantingDate,
            )
          : _editingFarm!.copyWith(
              name: _farmName.text.trim(),
              location: KarnatakaLocations.formatLocation(
                state: _state,
                district: _district!,
                taluk: _taluk!,
                village: _village!.name,
              ),
              sizeAcres: size,
              waterSource: _waterSource!,
              irrigationMethod: _irrigationMethod!,
              updatedAt: DateTime.now(),
              landSurveyNumber: _survey.text.trim(),
              state: _state,
              district: _district!,
              taluk: _taluk!,
              village: _village!.name,
              villageCode: _village!.code,
              arecanutCultivationType: _cultivation!,
              soilType: _soil!,
              crop: 'Arecanut',
              plantingDate: _plantingDate,
            );

      await ref.read(farmRepositoryProvider).saveFarm(farm);

      // The user profile is farmer-level data. Only the first farm is
      // mirrored there for legacy compatibility; additional farms stay
      // independent under users/{uid}/farms/{farmId}.
      if (_savedFarmCount == 0) {
        final profileBase =
            _existingProfile ??
            FarmProfileModel(
              userId: user.uid,
              name: user.name,
              phone: user.phone,
              location: KarnatakaLocations.formatLocation(
                state: _state,
                district: _district!,
                taluk: _taluk!,
                village: _village!.name,
              ),
              language: 'English',
              notificationsEnabled: true,
              farmName: '',
              farmSizeAcres: 0,
              waterSource: '',
              irrigationMethod: '',
              crop: 'Arecanut',
              plantingDate: _plantingDate!,
            );

        final profile = profileBase.copyWith(
          location: KarnatakaLocations.formatLocation(
            state: _state,
            district: _district!,
            taluk: _taluk!,
            village: _village!.name,
          ),
          state: _state,
          district: _district!,
          taluk: _taluk!,
          village: _village!.name,
          villageCode: _village!.code,
          farmName: _farmName.text.trim(),
          farmSizeAcres: size,
          waterSource: _waterSource!,
          irrigationMethod: _irrigationMethod!,
          crop: 'Arecanut',
          plantingDate: _plantingDate!,
          landSurveyNumber: _survey.text.trim(),
          arecanutCultivationType: _cultivation!,
          soilType: _soil!,
        );
        await ref.read(profileRepositoryProvider).save(profile);
      }

      if (!mounted) return;

      setState(() {
        _savedFarmCount += _editingFarm == null ? 1 : 0;
        _saving = false;
      });

      if (addAnother) {
        _clearFormForNewFarm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Farm saved. Add the details for your next farm.'),
          ),
        );
        return;
      }

      final storage = ref.read(localStorageServiceProvider);
      await storage.setCompletedPhaseB(true);
      await storage.setOnboardingCompleted(true);
      await storage.setOnboardingRequired(false);
      await storage.setPhaseBMigrated(true);

      if (mounted) {
        // Farm details is opened from Farm Management with a local
        // Navigator push. Pop back to that page when possible; if this
        // screen was opened directly (for example during onboarding),
        // navigate to Farm Management instead.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/farms');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save farm details: $e')),
        );
      }
    }
  }

  String? _requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _requiredSelection(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final editing = _editingFarm != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit farm' : 'Add farm'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Start a new farm',
              onPressed: _saving ? null : _clearFormForNewFarm,
              icon: const Icon(Icons.add_business_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth >= 1000 ? 900.0 : 720.0;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FarmDetailsHero(
                            editing: editing,
                            savedFarmCount: _savedFarmCount,
                          ),
                          const SizedBox(height: 16),
                          _FormSection(
                            icon: Icons.agriculture_outlined,
                            title: 'Farm identity',
                            subtitle: 'Give this farm a clear name and size.',
                            children: [
                              TextFormField(
                                controller: _farmName,
                                decoration: const InputDecoration(
                                  labelText: 'Farm name',
                                  hintText: 'Example: Ramesh Arecanut Farm',
                                  prefixIcon: Icon(Icons.agriculture_outlined),
                                ),
                                validator: _requiredText,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _size,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Farm size (acres)',
                                  hintText: 'Enter size in acres',
                                  prefixIcon: Icon(Icons.square_foot_outlined),
                                ),
                                validator: (value) {
                                  final parsed = double.tryParse(
                                    value?.trim() ?? '',
                                  );
                                  if (parsed == null) {
                                    return 'Enter a valid farm size';
                                  }
                                  if (parsed <= 0) {
                                    return 'Farm size must be greater than 0';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _survey,
                                textCapitalization:
                                    TextCapitalization.characters,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9A-Za-z/]'),
                                  ),
                                ],
                                maxLength: 8,
                                decoration: const InputDecoration(
                                  labelText: 'Land survey number',
                                  hintText: 'Example: 12/3A',
                                  prefixIcon: Icon(Icons.pin_drop_outlined),
                                ),
                                validator: AuthValidators.validateSurveyNumber,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _FormSection(
                            icon: Icons.location_on_outlined,
                            title: 'Farm location',
                            subtitle: 'This location is used to resolve weather data.',
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _state,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'State',
                                  prefixIcon: Icon(Icons.map_outlined),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Karnataka',
                                    child: Text('Karnataka'),
                                  ),
                                ],
                                onChanged: null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _district,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'District',
                                  prefixIcon: Icon(
                                    Icons.location_city_outlined,
                                  ),
                                ),
                                items: _districts
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  final service = ref.read(
                                    locationMasterServiceProvider,
                                  );
                                  setState(() {
                                    _district = value;
                                    _taluk = null;
                                    _village = null;
                                    _taluks = value == null
                                        ? []
                                        : service.taluksFor(value);
                                    _villages = [];
                                  });
                                },
                                validator: (value) => value == null
                                    ? 'Please select a district'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _taluk,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Taluk',
                                  prefixIcon: Icon(
                                    Icons.account_balance_outlined,
                                  ),
                                ),
                                items: _taluks
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _district == null
                                    ? null
                                    : (value) {
                                        final service = ref.read(
                                          locationMasterServiceProvider,
                                        );
                                        setState(() {
                                          _taluk = value;
                                          _village = null;
                                          _villages = value == null
                                              ? []
                                              : service.villagesFor(value);
                                        });
                                      },
                                validator: (value) => value == null
                                    ? 'Please select a taluk'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<VillageEntry>(
                                initialValue: _village,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Village',
                                  prefixIcon: Icon(Icons.home_work_outlined),
                                ),
                                items: _villages
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _taluk == null
                                    ? null
                                    : (value) =>
                                          setState(() => _village = value),
                                validator: (value) => value == null
                                    ? 'Please select a village'
                                    : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _FormSection(
                            icon: Icons.eco_outlined,
                            title: 'Crop & cultivation',
                            subtitle: 'Tell ArecaSmart how this arecanut farm is managed.',
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _cultivation,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Arecanut cultivation type',
                                  prefixIcon: Icon(Icons.spa_outlined),
                                ),
                                items: cultivationTypes
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _cultivation = value),
                                validator: _requiredSelection,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _soil,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Soil type',
                                  prefixIcon: Icon(Icons.grass_outlined),
                                ),
                                items: soilTypes
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _soil = value),
                                validator: _requiredSelection,
                              ),
                              const SizedBox(height: 14),
                              InkWell(
                                onTap: _pickPlantingDate,
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Planting date',
                                    prefixIcon: Icon(
                                      Icons.calendar_month_outlined,
                                    ),
                                  ),
                                  child: Text(
                                    _plantingDate == null
                                        ? 'Select planting date'
                                        : _plantingDate!.day.toString() +
                                              '/' +
                                              _plantingDate!.month.toString() +
                                              '/' +
                                              _plantingDate!.year.toString(),
                                    style: TextStyle(
                                      color: _plantingDate == null
                                          ? Theme.of(context).hintColor
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              if (_plantingDate == null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12,
                                    top: 6,
                                  ),
                                  child: Text(
                                    'Planting date is required',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _FormSection(
                            icon: Icons.water_drop_outlined,
                            title: 'Water & irrigation',
                            subtitle: 'These settings feed the irrigation recommendation engine.',
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _waterSource,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Water source',
                                  prefixIcon: Icon(Icons.water_drop_outlined),
                                ),
                                items: waterSources
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _waterSource = value),
                                validator: _requiredSelection,
                              ),
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _irrigationMethod,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Irrigation method',
                                  prefixIcon: Icon(Icons.water_outlined),
                                ),
                                items: irrigationMethods
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => _irrigationMethod = value),
                                validator: _requiredSelection,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          if (editing) ...[
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _clearFormForNewFarm,
                              icon: const Icon(Icons.add_business_outlined),
                              label: const Text('Add another farm instead'),
                            ),
                            const SizedBox(height: 10),
                          ],
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _saveCurrentFarm(addAnother: true),
                            icon: const Icon(Icons.add_business_outlined),
                            label: const Text('Save & add another farm'),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _saveCurrentFarm(addAnother: false),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _saving
                                  ? 'Saving...'
                                  : (editing
                                        ? 'Save changes'
                                        : 'Save & complete setup'),
                            ),
                          ),
                          if (_savedFarmCount > 0) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Each farm is saved separately. You can add as many farms as you manage.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FarmDetailsHero extends StatelessWidget {
  final bool editing;
  final int savedFarmCount;

  const _FarmDetailsHero({required this.editing, required this.savedFarmCount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, 0.45)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.onPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              editing ? Icons.edit_location_alt_outlined : Icons.add_business,
              color: scheme.primary,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editing ? 'Edit your farm' : 'Set up your farm',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  savedFarmCount == 0
                      ? 'Complete the details to unlock your smart workspace.'
                      : savedFarmCount.toString() +
                            ' farm(s) saved • Add another or update this one.',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _FormSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}
