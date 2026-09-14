import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/karnataka_locations.dart';
import '../../../core/services/location_master_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/validators/auth_validators.dart';
import '../../../models/farm/farm_profile_model.dart';
import '../../auth/controllers/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _village;

  final _state = KarnatakaLocations.state;
  String _district = '';
  String _taluk = '';
  String _villageCode = '';
  bool _loadingMaster = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _village = TextEditingController();
    _loadMaster();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _village.dispose();
    super.dispose();
  }

  Future<void> _loadMaster() async {
    final service = ref.read(locationMasterServiceProvider);
    try {
      await service.load();
      if (!mounted) return;
      setState(() {
        _loadingMaster = false;
        _loadError = null;
        final districts = service.districts.isNotEmpty
            ? service.districts
            : KarnatakaLocations.districts;
        _district = districts.isNotEmpty ? districts.first : '';
        final taluks = service.taluksFor(_district);
        _taluk = taluks.isNotEmpty ? taluks.first : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMaster = false;
        _loadError = 'Could not load location master. Please try again.';
      });
    }
  }

  LocationMasterService get _locations =>
      ref.read(locationMasterServiceProvider);

  List<String> get _districts =>
      _locations.districts.isNotEmpty ? _locations.districts : KarnatakaLocations.districts;

  List<String> get _taluks => _locations.taluksFor(_district).isNotEmpty
      ? _locations.taluksFor(_district)
      : KarnatakaLocations.taluksFor(_district);

  List<VillageEntry> get _villages => _locations.villagesFor(_taluk);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_villageCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a village from the list.')),
      );
      return;
    }

    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final profile = FarmProfileModel(
        userId: user.uid,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        location: KarnatakaLocations.formatLocation(
          state: _state,
          district: _district,
          taluk: _taluk,
          village: _village.text.trim(),
        ),
        state: _state,
        district: _district,
        taluk: _taluk,
        village: _village.text.trim(),
        villageCode: _villageCode,
        language: 'English',
        notificationsEnabled: true,
        farmName: '',
        farmSizeAcres: 0,
        waterSource: 'Borewell',
        irrigationMethod: 'Drip',
        crop: 'Arecanut',
        plantingDate: DateTime.now(),
      );

      await ref
          .read(localStorageServiceProvider)
          .raw
          .setString('phase25_profile_${user.uid}', profile.toJson());
      await ref.read(localStorageServiceProvider).setCompletedPhaseA(true);
      await ref.read(localStorageServiceProvider).setCompletedPhaseB(false);
      await ref.read(localStorageServiceProvider).setOnboardingCompleted(false);

      if (!mounted) return;
      context.go('/farm-details');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save onboarding: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding — Phase A')),
      body: SafeArea(
        child: _loadingMaster
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Farmer details',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    const Text('Step 1 of 2 • Core farmer and location details'),
                    const SizedBox(height: 20),
                    if (_loadError != null) ...[
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text(_loadError!),
                          trailing: TextButton(
                            onPressed: _loadMaster,
                            child: const Text('Retry'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: AuthValidators.validateName,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: AuthValidators.validatePhone,
                    ),
                    const SizedBox(height: 18),
                    Text('Location',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _state,
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
                      value: _district.isEmpty ? null : _district,
                      decoration: const InputDecoration(
                        labelText: 'District',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      items: _districts
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final taluks = _locations.taluksFor(value);
                        setState(() {
                          _district = value;
                          _taluk = taluks.isNotEmpty ? taluks.first : '';
                          _village.clear();
                          _villageCode = '';
                        });
                      },
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Select a district' : null,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _taluk.isEmpty ? null : _taluk,
                      decoration: const InputDecoration(
                        labelText: 'Taluk',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      items: _taluks
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _taluk = value;
                          _village.clear();
                          _villageCode = '';
                        });
                      },
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Select a taluk' : null,
                    ),
                    const SizedBox(height: 14),
                    Autocomplete<VillageEntry>(
                      displayStringForOption: (option) => option.name,
                      optionsBuilder: (value) {
                        final query = value.text.trim().toLowerCase();
                        if (query.isEmpty) return _villages;
                        return _villages.where(
                          (v) => v.name.toLowerCase().contains(query),
                        );
                      },
                      onSelected: (village) {
                        setState(() {
                          _village.text = village.name;
                          _villageCode = village.code;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        controller.text = _village.text;
                        controller.selection = TextSelection.collapsed(
                          offset: controller.text.length,
                        );
                        controller.addListener(() {
                          if (_village.text != controller.text) {
                            _village.text = controller.text;
                            _villageCode = '';
                          }
                        });
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Village',
                            hintText: 'Search village',
                            prefixIcon: Icon(Icons.home_work_outlined),
                          ),
                          validator: (_) => _villageCode.isEmpty
                              ? 'Select a village from the list'
                              : null,
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        final values = options.toList();
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: values.length,
                                itemBuilder: (context, index) {
                                  final village = values[index];
                                  return ListTile(
                                    title: Text(village.name),
                                    subtitle: Text(village.code),
                                    onTap: () => onSelected(village),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
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
                          : const Icon(Icons.arrow_forward),
                      label: Text(_saving ? 'Saving...' : 'Continue to Farm Details'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
