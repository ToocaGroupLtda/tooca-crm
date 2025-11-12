// =============================================================
// 📄 TOOCA CRM - Visualizar PDF (v4.4 SaaS Multiempresa)
// -------------------------------------------------------------
// Compatível com modo online/offline e parâmetros multiempresa.
// =============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  final void Function(BuildContext context, Map<String, dynamic> pedidoOffline)? onEditarOffline;

  const VisualizarPdfScreen({
    Key? key,
    required this.pedidoId,
    required this.empresaId,
    required this.usuarioId,
    required this.plano,
    this.isAdmin = false,
    this.pedidoOffline,
    this.onEditarOffline,
  }) : super(key: key);

  const VisualizarPdfScreen.online({
    Key? key,
    required this.pedidoId,
    required this.empresaId,
    required this.usuarioId,
    required this.plano,
    this.isAdmin = false,
  })  : pedidoOffline = null,
        onEditarOffline = null,
        super(key: key);

  const VisualizarPdfScreen.offline({
    Key? key,
    required this.pedidoOffline,
    required this.empresaId,
    required this.usuarioId,
    required this.plano,
    this.isAdmin = false,
    this.onEditarOffline,
  })  : pedidoId = null,
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
      setState(() => carregando = false);
    } else {
      carregarPdf();
    }
  }

  Future<void> carregarPdf() async {
    if (widget.pedidoId == null) {
      setState(() => carregando = false);
      return;
    }

    try {
      final url =
          'https://app.toocagroup.com.br/api/gerar_pdf.php'
          '?id=${widget.pedidoId}'
          '&empresa_id=${widget.empresaId}'
          '&usuario_id=${widget.usuarioId}'
          '&plano=${widget.plano}';

      debugPrint('📄 Gerando PDF → $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
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
      } else {
        throw Exception('Erro HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar PDF: $e')),
        );
      }
      setState(() => carregando = false);
    }
  }

  Future<void> compartilharPdf() async {
    if (widget.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📴 Pedido offline: gere o PDF quando estiver online.')),
      );
      return;
    }

    if (localPdfPath != null) {
      await Share.shareXFiles(
        [XFile(localPdfPath!)],
        text: '📄 Pedido #${widget.pedidoId} - Tooca CRM',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF ainda não carregado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final offline = widget.isOffline;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(offline ? 'Pedido Offline' : 'Visualizar PDF'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        actions: [
          if (!offline)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: carregarPdf,
              tooltip: 'Atualizar PDF',
            ),
          if (!offline)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: compartilharPdf,
              tooltip: 'Compartilhar PDF',
            ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : offline
          ? _buildOfflineBody(context)
          : (localPdfPath != null
          ? SfPdfViewer.file(File(localPdfPath!))
          : const Center(child: Text('Falha ao carregar PDF.'))),
    );
  }

  Widget _buildOfflineBody(BuildContext context) {
    final pedido = widget.pedidoOffline ?? {};
    final clienteNome =
    (pedido['cliente_nome'] ?? pedido['cliente'] ?? 'Cliente não informado').toString();
    final total = (pedido['total'] ?? pedido['valor_total'] ?? 0).toString();

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
                          'Pedido Offline — sem PDF ainda',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('Cliente: $clienteNome'),
                        Text('Total (estimado): R\$ $total'),
                        const SizedBox(height: 10),
                        const Text(
                          'Este pedido foi criado offline.\n'
                              'Você pode editar ou sincronizar quando estiver online.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.onEditarOffline != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Editar Pedido Offline'),
                onPressed: () => widget.onEditarOffline!(context, pedido),
              ),
            ),
        ],
      ),
    );
  }
}
