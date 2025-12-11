import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// URL base da API
const String baseUrl = "https://meindicaalguem.com.br/api/rastreio";

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', 
    'Rastreio Entregador', 
    description: 'Serviço de localização em tempo real',
    importance: Importance.high, 
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
      initialNotificationTitle: 'Rastreio Ativo',
      initialNotificationContent: 'Localizando...',
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
  
  // Stream global para evitar recriação
  StreamSubscription<Position>? positionStream;

  // --- PARAR O SERVIÇO ---
  service.on('stopService').listen((event) async {
    await positionStream?.cancel();
    positionStream = null;
    await flutterLocalNotificationsPlugin.cancel(888);
    service.stopSelf();
    print("BACKGROUND: Serviço encerrado.");
  });

  // --- INICIAR RASTREIO (GENÉRICO PARA O MOTOBOY) ---
  service.on('startTracking').listen((event) async {
    if (event != null) {
      String motoboyId = event['motoboy_id']; // Recebe o ID do Motoboy, não do pedido
      
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
      }

      // Notificação Fixa
      flutterLocalNotificationsPlugin.show(
        888,
        'Rastreio Ativo',
        'Suas entregas estão sendo atualizadas.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'Rastreio Entregador',
            icon: 'ic_bg_service_small', 
            ongoing: true,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
          ),
        ),
      );

      // Configuração GPS
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // Atualiza a cada 15 metros
      );

      // Reinicia stream se já existir
      await positionStream?.cancel();

      positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
        try {
          print("BACKGROUND: Atualizando para Motoboy $motoboyId -> Lat: ${position.latitude}");
          
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Rastreio em Andamento",
              content: "Última atualização: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2,'0')}",
            );
          }

          // CHAMA O NOVO PHP DE ATUALIZAÇÃO EM MASSA
          await http.post(
            Uri.parse('$baseUrl/atualizar_local_motoboy.php'),
            body: {
              'motoboy_id': motoboyId,
              'lat': position.latitude.toString(),
              'lng': position.longitude.toString(),
            },
          );
        } catch (e) {
          print("Erro background: $e");
        }
      });
    }
  });
}