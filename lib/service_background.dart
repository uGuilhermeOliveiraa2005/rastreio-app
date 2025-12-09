import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// URL REPETIDA AQUI POIS O SERVIÇO RODA ISOLADO DO MAIN
const String baseUrl = "https://meindicaalguem.com.br/api/rastreio";

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Configura o canal de notificação (Android)
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
      // Esta é a função que será executada
      onStart: onStart,
      
      // Importante: autoStart false para só ligar quando o motoboy clicar
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

// --- FUNÇÃO QUE RODA EM SEGUNDO PLANO ---
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Garante que o Dart esteja pronto
  DartPluginRegistrant.ensureInitialized();
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Variáveis locais do serviço
  StreamSubscription<Position>? positionStream;

  // Escuta o comando "stopService" vindo da tela
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Escuta o comando "startTracking" vindo da tela
  service.on('startTracking').listen((event) async {
    if (event != null) {
      String codigo = event['codigo'];
      
      // Atualiza a notificação para mostrar que está rodando
      flutterLocalNotificationsPlugin.show(
        888,
        'Rastreio em Andamento',
        'Enviando localização do pedido #$codigo',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_foreground',
            'Rastreio Ativo',
            icon: 'ic_bg_service_small', // Ícone padrão do Android
            ongoing: true,
          ),
        ),
      );

      // Inicia o GPS aqui dentro do serviço
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, 
      );

      positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
        try {
          print("BACKGROUND: Enviando Lat: ${position.latitude}");
          
          await http.post(
            Uri.parse('$baseUrl/atualizar_local.php'),
            body: {
              'codigo': codigo,
              'lat': position.latitude.toString(),
              'lng': position.longitude.toString(),
            },
          );
        } catch (e) {
          print("Erro no envio background: $e");
        }
      });
    }
  });
}