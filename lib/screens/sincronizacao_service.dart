// =============================================================
// 🔄 TOOCA CRM - Sincronização (v8.2 EVA GOLD SUPREMO)
// -------------------------------------------------------------
// ✔ Somente LOGIN e SINCRONIZAR podem bloquear
// ✔ Home, Pedidos, Clientes, Produtos → NUNCA bloqueiam
// ✔ sincronizarSilenciosamente → nunca bloqueia
// ✔ consultarStatusEmpresa → nunca bloqueia
// ✔ empresaAtivaLocal → não bloqueia datas vazias
// ✔ enviarPedidosPendentes incluído
// ✔ carregarCondicoesOffline + salvarCondicoesOffline
// ✔ leitura REAL das listas (JSON do servidor)
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'TelaBloqueio.dart';

class SincronizacaoService {

  // ============================================================
  // 🛡 EMPRESA ATIVA (LOCAL) — NÃO BLOQUEIA DATAS VAZIAS
  // ============================================================
  static Future<bool> empresaAtivaLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final status = prefs.getString('empresa_status') ?? 'ativo';
    final expira = prefs.getString('empresa_expira') ?? '';

    if (status != 'ativo') return false;
    if (expira.isEmpty) return true;

    final dt = DateTime.tryParse(expira);
    if (dt == null) return true;

    return dt.isAfter(DateTime.now());
  }

  // ============================================================
  // 🛡 JSON SEGURO
  // ============================================================
  static dynamic jsonSeguro(String raw) {
    if (raw.isEmpty) return {};
    try { return jsonDecode(raw); }
    catch (_) { return {}; }
  }

  // ============================================================
  // 🌐 CONSULTA STATUS REAL — NUNCA BLOQUEIA
  // ============================================================
  static Future<bool> consultarStatusEmpresa() async {
    final prefs = await SharedPreferences.getInstance();
    final empresaId = prefs.getInt('empresa_id') ?? 0;

    if (empresaId == 0) return true;

    try {
      final r = await http.get(Uri.parse(
          "https://app.toocagroup.com.br/api/status_empresa.php?empresa_id=$empresaId"
      ));

      final data = jsonSeguro(r.body);

      if (data.isEmpty || data['status'] != 'ok') return true;

      await prefs.setString('plano_empresa', data['plano'] ?? 'free');
      await prefs.setString('empresa_expira', data['expira'] ?? '');
      await prefs.setString('empresa_status', data['empresa_status'] ?? 'ativo');

      final exp = DateTime.tryParse(data['expira'] ?? '');
      if (exp == null) return true;

      return data['empresa_status'] == 'ativo' && exp.isAfter(DateTime.now());

    } catch (_) {
      return true;
    }
  }

  // ============================================================
  // 🚫 BLOQUEIO — usado SOMENTE se você chamar
  // ============================================================
  static void irParaBloqueio({required String plano, required String expira}) {
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
  // 🔁 SINCRONIZAÇÃO MANUAL (ÚNICA QUE BLOQUEIA)
  // ============================================================
  static Future<void> sincronizarTudo(BuildContext context, int empresaId) async {
    final prefs = await SharedPreferences.getInstance();

    if (!await empresaAtivaLocal()) {
      return irParaBloqueio(
        plano: prefs.getString('plano_empresa') ?? 'free',
        expira: prefs.getString('empresa_expira') ?? '',
      );
    }

    final ativa = await consultarStatusEmpresa();
    if (!ativa) {
      return irParaBloqueio(
        plano: prefs.getString('plano_empresa') ?? 'free',
        expira: prefs.getString('empresa_expira') ?? '',
      );
    }

    final usuario = prefs.getInt('usuario_id') ?? 0;
    final planoUser = prefs.getString('plano_usuario') ?? 'free';

    final endpoints = {
      'clientes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_clientes.php?empresa_id=$empresaId&usuario_id=$usuario&plano=$planoUser',

      'produtos_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_produtos.php?empresa_id=$empresaId&usuario_id=$usuario&plano=$planoUser',

      'tabelas_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_tabelas.php?empresa_id=$empresaId&usuario_id=$usuario&plano=$planoUser',

      'condicoes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_condicoes.php?empresa_id=$empresaId&usuario_id=$usuario&plano=$planoUser',
    };

    int ok = 0, falha = 0;

    for (final e in endpoints.entries) {
      try {
        final r = await http.get(Uri.parse(e.value));
        if (r.statusCode == 200) {
          await prefs.setString(e.key, r.body);
          ok++;
        } else {
          falha++;
        }
      } catch (_) {
        falha++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🔄 OK: $ok • Falhas: $falha"),
        backgroundColor: falha == 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  // ============================================================
  // 🔇 SINCRONIZAÇÃO SILENCIOSA — NUNCA BLOQUEIA
  // ============================================================
  static Future<void> sincronizarSilenciosamente(
      int empresaId,
      int usuarioId,
      ) async {

    await consultarStatusEmpresa();

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

    for (final e in endpoints.entries) {
      try {
        final r = await http.get(Uri.parse(e.value));
        if (r.statusCode == 200) {
          await prefs.setString(e.key, r.body);
        }
      } catch (_) {}
    }
  }


  // ============================================================
  // 💾 CARREGADORES OFFLINE
  // ============================================================

  static Future<List<Map<String, dynamic>>> carregarClientesOffline(int empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('clientes_offline_$empresaId') ?? '';

    if (raw.isEmpty) return [];

    final data = jsonSeguro(raw);
    return List<Map<String, dynamic>>.from(data['clientes'] ?? data);
  }

  static Future<List<Map<String, dynamic>>> carregarProdutosOffline(int empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('produtos_offline_$empresaId') ?? '';

    if (raw.isEmpty) return [];

    final data = jsonSeguro(raw);
    return List<Map<String, dynamic>>.from(data['produtos'] ?? data);
  }

  static Future<List<Map<String, dynamic>>> carregarTabelasOffline(int empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tabelas_offline_$empresaId') ?? '';

    if (raw.isEmpty) return [];

    final data = jsonSeguro(raw);
    return List<Map<String, dynamic>>.from(data['tabelas'] ?? data);
  }

  // ============================================================
  // 💾 CONDIÇÕES — FALTAVA AQUI! (CORRIGIDO)
  // ============================================================

  static Future<List<Map<String, dynamic>>> carregarCondicoesOffline(int empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('condicoes_offline_$empresaId') ?? '';

    if (raw.isEmpty) return [];

    final data = jsonSeguro(raw);

    return List<Map<String, dynamic>>.from(data['condicoes'] ?? data);
  }

  static Future<void> salvarCondicoesOffline(int empresaId, List condicoes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('condicoes_offline_$empresaId', jsonEncode({'condicoes': condicoes}));
  }


  // ============================================================
  // 📤 ENVIAR PEDIDOS PENDENTES — NUNCA BLOQUEIA
  // ============================================================
  static Future<void> enviarPedidosPendentes(
      BuildContext context,
      int usuarioId,
      int empresaId,
      ) async {

    final prefs = await SharedPreferences.getInstance();
    final chave = 'pedidos_pendentes_$empresaId';

    final fila = prefs.getStringList(chave) ?? <String>[];

    if (fila.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum pedido offline para enviar.')),
      );
      return;
    }

    int enviados = 0;
    int erros = 0;

    for (String raw in fila.toList()) {
      try {
        final dados = jsonDecode(raw);

        final resp = await http.post(
          Uri.parse("https://app.toocagroup.com.br/api/criar_pedido.php"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "usuario_id": usuarioId,
            "empresa_id": empresaId,
            "pedido": dados,
          }),
        );

        final json = jsonDecode(resp.body);

        if (json["status"] == "ok") {
          fila.remove(raw);
          enviados++;
        } else {
          erros++;
        }
      } catch (_) {
        erros++;
      }
    }

    await prefs.setStringList(chave, fila);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("📤 Enviados: $enviados • ❌ Erros: $erros"),
        backgroundColor: enviados > 0 && erros == 0 ? Colors.green : Colors.orange,
      ),
    );
  }
}
