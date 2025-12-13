// =============================================================
// 📄 TOOCA CRM - Visualizar PDF (v4.4.4 SaaS Multiempresa FINAL)
// -------------------------------------------------------------
// ✔ Online / Offline
// ✔ Multiempresa
// ✔ Multiusuário
// ✔ Compartilhar PDF
// ✔ Editar pedido offline
// ✔ Sem warnings / sem erros
// =============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class VisualizarPdfScreen extends StatefulWidget {
  final int? pedidoId;
  final Map<String, dynamic>? pedidoOffline;

  final int empresaId;
  final int usuarioId;
  final String plano;
  final bool isAdmin;

  /// Callback opcional para editar pedido offline
  final void Function(BuildContext context, Map<String, dynamic> pedidoOffline)?
  onEditarOffline;

  // =============================================================
  // 🔹 CONSTRUTOR PADRÃO (ROBUSTO)
  // =============================================================
  const VisualizarPdfScreen({
    Key? key,
    this.pedidoId,
    this.pedidoOffline,
    required this.empresaId,
    required this.usuarioId,
    this.plano = 'free',
    this.isAdmin = false,
    this.onEditarOffline,
  }) : super(key: key);

  // =============================================================
  // 🔹 ONLINE
  // =============================================================
  const VisualizarPdfScreen.online({
    Key? key,
    required int pedidoId,
    required this.empresaId,
    required this.usuarioId,
    this.plano = 'free',
    this.isAdmin = false,
  })  : pedidoId = pedidoId,
        pedidoOffline = null,
        onEditarOffline = null,
        super(key: key);

  // =============================================================
  // 🔹 OFFLINE
  // =============================================================
  const VisualizarPdfScreen.offline({
    Key? key,
    required Map<String, dynamic> pedidoOffline,
    required this.empresaId,
    required this.usuarioId,
    this.plano = 'free',
    this.isAdmin = false,
    this.onEditarOffline,
  })  : pedidoId = null,
        pedidoOffline = pedidoOffline,
        super(key: key);

  bool get isOffline => pedidoOffline != null;

  @override
  State<VisualizarPdfScreen> createState() => _VisualizarPdfScreenState();
}

class _VisualizarPdfScreenState extends State<VisualizarPdfScreen> {
  String? localPdfPath;
  bool carregando = true;

  @override
  void initState() {
    super.initState();

    if (widget.isOffline) {
      carregando = false;
    } else {
      carregarPdf();
    }
  }

  // =============================================================
  // 🔄 CARREGAR PDF ONLINE
  // =============================================================
  Future<void> carregarPdf() async {
    if (widget.pedidoId == null) {
      setState(() => carregando = false);
      return;
    }

    try {
      final url =
          'https://toocagroup.com.br/api/gerar_pdf.php'
          '?id=${widget.pedidoId}'
          '&empresa_id=${widget.empresaId}'
          '&usuario_id=${widget.usuarioId}'
          '&plano=${widget.plano}';

      debugPrint('📄 Gerando PDF → $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final pdfBytes = response.bodyBytes;

      if (pdfBytes.lengthInBytes < 1000) {
        throw Exception('PDF inválido ou vazio.');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/pedido_${widget.pedidoId}.pdf');
      await file.writeAsBytes(pdfBytes, flush: true);

      setState(() {
        localPdfPath = file.path;
        carregando = false;
      });
    } catch (e) {
      debugPrint('❌ Erro PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar PDF: $e')),
        );
      }
      setState(() => carregando = false);
    }
  }

  // =============================================================
  // 📤 COMPARTILHAR PDF
  // =============================================================
  Future<void> compartilharPdf() async {
    if (widget.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📴 Pedido offline não possui PDF.')),
      );
      return;
    }

    if (localPdfPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF ainda não carregado.')),
      );
      return;
    }

    await Share.shareXFiles(
      [XFile(localPdfPath!)],
      text: '📄 Pedido #${widget.pedidoId} - Tooca CRM',
    );
  }

  // =============================================================
  // 🖥️ UI
  // =============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: Text(widget.isOffline ? 'Pedido Offline' : 'Visualizar PDF'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        actions: [
          if (!widget.isOffline)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: carregarPdf,
            ),
          if (!widget.isOffline)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: compartilharPdf,
            ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : widget.isOffline
          ? _buildOffline()
          : _buildOnline(),
    );
  }

  // =============================================================
  // 📄 ONLINE
  // =============================================================
  Widget _buildOnline() {
    if (localPdfPath == null) {
      return const Center(child: Text('Falha ao carregar PDF.'));
    }
    return SfPdfViewer.file(File(localPdfPath!));
  }

  // =============================================================
  // 📦 OFFLINE
  // =============================================================
  Widget _buildOffline() {
    final pedido = widget.pedidoOffline ?? {};

    final cliente =
    (pedido['cliente_nome'] ?? pedido['cliente'] ?? 'Cliente não informado')
        .toString();

    final total =
    (pedido['total'] ?? pedido['total_geral'] ?? pedido['valor_total'] ?? 0)
        .toString();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pedido Offline — sem PDF',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Cliente: $cliente'),
                        Text('Total estimado: R\$ $total'),
                        const SizedBox(height: 12),
                        const Text(
                          'Você poderá gerar o PDF assim que estiver online.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (widget.onEditarOffline != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Editar Pedido Offline'),
                onPressed: () =>
                    widget.onEditarOffline!(context, pedido),
              ),
            ),
        ],
      ),
    );
  }
}
