import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sincronizacao_service.dart';
import 'novo_pedido_screen.dart';
import 'visualizar_pdf_screen.dart';

// =============================================================
// 📦 TOOCA CRM - PEDIDOS OFFLINE (MULTIEMPRESA FINAL)
// =============================================================

class PedidosOfflineScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId; // ✅ MULTIEMPRESA

  const PedidosOfflineScreen({
    Key? key,
    required this.usuarioId,
    required this.empresaId,
  }) : super(key: key);

  @override
  State<PedidosOfflineScreen> createState() => _PedidosOfflineScreenState();
}

class _PedidosOfflineScreenState extends State<PedidosOfflineScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  String get _chaveFila => 'pedidos_pendentes_${widget.empresaId}';

  @override
  void initState() {
    super.initState();
    _future = _carregarPendentes();
  }

  // ===========================================================
  // 📥 CARREGAR PEDIDOS OFFLINE (POR EMPRESA)
  // ===========================================================
  Future<List<Map<String, dynamic>>> _carregarPendentes() async {
    final prefs = await SharedPreferences.getInstance();
    final fila = prefs.getStringList(_chaveFila) ?? <String>[];

    return fila.map((raw) {
      final reg = jsonDecode(raw);

      final bool temTipo = reg is Map && reg.containsKey('tipo');
      final Map<String, dynamic> dados =
      temTipo ? Map<String, dynamic>.from(reg['dados'] ?? {}) : Map<String, dynamic>.from(reg);

      // 🔢 Calcula total se não vier pronto
      double total = 0.0;
      if (dados['total'] != null) {
        total = (dados['total'] as num).toDouble();
      } else {
        final itens = (dados['itens'] as List<dynamic>? ?? []);
        for (final it in itens) {
          final qtd = (it['qtd'] ?? it['quantidade'] ?? 0) as num;
          final preco = (it['preco'] ?? it['preco_unit'] ?? 0) as num;
          total += qtd.toDouble() * preco.toDouble();
        }
      }

      return {
        'raw': raw,
        'tipo': temTipo ? (reg['tipo'] ?? 'novo') : 'novo',
        'pedido_id': temTipo ? reg['pedido_id'] : null,
        'cliente_nome': (dados['cliente_nome'] ?? 'Cliente Offline').toString(),
        'tabela_nome': (dados['tabela_nome'] ?? '---').toString(),
        'condicao_nome': (dados['condicao_nome'] ?? '---').toString(),
        'total': total,
        'dados': dados,
      };
    }).toList();
  }

  // ===========================================================
  // 🗑️ REMOVER PEDIDO OFFLINE
  // ===========================================================
  Future<void> _remover(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    final fila = prefs.getStringList(_chaveFila) ?? <String>[];
    fila.remove(rawJson);
    await prefs.setStringList(_chaveFila, fila);
    setState(() => _future = _carregarPendentes());
  }

  // ===========================================================
  // 🔄 SINCRONIZAR AGORA
  // ===========================================================
  Future<void> _sincronizarAgora() async {
    await SincronizacaoService.enviarPedidosPendentes(
      context,
      widget.usuarioId,
      widget.empresaId,
    );
    setState(() => _future = _carregarPendentes());
  }

  // ===========================================================
  // ✏️ EDITAR PEDIDO OFFLINE
  // ===========================================================
  void _editar(Map<String, dynamic> pedido, int filaIndex) {
    final raw = pedido['dados'];
    Map<String, dynamic> dados = {};

    if (raw is Map) {
      dados = raw.map((k, v) => MapEntry(k.toString(), v));
    } else if (raw is String) {
      try {
        final dec = jsonDecode(raw);
        if (dec is Map) {
          dados = dec.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }

    if (dados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido offline inválido para editar.')),
      );
      return;
    }

    // =====================================================
    // 🔥 NORMALIZA ITENS PARA O FORMATO DO EDITAR
    // =====================================================
    final itensRaw = (dados['itens'] as List?) ?? [];

    final itensCorrigidos = itensRaw.map<Map<String, dynamic>>((it) {
      final map = Map<String, dynamic>.from(it);

      final qtd = map['qtd']
          ?? map['quantidade']
          ?? 0;

      final preco = map['preco']
          ?? map['preco_unit']
          ?? 0;

      return {
        ...map,
        'qtd': (qtd is num) ? qtd : double.tryParse(qtd.toString()) ?? 0,
        'preco': (preco is num) ? preco : double.tryParse(preco.toString()) ?? 0,
        'preco_base': map['preco_base']
            ?? map['preco']
            ?? map['preco_unit']
            ?? 0,
        'desconto': map['desconto'] ?? 0,
      };
    }).toList();

    dados['itens'] = itensCorrigidos;

    // =====================================================
    // 🚀 ABRE O EDITAR
    // =====================================================
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovoPedidoScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: 'free', // mantém
          pedidoId: null,
          isAdmin: false,
          pedidoRascunho: dados,
          filaIndex: filaIndex,
        ),
      ),
    );
  }


  // ===========================================================
  // 👁️ VISUALIZAR OFFLINE
  // ===========================================================
  void _visualizarOffline(Map<String, dynamic> pedido) {
    final raw = pedido['dados'];
    Map<String, dynamic> dados = {};

    if (raw is Map) {
      dados = raw.map((k, v) => MapEntry(k.toString(), v));
    } else if (raw is String) {
      try {
        final dec = jsonDecode(raw);
        if (dec is Map) dados = dec.map((k, v) => MapEntry(k.toString(), v));
      } catch (_) {}
    }

    if (dados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pedido offline inválido para visualizar.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualizarPdfScreen.offline(
          pedidoOffline: dados,
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          isAdmin: false,
        ),
      ),
    );
  }

  // ===========================================================
  // 🗑️ CONFIRMAR EXCLUSÃO
  // ===========================================================
  Future<void> _confirmarExcluir(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir pedido offline?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (ok == true) {
      await _remover(p['raw'] as String);
    }
  }

  // ===========================================================
  // 🖥️ UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pedidos Offline'),
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,

      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final itens = snap.data ?? [];
          if (itens.isEmpty) {
            return const Center(child: Text('Nenhum pedido offline salvo.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: itens.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = itens[i];
              final totalStr = (p['total'] as double).toStringAsFixed(2);

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text('${p['cliente_nome']} | R\$ $totalStr'),
                  subtitle: Text(
                    'Tabela: ${p['tabela_nome']} | Condição: ${p['condicao_nome']}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'editar') _editar(p, i);
                      if (v == 'visualizar') _visualizarOffline(p);
                      if (v == 'excluir') _confirmarExcluir(p);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'visualizar', child: Text('Visualizar')),
                      PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
