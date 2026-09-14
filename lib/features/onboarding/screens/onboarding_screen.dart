import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/karnataka_locations.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../models/farm/farm_profile_model.dart';
import '../../../models/farm/farm_model.dart';
import '../../../repositories/farm/farm_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _village = TextEditingController();
  final _farmName = TextEditingController();
  final _size = TextEditingController();
  DateTime? _plantingDate;
  String _state = KarnatakaLocations.state;
  late String _district;
  late String _taluk;
  String _language = 'English';
  String _waterSource = 'Borewell';
  String _irrigationMethod = 'Drip';
  bool _notifications = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final districts = KarnatakaLocations.districtsFor(_state);
    _district = districts.isNotEmpty ? districts.first : '';
    final taluks = KarnatakaLocations.taluksFor(_district);
    _taluk = taluks.isNotEmpty ? taluks.first : 'General';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _village.dispose();
    _farmName.dispose();
    _size.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate() || _plantingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please complete all required fields.')));
      return;
    }
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
      farmSizeAcres: double.parse(_size.text),
      waterSource: _waterSource,
      irrigationMethod: _irrigationMethod,
      crop: 'Arecanut',
      plantingDate: _plantingDate!,
    );
    await ref.read(farmRepositoryProvider).saveFarm(FarmModel(
          id: 'farm_${DateTime.now().microsecondsSinceEpoch}',
          userId: user.uid,
          name: profile.farmName,
          location: profile.location,
          sizeAcres: profile.farmSizeAcres,
          waterSource: profile.waterSource,
          irrigationMethod: profile.irrigationMethod,
          createdAt: DateTime.now(),
        ));
    await ref
        .read(localStorageServiceProvider)
        .raw
        .setString('phase25_profile_${user.uid}', profile.toJson());
    await ref.read(localStorageServiceProvider).setOnboardingCompleted(true);
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your farm')),
      body: SafeArea(
          child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Farmer profile',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _field(_name, 'Full name'),
            _field(_phone, 'Phone number', keyboard: TextInputType.phone),
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
                  _district =
                      districts.isNotEmpty ? districts.first : '';
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
                  v == null || v.isEmpty ? 'Select a district' : null,
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
            _field(_village, 'Village'),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(labelText: 'Language'),
              items: const ['English', 'Kannada', 'Malayalam', 'Hindi']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _language = v!),
            ),
            SwitchListTile(
                value: _notifications,
                onChanged: (v) => setState(() => _notifications = v),
                title: const Text('Enable notifications')),
            const SizedBox(height: 18),
            Text('Farm & crop',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _field(_farmName, 'Farm name'),
            _field(_size, 'Farm size (acres)',
                keyboard:
                    const TextInputType.numberWithOptions(decimal: true)),
            DropdownButtonFormField<String>(
              value: _waterSource,
              decoration: const InputDecoration(labelText: 'Water source'),
              items: const [
                'Borewell',
                'Open well',
                'Canal',
                'Rainwater',
                'Other'
              ]
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _waterSource = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _irrigationMethod,
              decoration: const InputDecoration(labelText: 'Irrigation method'),
              items: const ['Drip', 'Sprinkler', 'Flood', 'Other']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _irrigationMethod = v!),
            ),
            ListTile(
                title: Text(_plantingDate == null
                    ? 'Planting date'
                    : 'Planted ${_plantingDate!.day}/${_plantingDate!.month}/${_plantingDate!.year}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now(),
                      initialDate: DateTime.now());
                  if (d != null) setState(() => _plantingDate = d);
                }),
            const ListTile(
                leading: Icon(Icons.eco),
                title: Text('Crop'),
                subtitle: Text('Arecanut')),
            const SizedBox(height: 20),
            FilledButton.icon(
                onPressed: _saving ? null : _complete,
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Saving...' : 'Complete setup')),
          ],
        ),
      )),
    );
  }

  Widget _field(TextEditingController controller, String label,
          {TextInputType? keyboard}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              controller: controller,
              keyboardType: keyboard,
              decoration: InputDecoration(labelText: label),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null));
}
