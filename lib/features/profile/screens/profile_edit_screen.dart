import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/karnataka_locations.dart';
import '../../../models/farm/farm_profile_model.dart';
import '../../../repositories/profile/profile_repository.dart';
import '../../auth/controllers/auth_controller.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() =>
      _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _phone;
  late TextEditingController _village;
  late TextEditingController _farmName;
  late TextEditingController _farmSize;
  late String _state;
  late String _district;
  late String _taluk;
  late String _language;
  late String _waterSource;
  late String _irrigationMethod;
  late bool _notifications;
  late DateTime _plantingDate;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _village = TextEditingController();
    _farmName = TextEditingController();
    _farmSize = TextEditingController();
    _state = KarnatakaLocations.state;
    _district = KarnatakaLocations.districts.first;
    _taluk = KarnatakaLocations.taluksFor(_district).first;
    _language = 'English';
    _waterSource = 'Borewell';
    _irrigationMethod = 'Drip';
    _notifications = true;
    _plantingDate = DateTime.now();
    _loadExisting();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _village.dispose();
    _farmName.dispose();
    _farmSize.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final existing = ref.read(profileRepositoryProvider).load(user.uid);
    if (existing != null && mounted) {
      setState(() {
        _name.text = existing.name;
        _phone.text = existing.phone;
        _village.text = existing.village;
        _farmName.text = existing.farmName;
        _farmSize.text = existing.farmSizeAcres.toString();
        _state = existing.state.isEmpty ? KarnatakaLocations.state : existing.state;
        final districts = KarnatakaLocations.districtsFor(_state);
        _district = existing.district.isEmpty
            ? (districts.isNotEmpty ? districts.first : '')
            : existing.district;
        final taluks = KarnatakaLocations.taluksFor(_district);
        _taluk = existing.taluk.isEmpty
            ? (taluks.isNotEmpty ? taluks.first : 'General')
            : existing.taluk;
        _language = existing.language;
        _waterSource = existing.waterSource;
        _irrigationMethod = existing.irrigationMethod;
        _notifications = existing.notificationsEnabled;
        _plantingDate = existing.plantingDate;
        _loaded = true;
      });
    } else {
      setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    setState(() => _saving = true);
    final location = KarnatakaLocations.formatLocation(
      state: _state,
      district: _district,
      taluk: _taluk,
      village: _village.text.trim(),
    );
    final profile = FarmProfileModel(
      userId: user.uid,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      location: location,
      state: _state,
      district: _district,
      taluk: _taluk,
      village: _village.text.trim(),
      language: _language,
      notificationsEnabled: _notifications,
      farmName: _farmName.text.trim(),
      farmSizeAcres: double.tryParse(_farmSize.text) ?? 0,
      waterSource: _waterSource,
      irrigationMethod: _irrigationMethod,
      crop: 'Arecanut',
      plantingDate: _plantingDate,
    );
    try {
      await ref.read(profileRepositoryProvider).save(profile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Farmer profile',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              _field(_name, 'Full name', Icons.person),
              _field(_phone, 'Phone number', Icons.phone,
                  keyboard: TextInputType.phone),
              const SizedBox(height: 6),
              Text('Location', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _state,
                decoration: const InputDecoration(
                  labelText: 'State',
                  prefixIcon: Icon(Icons.map, size: 20),
                ),
                items: KarnatakaLocations.states
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _state = v;
                    final districts = KarnatakaLocations.districtsFor(v);
                    _district = districts.isNotEmpty ? districts.first : '';
                    final taluks = KarnatakaLocations.taluksFor(_district);
                    _taluk = taluks.isNotEmpty ? taluks.first : 'General';
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _district.isEmpty ? null : _district,
                decoration: const InputDecoration(
                  labelText: 'District',
                  prefixIcon: Icon(Icons.location_city, size: 20),
                ),
                items: KarnatakaLocations.districtsFor(_state)
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _district = v;
                    final taluks = KarnatakaLocations.taluksFor(v);
                    _taluk = taluks.isNotEmpty ? taluks.first : 'General';
                  });
                },
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please select a district' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _taluk,
                decoration: const InputDecoration(
                  labelText: 'Taluk',
                  prefixIcon: Icon(Icons.location_on, size: 20),
                ),
                items: KarnatakaLocations.taluksFor(_district)
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => v != null ? setState(() => _taluk = v) : null,
              ),
              const SizedBox(height: 12),
              _field(_village, 'Village', Icons.house),
              const SizedBox(height: 18),
              Text('Preferences',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _language,
                decoration: const InputDecoration(
                  labelText: 'Language',
                  prefixIcon: Icon(Icons.language, size: 20),
                ),
                items: const ['English', 'Kannada', 'Malayalam', 'Hindi']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) =>
                    v != null ? setState(() => _language = v) : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _notifications,
                onChanged: (v) => setState(() => _notifications = v),
                title: const Text('Enable notifications'),
                secondary: const Icon(Icons.notifications),
              ),
              const SizedBox(height: 18),
              Text('Farm details',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              _field(_farmName, 'Farm name', Icons.agriculture),
              _field(
                _farmSize,
                'Farm size (acres)',
                Icons.square_foot,
                keyboard:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Enter valid size' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _waterSource,
                decoration: const InputDecoration(
                  labelText: 'Water source',
                  prefixIcon: Icon(Icons.water_drop, size: 20),
                ),
                items: const ['Borewell', 'Open well', 'Canal', 'Rainwater', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) =>
                    v != null ? setState(() => _waterSource = v) : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _irrigationMethod,
                decoration: const InputDecoration(
                  labelText: 'Irrigation method',
                  prefixIcon: Icon(Icons.waves, size: 20),
                ),
                items: const ['Drip', 'Sprinkler', 'Flood', 'Other']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) =>
                    v != null ? setState(() => _irrigationMethod = v) : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(
                  'Planting date: ${_plantingDate.day}/${_plantingDate.month}/${_plantingDate.year}',
                ),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1980),
                    lastDate: DateTime.now(),
                    initialDate: _plantingDate,
                  );
                  if (d != null) setState(() => _plantingDate = d);
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Saving...' : 'Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator ??
            (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
