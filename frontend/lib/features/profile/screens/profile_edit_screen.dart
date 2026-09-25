import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/karnataka_locations.dart';
import '../../../core/services/location_master_service.dart';
import '../../../core/validators/auth_validators.dart';
import '../../../models/farm/farm_profile_model.dart';
import '../../../models/farm/farm_model.dart';
import '../../../repositories/farm/farm_repository.dart';
import '../../../repositories/profile/profile_repository.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../farm/screens/farm_details_screen.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  String _state = KarnatakaLocations.state;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _village;
  late final TextEditingController _otp;
  String _district = '';
  String _taluk = '';
  String _villageCode = '';
  String _language = 'English';
  bool _notifications = true;
  bool _loading = true;
  bool _saving = false;
  List<FarmModel> _farms = [];
  final Map<String, List<PlotModel>> _farmPlots = {};
  String? _pendingPhone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _village = TextEditingController();
    _otp = TextEditingController();
    _loadExisting();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _village.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final locations = ref.read(locationMasterServiceProvider);
    await locations.load();
    final existing = await ref.read(profileRepositoryProvider).load(user.uid);
    final farms = await ref.read(farmRepositoryProvider).getFarms(user.uid);
    for (final farm in farms) {
      _farmPlots[farm.id] = await ref.read(farmRepositoryProvider).getPlots(user.uid, farm.id);
    }
    if (!mounted) return;

    final districts = locations.districts.isNotEmpty
        ? locations.districts
        : KarnatakaLocations.districts;
    final district = existing?.district.isNotEmpty == true
        ? existing!.district
        : (districts.isNotEmpty ? districts.first : '');
    final taluks = locations.taluksFor(district);
    final taluk = existing?.taluk.isNotEmpty == true
        ? existing!.taluk
        : (taluks.isNotEmpty ? taluks.first : '');

    setState(() {
      _name.text = existing?.name ?? user.name;
      _phone.text = existing?.phone ?? user.phone;
      _village.text = existing?.village ?? '';
      _villageCode = existing?.villageCode ?? '';
      _state = KarnatakaLocations.state;
      _district = district;
      _taluk = taluk;
      _language = existing?.language ?? 'English';
      _notifications = existing?.notificationsEnabled ?? true;
      _farms = farms;
      _loading = false;
    });
  }

  List<String> get _districts {
    final values = ref.read(locationMasterServiceProvider).districts;
    return values.isNotEmpty ? values : KarnatakaLocations.districts;
  }

  List<String> get _taluks {
    final values = ref.read(locationMasterServiceProvider).taluksFor(_district);
    return values.isNotEmpty ? values : KarnatakaLocations.taluksFor(_district);
  }

  List<VillageEntry> get _villages =>
      ref.read(locationMasterServiceProvider).villagesFor(_taluk);

  Future<void> _requestPhoneOtp() async {
    final phone = _phone.text.trim();
    final error = AuthValidators.validatePhone(phone);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final code = await ref.read(authControllerProvider.notifier).sendPhoneChangeOtp(phone);
    if (!mounted || code == null) return;

    setState(() => _pendingPhone = phone);
    _otp.clear();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify new phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the 6-digit code sent to $phone.'),
            const SizedBox(height: 8),
            Text('[QA] Mock OTP: $code', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'OTP'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final verified = await ref
                  .read(authControllerProvider.notifier)
                  .verifyPhoneChangeOtp(phone, _otp.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext, verified);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New phone number verified.')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    if (_villageCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a village from the master list.')),
      );
      return;
    }

    final original = await ref.read(profileRepositoryProvider).load(user.uid);
    final newPhone = _phone.text.trim();
    final oldPhone = (original?.phone ?? user.phone).trim();
    if (newPhone != oldPhone) {
      if (_pendingPhone != newPhone || !ref.read(authControllerProvider).user!.isPhoneVerified) {
        await _requestPhoneOtp();
        final refreshed = ref.read(authControllerProvider).user;
        if (!mounted || refreshed == null || refreshed.phone.trim() != newPhone || !refreshed.isPhoneVerified) {
          return;
        }
      }
    }

    setState(() => _saving = true);
    final profile = FarmProfileModel(
      userId: user.uid,
      name: _name.text.trim(),
      phone: newPhone,
      location: KarnatakaLocations.formatLocation(
        state: KarnatakaLocations.state,
        district: _district,
        taluk: _taluk,
        village: _village.text.trim(),
      ),
      state: KarnatakaLocations.state,
      district: _district,
      taluk: _taluk,
      village: _village.text.trim(),
      villageCode: _villageCode,
      language: _language,
      notificationsEnabled: _notifications,
      farmName: original?.farmName ?? '',
      farmSizeAcres: original?.farmSizeAcres ?? 0,
      waterSource: original?.waterSource ?? '',
      irrigationMethod: original?.irrigationMethod ?? '',
      crop: original?.crop ?? 'Arecanut',
      plantingDate: original?.plantingDate ?? DateTime.now(),
      landSurveyNumber: original?.landSurveyNumber ?? '',

    );

    try {
      await ref.read(profileRepositoryProvider).save(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Farmer profile', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person)), validator: AuthValidators.validateName),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone, validator: AuthValidators.validatePhone),
            const SizedBox(height: 18),
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(isExpanded: true, initialValue: KarnatakaLocations.state, decoration: const InputDecoration(labelText: 'State', prefixIcon: Icon(Icons.map)), items: const [DropdownMenuItem(value: 'Karnataka', child: Text('Karnataka'))], onChanged: null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(isExpanded: true, initialValue: _district.isEmpty ? null : _district, decoration: const InputDecoration(labelText: 'District', prefixIcon: Icon(Icons.location_city)), items: _districts.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) {
              if (value == null) return;
              final taluks = ref.read(locationMasterServiceProvider).taluksFor(value);
              setState(() { _district = value; _taluk = taluks.isNotEmpty ? taluks.first : ''; _village.clear(); _villageCode = ''; });
            }),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(isExpanded: true, initialValue: _taluk.isEmpty ? null : _taluk, decoration: const InputDecoration(labelText: 'Taluk', prefixIcon: Icon(Icons.place)), items: _taluks.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) {
              if (value == null) return;
              setState(() { _taluk = value; _village.clear(); _villageCode = ''; });
            }),
            const SizedBox(height: 12),
            Autocomplete<VillageEntry>(
              initialValue: TextEditingValue(text: _village.text),
              displayStringForOption: (option) => option.name,
              optionsBuilder: (value) {
                final query = value.text.trim().toLowerCase();
                final options = _villages;
                return query.isEmpty ? options : options.where((v) => v.name.toLowerCase().contains(query));
              },
              onSelected: (value) => setState(() { _village.text = value.name; _villageCode = value.code; }),
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(labelText: 'Village', hintText: 'Search village', prefixIcon: Icon(Icons.home_work)),
                validator: (_) => _villageCode.isEmpty ? 'Select a village from the list' : null,
                onChanged: (_) => _villageCode = '',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your farms',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (_farms.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No farms have been added yet.'),
                ),
              )
            else
              ..._farms.map(
                (farm) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      child: Icon(Icons.agriculture),
                    ),
                    title: Text(
                      farm.name.isEmpty ? 'Unnamed farm' : farm.name,
                    ),
                    subtitle: Text(
                      '${farm.location}\n'
                      '${farm.sizeAcres} acres • ${farm.waterSource} • ${farm.irrigationMethod}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FarmDetailsScreen(farmId: farm.id),
                        ),
                      );
                      if (mounted) {
                        _loadExisting();
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(value: _notifications, onChanged: (value) => setState(() => _notifications = value), title: const Text('Enable notifications')),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.check), label: Text(_saving ? 'Saving...' : 'Save profile')),
          ],
        ),
      ),
    );
  }
}



