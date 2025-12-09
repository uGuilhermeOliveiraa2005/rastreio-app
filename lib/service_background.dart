import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

const String baseUrl = "https://meindicaalguem.com.br/api/rastreio";

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', 
    'Rastreio Ativo', 
    description: 'Canal de notificação do rastreio',
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, 
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'Rastreio MeIndica',
      initialNotificationContent: 'Inicializando GPS...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? positionStream;
  bool isTracking = false;

  // Escuta o comando "stopService" - PARA TUDO E ENCERRA
  service.on('stopService').listen((event) {
    print("BACKGROUND: Recebido comando stopService");
    
    // Cancela o stream de localização
    positionStream?.cancel();
    positionStream = null;
    isTracking = false;
    
    // Remove a notificação
    flutterLocalNotificationsPlugin.cancel(888);
    
    // Para o serviço completamente
    service.stopSelf();
  });

  // Escuta o comando "startTracking"
  service.on('startTracking').listen((event) async {
    if (event != null && !isTracking) {
      String codigo = event['codigo'];
      isTracking = true;
      
      print("BACKGROUND: Iniciando rastreio para código $codigo");
      
      // Mostra notificação
      flutterLocalNotificationsPlugin.show(
        888,
        'Rastreio em Andamento',
        'Enviando localização do pedido #$codigo',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'Rastreio Ativo',
            icon: 'ic_bg_service_small',
            ongoing: true,
            autoCancel: false,
          ),
        ),
      );

      // Configura o GPS
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, 
      );

      // Inicia o stream de localização
      positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings
      ).listen(
        (Position position) async {
          if (!isTracking) {
            positionStream?.cancel();
            return;
          }
          
          try {
            print("BACKGROUND: Enviando Lat: ${position.latitude}, Lng: ${position.longitude}");
            
            await http.post(
              Uri.parse('$baseUrl/atualizar_local.php'),
              body: {
                'codigo': codigo,
                'lat': position.latitude.toString(),
                'lng': position.longitude.toString(),
              },
            ).timeout(const Duration(seconds: 10));
            
          } catch (e) {
            print("BACKGROUND: Erro no envio: $e");
          }
        },
        onError: (error) {
          print("BACKGROUND: Erro no GPS: $error");
        },
        cancelOnError: false,
      );
    }
  });
}