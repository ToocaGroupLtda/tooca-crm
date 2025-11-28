// =============================================================
// 🔄 TOOCA CRM - Sincronização (v8.3 EVA GOLD SUPREMO FINAL)
// -------------------------------------------------------------
// ✔ Todos os loaders OFFLINE corrigidos (clientes/produtos/tabelas/condições)
// ✔ Suporta TODOS os formatos JSON da API ou local
// ✔ Nunca bloqueia Home/Pedidos/Produtos/Clientes
// ✔ Sincronização silenciosa atualizada
// ✔ Envio de pedidos pendentes 100% compatível com NovoPedidoScreen
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import 'TelaBloqueio.dart';

class SincronizacaoService {

  // ============================================================
  // 🛡 EMPRESA ATIVA (LOCAL)
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
    try {
      return jsonDecode(raw);
    } catch (_) {
      return {};
    }
  }

  // ============================================================
  // 🌐 CONSULTA STATUS REAL
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
  // 🚫 BLOQUEIO MANUAL
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
  // 🔁 SINCRONIZAÇÃO MANUAL
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

          // mini índice clientes
          if (e.key.startsWith('clientes_offline_')) {
            try {
              final data = jsonDecode(r.body);
              final List lista = data['clientes'] ?? [];
              final List mini = lista.map((c) => {
                'i': c['id'],
                'n': c['nome'],
                'd': (c['cnpj'] ?? c['cpf'] ?? '')
                    .toString()
                    .replaceAll(RegExp(r'\D'), ''),
              }).toList();

              await prefs.setString('clientes_min_$empresaId', jsonEncode(mini));
            } catch (_) {}
          }

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
  // 🔇 SINCRONIZAÇÃO SILENCIOSA
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
  // 💾 CARREGADORES OFFLINE 100% COMPATÍVEIS
  // ============================================================

  static List<Map<String, dynamic>> _resolverLista(dynamic data, String chave) {
    if (data is Map && data.containsKey(chave)) {
      return List<Map<String, dynamic>>.from(data[chave]);
    }
    if (data is Map && data.values.isNotEmpty && data.values.first is List) {
      return List<Map<String, dynamic>>.from(data.values.first);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> carregarClientesOffline(int empresaId) async {
    final raw = (await SharedPreferences.getInstance())
        .getString('clientes_offline_$empresaId') ?? '';
    if (raw.isEmpty) return [];
    return _resolverLista(jsonSeguro(raw), 'clientes');
  }

  static Future<List<Map<String, dynamic>>> carregarProdutosOffline(int empresaId) async {
    final raw = (await SharedPreferences.getInstance())
        .getString('produtos_offline_$empresaId') ?? '';
    if (raw.isEmpty) return [];
    return _resolverLista(jsonSeguro(raw), 'produtos');
  }

  static Future<List<Map<String, dynamic>>> carregarTabelasOffline(int empresaId) async {
    final raw = (await SharedPreferences.getInstance())
        .getString('tabelas_offline_$empresaId') ?? '';
    if (raw.isEmpty) return [];
    return _resolverLista(jsonSeguro(raw), 'tabelas');
  }

  static Future<List<Map<String, dynamic>>> carregarCondicoesOffline(int empresaId) async {
    final raw = (await SharedPreferences.getInstance())
        .getString('condicoes_offline_$empresaId') ?? '';
    if (raw.isEmpty) return [];
    return _resolverLista(jsonSeguro(raw), 'condicoes');
  }

  // ============================================================
  // 📤 ENVIAR PEDIDOS PENDENTES — AJUSTADO
  // ============================================================
  static Future<void> enviarPedidosPendentes(
      BuildContext context,
      int usuarioId,
      int empresaId,
      ) async {

    final prefs = await SharedPreferences.getInstance();
    final chave = 'pedidos_pendentes';       // 🔥 CORRIGIDO AQUI!

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
