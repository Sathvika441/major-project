import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/backend/backend_api.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/services/device_location_service.dart';
import '../../../models/weather/weather_model.dart';
import '../../weather/widgets/manual_location_picker.dart';
import '../../../widgets/asset_glass_panel.dart';
import '../../../widgets/app_navigation_scaffold.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  WeatherData? _weather;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = await ref
          .read(deviceLocationServiceProvider)
          .resolveCurrentLocation();
      WeatherData weather;
      if (location != null) {
        weather = await ref
            .read(backendApiProvider)
            .getWeatherByCoordinates(
              latitude: location.latitude,
              longitude: location.longitude,
              label: location.label,
            );
      } else {
        final saved = await ref
            .read(deviceLocationServiceProvider)
            .loadLastWeatherPlace();
        weather = saved != null
            ? await ref
                  .read(backendApiProvider)
                  .getWeatherByPlace(
                    district: saved['district']!,
                    taluk: saved['taluk']!,
                    village: saved['village']!,
                  )
            : await ref
                  .read(backendApiProvider)
                  .getWeatherByPlace(district: 'Shivamogga');
      }
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final scheme = Theme.of(context).colorScheme;
    return AppNavigationScaffold(
      title: 'Home',
      selectedIndex: 0,
      body: RefreshIndicator(
        onRefresh: _loadWeather,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            _hero(context, user?.name, _weather),
            if (_loading && _weather == null)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(color: scheme.onSecondaryContainer),
                      ),
                      TextButton(
                        onPressed: () => showManualLocationPicker(
                          context,
                          ref,
                          onSelected: (district, taluk, village) async {
                            await ref
                                .read(backendApiProvider)
                                .getWeatherByPlace(
                                  district: district,
                                  taluk: taluk,
                                  village: village,
                                );
                            await _loadWeather();
                          },
                        ),
                        child: const Text('Choose Karnataka location'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _action(
                  context,
                  Icons.wb_cloudy_rounded,
                  'Weather',
                  () => context.push('/weather'),
                ),
                _action(
                  context,
                  Icons.biotech_rounded,
                  'Detect disease',
                  () => showDialog<void>(
                    context: context,
                    builder: (_) => const _DiseaseDetectionDialog(),
                  ),
                ),
                _action(
                  context,
                  Icons.agriculture_rounded,
                  'My farms',
                  () => context.push('/farms'),
                ),
                _action(
                  context,
                  user == null
                      ? Icons.login_rounded
                      : Icons.account_circle_rounded,
                  user == null ? 'Sign in' : 'Profile',
                  () => context.push(user == null ? '/login' : '/profile'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.agriculture_rounded,
                      color: scheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user == null ? 'Add your farm' : 'Your farms',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user == null
                                ? 'Sign in to save farms and get farm-specific weather.'
                                : 'Open a farm to view its saved location weather and recommendations.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () =>
                          context.push(user == null ? '/login' : '/farms'),
                      child: Text(user == null ? 'Sign in' : 'Open'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, String? name, WeatherData? weather) {
    final scheme = Theme.of(context).colorScheme;
    final temperature = weather?.temperature == null
        ? '--°C'
        : '${weather!.temperature!.round()}°C';
    return AssetGlassPanel(
      imagePath: 'assets/images/360_F_973272541_ZKlahbFV5Tnn2GTd83z0wJQlSEPIWT4Y.jpg.jpeg',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name == null ? 'Good day, farmer' : 'Welcome back, ${name}',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadWeather,
                icon: Icon(Icons.refresh_rounded, color: scheme.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather?.weatherDescription ?? 'Weather loading',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      temperature,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      weather == null
                          ? 'Getting local weather…'
                          : '${weather.locality?.isNotEmpty == true ? weather.locality : (weather.district?.isNotEmpty == true ? weather.district : weather.locationName)} • today',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _glyph(weather?.weatherCode),
                color: scheme.onPrimary,
                size: 56,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: scheme.onPrimary.withValues(alpha: 0.25)),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric(
                scheme,
                'Rain',
                '${weather?.next24hPrecipitationProbability.round() ?? '--'}%',
              ),
              _metric(
                scheme,
                'Humidity',
                '${weather?.humidity?.round() ?? '--'}%',
              ),
              _metric(
                scheme,
                'Wind',
                '${weather?.windKmh?.round() ?? '--'} km/h',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(ColorScheme scheme, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: scheme.onPrimary.withValues(alpha: 0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionTextColor = isDark ? Colors.white : Colors.black;
    return SizedBox(
      width: 150,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: actionTextColor),
        label: Text(label, style: TextStyle(color: actionTextColor)),
        style: OutlinedButton.styleFrom(
          foregroundColor: actionTextColor,
          side: BorderSide(color: actionTextColor.withValues(alpha: 0.28)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  static IconData _glyph(int? code) {
    if (code == null) return Icons.cloud_outlined;
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code < 4) return Icons.cloud_outlined;
    if (code < 50) return Icons.foggy;
    if (code < 70) return Icons.grain;
    if (code < 90) return Icons.water_drop_outlined;
    return Icons.thunderstorm_outlined;
  }
}

class _DiseaseDetectionDialog extends ConsumerStatefulWidget {
  const _DiseaseDetectionDialog();

  @override
  ConsumerState<_DiseaseDetectionDialog> createState() =>
      _DiseaseDetectionDialogState();
}

class _DiseaseDetectionDialogState
    extends ConsumerState<_DiseaseDetectionDialog> {
  PlatformFile? _image;
  Map<String, dynamic>? _result;
  String? _error;
  bool _predicting = false;

  Future<void> _pickImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (picked == null || !mounted) return;

    final file = picked.files.single;
    if (file.bytes == null || file.bytes!.isEmpty) {
      setState(() {
        _error = 'Unable to read the selected image. Please choose another.';
        _result = null;
      });
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setState(() {
        _error = 'Please select an image smaller than 10 MB.';
        _result = null;
      });
      return;
    }

    setState(() {
      _image = file;
      _result = null;
      _error = null;
    });
  }

  Future<void> _predict() async {
    final file = _image;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Please upload an image before predicting.');
      return;
    }

    setState(() {
      _predicting = true;
      _result = null;
      _error = null;
    });
    try {
      final result = await ref
          .read(backendApiProvider)
          .predictImage(bytes, filename: file.name);
      if (!mounted) return;
      setState(() {
        _result = result;
        _predicting = false;
      });
    } on BackendApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _predicting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to contact the disease detection service.';
        _predicting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final confidence = (_result?['confidence'] as num?)?.toDouble();

    return AlertDialog(
      title: const Text('Detect disease'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_image?.bytes case final bytes?)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    height: 240,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text('Unable to preview this image.'),
                      ),
                    ),
                  ),
                )
              else
                const Text('Upload a JPG, PNG or WEBP image to get started.'),
              if (_image != null) ...[
                const SizedBox(height: 8),
                Text(
                  _image!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                Text(
                  _result!['prediction']?.toString() ?? 'Result received',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (confidence != null)
                  Text(
                    'Prediction score: ${(confidence * 100).toStringAsFixed(1)}%',
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _predicting ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: _predicting ? null : _pickImage,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(_image == null ? 'Upload image' : 'Change image'),
        ),
        if (_image != null)
          FilledButton.icon(
            onPressed: _predicting ? null : _predict,
            icon: _predicting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(_predicting ? 'Predicting...' : 'Predict'),
          ),
      ],
    );
  }
}
