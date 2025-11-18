// =============================================================
// 🗂️ TOOCA CRM - Pedidos Offline (v8.0 EVA SUPREMO BLOQUEIO)
// -------------------------------------------------------------
// ✔ Bloqueio TOTAL se empresa expirada (Editar/Visualizar/Enviar)
// ✔ Apenas exclusão e listagem continuam funcionando offline
// ✔ Usa fluxo unificado do SaaS (empresaAtivaLocal + consultarStatus)
// ✔ Se expirar → TelaBloqueio imediatamente
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sincronizacao_service.dart';
import 'novo_pedido_screen.dart';
import 'visualizar_pdf_screen.dart';

class PedidosOfflineScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;

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

  @override
  void initState() {
    super.initState();
    _future = _carregarPendentes();
  }

  // ============================================================
  // 🔄 Carrega pedidos offline (por empresa)
  // ============================================================
  Future<List<Map<String, dynamic>>> _carregarPendentes() async {
    final prefs = await SharedPreferences.getInstance();
    final chave = 'pedidos_pendentes_${widget.empresaId}';
    final fila = prefs.getStringList(chave) ?? <String>[];

    return fila.map((s) {
      final reg = jsonDecode(s);
      final bool temTipo = reg is Map && reg.containsKey('tipo');
      final Map<String, dynamic> dados =
      temTipo ? Map<String, dynamic>.from(reg['dados'] ?? {}) : Map<String, dynamic>.from(reg);

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
        'raw': s,
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

  // ============================================================
  // 🔐 BLOQUEIO GLOBAL
  // ============================================================
  Future<bool> _bloqueioSeNecessario() async {
    final ativoLocal = await SincronizacaoService.empresaAtivaLocal();
    if (!ativoLocal) {
      final prefs = await SharedPreferences.getInstance();
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return false;
    }

    await SincronizacaoService.consultarStatusEmpresa();

    final ativoDepois = await SincronizacaoService.empresaAtivaLocal();
    if (!ativoDepois) {
      final prefs = await SharedPreferences.getInstance();
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return false;
    }

    return true;
  }

  // ============================================================
  // 🗑️ Remover pedido local
  // ============================================================
  Future<void> _remover(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = 'pedidos_pendentes_${widget.empresaId}';
    final fila = prefs.getStringList(chave) ?? <String>[];
    fila.remove(rawJson);
    await prefs.setStringList(chave, fila);
    setState(() => _future = _carregarPendentes());
  }

  // ============================================================
  // 📡 SINCRONIZAR (bloqueado se expirada)
  // ============================================================
  Future<void> _sincronizarAgora() async {
    if (!await _bloqueioSeNecessario()) return;

    await SincronizacaoService.enviarPedidosPendentes(
      context,
      widget.usuarioId,
      widget.empresaId,
    );

    setState(() => _future = _carregarPendentes());
  }

  // ============================================================
  // ✏️ Editar (bloqueado se expirada)
  // ============================================================
  void _editar(Map<String, dynamic> pedido, int filaIndex) async {
    if (!await _bloqueioSeNecessario()) return;

    final raw = pedido['dados'];
    Map<String, dynamic> dados = <String, dynamic>{};

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
        const SnackBar(content: Text('Pedido offline inválido.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NovoPedidoScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: 'free',
          pedidoId: null,
          isAdmin: false,
          pedidoRascunho: dados,
          filaIndex: filaIndex,
        ),
      ),
    );
  }

  // ============================================================
  // 👁️ Visualizar (bloqueado se expirada)
  // ============================================================
  void _visualizarOffline(Map<String, dynamic> pedido) async {
    if (!await _bloqueioSeNecessario()) return;

    final raw = pedido['dados'];
    Map<String, dynamic> dados = <String, dynamic>{};

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
        const SnackBar(content: Text('Pedido offline inválido.')),
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
          plano: 'free',
          isAdmin: false,
        ),
      ),
    );
  }

  // ============================================================
  // 🖥️ UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pedidos Offline'),
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: 'Sincronizar agora',
            onPressed: _sincronizarAgora,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final itens = snap.data ?? [];
          if (itens.isEmpty) {
            return const Center(child: Text("Nenhum pedido offline salvo."));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: itens.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = itens[i];
              final totalStr = p['total'].toStringAsFixed(2);

              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text('${p['cliente_nome']} | Total: R\$ $totalStr'),
                  subtitle: Text(
                    'Tabela: ${p['tabela_nome']} | Condição: ${p['condicao_nome']}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      switch (v) {
                        case 'editar':
                          _editar(p, i);
                          break;
                        case 'visualizar':
                          _visualizarOffline(p);
                          break;
                        case 'excluir':
                          _confirmarExcluir(p);
                          break;
                      }
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

  // ============================================================
  // ❌ Confirmar exclusão
  // ============================================================
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
}
