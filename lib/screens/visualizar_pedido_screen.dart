// =============================================================
// 📄 TOOCA CRM - Visualizar Pedido (v5.0 EVA FINAL)
// -------------------------------------------------------------
// ✔ Integra 100% com VisualizarPdfScreen.online()
// ✔ Suporte total a multiempresa + multiusuário
// ✔ Exibe itens, descontos, totais e observação
// ✔ Compatível com pedidos vindos da API ou offline
// ✔ Layout padrão Tooca CRM 2025
// =============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'visualizar_pdf_screen.dart';

class VisualizarPedidoScreen extends StatefulWidget {
  final Map<String, dynamic> pedidoJson;

  const VisualizarPedidoScreen({
    Key? key,
    required this.pedidoJson,
  }) : super(key: key);

  @override
  State<VisualizarPedidoScreen> createState() => _VisualizarPedidoScreenState();
}

class _VisualizarPedidoScreenState extends State<VisualizarPedidoScreen> {
  late Map<String, dynamic> pedido;
  bool carregando = true;

  int empresaId = 0;
  int usuarioId = 0;
  String plano = 'free';

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  // =============================================================
  // 🔧 Inicializa dados da sessão
  // =============================================================
  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    empresaId = prefs.getInt('empresa_id') ?? 0;
    usuarioId = prefs.getInt('usuario_id') ?? 0;
    plano = prefs.getString('plano_usuario') ?? 'free';

    pedido = widget.pedidoJson;

    setState(() => carregando = false);
  }

  // =============================================================
  // 💰 Cálculo total do pedido
  // =============================================================
  double calcularTotal() {
    double total = 0;

    if (pedido['itens'] == null) return 0;

    for (var item in pedido['itens']) {
      final qtd = double.tryParse('${item['qtd'] ?? item['quantidade'] ?? 0}') ?? 0;
      final preco = double.tryParse('${item['preco'] ?? item['preco_unit'] ?? 0}') ?? 0;
      total += qtd * preco;
    }

    return total;
  }

  // =============================================================
  // 📄 Abre PDF usando a nova VisualizarPdfScreen
  // =============================================================
  void abrirPdf() {
    final id = pedido['id'] ?? pedido['pedido_id'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Este pedido ainda não possui PDF.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualizarPdfScreen.online(
          pedidoId: int.tryParse(id.toString()) ?? 0,
          empresaId: empresaId,
          usuarioId: usuarioId,
          plano: plano,
        ),
      ),
    );
  }

  // =============================================================
  // 🎨 Layout principal
  // =============================================================
  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    final itens = (pedido['itens'] as List? ?? []);
    final total = calcularTotal();
    final descontoGeral = pedido['desconto_geral'] ?? pedido['descontoGeral'] ?? '0';
    final cliente = pedido['cliente'] ?? pedido['cliente_nome'] ?? 'Cliente não informado';
    final tabela = pedido['tabela_nome'] ?? pedido['tabela'] ?? '---';
    final cond = pedido['cond_pagamento'] ?? pedido['condicao'] ?? '---';
    final obs = pedido['observacao'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text(
          'Visualizar Pedido',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
      ),

      // =========================================================
      // BODY
      // =========================================================
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------
            // 🧱 Cabeçalho
            // -----------------------------------------------------
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente: $cliente',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Tabela: $tabela'),
                    Text('Condição: $cond'),
                    Text('Desconto geral: $descontoGeral%'),
                    if (obs.toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Obs: $obs'),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Text('Itens', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            // -----------------------------------------------------
            // 🧾 Lista de itens
            // -----------------------------------------------------
            Expanded(
              child: ListView.builder(
                itemCount: itens.length,
                itemBuilder: (_, i) {
                  final item = itens[i];

                  final codigo = item['codigo'] ?? '';
                  final nome = item['nome'] ?? '';
                  final qtd = double.tryParse('${item['qtd'] ?? 0}') ?? 0;
                  final preco = double.tryParse('${item['preco'] ?? 0}') ?? 0;
                  final desc = item['desconto'] ?? 0;

                  final subtotal = qtd * preco;

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text('$codigo - $nome',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Qtd: $qtd | Unit: R\$ ${preco.toStringAsFixed(2)} | Desc: $desc% | Sub: R\$ ${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(),

            // -----------------------------------------------------
            // 💵 Total
            // -----------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'R\$ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // -----------------------------------------------------
            // 🔗 BOTÃO PDF
            // -----------------------------------------------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
                label: const Text('Ver PDF', style: TextStyle(color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: abrirPdf,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
