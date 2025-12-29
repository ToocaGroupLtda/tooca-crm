import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'login_screen.dart';
import 'novo_pedido_screen.dart';
import 'pedidos_screen.dart';
import 'clientes_screen.dart';
import 'pedidos_offline_screen.dart';
import 'sincronizacao_service.dart';

class HomeScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;
  final String plano;
  final String email;

  const HomeScreen({
    super.key,
    required this.usuarioId,
    required this.empresaId,
    required this.plano,
    required this.email,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String planoAtual;
  String? empresaExpira;

  List<dynamic> ultimosPedidos = [];
  List<dynamic> pedidosRascunho = [];
  double totalMes = 0.0;
  bool carregandoPedidos = true;

  final NumberFormat _moeda =
  NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();

    // Plano inicial (pode ser temporário)
    planoAtual = widget.plano.toLowerCase().trim();

    _carregarPlanoReal();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executarSincronizacaoInicial();
    });
  }

  // =============================================================
  // 🔐 Carrega plano REAL da empresa
  // =============================================================
  Future<void> _carregarPlanoReal() async {
    final prefs = await SharedPreferences.getInstance();

    final planoPrefs = prefs.getString('plano_empresa');
    final expiraPrefs = prefs.getString('empresa_expira');

    if (!mounted) return;

    setState(() {
      if (planoPrefs != null && planoPrefs.isNotEmpty) {
        planoAtual = planoPrefs.toLowerCase().trim();
      }
      empresaExpira = expiraPrefs;
    });

    debugPrint('🏠 HOME -> plano=$planoAtual | expira=$empresaExpira');
  }

  // =============================================================
  // 🔄 Sincronização (server-driven)
  // =============================================================
  Future<void> _executarSincronizacaoInicial() async {
    final bool ativa =
    await SincronizacaoService.consultarStatusEmpresa(widget.empresaId);

    if (!ativa) return;

    await SincronizacaoService.sincronizarSilenciosamente(
      widget.empresaId,
      widget.usuarioId,
    );

    await SincronizacaoService.enviarPedidosPendentes(
      context,
      widget.usuarioId,
      widget.empresaId,
    );

    await carregarUltimosPedidos();
  }

  // =============================================================
  // 📦 Últimos pedidos
  // =============================================================
  Future<void> carregarUltimosPedidos() async {
    final url = Uri.parse(
        'https://toocagroup.com.br/api/listar_pedidos_faturados.php');

    final cachePedidos = 'pedidos_faturados_${widget.empresaId}';
    final cacheRascunhos = 'pedidos_rascunho_${widget.empresaId}';

    try {
      final response = await http
          .post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'empresa_id': widget.empresaId,
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(
            cachePedidos, jsonEncode(data['pedidos'] ?? []));
        await prefs.setString(
            cacheRascunhos, jsonEncode(data['rascunhos'] ?? []));

        if (!mounted) return;
        setState(() {
          ultimosPedidos = data['pedidos'] ?? [];
          pedidosRascunho = data['rascunhos'] ?? [];
          totalMes = _parseValor(data['total_mes']);
          carregandoPedidos = false;
        });
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      setState(() {
        ultimosPedidos = jsonDecode(prefs.getString(cachePedidos) ?? '[]');
        pedidosRascunho =
            jsonDecode(prefs.getString(cacheRascunhos) ?? '[]');
        carregandoPedidos = false;
      });
    }
  }

  double _parseValor(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString().replaceAll(',', '.')) ?? 0.0;
  }

  // =============================================================
  // 🎨 STATUS VISUAL DA EMPRESA
  // =============================================================
  Color _corStatusEmpresa() {
    if (planoAtual == 'free') return Colors.red;

    if (empresaExpira == null || empresaExpira!.isEmpty) {
      return Colors.orange;
    }

    try {
      final venc = DateTime.parse(empresaExpira!);
      final diff = venc.difference(DateTime.now()).inDays;

      if (diff < 0) return Colors.red;
      if (diff <= 7) return Colors.orange;
      return Colors.green;
    } catch (_) {
      return Colors.orange;
    }
  }

  Widget _avisoEmpresa() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _corStatusEmpresa().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _corStatusEmpresa()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Status da Empresa',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text('🏢 Empresa ID: ${widget.empresaId}'),
          Text('👤 Usuário ID: ${widget.usuarioId}'),
          Text('📦 Plano: ${planoAtual.toUpperCase()}'),
          Text('⏰ Vencimento: ${empresaExpira ?? 'não informado'}'),
        ],
      ),
    );
  }

  // =============================================================
  // 🖥️ UI
  // =============================================================
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menu = [
      {
        'icon': Icons.add_box,
        'label': 'Novo Pedido',
        'route': () => NovoPedidoScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: planoAtual,
        ),
      },
      {
        'icon': Icons.list_alt,
        'label': 'Pedidos',
        'route': () => PedidosScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: planoAtual,
        ),
      },
      {
        'icon': Icons.drafts,
        'label': 'Rascunhos',
        'route': () => PedidosOfflineScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
        ),
      },
      {
        'icon': Icons.person_add,
        'label': 'Clientes',
        'route': () => ClientesScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: planoAtual,
        ),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tooca CRM'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _avisoEmpresa(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: menu.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          (menu[i]['route'] as Widget Function())(),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(2, 2),
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          menu[i]['icon'] as IconData,
                          size: 48,
                          color: const Color(0xFFFFC107),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          menu[i]['label'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.sync),
        label: const Text('Sincronizar'),
        onPressed: _executarSincronizacaoInicial,
      ),
    );
  }
}
