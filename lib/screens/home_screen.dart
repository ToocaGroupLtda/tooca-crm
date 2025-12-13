import 'dart:convert';
import 'dart:io';

import 'package:app_tooca_crm/screens/clientes_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'login_screen.dart';
import 'pedidos_screen.dart';
import 'novo_pedido_screen.dart';
import 'sincronizacao_service.dart';
import 'cadastrar_cliente_screen.dart';
import 'pedidos_offline_screen.dart';

class HomeScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;          // ✅ MULTIEMPRESA
  final String plano;           // ✅ free / pro
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
  late String tipoUsuario;

  List<dynamic> ultimosPedidos = [];
  List<dynamic> pedidosRascunho = [];
  double totalMes = 0.0;
  bool carregandoPedidos = true;

  // ---------------- HELPERS ----------------
  final NumberFormat _moeda =
  NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  String formatMoeda(num v) => _moeda.format(v);

  double parseValorHibridoDart(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();
    var s = valor.toString().trim();
    if (s.isEmpty) return 0.0;

    s = s.replaceAll(RegExp(r'[^\d.,-]'), '');

    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll('.', '');
      s = s.replaceAll(',', '.');
    } else if (s.contains(',')) {
      s = s.replaceAll('.', '');
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0.0;
  }
  // -----------------------------------------

  @override
  void initState() {
    super.initState();
    tipoUsuario = widget.plano;

    if (tipoUsuario == 'free') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Alguns recursos são exclusivos para usuários PRO'),
          ),
        );
      });
    }

    // ✅ TUDO QUE ENVOLVE HTTP / OFFLINE DEPOIS DO PRIMEIRO FRAME
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SincronizacaoService.sincronizarSilenciosamente(
        widget.empresaId,
        widget.usuarioId,
      );

      await SincronizacaoService.enviarPedidosPendentes(
        context,
        widget.usuarioId,
        widget.empresaId,
      );
    });

    carregarUltimosPedidos();
  }


  Future<void> carregarUltimosPedidos() async {
    final url = Uri.parse(
        'https://toocagroup.com.br/api/listar_pedidos_faturados.php');

    final cachePedidos = 'pedidos_faturados_${widget.empresaId}';
    final cacheRascunhos = 'pedidos_rascunho_${widget.empresaId}';

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'empresa_id': widget.empresaId, // ✅ ISOLAMENTO
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cachePedidos, jsonEncode(data['pedidos'] ?? []));
        await prefs.setString(
            cacheRascunhos, jsonEncode(data['rascunhos'] ?? []));

        if (!mounted) return;
        setState(() {
          ultimosPedidos = data['pedidos'] ?? [];
          pedidosRascunho = data['rascunhos'] ?? [];
          totalMes = parseValorHibridoDart(data['total_mes']);
          carregandoPedidos = false;
        });
      }
    } on SocketException {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      setState(() {
        ultimosPedidos =
            jsonDecode(prefs.getString(cachePedidos) ?? '[]');
        pedidosRascunho =
            jsonDecode(prefs.getString(cacheRascunhos) ?? '[]');
        carregandoPedidos = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📴 Sem conexão. Exibindo dados offline.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      carregandoPedidos = false;
      debugPrint('❌ Erro HomeScreen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> menu = [
      {
        'icon': Icons.add_box,
        'label': 'Novo Pedido',
        'route': () => NovoPedidoScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: widget.plano,
        ),
      },
      {
        'icon': Icons.list_alt,
        'label': 'Pedidos',
        'route': () => PedidosScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: widget.plano,
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
          plano: widget.plano, // 🔥 ESSENCIAL
        ),
      },

    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tooca CRM'),
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.builder(
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
                  MaterialPageRoute(builder: (_) => menu[i]['route']()),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(menu[i]['icon'],
                          size: 48, color: const Color(0xFFFFCC00)),
                      const SizedBox(height: 10),
                      Text(
                        menu[i]['label'],
                        textAlign: TextAlign.center,
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
            const SizedBox(height: 30),
            if (!carregandoPedidos)
              Center(
                child: Column(
                  children: [
                    const Text(
                      '📦 Total Faturado no Mês',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formatMoeda(totalMes),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.sync),
        label: const Text('Sincronizar'),
        onPressed: () async {
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
        },

      ),
    );
  }
}
