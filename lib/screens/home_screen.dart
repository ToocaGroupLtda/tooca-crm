// =============================================================
// 🚀 TOOCA CRM - HOME SCREEN (v9.5 EVA GOLD FIXED)
// -------------------------------------------------------------
// ✔ Correção Multiempresa: Sincronização vinculada ao ID real
// ✔ Logout Seguro: Não apaga dados offline pendentes
// ✔ Bloqueio Imediato: Validação de Status ao Sincronizar
// =============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'login_screen.dart';
import 'pedidos_screen.dart';
import 'novo_pedido_screen.dart';
import 'sincronizacao_service.dart';
import 'clientes_screen.dart';
import 'pedidos_offline_screen.dart';

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
  late String tipoUsuario;
  List<dynamic> ultimosPedidos = [];
  List<dynamic> pedidosRascunho = [];
  double totalMes = 0.0;
  bool carregandoPedidos = true;

  final NumberFormat _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    tipoUsuario = widget.plano;

    // 🛡️ TRAVA DE ABERTURA: Verifica status assim que entra na Home
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bool ativa = await SincronizacaoService.consultarStatusEmpresa(widget.empresaId);
      if (ativa) {
        _executarSincronizacaoInicial();
      }
    });
  }

  // 🔄 Função que garante a sincronia e verifica bloqueios
  Future<void> _executarSincronizacaoInicial() async {
    debugPrint("🔄 Validando Empresa: ${widget.empresaId}");

    // 🛡️ 1. CONSULTA STATUS REAL NO SERVIDOR (Se bloqueado, o Service redireciona)
    final bool ativa = await SincronizacaoService.consultarStatusEmpresa(widget.empresaId);

    // Se a API retornar que não está ativa, interrompe qualquer processamento
    if (!ativa) return;

    // 2. Prosegue com as sincronias silenciosas e pendentes
    await SincronizacaoService.sincronizarSilenciosamente(
      widget.empresaId,
      widget.usuarioId,
    );

    // O método abaixo também já possui a trava interna de segurança
    await SincronizacaoService.enviarPedidosPendentes(
      context,
      widget.usuarioId,
      widget.empresaId,
    );

    await carregarUltimosPedidos();
  }

  Future<void> carregarUltimosPedidos() async {
    final url = Uri.parse('https://toocagroup.com.br/api/listar_pedidos_faturados.php');
    final cachePedidos = 'pedidos_faturados_${widget.empresaId}';
    final cacheRascunhos = 'pedidos_rascunho_${widget.empresaId}';

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'empresa_id': widget.empresaId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(cachePedidos, jsonEncode(data['pedidos'] ?? []));
        await prefs.setString(cacheRascunhos, jsonEncode(data['rascunhos'] ?? []));

        if (!mounted) return;
        setState(() {
          ultimosPedidos = data['pedidos'] ?? [];
          pedidosRascunho = data['rascunhos'] ?? [];
          totalMes = _parseValor(data['total_mes']);
          carregandoPedidos = false;
        });
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      setState(() {
        ultimosPedidos = jsonDecode(prefs.getString(cachePedidos) ?? '[]');
        pedidosRascunho = jsonDecode(prefs.getString(cacheRascunhos) ?? '[]');
        carregandoPedidos = false;
      });
    }
  }

  double _parseValor(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor.toString().replaceAll(',', '.')) ?? 0.0;
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
          plano: widget.plano,
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
              await prefs.remove('usuario_id');
              await prefs.remove('empresa_id');
              await prefs.remove('email');
              await prefs.remove('nome');

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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: menu.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(2, 2))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(menu[i]['icon'], size: 48, color: const Color(0xFFFFCC00)),
                      const SizedBox(height: 10),
                      Text(menu[i]['label'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                    ],
                  ),
                ),
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
          // 🛡️ Ao clicar no botão, a validação de status é a prioridade zero
          await _executarSincronizacaoInicial();
        },
      ),
    );
  }
}