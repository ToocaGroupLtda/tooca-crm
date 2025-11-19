// =============================================================
// 📋 TOOCA CRM - Pedidos Screen (v7.0 GOLD SEM BLOQUEIO)
// -------------------------------------------------------------
// ✔ NÃO BLOQUEIA (somente Login e Sincronizar bloqueiam)
// ✔ Consulta SaaS leve (apenas atualiza dados)
// ✔ Carrega pedidos online → fallback offline
// ✔ Suporta edição e exclusão mesmo offline
// ✔ Exportação Excel com share
// ✔ Layout responsivo e estável
// =============================================================

import 'dart:convert';
import 'dart:io';

import 'package:app_tooca_crm/screens/visualizar_pdf_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'novo_pedido_screen.dart';
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
  List<dynamic> pedidos = [];
  bool carregando = true;
  bool offline = false;

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
    _validarECarregar();
  }

  // =============================================================
  // 🔄 Carregar pedidos SEM BLOQUEIO
  // =============================================================
  Future<void> _validarECarregar() async {
    setState(() {
      carregando = true;
      offline = false;
    });

    // Atualiza status SaaS, mas nunca bloqueia
    await SincronizacaoService.consultarStatusEmpresa();

    await _carregarOnline();
  }

  // =============================================================
  // 🔄 Carregar pedidos online
  // =============================================================
  Future<void> _carregarOnline() async {
    try {
      final url =
      Uri.parse('https://app.toocagroup.com.br/api/listar_pedidos.php');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'empresa_id': widget.empresaId,
          'plano': widget.plano,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'ok') {
        pedidos = data['pedidos'];
        offline = false;

        // Atualiza cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'pedidos_offline_${widget.empresaId}',
          jsonEncode({'pedidos': pedidos}),
        );
      } else {
        await _carregarOffline();
      }
    } catch (_) {
      await _carregarOffline();
    }

    if (mounted) setState(() => carregando = false);
  }

  // =============================================================
  // 💾 Carregar pedidos do cache offline
  // =============================================================
  Future<void> _carregarOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pedidos_offline_${widget.empresaId}');

    if (raw != null) {
      final json = jsonDecode(raw);
      pedidos = json['pedidos'] ?? [];
      offline = true;
    } else {
      pedidos = [];
      offline = true;
    }
  }

  // =============================================================
  // 🔄 Exportar Excel direto (save + share)
  // =============================================================
  Future<void> exportarExcelDireto(Map<String, dynamic> pedido) async {
    final pedidoId = pedido['id'].toString();

    final url =
        "https://app.toocagroup.com.br/api/exportar_excel.php?pedido_id=$pedidoId&empresa_id=${widget.empresaId}";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Erro ao gerar Excel.")),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Pedido_$pedidoId.xlsx");
      await file.writeAsBytes(response.bodyBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Pedido #$pedidoId - Excel gerado pelo Tooca CRM",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro: $e")),
      );
    }
  }

  // =============================================================
  // 🗑️ Excluir pedido (não bloqueia)
  // =============================================================
  Future<void> excluirPedido(int pedidoId) async {
    // Atualiza status SaaS
    await SincronizacaoService.consultarStatusEmpresa();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Pedido'),
        content: Text("Deseja excluir o pedido #$pedidoId?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir')),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final url =
      Uri.parse('https://app.toocagroup.com.br/api/excluir_pedido.php');

      final response = await http.post(
        url,
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
        _validarECarregar();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Erro: ${json['mensagem']}")),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Erro ao excluir")),
      );
    }
  }

  // =============================================================
  // ✏️ Abrir edição (não bloqueia)
  // =============================================================
  void abrirEdicao(Map<String, dynamic> pedidoJson) async {
    await SincronizacaoService.consultarStatusEmpresa();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovoPedidoScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: widget.plano,
          pedidoId: int.tryParse(pedidoJson['id'].toString()),
          pedidoJson: pedidoJson,
        ),
      ),
    ).then((ok) {
      if (ok == true) _validarECarregar();
    });
  }

  // =============================================================
  // 🧱 UI
  // =============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title:
        const Text('Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _validarECarregar,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
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

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pedido #${p['id']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text("Cliente: ${p['cliente']}"),
                  Text("Total: ${formatMoeda(total)}"),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 38,
                          margin: const EdgeInsets.only(right: 6),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VisualizarPdfScreen(
                                    pedidoId: int.parse(p['id'].toString()),
                                    usuarioId: widget.usuarioId,
                                    empresaId: widget.empresaId,
                                    plano: widget.plano,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.yellow[700],
                            ),
                            child: const Text("PDF", style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Container(
                          height: 38,
                          margin: const EdgeInsets.only(right: 6),
                          child: ElevatedButton(
                            onPressed: () => abrirEdicao(p),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            child: const Text("EDITAR", style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Container(
                          height: 38,
                          margin: const EdgeInsets.only(right: 6),
                          child: ElevatedButton(
                            onPressed: () => excluirPedido(int.parse(p['id'].toString())),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text("EXCLUIR", style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Container(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () => exportarExcelDireto(p),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text("EXCEL", style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ),
                    ],
                  )



                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
