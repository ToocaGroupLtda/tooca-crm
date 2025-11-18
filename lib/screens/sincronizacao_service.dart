// =============================================================
// 🔄 TOOCA CRM - Sincronização Offline/Online (v7.5 EVA SUPREMO)
// -------------------------------------------------------------
// ✔ Modo Offline Completo (clientes, produtos, tabelas, condições)
// ✔ Cache por empresa (clientes_offline_ID, etc.)
// ✔ Sincronização Silenciosa Automática
// ✔ Envio de pedidos pendentes com merge local
// ✔ Bloqueio SaaS Centralizado (globalNavigatorKey)
// ✔ Carregamento Offline separado para cada entidade
// ✔ 100% compatível com NovoPedidoScreen / PedidosScreen / Splash
// ✔ Código limpo, organizado e sem duplicações
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'TelaBloqueio.dart';

class SincronizacaoService {

  // ============================================================
  // 🛡️ VERIFICAÇÃO LOCAL: Empresa ativa?
  // ============================================================
  static Future<bool> empresaAtivaLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final plano = prefs.getString('plano_empresa') ?? '';
    final expira = prefs.getString('empresa_expira') ?? '';
    final status = prefs.getString('empresa_status') ?? 'ativo';

    if (status != 'ativo') return false;
    if (plano.isEmpty || expira.isEmpty) return false;

    final dt = DateTime.tryParse(expira);
    if (dt == null) return false;

    return dt.isAfter(DateTime.now());
  }

  // ============================================================
// 🛡️ JSON seguro — evita FormatException
// ============================================================
  static dynamic jsonSeguro(String raw) {
    if (raw.isEmpty) return {};
    try {
      return jsonDecode(raw);
    } catch (e) {
      debugPrint("❌ JSON inválido: $e\nRAW: $raw");
      return {};
    }
  }


  // ============================================================
// 🌐 CONSULTA STATUS REAL (SaaS) — VERSÃO BLINDADA
// ============================================================
  static Future<void> consultarStatusEmpresa() async {
    final prefs = await SharedPreferences.getInstance();
    final empresaId = prefs.getInt('empresa_id') ?? 0;

    if (empresaId == 0) return;

    try {
      final res = await http.get(Uri.parse(
          "https://app.toocagroup.com.br/api/status_empresa.php?empresa_id=$empresaId"));

      final data = jsonSeguro(res.body);

      if (data.isEmpty || data['status'] != 'ok') {
        debugPrint("⚠️ Status SaaS vazio ou inválido");
        return;
      }

      await prefs.setString('plano_empresa', data['plano'] ?? 'free');
      await prefs.setString('empresa_expira', data['expira'] ?? '');
      await prefs.setString('empresa_status', data['empresa_status'] ?? 'inativo');

      final exp = DateTime.tryParse(data['expira'] ?? '');
      final agora = DateTime.now();

      if (data['empresa_status'] != 'ativo' ||
          (exp != null && exp.isBefore(agora))) {
        irParaBloqueio(data['plano'] ?? 'free', data['expira'] ?? '');
      }

    } catch (e) {
      debugPrint("❌ Erro ao consultar status SaaS: $e");
    }
  }

  // ============================================================
  // 🚫 BLOQUEIO CENTRALIZADO
  // ============================================================
  static void irParaBloqueio(String plano, String expira) {
    globalNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => TelaBloqueio(
          planoEmpresa: plano,
          empresaExpira: expira,
        ),
      ),
          (_) => false,
    );
  }

  // ============================================================
  // 💾 CARREGAMENTO OFFLINE → CLIENTES
  // ============================================================
  static Future<List<Map<String, dynamic>>> carregarClientesOffline(int empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('clientes_offline_$empresaId');

    if (raw == null) return [];
    final json = jsonDecode(raw);

    if (json is Map && json.containsKey('clientes')) {
      return List<Map<String, dynamic>>.from(json['clientes']);
    }
    if (json is List) {
      return List<Map<String, dynamic>>.from(json);
    }

    return [];
  }

  // ============================================================
  // 💾 CARREGAMENTO OFFLINE → PRODUTOS
  // ============================================================
  static Future<List<Map<String, dynamic>>> carregarProdutosOffline(int empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('produtos_offline_$empresaId');

    if (raw == null) return [];
    final json = jsonDecode(raw);

    if (json is Map && json.containsKey('produtos')) {
      return List<Map<String, dynamic>>.from(json['produtos']);
    }
    if (json is List) {
      return List<Map<String, dynamic>>.from(json);
    }

    return [];
  }

  // ============================================================
  // 💾 CARREGAMENTO OFFLINE → TABELAS DE PREÇO
  // ============================================================
  static Future<List<Map<String, dynamic>>> carregarTabelasOffline(int empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tabelas_offline_$empresaId');

    if (raw == null) return [];
    final json = jsonDecode(raw);

    if (json is Map && json.containsKey('tabelas')) {
      return List<Map<String, dynamic>>.from(json['tabelas']);
    }
    if (json is List) {
      return List<Map<String, dynamic>>.from(json);
    }

    return [];
  }

  // ============================================================
  // 💾 CARREGAMENTO OFFLINE → CONDIÇÕES DE PAGAMENTO
  // ============================================================
  static Future<List<Map<String, dynamic>>> carregarCondicoesOffline(int empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('condicoes_offline_$empresaId');

    if (raw == null) return [];
    final json = jsonDecode(raw);

    if (json is Map && json.containsKey('condicoes')) {
      return List<Map<String, dynamic>>.from(json['condicoes']);
    }
    if (json is List) {
      return List<Map<String, dynamic>>.from(json);
    }

    return [];
  }

  // ============================================================
  // 🔁 SINCRONIZAÇÃO MANUAL COMPLETA
  // ============================================================
  static Future<void> sincronizarTudo(
      BuildContext context, int empresaId) async {

    if (!await empresaAtivaLocal()) {
      final prefs = await SharedPreferences.getInstance();
      irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    await consultarStatusEmpresa();

    if (!await empresaAtivaLocal()) {
      final prefs = await SharedPreferences.getInstance();
      irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getInt('usuario_id') ?? 0;
    final planoUser = prefs.getString('plano_usuario') ?? 'free';

    final endpoints = {
      'clientes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_clientes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',

      'produtos_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_produtos.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',

      'tabelas_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_tabelas.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',

      'condicoes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_condicoes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',
    };

    int ok = 0, falha = 0;

    try {
      for (final entry in endpoints.entries) {
        final res = await http.get(Uri.parse(entry.value));
        if (res.statusCode == 200) {
          await prefs.setString(entry.key, res.body);
          ok++;
        } else {
          falha++;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🔄 Sincronização concluída • OK: $ok • Falhas: $falha"),
          backgroundColor: falha == 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint("❌ Erro sincronização manual: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Erro inesperado."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // 📡 ENVIO DE PEDIDOS PENDENTES
  // ============================================================
  static Future<void> enviarPedidosPendentes(
      BuildContext context, int usuarioId, int empresaId) async {

    if (!await empresaAtivaLocal()) {
      final prefs = await SharedPreferences.getInstance();
      irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    await consultarStatusEmpresa();

    if (!await empresaAtivaLocal()) {
      final prefs = await SharedPreferences.getInstance();
      irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final chave = 'pedidos_pendentes_$empresaId';
    final fila = prefs.getStringList(chave) ?? [];

    if (fila.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📭 Nenhum pedido pendente.')),
      );
      return;
    }

    int enviados = 0, erros = 0;
    final sucesso = <String>[];

    for (final item in fila) {
      try {
        final reg = jsonDecode(item);
        final dados = Map<String, dynamic>.from(reg['dados'] ?? reg);

        final itens = (dados['itens'] as List? ?? []).map((it) {
          return {
            'produto_id': it['produto_id'] ?? '',
            'quantidade': it['qtd'] ?? it['quantidade'] ?? 0,
            'preco_unit': it['preco'] ?? 0,
            'desconto': it['desconto'] ?? 0,
            'nome': it['nome'] ?? '',
            'codigo': it['codigo'] ?? '',
          };
        }).toList();

        final resp = await http.post(
          Uri.parse('https://app.toocagroup.com.br/api/criar_pedido.php'),
          body: {
            'usuario_id': '${dados['usuario_id'] ?? usuarioId}',
            'empresa_id': '$empresaId',
            'cliente_id': '${dados['cliente_id'] ?? ''}',
            'tabela_id': '${dados['tabela_id'] ?? ''}',
            'cond_pagto_id': '${dados['cond_pagto_id'] ?? ''}',
            'observacao': '${dados['observacao'] ?? ''}',
            'desconto_geral': '${dados['desconto_geral'] ?? 0}',
            'total': '${dados['total'] ?? 0}',
            'itens': jsonEncode(itens),
          },
        );

        final data = jsonDecode(resp.body);

        if (data['status'] == 'ok') {
          enviados++;
          sucesso.add(item);
        } else {
          erros++;
        }
      } catch (_) {
        erros++;
      }
    }

    final restante = List<String>.from(fila)..removeWhere(sucesso.contains);
    await prefs.setStringList(chave, restante);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("📡 Enviados: $enviados • Falhas: $erros"),
      ),
    );
  }

  // ============================================================
  // 🔇 SINCRONIZAÇÃO SILENCIOSA
  // ============================================================
  static Future<void> sincronizarSilenciosamente(
      int empresaId, int usuarioId) async {
    if (!await empresaAtivaLocal()) return;

    await consultarStatusEmpresa();

    if (!await empresaAtivaLocal()) return;

    final prefs = await SharedPreferences.getInstance();
    final planoUser = prefs.getString('plano_usuario') ?? 'free';

    final endpoints = {
      'clientes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_clientes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',

      'produtos_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_produtos.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',

      'tabelas_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_tabelas.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',

      'condicoes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_condicoes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',
    };

    try {
      for (final entry in endpoints.entries) {
        final res = await http.get(Uri.parse(entry.value));
        if (res.statusCode == 200) {
          await prefs.setString(entry.key, res.body);
        }
      }
    } catch (_) {}
  }
}
