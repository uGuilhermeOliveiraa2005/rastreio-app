import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

// Importamos o arquivo do serviço de background
import 'service_background.dart';

// ---------------------------------------------------------
// CONFIGURAÇÃO DO SERVIDOR
// ---------------------------------------------------------
const String baseUrl = "https://meindicaalguem.com.br/api/rastreio";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService(); // Inicializa o serviço de background
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rastreio MeIndica',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const MenuScreen(),
    );
  }
}

// --- TELA INICIAL (MENU) ---
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, size: 60, color: Colors.blue),
              ),
              const SizedBox(height: 30),
              const Text(
                "Rastreio MeIndica",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              const Text(
                "Escolha como deseja acessar",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 60),

              _botaoMenu(
                context,
                "SOU MOTOBOY",
                "Compartilhar localização",
                Icons.two_wheeler,
                Colors.blue,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MotoboyScreen()))
              ),

              const SizedBox(height: 20),

              _botaoMenu(
                context,
                "SOU CLIENTE",
                "Acompanhar pedido",
                Icons.person_pin_circle,
                Colors.green,
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClienteLoginScreen()))
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoMenu(BuildContext context, String titulo, String sub, IconData icone, Color cor, VoidCallback aoClicar) {
    return InkWell(
      onTap: aoClicar,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0,10)),
            BoxShadow(color: cor.withOpacity(0.1), blurRadius: 0, offset: const Offset(0,0)),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [cor, cor.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(15)
              ),
              child: Icon(icone, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            // MUDANÇA PRINCIPAL: Usar Expanded para que o Column de texto use
            // o espaço restante, evitando overflow em títulos longos ou telas pequenas.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                  Text(sub, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10), // Adicionado um pequeno espaço
            Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

// --- TELA DO MOTOBOY (CORRIGIDA) ---
class MotoboyScreen extends StatefulWidget {
  const MotoboyScreen({super.key});

  @override
  State<MotoboyScreen> createState() => _MotoboyScreenState();
}

class _MotoboyScreenState extends State<MotoboyScreen> with WidgetsBindingObserver {
  String? _codigoSessao;
  bool _isLoading = false;

  String _generateCode() => (10000 + Random().nextInt(90000)).toString();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // IMPORTANTE: Para o serviço quando a tela é destruída
    if (_codigoSessao != null) {
      _pararServico();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Detecta quando o app está sendo fechado completamente
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      if (_codigoSessao != null) {
        _pararServico();
      }
    }
  }

  // Método centralizado para parar o serviço
  void _pararServico() {
    final service = FlutterBackgroundService();
    service.invoke("stopService");
  }

  Future<void> _iniciarEntrega() async {
    setState(() => _isLoading = true);

    await Permission.notification.request();
    var statusLoc = await Permission.location.request();

    if (statusLoc.isGranted) {
      try {
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        String novoCodigo = _generateCode();

        var url = Uri.parse('$baseUrl/criar_sessao.php');
        var response = await http.post(url, body: {
          'codigo': novoCodigo,
          'lat': pos.latitude.toString(),
          'lng': pos.longitude.toString(),
        });

        if (response.statusCode == 200) {
          var json = jsonDecode(response.body);
          if (json['status'] == 'sucesso') {
             setState(() {
              _codigoSessao = novoCodigo;
              _isLoading = false;
            });

            final service = FlutterBackgroundService();
            await service.startService();
            service.invoke("startTracking", {'codigo': novoCodigo});

          } else {
            throw Exception(json['msg'] ?? "Erro desconhecido");
          }
        } else {
          throw Exception("Erro HTTP: ${response.statusCode}");
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _mostrarErro("Erro ao conectar: $e");
      }
    } else {
      setState(() => _isLoading = false);
      _mostrarErro("Permissão de GPS negada.");
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _finalizar() async {
    if (_codigoSessao != null) {
      try {
        await http.post(Uri.parse('$baseUrl/finalizar.php'), body: {'codigo': _codigoSessao!});
      } catch (e) { /* Ignora erro de rede ao finalizar */ }

      _pararServico();
    }
    setState(() => _codigoSessao = null);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // MUDANÇA: Sempre impede o pop automático
      onPopInvoked: (didPop) async {
        if (didPop) return;

        if (_codigoSessao == null) {
          // Se não tem corrida ativa, pode sair
          Navigator.pop(context);
          return;
        }

        // Se tem corrida ativa, mostra o diálogo
        final deveSair = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Entrega Ativa"),
            content: const Text("Você precisa finalizar a entrega antes de sair."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Voltar")),
              TextButton(onPressed: () {
                Navigator.pop(context, true);
              }, child: const Text("Finalizar e Sair", style: TextStyle(color: Colors.red))),
            ],
          ),
        );

        if (deveSair == true) {
          await _finalizar();
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Painel do Entregador"),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _codigoSessao == null
                ? _buildTelaInicial()
                : _buildTelaAtiva(),
      ),
    );
  }

  Widget _buildTelaInicial() {
    return Center(
      child: SingleChildScrollView( // Envolver em SingleChildScrollView para evitar overflow em telas pequenas
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3))
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                     Row(children: [Icon(Icons.wifi, size: 16, color: Colors.blue), SizedBox(width: 5), Text("Online", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]),
                     Row(children: [Icon(Icons.gps_fixed, size: 16, color: Colors.blue), SizedBox(width: 5), Text("GPS Pronto", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))]),
                  ],
                ),
              ),
              const SizedBox(height: 50),

              GestureDetector(
                onTap: _iniciarEntrega,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 20, spreadRadius: 5, offset: const Offset(0, 10))
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 80, color: Colors.white),
                      Text("INICIAR", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
              const Text("Toque para gerar o código\ne começar a compartilhar sua rota", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelaAtiva() {
    return SingleChildScrollView( // Envolver em SingleChildScrollView para evitar overflow em telas pequenas
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_manual_record, size: 12, color: Colors.green),
                  SizedBox(width: 8),
                  Text("TRANSMITINDO LOCALIZAÇÃO", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0,10))],
              ),
              child: Column(
                children: [
                  const Text("Código do Pedido", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(_codigoSessao!, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 5, color: Colors.black87)),
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(backgroundColor: Color(0xFFEEEEEE), valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                  const SizedBox(height: 10),
                  const Text("Compartilhe este número com o cliente", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),

            const SizedBox(height: 50),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text("FINALIZAR ENTREGA"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                onPressed: _finalizar,
              ),
            ),
            const SizedBox(height: 20),
            const Text("O GPS continua ativo mesmo com a tela bloqueada.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// --- TELA DO CLIENTE (LOGIN) ---
class ClienteLoginScreen extends StatelessWidget {
  const ClienteLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Rastrear Pedido"),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      body: SingleChildScrollView( // Envolver em SingleChildScrollView
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Onde está meu pedido?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("Insira o código que o entregador lhe enviou.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
                maxLength: 5,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  counterText: "",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  hintText: "00000",
                  hintStyle: TextStyle(color: Colors.grey[300]),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.length == 5) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MapaClienteScreen(codigo: controller.text)));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  child: const Text("RASTREAR AGORA"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- TELA DO CLIENTE (MAPA E CÁLCULO DE ETA) ---
class MapaClienteScreen extends StatefulWidget {
  final String codigo;
  const MapaClienteScreen({super.key, required this.codigo});

  @override
  State<MapaClienteScreen> createState() => _MapaClienteScreenState();
}

class _MapaClienteScreenState extends State<MapaClienteScreen> {
  final MapController _mapController = MapController();

  LatLng? _posicaoMoto;
  LatLng? _minhaPosicao;
  Timer? _timerPolling;

  bool _ativo = true;
  String _statusTxt = "Localizando motoboy...";
  String _distanciaTxt = "-- km";
  String _tempoTxt = "-- min";

  bool _mapaPronto = false;
  bool _seguirMoto = true;

  @override
  void initState() {
    super.initState();
    _pegarMinhaLocalizacao();
    _atualizarPosicaoMoto();

    _timerPolling = Timer.periodic(const Duration(seconds: 3), (timer) {
      _atualizarPosicaoMoto();
    });
  }

  Future<void> _pegarMinhaLocalizacao() async {
    if (await Permission.location.request().isGranted) {
      Position pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _minhaPosicao = LatLng(pos.latitude, pos.longitude);
        });
      }
    }
  }

  Future<void> _atualizarPosicaoMoto() async {
    if (!mounted) return;

    try {
      final response = await http.get(Uri.parse('$baseUrl/ler_posicao.php?codigo=${widget.codigo}'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'ativo') {
          LatLng novaPos = LatLng(data['lat'], data['lng']);

          setState(() {
            _posicaoMoto = novaPos;
            _statusTxt = "Em trânsito";
            _calcularEstimativa();
          });

          if (_seguirMoto && _mapaPronto) {
            _mapController.move(novaPos, _mapController.camera.zoom);
          }

        } else {
          setState(() {
            _ativo = false;
            _statusTxt = "Entrega finalizada.";
            _tempoTxt = "Finalizado";
          });
          _timerPolling?.cancel();
        }
      }
    } catch (e) {
      print("Erro de rede ignorado: $e");
    }
  }

  void _calcularEstimativa() {
    if (_posicaoMoto != null && _minhaPosicao != null) {
      final Distance distance = const Distance();
      double kmReto = distance.as(LengthUnit.Kilometer, _posicaoMoto!, _minhaPosicao!);

      double kmReal = kmReto * 1.4;
      double horas = kmReal / 30.0;
      int minutos = (horas * 60).round();

      if (minutos < 1) minutos = 1;

      setState(() {
        _distanciaTxt = "${kmReal.toStringAsFixed(1)} km";
        _tempoTxt = "$minutos min";
      });
    }
  }

  @override
  void dispose() {
    _timerPolling?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pedido #${widget.codigo}")),
      body: Stack(
        children: [
          if (_posicaoMoto != null)
             FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _posicaoMoto!,
                initialZoom: 16.0,
                onMapReady: () {
                  _mapaPronto = true;
                },
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture) {
                    setState(() => _seguirMoto = false);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.meindica.rastreio',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _posicaoMoto!,
                      width: 80,
                      height: 80,
                      child: const Column(
                        children: [
                          Icon(Icons.delivery_dining, color: Colors.red, size: 50),
                          Text("Moto", style: TextStyle(fontWeight: FontWeight.bold, backgroundColor: Colors.white)),
                        ],
                      ),
                    ),
                    if (_minhaPosicao != null)
                      Marker(
                        point: _minhaPosicao!,
                        width: 60,
                        height: 60,
                        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                      ),
                  ],
                ),
              ],
            ),

          if (_posicaoMoto != null && _ativo)
            Positioned(
              right: 20,
              bottom: 140,
              child: FloatingActionButton(
                backgroundColor: _seguirMoto ? Colors.blue : Colors.white,
                child: Icon(Icons.gps_fixed, color: _seguirMoto ? Colors.white : Colors.grey),
                onPressed: () {
                  setState(() {
                    _seguirMoto = !_seguirMoto;
                    if (_seguirMoto && _posicaoMoto != null && _mapaPronto) {
                      _mapController.move(_posicaoMoto!, 16.0);
                    }
                  });
                },
              ),
            ),

          if (_ativo && _posicaoMoto != null)
            Positioned(
              left: 10,
              right: 10,
              bottom: 20,
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, color: Colors.blue),
                          const SizedBox(height: 5),
                          Text(_tempoTxt, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const Text("Previsão", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timeline, color: Colors.orange),
                          const SizedBox(height: 5),
                          Text(_distanciaTxt, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const Text("Distância", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_posicaoMoto == null || !_ativo)
            Container(
              color: Colors.white.withOpacity(0.95),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(!_ativo ? Icons.check_circle : Icons.search,
                         size: 60, color: !_ativo ? Colors.green : Colors.blue),
                    const SizedBox(height: 10),
                    Text(_statusTxt, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}