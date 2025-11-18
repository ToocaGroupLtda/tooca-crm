// =============================================================
// 📋 TOOCA CRM - Pedidos Screen (v6.0 SaaS + EXCEL SHARE SUPREMO)
// -------------------------------------------------------------
// ✔ Verificação LOCAL + SAAS (bloqueio total)
// ✔ Listagem responsiva para telas pequenas
// ✔ Botão PDF + Editar + Excluir
// ✔ Botão Excel -> BAIXA ARQUIVO (bytes) + SALVA + COMPARTILHA
// ✔ Wrap automático (não estoura layout)
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

  final NumberFormat _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  String formatMoeda(num v) => _moeda.format(v);

  double parseValorHibridoDart(dynamic valor) {
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
  // 🔐 Verificação LOCAL + SAAS
  // =============================================================
  Future<void> _validarECarregar() async {
    final prefs = await SharedPreferences.getInstance();

    // Local
    if (!await SincronizacaoService.empresaAtivaLocal()) {
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    // SaaS
    await SincronizacaoService.consultarStatusEmpresa();

    // Local novamente
    if (!await SincronizacaoService.empresaAtivaLocal()) {
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    await _carregarReal();
  }

  // =============================================================
  // 🔄 Carrega pedidos online
  // =============================================================
  Future<void> _carregarReal() async {
    setState(() => carregando = true);

    try {
      final url = Uri.parse('https://app.toocagroup.com.br/api/listar_pedidos.php');

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
      pedidos = data['status'] == 'ok' ? data['pedidos'] : [];
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📴 Sem conexão com o servidor.')),
      );
    }

    if (mounted) setState(() => carregando = false);
  }

  // =============================================================
  // 🔄 Exportar Excel (ARQUIVO DIRETO → Share)
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

      // Salvar arquivo temporário
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/Pedido_$pedidoId.xlsx");
      await file.writeAsBytes(response.bodyBytes);

      // Compartilhar no WhatsApp / Apps
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
  // 🗑️ Excluir Pedido
  // =============================================================
  Future<void> excluirPedido(int pedidoId) async {
    final prefs = await SharedPreferences.getInstance();

    if (!await SincronizacaoService.empresaAtivaLocal()) {
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    await SincronizacaoService.consultarStatusEmpresa();

    if (!await SincronizacaoService.empresaAtivaLocal()) {
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

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
      final url = Uri.parse('https://app.toocagroup.com.br/api/excluir_pedido.php');

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
  // ✏️ Abrir Edição
  // =============================================================
  void abrirEdicao(Map<String, dynamic> pedidoJson) async {
    final prefs = await SharedPreferences.getInstance();

    if (!await SincronizacaoService.empresaAtivaLocal()) {
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    await SincronizacaoService.consultarStatusEmpresa();

    if (!await SincronizacaoService.empresaAtivaLocal()) {
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

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
        title: const Text('Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
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
          final total = parseValorHibridoDart(p['total'] ?? 0);

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

                  // 🔥 BOTÕES RESPONSIVOS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFCC00),
                            minimumSize: const Size(0, 40),
                          ),
                          label: const Text('PDF', style: TextStyle(color: Colors.black)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VisualizarPdfScreen(
                                  pedidoId: int.tryParse(p['id'].toString()) ?? 0,
                                  empresaId: widget.empresaId,
                                  usuarioId: widget.usuarioId,
                                  plano: widget.plano,
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      Flexible(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit, color: Colors.black),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            minimumSize: const Size(0, 40),
                          ),
                          label: const Text('Editar', style: TextStyle(color: Colors.black)),
                          onPressed: () => abrirEdicao(p),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Flexible(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: const Size(0, 40),
                          ),
                          label: const Text('Excluir', style: TextStyle(color: Colors.white)),
                          onPressed: () => excluirPedido(p['id']),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Flexible(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download, color: Colors.black),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            minimumSize: const Size(0, 40),
                          ),
                          label: const Text('Excel', style: TextStyle(color: Colors.black)),
                          onPressed: () => exportarExcelDireto(p),
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
