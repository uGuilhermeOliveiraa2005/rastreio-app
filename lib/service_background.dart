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

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', 
    'Rastreio Ativo', 
    description: 'Canal de notificação do rastreio',
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
      initialNotificationTitle: 'Rastreio MeIndica',
      initialNotificationContent: 'Aguardando início...',
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

  // --- ESCUTA O COMANDO PARA PARAR TUDO ---
  service.on('stopService').listen((event) async {
    // 1. Tenta recuperar o código que veio da tela principal (se houver)
    String? codigo = event?['codigo'];

    // 2. Remove a notificação da bandeja imediatamente
    await flutterLocalNotificationsPlugin.cancel(888);

    // 3. Se um código foi passado, DELETA do banco.
    // Se nenhum código foi passado (fechamento do app), MANTÉM no banco.
    if (codigo != null) {
        try {
            await http.post(
                Uri.parse('$baseUrl/finalizar.php'),
                body: {'codigo': codigo},
            );
            print("Sessão $codigo destruída com sucesso.");
        } catch (e) {
            print("Erro ao finalizar no background: $e");
        }
    }

    // 4. Encerra o serviço definitivamente (notificação some)
    service.stopSelf();
  });

  service.on('startTracking').listen((event) async {
    if (event != null) {
      String codigo = event['codigo'];
      
      if (service is AndroidServiceInstance) {
        service.setAsForegroundService();
      }

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
            priority: Priority.high,
            visibility: NotificationVisibility.public,
          ),
        ),
      );

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, 
      );

      positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
        try {
          print("BACKGROUND: Enviando Lat: ${position.latitude}");
          
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Rastreio #$codigo Ativo",
              content: "Atualizado às ${DateTime.now().hour}:${DateTime.now().minute}",
            );
          }

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