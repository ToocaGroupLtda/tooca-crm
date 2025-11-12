// ============================================================
// 📄 TOOCA CRM - Visualizar Pedido (v4.4 SaaS + App)
// ------------------------------------------------------------
// - Exibe os detalhes completos de um pedido
// - Calcula subtotal, total e desconto geral
// - Abre o PDF gerado no servidor SaaS
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisualizarPedidoScreen extends StatefulWidget {
  final Map<String, dynamic> pedidoJson;

  const VisualizarPedidoScreen({Key? key, required this.pedidoJson}) : super(key: key);

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

  // ============================================================
  // 🔧 Inicialização
  // ============================================================
  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    empresaId = prefs.getInt('empresa_id') ?? 0;
    usuarioId = prefs.getInt('usuario_id') ?? 0;
    plano = prefs.getString('plano') ?? 'free';
    await Future.delayed(const Duration(milliseconds: 50));

    setState(() {
      pedido = widget.pedidoJson;
      carregando = false;
    });
  }

  // ============================================================
  // 💰 Cálculo total
  // ============================================================
  double calcularTotal() {
    double total = 0;
    if (pedido['itens'] != null) {
      for (var item in pedido['itens']) {
        final qtd = double.tryParse('${item['qtd'] ?? item['quantidade'] ?? 0}') ?? 0;
        final preco = double.tryParse('${item['preco'] ?? item['preco_unit'] ?? 0}') ?? 0;
        total += qtd * preco;
      }
    }
    return total;
  }

  // ============================================================
  // 🧾 Abre o PDF no navegador
  // ============================================================
  Future<void> abrirPdf() async {
    final id = pedido['id'] ?? pedido['pedido_id'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Este pedido ainda não tem PDF disponível.')),
      );
      return;
    }

    final url =
        'https://app.toocagroup.com.br/api/gerar_pdf.php'
        '?id=$id&empresa_id=$empresaId&usuario_id=$usuarioId&plano=$plano';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Não foi possível abrir o PDF.')),
      );
    }
  }

  // ============================================================
  // 🎨 Layout principal
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final itens = (pedido['itens'] as List<dynamic>? ?? []);
    final total = calcularTotal();
    final descontoGeral = (pedido['desconto_geral'] ?? pedido['descontoGeral'] ?? 0).toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Visualizar Pedido'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================================
            // 🧱 Cabeçalho com dados gerais
            // ============================================================
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cliente: ${pedido['cliente'] ?? pedido['cliente_nome'] ?? pedido['cliente_id'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text('Tabela: ${pedido['tabela_nome'] ?? pedido['tabela'] ?? pedido['tabela_id'] ?? ''}'),
                    Text('Condição: ${pedido['cond_pagamento_nome'] ?? pedido['cond_pagamento'] ?? pedido['cond_pagto_id'] ?? ''}'),
                    Text('Desconto geral: $descontoGeral%'),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Obs: ${(pedido['observacao'] ?? '').toString().isNotEmpty ? pedido['observacao'] : 'Sem observações'}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Text('Itens do Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),

            // ============================================================
            // 🧾 Lista de itens
            // ============================================================
            Expanded(
              child: ListView.builder(
                itemCount: itens.length,
                itemBuilder: (context, i) {
                  final item = itens[i];
                  final qtd = double.tryParse('${item['qtd'] ?? 0}') ?? 0;
                  final preco = double.tryParse('${item['preco'] ?? 0}') ?? 0;
                  final subtotal = qtd * preco;
                  final desconto = (item['desconto'] ?? 0).toString();

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(
                        '${item['codigo'] ?? ''} - ${item['nome'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Qtd: $qtd | Unit: R\$ ${preco.toStringAsFixed(2)} | Desc: $desconto% | Sub: R\$ ${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Divider(),

            // ============================================================
            // 💵 Total
            // ============================================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  'R\$ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ============================================================
            // 🔗 Botão PDF
            // ============================================================
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
                label: const Text('Ver PDF', style: TextStyle(color: Colors.black)),
                onPressed: abrirPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
