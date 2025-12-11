import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui'; // Necessário para efeitos visuais
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:http/http.dart' as http; 
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'service_background.dart';

// ============================================================================
// CONFIGURAÇÃO GERAL
// ============================================================================
const String baseUrl = "https://meindicaalguem.com.br/api/rastreio"; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TRAVA O APP EM MODO RETRATO
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initializeService(); 
  
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.blue, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          labelStyle: TextStyle(color: Colors.grey[600]),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
      home: const MenuScreen(),
    );
  }
}

// ============================================================================
// WIDGET: CUSTOM DIALOG (MODAL BONITO)
// ============================================================================
class CustomDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData icon;
  final Color color;

  const CustomDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.icon = Icons.info_rounded,
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: SingleChildScrollView( // Protege contra overflow do teclado
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              content,
              const SizedBox(height: 24),
              Row(
                children: actions.map((widget) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: widget,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TELA 1: MENU PRINCIPAL
// ============================================================================

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarSessaoGlobal();
    });
  }

  Future<void> _verificarSessaoGlobal() async {
    final prefs = await SharedPreferences.getInstance();
    final codigoSalvo = prefs.getString('sessao_codigo');

    if (codigoSalvo != null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CustomDialog(
          icon: Icons.history,
          color: Colors.orange,
          title: "Rastreio Pendente",
          content: Text(
            "O rastreio #$codigoSalvo ainda está ativo.\nDeseja retomar?",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          actions: [
            OutlinedButton(
              onPressed: () { Navigator.pop(ctx); _descartarSessao(codigoSalvo); },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.red.withOpacity(0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Descartar", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () { 
                Navigator.pop(ctx); 
                _direcionarMotoboy(autoRestaurar: true); 
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, 
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text("Retomar"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _descartarSessao(String codigo) async {
    try { await http.post(Uri.parse('$baseUrl/finalizar.php'), body: {'codigo': codigo}); } catch (e) { print("Erro rede: $e"); }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessao_codigo');
    await prefs.remove('sessao_total');
    await prefs.remove('sessao_concluidas');
    await prefs.remove('sessao_multipla');
  }

  Future<void> _direcionarMotoboy({bool autoRestaurar = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final motoboyId = prefs.getString('motoboy_id');
    
    if (mounted) {
      if (motoboyId != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => MotoboyScreen(autoRestaurar: autoRestaurar)));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MotoboyLoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LOGO E TÍTULO
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), shape: BoxShape.circle),
                          child: const Icon(Icons.location_on_rounded, size: 60, color: Colors.blue),
                        ),
                        const SizedBox(height: 25),
                        const FittedBox(
                          child: Text("Rastreio MeIndica", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87)),
                        ),
                        const SizedBox(height: 8),
                        const Text("Selecione seu perfil para acessar", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                    
                    const SizedBox(height: 60),

                    // BOTÕES
                    _botaoMenu(context, "SOU ENTREGADOR", "Compartilhar localização", Icons.two_wheeler, Colors.blue, () => _direcionarMotoboy()),
                    const SizedBox(height: 16),
                    _botaoMenu(context, "SOU VENDEDOR", "Gerenciar entregadores", Icons.storefront_rounded, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VendedorLoginScreen()))),
                    const SizedBox(height: 16),
                    _botaoMenu(context, "SOU CLIENTE", "Acompanhar pedido", Icons.person_pin_circle, Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClienteLoginScreen()))),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _botaoMenu(BuildContext context, String titulo, String sub, IconData icone, Color cor, VoidCallback aoClicar) {
    return InkWell(
      onTap: aoClicar,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0,5)),
            BoxShadow(color: cor.withOpacity(0.1), blurRadius: 0, offset: const Offset(0,0)), 
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [cor, cor.withOpacity(0.7)]), borderRadius: BorderRadius.circular(15)),
              child: Icon(icone, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                  ),
                  const SizedBox(height: 4),
                  Text(sub, style: TextStyle(color: Colors.grey[500], fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TELA 2: LOGIN DO MOTOBOY
// ============================================================================

class MotoboyLoginScreen extends StatefulWidget {
  const MotoboyLoginScreen({super.key});

  @override
  State<MotoboyLoginScreen> createState() => _MotoboyLoginScreenState();
}

class _MotoboyLoginScreenState extends State<MotoboyLoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _acaoAutenticacao() async {
    if (_emailCtrl.text.isEmpty || _senhaCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final isLogin = _tabController.index == 0;
      final endpoint = isLogin ? 'login_motoboy.php' : 'cadastro_motoboy.php';
      
      final response = await http.post(Uri.parse('$baseUrl/$endpoint'), body: {
        'email': _emailCtrl.text,
        'senha': _senhaCtrl.text,
        if (!isLogin) 'nome': _nomeCtrl.text,
      });

      dynamic data;
      try { data = jsonDecode(response.body); } catch (e) { throw Exception("Erro no servidor."); }

      if (data['status'] == 'sucesso') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('motoboy_id', data['id']);
        await prefs.setString('motoboy_nome', data['nome']);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MotoboyScreen()));
      } else {
        throw Exception(data['msg']);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Entregador")),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [Tab(text: "JÁ TENHO CONTA"), Tab(text: "CRIAR NOVA")],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildForm(isLogin: true),
                _buildForm(isLogin: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({required bool isLogin}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!isLogin) ...[
              TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Nome Completo", prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 15),
            ],
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 15),
            TextField(controller: _senhaCtrl, decoration: const InputDecoration(labelText: "Senha", prefixIcon: Icon(Icons.lock)), obscureText: true),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _acaoAutenticacao,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isLogin ? "ENTRAR" : "CRIAR CONTA"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TELA 3: LOGIN DO VENDEDOR
// ============================================================================

class VendedorLoginScreen extends StatefulWidget {
  const VendedorLoginScreen({super.key});

  @override
  State<VendedorLoginScreen> createState() => _VendedorLoginScreenState();
}

class _VendedorLoginScreenState extends State<VendedorLoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _verificarLoginSalvo();
  }

  Future<void> _verificarLoginSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('vendedor_id');
    final nome = prefs.getString('vendedor_nome');
    if (id != null && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VendedorDashboardScreen(id: id, nome: nome ?? "Vendedor")));
    }
  }

  Future<void> _acaoAutenticacao() async {
    if (_emailCtrl.text.isEmpty || _senhaCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final isLogin = _tabController.index == 0;
      final endpoint = isLogin ? 'login_vendedor.php' : 'cadastro_vendedor.php';
      final response = await http.post(Uri.parse('$baseUrl/$endpoint'), body: { 'email': _emailCtrl.text, 'senha': _senhaCtrl.text, if (!isLogin) 'nome': _nomeCtrl.text });
      dynamic data; try { data = jsonDecode(response.body); } catch (e) { throw Exception("Erro servidor."); }
      if (data['status'] == 'sucesso') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('vendedor_id', data['id']); await prefs.setString('vendedor_nome', data['nome']);
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VendedorDashboardScreen(id: data['id'], nome: data['nome'])));
      } else { throw Exception(data['msg']); }
    } catch (e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red)); } 
    finally { if(mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Vendedor")),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [Tab(text: "JÁ TENHO CONTA"), Tab(text: "CRIAR NOVA")],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildForm(isLogin: true),
                _buildForm(isLogin: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({required bool isLogin}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (!isLogin) ...[
              TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Nome da Loja", prefixIcon: Icon(Icons.store))),
              const SizedBox(height: 15),
            ],
            TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.email)), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 15),
            TextField(controller: _senhaCtrl, decoration: const InputDecoration(labelText: "Senha", prefixIcon: Icon(Icons.lock)), obscureText: true),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _acaoAutenticacao,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(isLogin ? "ENTRAR" : "CRIAR CONTA"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TELA 4: DASHBOARD DO VENDEDOR
// ============================================================================

class VendedorDashboardScreen extends StatefulWidget {
  final String id;
  final String nome;
  const VendedorDashboardScreen({super.key, required this.id, required this.nome});

  @override
  State<VendedorDashboardScreen> createState() => _VendedorDashboardScreenState();
}

class _VendedorDashboardScreenState extends State<VendedorDashboardScreen> {
  List<dynamic> _motoboys = [];
  bool _isLoadingInicial = true;
  Timer? _timerPolling;

  @override
  void initState() {
    super.initState();
    _carregarDados();
    _timerPolling = Timer.periodic(const Duration(seconds: 5), (timer) {
      _carregarDados(silencioso: true);
    });
  }

  @override
  void dispose() {
    _timerPolling?.cancel();
    super.dispose();
  }

  Future<void> _carregarDados({bool silencioso = false}) async {
    if (!silencioso) setState(() => _isLoadingInicial = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/listar_motoboys.php?vendedor_id=${widget.id}'));
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              _motoboys = data;
              _isLoadingInicial = false;
            });
          }
        } catch (e) {
          // Ignora
        }
      }
    } catch (e) {}
  }

  Future<void> _vincularMotoboy() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: "Adicionar Motoboy",
        icon: Icons.add_reaction_rounded,
        color: Colors.blue,
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            prefixText: "ENT-", 
            hintText: "1234567",
            labelText: "ID do Entregador",
            counterText: ""
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  final resp = await http.post(Uri.parse('$baseUrl/vincular.php'), body: {
                    'vendedor_id': widget.id,
                    'motoboy_id': "ENT-${controller.text}"
                  });
                  final data = jsonDecode(resp.body);
                  _carregarDados(); 
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['msg']), backgroundColor: data['status'] == 'sucesso' ? Colors.green : Colors.red));
                } catch(e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao vincular"), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Vincular"),
          ),
        ],
      ),
    );
  }

  Future<void> _desvincular(String alvoId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => CustomDialog(
        title: "Remover Entregador?",
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
        content: const Text("O entregador perderá o acesso à sua lista de lojas.", textAlign: TextAlign.center),
        actions: [
          OutlinedButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text("Cancelar")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: ()=>Navigator.pop(ctx,true), child: const Text("Remover"))
        ]
      )
    );
    if (confirm == true) {
      try {
        await http.post(Uri.parse('$baseUrl/desvincular.php'), body: { 'tipo': 'vendedor', 'meu_id': widget.id, 'alvo_id': alvoId });
        _carregarDados();
      } catch (e) {}
    }
  }

  void _mostrarDetalhesEntrega(Map<String, dynamic> moto) {
    if (moto['online'] != true) return;
    
    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: "Em Rota",
        icon: Icons.delivery_dining,
        color: Colors.green,
        content: Column(
          children: [
            const Text("Pedido:", style: TextStyle(color: Colors.grey)),
            Text(moto['pedido'] ?? "S/N", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text("Código de Rastreio:", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 5),
            GestureDetector(
              onTap: () {
                 Clipboard.setData(ClipboardData(text: moto['rastreio']));
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código copiado!")));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.3))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(moto['rastreio'] ?? "", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy, size: 20, color: Colors.blue)
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text("Envie para o cliente", style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fechar"))
        ],
      ),
    );
  }

  Future<void> _copiarID() async {
    await Clipboard.setData(ClipboardData(text: widget.id));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID copiado!"), duration: Duration(seconds: 1)));
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vendedor_id');
    await prefs.remove('vendedor_nome');
    if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MenuScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(widget.nome), actions: [IconButton(icon: const Icon(Icons.exit_to_app), onPressed: _logout)]),
      body: RefreshIndicator(
        onRefresh: () async { await _carregarDados(); },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                child: Column(
                  children: [
                    const Text("SEU ID DE VENDEDOR", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: SelectableText(widget.id, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1)))),
                        const SizedBox(width: 8),
                        IconButton(onPressed: _copiarID, icon: const Icon(Icons.copy, color: Colors.white), constraints: const BoxConstraints(), padding: EdgeInsets.zero),
                      ],
                    ),
                    const Text("Compartilhe com seus entregadores", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Meus Entregadores", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                TextButton.icon(onPressed: _vincularMotoboy, icon: const Icon(Icons.add, size: 18), label: const Text("Adicionar"))
              ]),
              
              const SizedBox(height: 10),
              
              if (_isLoadingInicial)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (_motoboys.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text("Nenhum entregador vinculado.", style: TextStyle(color: Colors.grey))))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _motoboys.length,
                  itemBuilder: (context, index) {
                    final moto = _motoboys[index];
                    final isOnline = moto['online'] == true;
                    
                    return Card(
                      elevation: 0,
                      color: isOnline ? Colors.green[50] : Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isOnline ? Colors.green.withOpacity(0.3) : Colors.grey.shade200)),
                      child: ListTile(
                        onTap: () => _mostrarDetalhesEntrega(moto),
                        leading: CircleAvatar(backgroundColor: isOnline ? Colors.green[100] : Colors.grey[100], child: Icon(Icons.two_wheeler, color: isOnline ? Colors.green[800] : Colors.grey)),
                        title: Text(moto['nome'] ?? "Entregador", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("ID: ${moto['id']}", style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if(isOnline) Container(margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)), child: const Text("EM ROTA", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _desvincular(moto['id']))
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TELA 5: PAINEL DO ENTREGADOR
// ============================================================================

class MotoboyScreen extends StatefulWidget {
  final bool autoRestaurar;
  const MotoboyScreen({super.key, this.autoRestaurar = false});
  @override State<MotoboyScreen> createState() => _MotoboyScreenState();
}

class _MotoboyScreenState extends State<MotoboyScreen> with WidgetsBindingObserver {
  String? _codigoSessao;
  String? _motoboyId;
  String? _motoboyNome;
  bool _isLoading = false;
  bool _modoMultiplo = false;
  int _totalEntregas = 1;
  int _entregasConcluidas = 0;
  
  // Lista para armazenar as entregas vindas do banco
  List<dynamic> _entregasAtivasLista = [];
  Timer? _timerAtualizacaoLista;

  @override 
  void initState() { 
    super.initState(); 
    WidgetsBinding.instance.addObserver(this); 
    _carregarDados(); 
    _checkPermissions(); 
    
    // Tenta restaurar estado local primeiro (SharedPreferences)
    if (widget.autoRestaurar) _restaurarEstadoLocal();

    // Inicia timer para buscar entregas ativas no banco a cada 10s
    _timerAtualizacaoLista = Timer.periodic(const Duration(seconds: 10), (timer) {
      if(_motoboyId != null && _codigoSessao == null) {
        _buscarEntregasAtivasNoBanco();
      }
    });
  }

  @override 
  void dispose() { 
    WidgetsBinding.instance.removeObserver(this); 
    _timerAtualizacaoLista?.cancel();
    super.dispose(); 
  }

  @override 
  void didChangeAppLifecycleState(AppLifecycleState state) { 
    // Opcional: Atualizar lista ao voltar para o app
    if (state == AppLifecycleState.resumed && _codigoSessao == null) {
      _buscarEntregasAtivasNoBanco();
    }
  }

  Future<void> _carregarDados() async { 
    final p = await SharedPreferences.getInstance(); 
    setState(() { 
      _motoboyId = p.getString('motoboy_id'); 
      _motoboyNome = p.getString('motoboy_nome'); 
    });
    // Busca inicial assim que tiver o ID
    _buscarEntregasAtivasNoBanco();
  }

  // --- NOVA FUNÇÃO: Busca no servidor ---
  Future<void> _buscarEntregasAtivasNoBanco() async {
    if (_motoboyId == null) return;
    try {
      final response = await http.get(Uri.parse('$baseUrl/listar_entregas_ativas.php?motoboy_id=$_motoboyId'));
      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _entregasAtivasLista = dados;
          });
        }
      }
    } catch (e) {
      print("Erro ao buscar ativas: $e");
    }
  }

  Future<List<dynamic>> _buscarVendedores() async { 
    if(_motoboyId==null)return[]; 
    try { final r = await http.get(Uri.parse('$baseUrl/listar_vendedores.php?motoboy_id=$_motoboyId')); 
    if(r.statusCode==200) return jsonDecode(r.body); } catch(e){} return []; 
  }
  
  Future<void> _vincularVendedor() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: "Vincular Vendedor",
        icon: Icons.store,
        color: Colors.blue,
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(prefixText: "VEND-", hintText: "1234567", labelText: "ID da Loja", counterText: ""),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  final resp = await http.post(Uri.parse('$baseUrl/vincular.php'), body: {
                    'motoboy_id': _motoboyId,
                    'vendedor_id': "VEND-${controller.text}"
                  });
                  final data = jsonDecode(resp.body);
                  setState(() {}); 
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['msg']), backgroundColor: data['status']=='sucesso'?Colors.green:Colors.red));
                } catch(e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao conectar"), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("Conectar"),
          ),
        ],
      ),
    );
  }

  Future<void> _desvincular(String alvoId) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => CustomDialog(title: "Remover Loja?", icon: Icons.delete_forever, color: Colors.red, content: const Text("Você deixará de aparecer para esta loja.", textAlign: TextAlign.center), actions: [OutlinedButton(onPressed: ()=>Navigator.pop(ctx,false), child: const Text("Não")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: ()=>Navigator.pop(ctx,true), child: const Text("Sim"))]));
    if (confirm == true) { try { await http.post(Uri.parse('$baseUrl/desvincular.php'), body: { 'tipo': 'motoboy', 'meu_id': _motoboyId, 'alvo_id': alvoId }); setState(() {}); } catch (e) {} }
  }

  Future<void> _copiarID() async { if (_motoboyId != null) { await Clipboard.setData(ClipboardData(text: _motoboyId!)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID copiado!"), duration: Duration(seconds: 1))); } }
  
  Future<void> _logout() async { 
    if(_codigoSessao!=null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Finalize a entrega antes."), backgroundColor: Colors.red)); return; } 
    final p=await SharedPreferences.getInstance(); await p.remove('motoboy_id'); await p.remove('motoboy_nome'); if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_)=>const MenuScreen())); 
  }
  
  Future<void> _checkPermissions() async { var s = await Permission.ignoreBatteryOptimizations.status; if (!s.isGranted) await Permission.ignoreBatteryOptimizations.request(); }
  
  Future<void> _configurarRota(int qtd) async {
    final vendedores = await _buscarVendedores(); 
    if (vendedores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vincule-se a uma loja primeiro."), backgroundColor: Colors.orange));
      return;
    }
    String? vendedorSelecionado = vendedores.first['id'];
    final pedidoController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: "Dados da Entrega",
        icon: Icons.assignment,
        color: Colors.blue,
        content: Column(
          children: [
            DropdownButtonFormField<String>(
              value: vendedorSelecionado,
              items: vendedores.map<DropdownMenuItem<String>>((v) => DropdownMenuItem(value: v['id'], child: Text(v['nome'], overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (val) => vendedorSelecionado = val,
              decoration: const InputDecoration(labelText: "Loja Parceira"),
              isExpanded: true,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: pedidoController,
              decoration: const InputDecoration(labelText: "Número do Pedido", hintText: "Ex: 12345"),
              keyboardType: TextInputType.number,
            )
          ],
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () {
              if (pedidoController.text.isNotEmpty && vendedorSelecionado != null) {
                Navigator.pop(ctx);
                _iniciarSessao(qtd, vendedorSelecionado!, pedidoController.text);
              }
            },
            child: const Text("INICIAR"),
          )
        ],
      )
    );
  }

  Future<void> _iniciarSessao(int qtd, String vendedorId, String pedidoId) async {
    setState(() => _isLoading = true);
    await Permission.notification.request();
    var statusLoc = await Permission.location.request();
    if (await Permission.locationAlways.isDenied) await Permission.locationAlways.request();

    if (statusLoc.isGranted) {
      try {
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        String novoCodigo = List.generate(5, (index) => 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[Random().nextInt(36)]).join();
        var response = await http.post(Uri.parse('$baseUrl/criar_sessao.php'), body: { 'codigo': novoCodigo, 'lat': pos.latitude.toString(), 'lng': pos.longitude.toString(), 'motoboy_id': _motoboyId, 'vendedor_id': vendedorId, 'pedido_id': pedidoId });
        if (response.statusCode == 200) {
             setState(() { _codigoSessao = novoCodigo; _totalEntregas = qtd; _entregasConcluidas = 0; _modoMultiplo = qtd > 1; _isLoading = false; });
            _salvarProgresso();
            final service = FlutterBackgroundService(); await service.startService(); service.invoke("startTracking", {'codigo': novoCodigo});
        } else { setState(() => _isLoading = false); }
      } catch (e) { setState(() => _isLoading = false); }
    } else { setState(() => _isLoading = false); }
  }

  // --- AÇÃO: RETOMAR SESSÃO PELA LISTA ---
  Future<void> _retomarSessaoEspecifica(String codigo) async {
    setState(() => _isLoading = true);
    // Como estamos retomando do banco, assumimos modo simples (1 entrega) pois o tracking múltiplo é local
    // Se quiser, poderia salvar qtd no banco também, mas para "resgate" o tracking é o mais importante.
    setState(() { 
      _codigoSessao = codigo;
      _totalEntregas = 1;
      _entregasConcluidas = 0;
      _modoMultiplo = false;
      _isLoading = false;
    });
    
    await _salvarProgresso();
    
    // Reinicia o tracking
    final service = FlutterBackgroundService(); 
    if (!(await service.isRunning())) await service.startService(); 
    service.invoke("startTracking", {'codigo': codigo});
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entrega retomada!"), backgroundColor: Colors.green));
  }

  // --- AÇÃO: FINALIZAR SESSÃO PELA LISTA ---
  Future<void> _finalizarSessaoEspecifica(String codigo) async {
    try {
      await http.post(Uri.parse('$baseUrl/finalizar.php'), body: {'codigo': codigo});
      _buscarEntregasAtivasNoBanco(); // Atualiza a lista
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entrega finalizada."), backgroundColor: Colors.orange));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao finalizar"), backgroundColor: Colors.red));
    }
  }

  Future<void> _restaurarEstadoLocal() async {
    setState(() => _isLoading = true); 
    final p = await SharedPreferences.getInstance(); 
    final c = p.getString('sessao_codigo');
    
    if (c != null) {
      setState(() { _codigoSessao = c; _totalEntregas = p.getInt('sessao_total')??1; _entregasConcluidas = p.getInt('sessao_concluidas')??0; _modoMultiplo = p.getBool('sessao_multipla')??false; _isLoading = false; });
      final s = FlutterBackgroundService(); 
      if (!(await s.isRunning())) await s.startService(); 
      s.invoke("startTracking", {'codigo': _codigoSessao});
    } else { 
      setState(() => _isLoading = false);
      // Se não tem local, busca no banco
      _buscarEntregasAtivasNoBanco();
    }
  }

  Future<void> _salvarProgresso() async { final p = await SharedPreferences.getInstance(); await p.setString('sessao_codigo', _codigoSessao!); await p.setInt('sessao_total', _totalEntregas); await p.setInt('sessao_concluidas', _entregasConcluidas); await p.setBool('sessao_multipla', _modoMultiplo); }
  Future<void> _limparMemoria() async { final p = await SharedPreferences.getInstance(); await p.remove('sessao_codigo'); await p.remove('sessao_total'); await p.remove('sessao_concluidas'); await p.remove('sessao_multipla'); }
  
  Future<void> _finalizarTotalmente() async { 
    if (_codigoSessao != null) { 
      final s = FlutterBackgroundService(); 
      s.invoke("stopService", {'codigo': _codigoSessao}); 
    } 
    await _limparMemoria(); 
    setState(() { _codigoSessao = null; });
    
    // Atualiza a lista para remover a finalizada visualmente
    _buscarEntregasAtivasNoBanco();
  }
  
  void _concluirEtapa() { if (_entregasConcluidas < _totalEntregas - 1) { setState(() { _entregasConcluidas++; }); _salvarProgresso(); } else { _finalizarTotalmente(); } }
  void _perguntarQtd() { final c = TextEditingController(); showDialog(context: context, builder: (ctx) => CustomDialog(title: "Quantas Entregas?", content: TextField(controller: c, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Ex: 3", labelText: "Quantidade")), actions: [OutlinedButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Cancelar")), ElevatedButton(onPressed: (){ if(c.text.isNotEmpty) { Navigator.pop(ctx); _configurarRota(int.parse(c.text)); } }, child: const Text("Continuar"))])); }

  @override
  Widget build(BuildContext context) {
    if (_codigoSessao != null) return _buildPainelAtivo();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Painel Entregador"), actions: [IconButton(icon: const Icon(Icons.exit_to_app), onPressed: _logout)]),
      body: RefreshIndicator(
        onRefresh: () async {
          await _buscarEntregasAtivasNoBanco();
          await _buscarVendedores();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.blue[800], borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0,5))]),
                child: Column(children: [
                  const Text("SEU ID DE ENTREGADOR", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: SelectableText(_motoboyId ?? "...", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)))), const SizedBox(width: 8), IconButton(onPressed: _copiarID, icon: const Icon(Icons.copy, color: Colors.white), padding: EdgeInsets.zero, constraints: const BoxConstraints())]),
                  Text(_motoboyNome ?? "", style: const TextStyle(color: Colors.white, fontSize: 16)),
                ]),
              ),
              
              // ======================================================
              // NOVA SEÇÃO: MINHAS ENTREGAS ATIVAS
              // ======================================================
              if (_entregasAtivasLista.isNotEmpty) ...[
                const SizedBox(height: 25),
                Row(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text("Minhas Entregas Ativas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.refresh, size: 20, color: Colors.blue), onPressed: _buscarEntregasAtivasNoBanco)
                  ],
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _entregasAtivasLista.length,
                  itemBuilder: (context, index) {
                    final entrega = _entregasAtivasLista[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 3))],
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
                              child: const Icon(Icons.local_shipping, color: Colors.green),
                            ),
                            title: Text("Pedido #${entrega['pedido']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entrega['loja'], style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                Text("Cód: ${entrega['codigo']}", style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey)),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Atualizado", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text(entrega['hora'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15))),
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _finalizarSessaoEspecifica(entrega['codigo']),
                                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                                    label: const Text("Finalizar"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: BorderSide(color: Colors.red.withOpacity(0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _retomarSessaoEspecifica(entrega['codigo']),
                                    icon: const Icon(Icons.play_circle_fill, size: 18),
                                    label: const Text("Retomar"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ],
              // ======================================================

              const SizedBox(height: 30),
              const Text("Iniciar Nova Rota", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _btnOpcao("Única", Icons.person, Colors.blue, () => _configurarRota(1))),
                const SizedBox(width: 10),
                Expanded(child: _btnOpcao("Múltipla", Icons.alt_route, Colors.orange, _perguntarQtd)),
              ]),
              const SizedBox(height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Lojas Vinculadas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), TextButton.icon(onPressed: _vincularVendedor, icon: const Icon(Icons.add), label: const Text("Adicionar"))]),
              FutureBuilder<List<dynamic>>(
                future: _buscarVendedores(),
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data!.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("Nenhuma loja vinculada."));
                  return ListView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: snap.data!.length,
                    itemBuilder: (c, i) => Card(child: ListTile(leading: const Icon(Icons.store), title: Text(snap.data![i]['nome']), subtitle: Text(snap.data![i]['id']), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _desvincular(snap.data![i]['id']))))
                  );
                }
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _btnOpcao(String t, IconData i, Color c, VoidCallback f) {
    return InkWell(onTap: f, child: Container(padding: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)), child: Column(children: [Icon(i, color: c, size: 30), const SizedBox(height: 5), Text(t, style: const TextStyle(fontWeight: FontWeight.bold))])));
  }

  Widget _buildPainelAtivo() {
    int atual = _entregasConcluidas + 1; bool isUltima = atual == _totalEntregas;
    return Scaffold(
      appBar: AppBar(title: const Text("Em Entrega"), automaticallyImplyLeading: false),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green)), child: const Text("RASTREIO ATIVO", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
            const SizedBox(height: 30),
            FittedBox(child: SelectableText(_codigoSessao!, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 3))),
            const Text("Código do Cliente"),
            const SizedBox(height: 40),
            if(_modoMultiplo) ...[Text("Entrega $atual de $_totalEntregas", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), LinearProgressIndicator(value: atual/_totalEntregas, minHeight: 8, borderRadius: BorderRadius.circular(4)), const SizedBox(height: 30)],
            SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: _concluirEtapa, style: ElevatedButton.styleFrom(backgroundColor: isUltima?Colors.red:Colors.blue, foregroundColor: Colors.white), child: Text(isUltima ? "FINALIZAR TUDO" : "CONCLUIR ENTREGA ATUAL"))),
            if(!isUltima) Padding(padding: const EdgeInsets.only(top: 15), child: TextButton(onPressed: _finalizarTotalmente, child: const Text("Cancelar e Encerrar Tudo", style: TextStyle(color: Colors.red))))
          ]),
        ),
      )
    );
  }
}

// ============================================================================
// TELA 6: CLIENTE - LOGIN DO RASTREIO
// ============================================================================

class ClienteLoginScreen extends StatelessWidget {
  const ClienteLoginScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Rastrear Pedido"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Código de Rastreio", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: controller, textAlign: TextAlign.center, textCapitalization: TextCapitalization.characters, maxLength: 5, style: const TextStyle(fontSize: 32, letterSpacing: 5, fontWeight: FontWeight.bold), decoration: const InputDecoration(hintText: "A1B2C", counterText: "")),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () { if (controller.text.length == 5) Navigator.push(context, MaterialPageRoute(builder: (_) => MapaClienteScreen(codigo: controller.text.toUpperCase()))); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("RASTREAR AGORA")))
          ],
        ),
      ),
    );
  }
}

class MapaClienteScreen extends StatefulWidget {
  final String codigo;
  const MapaClienteScreen({super.key, required this.codigo});
  @override State<MapaClienteScreen> createState() => _MapaClienteScreenState();
}

class _MapaClienteScreenState extends State<MapaClienteScreen> {
  final MapController _mapController = MapController();
  LatLng? _posicaoMoto;
  Timer? _timerPolling;
  String _statusTxt = "Localizando entregador...";
  bool _ativo = true;
  bool _seguirMoto = true;
  bool _mapaPronto = false;

  @override void initState() { super.initState(); _atualizarPosicaoMoto(); _timerPolling = Timer.periodic(const Duration(seconds: 3), (timer) { _atualizarPosicaoMoto(); }); }
  @override void dispose() { _timerPolling?.cancel(); super.dispose(); }

  Future<void> _atualizarPosicaoMoto() async {
    if (!mounted) return;
    try {
      final response = await http.get(Uri.parse('$baseUrl/ler_posicao.php?codigo=${widget.codigo}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ativo') {
          LatLng novaPos = LatLng(data['lat'], data['lng']);
          setState(() { _posicaoMoto = novaPos; _statusTxt = "Em trânsito"; });
          if (_seguirMoto && _mapaPronto) _mapController.move(novaPos, _mapController.camera.zoom);
        } else {
          setState(() { _ativo = false; _statusTxt = "Entrega finalizada."; });
          _timerPolling?.cancel();
        }
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pedido #${widget.codigo}")),
      body: _posicaoMoto == null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(!_ativo?Icons.check_circle:Icons.search, size: 60, color: !_ativo?Colors.green:Colors.blue), const SizedBox(height: 10), Text(_statusTxt)]))
          : Stack(children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(initialCenter: _posicaoMoto!, initialZoom: 16.0, onMapReady: () => _mapaPronto = true, onPositionChanged: (pos, hasGesture) { if (hasGesture) setState(() => _seguirMoto = false); }),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.meindica.rastreio'),
                  MarkerLayer(markers: [Marker(point: _posicaoMoto!, width: 80, height: 80, child: const Column(children: [Icon(Icons.delivery_dining, color: Colors.red, size: 50), Text("Moto", style: TextStyle(fontWeight: FontWeight.bold, backgroundColor: Colors.white))]))]),
                ],
              ),
              if (_ativo) Positioned(right: 20, bottom: 40, child: FloatingActionButton(backgroundColor: _seguirMoto ? Colors.blue : Colors.white, child: Icon(Icons.gps_fixed, color: _seguirMoto ? Colors.white : Colors.grey), onPressed: () => setState(() { _seguirMoto = !_seguirMoto; if (_seguirMoto) _mapController.move(_posicaoMoto!, 16.0); })))
            ]),
    );
  }
}