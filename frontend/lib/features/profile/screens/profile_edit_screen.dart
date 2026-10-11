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
import '../../../app/theme/theme_mode_controller.dart';
import '../../../widgets/app_navigation_scaffold.dart';

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

  String _initialName = '';
  String _initialPhone = '';
  String _initialDistrict = '';
  String _initialTaluk = '';
  String _initialVillage = '';
  String _initialVillageCode = '';
  String _initialLanguage = 'English';
  bool _initialNotifications = true;

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
      _farmPlots[farm.id] = await ref
          .read(farmRepositoryProvider)
          .getPlots(user.uid, farm.id);
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
      _initialName = _name.text.trim();
      _initialPhone = _phone.text.trim();
      _initialDistrict = _district;
      _initialTaluk = _taluk;
      _initialVillage = _village.text.trim();
      _initialVillageCode = _villageCode;
      _initialLanguage = _language;
      _initialNotifications = _notifications;
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

  bool get _hasUnsavedChanges {
    return _name.text.trim() != _initialName ||
        _phone.text.trim() != _initialPhone ||
        _district != _initialDistrict ||
        _taluk != _initialTaluk ||
        _village.text.trim() != _initialVillage ||
        _villageCode != _initialVillageCode ||
        _language != _initialLanguage ||
        _notifications != _initialNotifications;
  }

  Future<void> _requestPhoneOtp() async {
    final phone = _phone.text.trim();
    final error = AuthValidators.validatePhone(phone);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final code = await ref
        .read(authControllerProvider.notifier)
        .sendPhoneChangeOtp(phone);
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
        const SnackBar(
          content: Text('Please select a village from the master list.'),
        ),
      );
      return;
    }

    final original = await ref.read(profileRepositoryProvider).load(user.uid);
    final newPhone = _phone.text.trim();
    final oldPhone = (original?.phone ?? user.phone).trim();
    if (newPhone != oldPhone) {
      if (_pendingPhone != newPhone ||
          !ref.read(authControllerProvider).user!.isPhoneVerified) {
        await _requestPhoneOtp();
        final refreshed = ref.read(authControllerProvider).user;
        if (!mounted ||
            refreshed == null ||
            refreshed.phone.trim() != newPhone ||
            !refreshed.isPhoneVerified) {
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
      setState(() {
        _initialName = _name.text.trim();
        _initialPhone = newPhone;
        _initialDistrict = _district;
        _initialTaluk = _taluk;
        _initialVillage = _village.text.trim();
        _initialVillageCode = _villageCode;
        _initialLanguage = _language;
        _initialNotifications = _notifications;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final themeMode = ref.watch(themeModeProvider);

    return AppNavigationScaffold(
      title: 'Profile',
      subtitle: 'Manage your farmer profile and preferences',
      selectedIndex: 4,
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth >= 1100 ? 900.0 : 720.0;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileHero(name: _name.text),
                        const SizedBox(height: 18),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                  icon: Icons.person_outline_rounded,
                                  title: 'Personal details',
                                  subtitle: 'Keep your contact information up to date.',
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: _name,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    labelText: 'Full name',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: AuthValidators.validateName,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone number',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  onChanged: (_) => setState(() {}),
                                  validator: AuthValidators.validatePhone,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                  icon: Icons.location_on_outlined,
                                  title: 'Farm location',
                                  subtitle: 'Used to resolve weather for your farm workspace.',
                                ),
                                const SizedBox(height: 18),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: KarnatakaLocations.state,
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
                                  isExpanded: true,
                                  initialValue: _district.isEmpty
                                      ? null
                                      : _district,
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
                                    if (value == null) return;
                                    final taluks = ref
                                        .read(locationMasterServiceProvider)
                                        .taluksFor(value);
                                    setState(() {
                                      _district = value;
                                      _taluk = taluks.isNotEmpty
                                          ? taluks.first
                                          : '';
                                      _village.clear();
                                      _villageCode = '';
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _taluk.isEmpty ? null : _taluk,
                                  decoration: const InputDecoration(
                                    labelText: 'Taluk',
                                    prefixIcon: Icon(Icons.place_outlined),
                                  ),
                                  items: _taluks
                                      .map(
                                        (value) => DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _taluk = value;
                                      _village.clear();
                                      _villageCode = '';
                                    });
                                  },
                                ),
                                const SizedBox(height: 14),
                                Autocomplete<VillageEntry>(
                                  initialValue: TextEditingValue(
                                    text: _village.text,
                                  ),
                                  displayStringForOption: (option) =>
                                      option.name,
                                  optionsBuilder: (value) {
                                    final query = value.text
                                        .trim()
                                        .toLowerCase();
                                    final options = _villages;
                                    return query.isEmpty
                                        ? options
                                        : options.where(
                                            (v) => v.name
                                                .toLowerCase()
                                                .contains(query),
                                          );
                                  },
                                  onSelected: (value) => setState(() {
                                    _village.text = value.name;
                                    _villageCode = value.code;
                                  }),
                                  fieldViewBuilder:
                                      (
                                        context,
                                        controller,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) => TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: const InputDecoration(
                                          labelText: 'Village',
                                          hintText: 'Search village',
                                          prefixIcon: Icon(
                                            Icons.home_work_outlined,
                                          ),
                                        ),
                                        validator: (_) => _villageCode.isEmpty
                                            ? 'Select a village from the list'
                                            : null,
                                        onChanged: (_) =>
                                            setState(() => _villageCode = ''),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(
                                  icon: Icons.agriculture_outlined,
                                  title: 'Your farms',
                                  subtitle: 'Open any farm to edit its cultivation details.',
                                ),
                                const SizedBox(height: 16),
                                if (_farms.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Text(
                                      'No farms have been added yet.',
                                    ),
                                  )
                                else
                                  ..._farms.map(
                                    (farm) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 5,
                                            ),
                                        leading: CircleAvatar(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          child: Icon(
                                            Icons.agriculture_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        title: Text(
                                          farm.name.isEmpty
                                              ? 'Unnamed farm'
                                              : farm.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          farm.location +
                                              '\n' +
                                              farm.sizeAcres.toStringAsFixed(
                                                1,
                                              ) +
                                              ' acres • ' +
                                              farm.irrigationMethod,
                                        ),
                                        isThreeLine: true,
                                        trailing: const Icon(
                                          Icons.chevron_right,
                                        ),
                                        onTap: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => FarmDetailsScreen(
                                                farmId: farm.id,
                                              ),
                                            ),
                                          );
                                          if (mounted) _loadExisting();
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Card(
                          child: Column(
                            children: [
                              SwitchListTile.adaptive(
                                value: _notifications,
                                onChanged: (value) =>
                                    setState(() => _notifications = value),
                                title: const Text(
                                  'Farm notifications',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: const Text(
                                  'Receive important farm and irrigation alerts.',
                                ),
                                secondary: const Icon(
                                  Icons.notifications_none_rounded,
                                ),
                              ),
                              const Divider(height: 1),
                              SwitchListTile.adaptive(
                                value: themeMode == ThemeMode.dark,
                                onChanged: (value) => ref
                                    .read(themeModeProvider.notifier)
                                    .setMode(
                                      value ? ThemeMode.dark : ThemeMode.light,
                                    ),
                                title: const Text(
                                  'Dark mode',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: const Text(
                                  'Use a darker interface in low-light conditions.',
                                ),
                                secondary: Icon(
                                  themeMode == ThemeMode.dark
                                      ? Icons.dark_mode_outlined
                                      : Icons.light_mode_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_hasUnsavedChanges) ...[
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              _saving ? 'Saving profile...' : 'Save changes',
                            ),
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
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;

  const _ProfileHero({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = name.trim().isEmpty ? 'Farmer' : name.trim();
    final initial = displayName.substring(0, 1).toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, 0.42)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: scheme.onPrimary,
            child: Text(
              initial,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farmer profile',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
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

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
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
    );
  }
}
