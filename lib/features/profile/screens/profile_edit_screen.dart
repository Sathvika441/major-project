import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/karnataka_locations.dart';
import '../../../core/services/location_master_service.dart';
import '../../../core/validators/auth_validators.dart';
import '../../../models/farm/farm_profile_model.dart';
import '../../../repositories/profile/profile_repository.dart';
import '../../auth/controllers/auth_controller.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _village;
  late final TextEditingController _survey;
  late final TextEditingController _farmName;
  late final TextEditingController _farmSize;
  String _state = KarnatakaLocations.state;
  String _district = '';
  String _taluk = '';
  String _villageCode = '';
  String _language = 'English';
  String _waterSource = 'Borewell';
  String _irrigationMethod = 'Drip';
  String? _cultivation;
  String? _soil;
  bool _notifications = true;
  DateTime _plantingDate = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _otp;
  String? _pendingPhone;
  String? _sentOtpForDebug;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _village = TextEditingController();
    _survey = TextEditingController();
    _farmName = TextEditingController();
    _farmSize = TextEditingController();
    _otp = TextEditingController();
    _loadExisting();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _village.dispose();
    _survey.dispose();
    _farmName.dispose();
    _farmSize.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;
    final locationService = ref.read(locationMasterServiceProvider);
    await locationService.load();
    final existing = ref.read(profileRepositoryProvider).load(user.uid);
    if (!mounted) return;

    final districts = locationService.districts.isNotEmpty
        ? locationService.districts
        : KarnatakaLocations.districts;
    final district = existing?.district.isNotEmpty == true
        ? existing!.district
        : (districts.isNotEmpty ? districts.first : '');
    final taluks = locationService.taluksFor(district);
    final taluk = existing?.taluk.isNotEmpty == true
        ? existing!.taluk
        : (taluks.isNotEmpty ? taluks.first : '');

    setState(() {
      _name.text = existing?.name ?? user.name;
      _phone.text = existing?.phone ?? user.phone;
      _village.text = existing?.village ?? '';
      _villageCode = existing?.villageCode ?? '';
      _survey.text = existing?.landSurveyNumber ?? '';
      _farmName.text = existing?.farmName ?? '';
      _farmSize.text = (existing?.farmSizeAcres ?? 0).toString();
      _state = KarnatakaLocations.state;
      _district = district;
      _taluk = taluk;
      _language = existing?.language ?? 'English';
      _waterSource = existing?.waterSource ?? 'Borewell';
      _irrigationMethod = existing?.irrigationMethod ?? 'Drip';
      _cultivation = cultivationTypes.contains(existing?.arecanutCultivationType)
          ? existing?.arecanutCultivationType
          : null;
      _soil = soilTypes.contains(existing?.soilType) ? existing?.soilType : null;
      _notifications = existing?.notificationsEnabled ?? true;
      _plantingDate = existing?.plantingDate ?? DateTime.now();
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
    final normalized = _phone.text.trim();
    if (AuthValidators.validatePhone(normalized) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthValidators.validatePhone(normalized)!)),
      );
      return;
    }
    final code = await ref.read(authControllerProvider.notifier).sendPhoneChangeOtp(normalized);
    if (!mounted || code == null) return;
    setState(() {
      _pendingPhone = normalized;
      _sentOtpForDebug = code;
    });
    await _showPhoneOtpDialog();
  }

  Future<void> _showPhoneOtpDialog() async {
    _otp.clear();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify new phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the 6-digit code sent to $_pendingPhone.'),
            if (_sentOtpForDebug != null) ...[
              const SizedBox(height: 8),
              Text('[QA] Mock OTP: $_sentOtpForDebug', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'OTP'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final ok = await ref.read(authControllerProvider.notifier).verifyPhoneChangeOtp(
                    _pendingPhone!,
                    _otp.text.trim(),
                  );
              if (dialogContext.mounted) Navigator.pop(dialogContext, ok);
              if (!ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ref.read(authControllerProvider).errorMessage ?? 'Invalid OTP')),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New phone number verified.')),
      );
      setState(() => _sentOtpForDebug = null);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    final existing = ref.read(profileRepositoryProvider).load(user.uid);
    if (_phone.text.trim() != (existing?.phone ?? user.phone).trim()) {
      if (_pendingPhone != _phone.text.trim() || !user.isPhoneVerified) {
        await _requestPhoneOtp();
        final refreshed = ref.read(authControllerProvider).user;
        if (!mounted || refreshed == null || refreshed.phone.trim() != _phone.text.trim() || !refreshed.isPhoneVerified) {
          return;
        }
      }
    }

    if (_villageCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a village from the master list.')),
      );
      return;
    }

    setState(() => _saving = true);
    final profile = FarmProfileModel(
      userId: user.uid,
      name: _name.text.trim(),
      phone: _phone.text.trim(),
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
      farmName: _farmName.text.trim(),
      farmSizeAcres: double.tryParse(_farmSize.text) ?? 0,
      waterSource: _waterSource,
      irrigationMethod: _irrigationMethod,
      crop: 'Arecanut',
      plantingDate: _plantingDate,
      landSurveyNumber: _survey.text.trim(),
      arecanutCultivationType: _cultivation ?? '',
      soilType: _soil ?? '',
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
            DropdownButtonFormField<String>(
              value: KarnatakaLocations.state,
              decoration: const InputDecoration(labelText: 'State', prefixIcon: Icon(Icons.map)),
              items: const [DropdownMenuItem(value: 'Karnataka', child: Text('Karnataka'))],
              onChanged: null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _district.isEmpty ? null : _district,
              decoration: const InputDecoration(labelText: 'District', prefixIcon: Icon(Icons.location_city)),
              items: _districts.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value == null) return;
                final taluks = ref.read(locationMasterServiceProvider).taluksFor(value);
                setState(() {
                  _district = value;
                  _taluk = taluks.isNotEmpty ? taluks.first : '';
                  _village.clear();
                  _villageCode = '';
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _taluk.isEmpty ? null : _taluk,
              decoration: const InputDecoration(labelText: 'Taluk', prefixIcon: Icon(Icons.place)),
              items: _taluks.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _taluk = value;
                  _village.clear();
                  _villageCode = '';
                });
              },
            ),
            const SizedBox(height: 12),
            Autocomplete<VillageEntry>(
              displayStringForOption: (option) => option.name,
              optionsBuilder: (value) {
                final query = value.text.trim().toLowerCase();
                final options = _villages;
                return query.isEmpty ? options : options.where((v) => v.name.toLowerCase().contains(query));
              },
              initialValue: TextEditingValue(text: _village.text),
              onSelected: (value) => setState(() {
                _village.text = value.name;
                _villageCode = value.code;
              }),
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(labelText: 'Village', hintText: 'Search village', prefixIcon: Icon(Icons.home_work)),
                validator: (_) => _villageCode.isEmpty ? 'Select a village from the list' : null,
                onChanged: (_) => setState(() => _villageCode = ''),
              ),
            ),
            const SizedBox(height: 20),
            Text('Preferences', style: Theme.of(context).textTheme.titleMedium),
            DropdownButtonFormField<String>(value: _language, decoration: const InputDecoration(labelText: 'Language'), items: const ['English', 'Kannada', 'Malayalam', 'Hindi'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (value) => setState(() => _language = value!)),
            SwitchListTile(value: _notifications, onChanged: (value) => setState(() => _notifications = value), title: const Text('Enable notifications')),
            const SizedBox(height: 12),
            Text('Farm details', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextFormField(controller: _survey, decoration: const InputDecoration(labelText: 'Land survey number'), validator: AuthValidators.validateSurveyNumber),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: _cultivation, decoration: const InputDecoration(labelText: 'Arecanut cultivation type'), items: cultivationTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (value) => setState(() => _cultivation = value), validator: (value) => value == null ? 'Required' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(value: _soil, decoration: const InputDecoration(labelText: 'Soil type'), items: soilTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (value) => setState(() => _soil = value), validator: (value) => value == null ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _farmName, decoration: const InputDecoration(labelText: 'Farm name')),
            TextFormField(controller: _farmSize, decoration: const InputDecoration(labelText: 'Farm size (acres)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => double.tryParse(v ?? '') == null ? 'Enter valid size' : null),
            DropdownButtonFormField<String>(value: _waterSource, decoration: const InputDecoration(labelText: 'Water source'), items: const ['Borewell', 'Open well', 'Canal', 'Rainwater', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (value) => setState(() => _waterSource = value!)),
            DropdownButtonFormField<String>(value: _irrigationMethod, decoration: const InputDecoration(labelText: 'Irrigation method'), items: const ['Drip', 'Sprinkler', 'Flood', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (value) => setState(() => _irrigationMethod = value!)),
            ListTile(leading: const Icon(Icons.calendar_month), title: Text('Planting date: ${_plantingDate.day}/${_plantingDate.month}/${_plantingDate.year}'), onTap: () async {
              final selected = await showDatePicker(context: context, firstDate: DateTime(1980), lastDate: DateTime.now(), initialDate: _plantingDate);
              if (selected != null) setState(() => _plantingDate = selected);
            }),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.check), label: Text(_saving ? 'Saving...' : 'Save profile')),
          ],
        ),
      ),
    );
  }
}
