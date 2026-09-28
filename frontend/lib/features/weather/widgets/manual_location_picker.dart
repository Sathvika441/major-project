import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/location_master_service.dart';
import '../../../core/services/device_location_service.dart';

Future<void> showManualLocationPicker(BuildContext context, WidgetRef ref, {required Future<void> Function(String district,String taluk,String village) onSelected}) async {
  final master=ref.read(locationMasterServiceProvider);
  String? district;String? taluk;VillageEntry? village;
  await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(sheetContext)=>StatefulBuilder(builder:(context,setState){
    final taluks=district==null?const <String>[]:master.taluksFor(district!);
    final villages=taluk==null?const <VillageEntry>[]:master.villagesFor(taluk!);
    return Padding(padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(context).viewInsets.bottom+20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('Choose your location',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:6),
      const Text('Used only to load local weather on this device.'),
      const SizedBox(height:16),
      DropdownButtonFormField<String>(initialValue:district,decoration:const InputDecoration(labelText:'District'),items:master.districts.map((d)=>DropdownMenuItem(value:d,child:Text(d))).toList(),onChanged:(v)=>setState((){district=v;taluk=null;village=null;})),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(initialValue:taluk,decoration:const InputDecoration(labelText:'Taluk'),items:taluks.map((t)=>DropdownMenuItem(value:t,child:Text(t))).toList(),onChanged:district==null?null:(v)=>setState((){taluk=v;village=null;})),
      const SizedBox(height:10),
      DropdownButtonFormField<VillageEntry>(initialValue:village,decoration:const InputDecoration(labelText:'Village'),items:villages.map((v)=>DropdownMenuItem(value:v,child:Text(v.name))).toList(),onChanged:taluk==null?null:(v)=>setState(()=>village=v)),
      const SizedBox(height:18),
      SizedBox(width:double.infinity,child:FilledButton(onPressed:district!=null&&taluk!=null&&village!=null?()async{final d=district!,t=taluk!,v=village!;final service=ref.read(deviceLocationServiceProvider);await service.saveLastLocation(DeviceLocation(latitude:0,longitude:0,label:'$v, $t, $d',savedAt:DateTime.now()));if(context.mounted)Navigator.pop(context);await onSelected(d,t,v.name);}:null,child:const Text('Use this location')))
    ]);}));
}
