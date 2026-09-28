import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/backend/backend_api.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/services/device_location_service.dart';
import '../../../models/weather/weather_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override ConsumerState<HomeScreen> createState()=>_HomeScreenState();
}
class _HomeScreenState extends ConsumerState<HomeScreen>{
  WeatherData? _weather; String? _error; bool _loading=true; bool _mlLoading=false; Map<String,dynamic>? _mlResult; String? _mlError;
  @override void initState(){super.initState();_loadWeather();}
  Future<void> _loadWeather() async {
    setState((){_loading=true;_error=null;});
    try{
      final loc=await ref.read(deviceLocationServiceProvider).resolveCurrentLocation();
      if(loc==null)throw Exception('Location unavailable. Enable location access or use the Karnataka location picker.');
      final w=await ref.read(backendApiProvider).getWeatherByCoordinates(latitude:loc.latitude,longitude:loc.longitude,label:loc.label);
      if(mounted)setState((){_weather=w;_loading=false;});
    }catch(e){if(mounted)setState((){_loading=false;_error=e.toString().replaceFirst('Exception: ','');});}
  }
  Future<void> _detect() async {
    final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['jpg','jpeg','png','webp'],withData:true);
    if(picked==null||picked.files.single.bytes==null)return;
    final f=picked.files.single;
    if(f.size>10*1024*1024){setState(()=>_mlError='Please select an image smaller than 10 MB.');return;}
    setState((){_mlLoading=true;_mlError=null;_mlResult=null;});
    try{final r=await ref.read(backendApiProvider).predictImage(f.bytes!,filename:f.name);if(mounted)setState((){_mlResult=r;_mlLoading=false;});}
    on BackendApiException catch(e){if(mounted)setState((){_mlError=e.message;_mlLoading=false;});}
    catch(_){if(mounted)setState((){_mlError='Unable to contact the disease detection service.';_mlLoading=false;});}
  }
  @override Widget build(BuildContext context){
    final user=ref.watch(authControllerProvider).user; final s=Theme.of(context).colorScheme;
    return Scaffold(backgroundColor:s.surface,body:RefreshIndicator(onRefresh:_loadWeather,child:ListView(padding:const EdgeInsets.fromLTRB(20,24,20,40),children:[
      _hero(context,user?.name,_weather),
      if(_error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:s.secondaryContainer,borderRadius:BorderRadius.circular(14)),child:Text(_error!,style:TextStyle(color:s.onSecondaryContainer)))),
      const SizedBox(height:20),
      Wrap(spacing:10,runSpacing:10,children:[
        _action(context,Icons.cloud_outlined,'Weather',()=>context.push('/weather')),
        _action(context,Icons.document_scanner_outlined,'Detect disease',_detect),
        _action(context,Icons.agriculture_outlined,'My farms',()=>context.push('/farms')),
        _action(context,user==null?Icons.login_outlined:Icons.person_outline_rounded,user==null?'Sign in':'Profile',()=>context.push(user==null?'/login':'/profile')),
      ]),
      const SizedBox(height:20),_diseaseCard(context),
      const SizedBox(height:20),
      Card(child:Padding(padding:const EdgeInsets.all(20),child:Row(children:[Icon(Icons.agriculture_rounded,color:s.primary,size:28),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(user==null?'Add your farm':'Your farms',style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:4),Text(user==null?'Sign in to save farms and get farm-specific weather.':'Open a farm to view its saved location weather and recommendations.')]),TextButton(onPressed:()=>context.push(user==null?'/login':'/farms'),child:Text(user==null?'Sign in':'Open'))]))),
    ])));
  }
  Widget _hero(BuildContext c,String? name,WeatherData? w){final s=Theme.of(c).colorScheme;final temp=w?.temperature==null?'--°C':'${w!.temperature!.round()}°C';return Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(color:s.primary,borderRadius:BorderRadius.circular(28)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(name==null?'Good day, farmer':'Welcome back, $name',style:TextStyle(color:s.onPrimary,fontSize:18,fontWeight:FontWeight.w800))),IconButton(onPressed:_loadWeather,icon:Icon(Icons.refresh_rounded,color:s.onPrimary))]),
    const SizedBox(height:14),Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(w?.weatherDescription??'Weather loading',style:TextStyle(color:s.onPrimary.withValues(alpha:.9))),const SizedBox(height:3),Text(temp,style:TextStyle(color:s.onPrimary,fontSize:32,fontWeight:FontWeight.w800)),const SizedBox(height:5),Text(w==null?'Getting local weather…':'${w.district?.isNotEmpty==true?w.district:w.locationName} • today',style:TextStyle(color:s.onPrimary.withValues(alpha:.8),fontSize:12))])),Icon(_glyph(w?.weatherCode),color:s.onPrimary,size:56)]),
    const SizedBox(height:14),Divider(color:s.onPrimary.withValues(alpha:.25)),const SizedBox(height:12),Row(children:[_metric(s,'Rain','${w?.next24hPrecipitationProbability.round()??'--'}%'),_metric(s,'Humidity','${w?.humidity?.round()??'--'}%'),_metric(s,'Wind','${w?.windKmh?.round()??'--'} km/h')])
  ]));}
  Widget _metric(ColorScheme s,String l,String v)=>Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(l,style:TextStyle(color:s.onPrimary.withValues(alpha:.7),fontSize:11)),const SizedBox(height:2),Text(v,style:TextStyle(color:s.onPrimary,fontWeight:FontWeight.w700))]));
  Widget _action(BuildContext c,IconData i,String label,VoidCallback onTap)=>SizedBox(width:150,child:OutlinedButton.icon(onPressed:onTap,icon:Icon(i),label:Text(label),style:OutlinedButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:12,vertical:15),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)))));
  Widget _diseaseCard(BuildContext c){final s=Theme.of(c).colorScheme;final p=_mlResult?['prediction']?.toString();final conf=(_mlResult?['confidence'] as num?)?.toDouble();return Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(Icons.health_and_safety_outlined,color:s.primary),const SizedBox(width:10),Expanded(child:Text('AI crop health check',style:Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w800))),FilledButton.tonalIcon(onPressed:_mlLoading?null:_detect,icon:const Icon(Icons.upload_file_outlined),label:const Text('Image'))]),const SizedBox(height:12),if(_mlLoading)const LinearProgressIndicator(),if(_mlError!=null)Padding(padding:const EdgeInsets.only(top:10),child:Text(_mlError!,style:TextStyle(color:s.error))),if(p!=null)...[const SizedBox(height:12),Text(p,style:Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),if(conf!=null)Text('Prediction score: ${(conf*100).toStringAsFixed(1)}%'),const SizedBox(height:6),Text('AI prediction only — not a confirmed field diagnosis.',style:Theme.of(c).textTheme.bodySmall)]else if(!_mlLoading)const Text('Upload a JPG, PNG or WEBP image for arecanut disease classification.')]))));}
  static IconData _glyph(int? c){if(c==null)return Icons.cloud_outlined;if(c==0)return Icons.wb_sunny_outlined;if(c<4)return Icons.cloud_outlined;if(c<50)return Icons.foggy;if(c<70)return Icons.grain;if(c<90)return Icons.water_drop_outlined;return Icons.thunderstorm_outlined;}
}
