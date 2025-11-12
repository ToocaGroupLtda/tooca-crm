// =============================================================
// 📋 TOOCA CRM - Pedidos Screen (v4.4 SaaS Multiempresa)
// -------------------------------------------------------------
// Lista de pedidos com layout limpo, integração SaaS e parâmetros
// consistentes (usuarioId, empresaId, plano).
// =============================================================

import 'dart:convert';
import 'package:app_tooca_crm/screens/visualizar_pdf_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'novo_pedido_screen.dart';

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
  late String planoUsuario;

  final NumberFormat _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
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
    } else if (s.contains(',') && !s.contains('.')) {
      s = s.replaceAll('.', '');
      s = s.replaceAll(',', '.');
    }
    return double.tryParse(s) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    carregarPlano();
  }

  Future<void> carregarPlano() async {
    final prefs = await SharedPreferences.getInstance();
    planoUsuario = widget.plano.isNotEmpty
        ? widget.plano
        : prefs.getString('plano') ?? 'free';

    debugPrint(
        '🟢 PedidosScreen → usuario=${widget.usuarioId}, empresa=${widget.empresaId}, plano=$planoUsuario');
    await carregarPedidos();
  }

  // =============================================================
  // 🔄 Carrega pedidos do servidor SaaS
  // =============================================================
  Future<void> carregarPedidos() async {
    setState(() => carregando = true);
    try {
      final url = Uri.parse('https://app.toocagroup.com.br/api/listar_pedidos.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'empresa_id': widget.empresaId,
          'plano': planoUsuario,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['status'] == 'ok' && data['pedidos'] is List) {
        setState(() => pedidos = data['pedidos']);
      } else {
        setState(() => pedidos = []);
      }
      debugPrint('📦 ${pedidos.length} pedidos carregados da empresa ${widget.empresaId}');
    } catch (e) {
      debugPrint('❌ Erro ao carregar pedidos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📴 Sem conexão com o servidor.')),
        );
      }
    }
    if (mounted) setState(() => carregando = false);
  }

  // =============================================================
  // 🗑️ Excluir pedido
  // =============================================================
  Future<void> excluirPedido(int pedidoId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Pedido'),
        content: Text('Tem certeza que deseja excluir o pedido #$pedidoId?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
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
          'plano': planoUsuario,
        }),
      );

      final json = jsonDecode(response.body);
      if (!mounted) return;
      if (json['status'] == 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Pedido excluído com sucesso')),
        );
        carregarPedidos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro: ${json['mensagem']}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro de conexão: $e')),
      );
    }
  }

  // =============================================================
  // ✏️ Abre pedido para edição
  // =============================================================
  void abrirEdicao(Map<String, dynamic> pedidoJson) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NovoPedidoScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: planoUsuario,
          pedidoId: int.tryParse(pedidoJson['id'].toString()),
          pedidoJson: pedidoJson,
        ),
      ),
    ).then((sucesso) {
      if (sucesso == true) carregarPedidos();
    });
  }

  // =============================================================
  // 🧱 Interface
  // =============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Pedidos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: carregarPedidos,
            icon: const Icon(Icons.refresh, color: Colors.black),
            tooltip: 'Atualizar pedidos',
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
          final statusStr = (p['status'] ?? '').toString();
          final isFaturado = statusStr.toLowerCase() == 'faturado';
          final podeEditar =
              (p['usuario_id'] == widget.usuarioId) || planoUsuario != 'free';
          final total = parseValorHibridoDart(p['total']);

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedido #${p['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Cliente: ${p['cliente']}', style: const TextStyle(color: Colors.black87)),
                  Text('Total: ${formatMoeda(total)}',
                      style: const TextStyle(color: Colors.black87)),
                  const SizedBox(height: 8),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        isFaturado ? Icons.check_circle : Icons.hourglass_bottom,
                        color: isFaturado ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text('Status: $statusStr',
                          style: const TextStyle(color: Colors.black87)),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Divider(color: Colors.grey.shade300, thickness: 1),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFCC00),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
                          label: const Text('PDF',
                              style: TextStyle(color: Colors.black)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PedidosScreen(
                                  usuarioId: widget.usuarioId,
                                  empresaId: widget.empresaId,
                                  plano: widget.plano, // ✅ adicionado
                                ),
                              ),
                            );

                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.edit, color: Colors.black),
                          label: const Text('Editar',
                              style: TextStyle(color: Colors.black)),
                          onPressed: podeEditar ? () => abrirEdicao(p) : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.delete, color: Colors.white),
                          label: const Text('Excluir',
                              style: TextStyle(color: Colors.white)),
                          onPressed: podeEditar ? () => excluirPedido(p['id']) : null,
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
