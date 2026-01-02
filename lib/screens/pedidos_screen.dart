// =============================================================
// 📋 TOOCA CRM - Pedidos Screen (v7.2 GOLD FIXED)
// -------------------------------------------------------------
// ✔ EXIBE NÚMERO SEQUENCIAL POR EMPRESA (Ex: Pedido #1)
// ✔ SOMENTE PEDIDOS ONLINE
// ✔ BLOQUEIA TELA QUANDO OFFLINE
// ✔ Consulta SaaS leve
// ✔ Layout 100% mantido
// =============================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async'; // ← StreamSubscription

import 'novo_pedido_screen.dart';
import 'visualizar_pdf_screen.dart';
import 'sincronizacao_service.dart';

class PedidosScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;
  final String plano;

  const PedidosScreen({
    Key? key,
    required this.usuarioId,
    required this.empresaId,
    required this.plano,
  }) : super(key: key);

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  List<Map<String, dynamic>> pedidos = [];
  bool carregando = true;

  bool _isOnline = true;
  StreamSubscription<ConnectivityResult>? _connSub;

  final NumberFormat _moeda =
  NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  String formatMoeda(num v) => _moeda.format(v);

  double parseValorHibrido(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();

    var s = valor.toString().trim();
    if (s.isEmpty) return 0.0;

    s = s.replaceAll(RegExp(r'[^\d.,-]'), '');

    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(s) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();

    _connSub =
        Connectivity().onConnectivityChanged.listen((result) {
          final online = result != ConnectivityResult.none;
          if (mounted) setState(() => _isOnline = online);
        });

    Connectivity().checkConnectivity().then((result) {
      final online = result != ConnectivityResult.none;
      if (mounted) setState(() => _isOnline = online);
    });

    _carregarPedidos();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  // =============================================================
  // 🔄 CARREGAR PEDIDOS ONLINE
  // =============================================================
  Future<void> _carregarPedidos() async {
    setState(() => carregando = true);

    debugPrint('🚨 PASSO 1 -> empresa_id ENVIADO: ${widget.empresaId}');
    debugPrint('🚨 PASSO 1 -> usuario_id ENVIADO: ${widget.usuarioId}');

    await SincronizacaoService.consultarStatusEmpresa(widget.empresaId);

    try {
      final response = await http.post(
        Uri.parse('https://toocagroup.com.br/api/listar_pedidos.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'empresa_id': widget.empresaId,
          'plano': widget.plano,
        }),
      );


      final data = jsonDecode(response.body);

      debugPrint('🚨 PASSO 2 -> RESPONSE RAW: ${response.body}');
      debugPrint('🚨 PASSO 2 -> QTD PEDIDOS: ${data['pedidos']?.length}');


      if (data['status'] == 'ok') {
        pedidos = List<Map<String, dynamic>>.from(data['pedidos']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'pedidos_cache_${widget.empresaId}',
          jsonEncode(pedidos),
        );
      } else {
        pedidos = [];
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cache = prefs.getString('pedidos_cache_${widget.empresaId}');
      if (cache != null) {
        pedidos = List<Map<String, dynamic>>.from(jsonDecode(cache));
      } else {
        pedidos = [];
      }
    }

    if (mounted) setState(() => carregando = false);
  }

  // =============================================================
  // 📤 EXPORTAR EXCEL
  // =============================================================
  Future<void> exportarExcelDireto(Map<String, dynamic> pedido) async {
    final pedidoId = pedido['id'].toString(); // ID Global para o Banco
    final numeroVisual = (pedido['numero_pedido_empresa'] ?? pedidoId).toString();

    final url =
        "https://toocagroup.com.br/api/exportar_excel.php?pedido_id=$pedidoId&empresa_id=${widget.empresaId}";

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return;

    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/Pedido_$numeroVisual.xlsx");
    await file.writeAsBytes(response.bodyBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: "Pedido #$numeroVisual - Excel (Tooca CRM)",
    );
  }

  // =============================================================
  // 🗑️ EXCLUIR PEDIDO
  // =============================================================
  Future<void> excluirPedido(Map<String, dynamic> pedido) async {
    final pedidoId = int.parse(pedido['id'].toString());
    final numeroVisual = pedido['numero_pedido_empresa'] ?? pedidoId;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Pedido'),
        content: Text("Deseja excluir o pedido #$numeroVisual?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final response = await http.post(
        Uri.parse('https://toocagroup.com.br/api/listar_excluir_pedido.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pedido_id': pedidoId,
          'usuario_id': widget.usuarioId,
          'empresa_id': widget.empresaId,
          'plano': widget.plano,
        }),
      );

      final json = jsonDecode(response.body);

      if (json['status'] == 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Pedido excluído")),
        );
        _carregarPedidos();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Erro ao excluir pedido")),
      );
    }
  }

  // =============================================================
  // ✏️ EDITAR
  // =============================================================
  void abrirEdicao(Map<String, dynamic> pedido) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovoPedidoScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: widget.plano,
          pedidoId: int.tryParse(pedido['id'].toString()),
          pedidoJson: pedido,
        ),
      ),
    ).then((ok) {
      if (ok == true) _carregarPedidos();
    });
  }

  // =============================================================
  // 🧱 UI
  // =============================================================
  @override
  Widget build(BuildContext context) {

    if (!_isOnline) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFFFFCC00),
          foregroundColor: Colors.black,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.wifi_off, size: 72, color: Colors.grey),
                SizedBox(height: 16),
                Text('Você está sem internet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Não é possível acessar pedidos sem conexão.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : pedidos.isEmpty
          ? const Center(child: Text('Nenhum pedido encontrado.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pedidos.length,
        itemBuilder: (context, index) {
          final p = pedidos[index];
          final total = parseValorHibrido(p['total'] ?? 0);

          // 🔢 LÓGICA DO NÚMERO VISUAL (Prioriza o número da empresa)
          final numeroExibicao = p['numero_pedido_empresa'] ?? p['id'];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pedido #$numeroExibicao", // 🔥 MOSTRA 1, 2, 3...
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text("Cliente: ${p['cliente']}"),
                  Text("Total: ${formatMoeda(total)}"),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisualizarPdfScreen(
                                    pedidoId: int.parse(p['id'].toString()), // ID Global para o PDF
                                    usuarioId: widget.usuarioId,
                                    empresaId: widget.empresaId,
                                    plano: widget.plano,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow[700]),
                            child: const Text("PDF", style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () => abrirEdicao({...p, 'forcar_master': true}),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            child: const Text("EDITAR", style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () => excluirPedido(p),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text("EXCLUIR", style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () => exportarExcelDireto(p),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("EXCEL", style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}