import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/device_location_service.dart';
import '../../../core/services/location_master_service.dart';

Future<void> showManualLocationPicker(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function(String district, String taluk, String village) onSelected,
}) async {
  final master = ref.read(locationMasterServiceProvider);
  String? district;
  String? taluk;
  VillageEntry? village;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) {
        final taluks = district == null ? const <String>[] : master.taluksFor(district!);
        final villages = taluk == null ? const <VillageEntry>[] : master.villagesFor(taluk!);

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your location',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('Used only to load local weather on this device.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: district,
                decoration: const InputDecoration(labelText: 'District'),
                items: master.districts
                    .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) => setState(() {
                  district = value;
                  taluk = null;
                  village = null;
                }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: taluk,
                decoration: const InputDecoration(labelText: 'Taluk'),
                items: taluks
                    .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
                    .toList(),
                onChanged: district == null
                    ? null
                    : (value) => setState(() {
                          taluk = value;
                          village = null;
                        }),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<VillageEntry>(
                initialValue: village,
                decoration: const InputDecoration(labelText: 'Village'),
                items: villages
                    .map((item) => DropdownMenuItem<VillageEntry>(value: item, child: Text(item.name)))
                    .toList(),
                onChanged: taluk == null ? null : (value) => setState(() => village = value),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: district != null && taluk != null && village != null
                      ? () async {
                          final selectedDistrict = district!;
                          final selectedTaluk = taluk!;
                          final selectedVillage = village!;
                          await ref.read(deviceLocationServiceProvider).saveLastWeatherPlace(
                                district: selectedDistrict,
                                taluk: selectedTaluk,
                                village: selectedVillage.name,
                              );
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                          await onSelected(selectedDistrict, selectedTaluk, selectedVillage.name);
                        }
                      : null,
                  child: const Text('Use this location'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
