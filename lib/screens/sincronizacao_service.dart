// =============================================================
// 🔄 TOOCA CRM - Sincronização (v8.9 EVA GOLD FIXED)
// -------------------------------------------------------------
// ✔ Sincronização Multiempresa (Isolamento por ID)
// ✔ Processamento de Pedidos (Novo/Update)
// ✔ Processamento de Clientes (Novo/Update/Delete)
// ✔ Gestão de Status e Bloqueio de Empresa (IMEDIATO)
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
  static Future<bool> consultarStatusEmpresa(int empresaId) async {
    final prefs = await SharedPreferences.getInstance();
    if (empresaId == 0) return true;

    try {
      final r = await http.get(Uri.parse(
          "https://toocagroup.com.br/api/status_empresa.php?empresa_id=$empresaId"
      )).timeout(const Duration(seconds: 8));

      final data = jsonSeguro(r.body);

      // 🛡️ A REGRA DE OURO: Se não for "ok", bloqueia tudo.
      if (data.isEmpty || data['status'] != 'ok') {

        // Atualiza os dados locais com o que veio da API antes de bloquear
        if (data['plano'] != null) {
          await prefs.setString('plano_empresa', data['plano'].toString());
        }
        await prefs.setString('empresa_expira', data['expira'] ?? 'Vencido');
        await prefs.setString('empresa_status', 'bloqueado');

        // Chama a tela de bloqueio IMEDIATAMENTE
        irParaBloqueio(
          plano: data['plano'] ?? 'bloqueado',
          expira: data['expira'] ?? 'Expirado',
        );
        return false;
      }

      // ✅ Se chegou aqui, o status é "ok"
      await prefs.setInt('empresa_id', empresaId);
      if (data['plano'] != null && data['plano'].toString().isNotEmpty) {
        await prefs.setString('plano_empresa', data['plano'].toString());
      }
      await prefs.setString('empresa_expira', data['expira'] ?? '');
      await prefs.setString('empresa_status', 'ativo');

      final exp = DateTime.tryParse(data['expira'] ?? '');
      if (exp == null) return true;

      // Verificação extra de data no lado do Flutter
      if (exp.isBefore(DateTime.now())) {
        irParaBloqueio(plano: data['plano'], expira: data['expira']);
        return false;
      }

      return true;
    } catch (e) {
      debugPrint("⚠️ Erro ao consultar API: $e");
      return await empresaAtivaLocal();
    }
  }
  // ============================================================
  // 🚫 BLOQUEIO MANUAL
  // ============================================================
  static void irParaBloqueio({required String plano, required String expira}) {
    globalNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            TelaBloqueio(
              planoEmpresa: plano,
              empresaExpira: expira,
            ),
      ),
          (_) => false,
    );
  }

  // ============================================================
  // 🔁 SINCRONIZAÇÃO MANUAL (SEM RESET!)
  // ============================================================
  static Future<void> sincronizarTudo(BuildContext context,
      int empresaId) async {
    final prefs = await SharedPreferences.getInstance();

    // 🛡️ BLOQUEIO IMEDIATO: Verifica local e servidor antes de prosseguir
    if (!await empresaAtivaLocal() || !await consultarStatusEmpresa(empresaId)) {
      return irParaBloqueio(
        plano: prefs.getString('plano_empresa') ?? 'free',
        expira: prefs.getString('empresa_expira') ?? '',
      );
    }

    final usuario = prefs.getInt('usuario_id') ?? 0;
    final planoUser = prefs.getString('plano_usuario') ?? 'free';

    final endpoints = {
      'clientes_offline_$empresaId':
      'https://toocagroup.com.br/api/listar_clientes.php?empresa_id=$empresaId&usuario_id=$usuario&plano=$planoUser',

      'produtos_offline_$empresaId':
      'https://toocagroup.com.br/api/listar_produtos.php?empresa_id=$empresaId&usuario_id=$usuario&plano=$planoUser',

      'tabelas_offline_$empresaId':
      'https://toocagroup.com.br/api/listar_tabelas.php?empresa_id=$empresaId&usuario_id=$usuario&plano=$planoUser',

      'condicoes_offline_$empresaId':
      'https://toocagroup.com.br/api/listar_condicoes.php?empresa_id=$empresaId&usuario_id=$usuario&plano=$planoUser',
    };

    int ok = 0,
        falha = 0;

    for (final e in endpoints.entries) {
      try {
        final r = await http.get(Uri.parse(e.value));
        if (r.statusCode == 200) {
          await prefs.setString(e.key, r.body);

          if (e.key.startsWith('clientes_offline_')) {
            try {
              final data = jsonDecode(r.body);
              final List lista = data['clientes'] ?? [];
              final List mini = lista.map((c) =>
              {
                'i': c['id'],
                'n': c['nome'],
                'd': (c['cnpj'] ?? c['cpf'] ?? '')
                    .toString()
                    .replaceAll(RegExp(r'\D'), ''),
              }).toList();

              await prefs.setString(
                  'clientes_min_$empresaId', jsonEncode(mini));
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
  // 🔇 SINCRONIZAÇÃO SILENCIOSA (SEM RESET!)
  // ============================================================
  static Future<void> sincronizarSilenciosamente(int empresaId,
      int usuarioId,) async {
    // 🛡️ Se consultarStatus retornar false, interrompe o background
    if (!await consultarStatusEmpresa(empresaId)) return;

    final prefs = await SharedPreferences.getInstance();
    final planoUser = prefs.getString('plano_usuario') ?? 'free';

    final endpoints = {
      'clientes_offline_$empresaId':
      'https://toocagroup.com.br/api/listar_clientes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',

      'produtos_offline_$empresaId':
      'https://toocagroup.com.br/api/listar_produtos.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',

      'tabelas_offline_$empresaId':
      'https://toocagroup.com.br/api/listar_tabelas.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',

      'condicoes_offline_$empresaId':
      'https://toocagroup.com.br/api/listar_condicoes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$planoUser',
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
  // LOADERS OFFLINE
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

  static Future<List<Map<String, dynamic>>> carregarClientesOffline(
      int empresaId) async {
    final raw = (await SharedPreferences.getInstance())
        .getString('clientes_offline_$empresaId') ?? '';
    if (raw.isEmpty) return [];
    return _resolverLista(jsonSeguro(raw), 'clientes');
  }

  static Future<List<Map<String, dynamic>>> carregarProdutosOffline(
      int empresaId) async {
    final raw = (await SharedPreferences.getInstance())
        .getString('produtos_offline_$empresaId') ?? '';
    if (raw.isEmpty) return [];
    return _resolverLista(jsonSeguro(raw), 'produtos');
  }

  static Future<List<Map<String, dynamic>>> carregarTabelasOffline(
      int empresaId) async {
    final raw = (await SharedPreferences.getInstance())
        .getString('tabelas_offline_$empresaId') ?? '';
    if (raw.isEmpty) return [];
    return _resolverLista(jsonSeguro(raw), 'tabelas');
  }

  static Future<List<Map<String, dynamic>>> carregarCondicoesOffline(
      int empresaId) async {
    final raw = (await SharedPreferences.getInstance())
        .getString('condicoes_offline_$empresaId') ?? '';
    if (raw.isEmpty) return [];
    return _resolverLista(jsonSeguro(raw), 'condicoes');
  }

  static Future<void> enviarPedidosPendentes(
      BuildContext context,
      int usuarioId,
      int empresaId,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = 'pedidos_pendentes_$empresaId';
    final fila = prefs.getStringList(chave) ?? <String>[];

    int enviados = 0;
    int erros = 0;

    final filaAtualizada = List<String>.from(fila);

    for (final raw in fila) {
      try {
        final registro = jsonDecode(raw);

        final String tipo = registro['tipo'] ?? 'novo';
        final Map<String, dynamic> dados =
        Map<String, dynamic>.from(registro['dados'] ?? {});

        // 🔒 Blindagem obrigatória
        dados['usuario_id'] ??= usuarioId;
        dados['empresa_id'] ??= empresaId;

        // 🔥 UPDATE = TEM QUE TER pedido_id
        if (tipo == 'update') {
          final pid = registro['pedido_id'] ?? dados['pedido_id'];

          if (pid != null && pid > 0) {
            dados['pedido_id'] = pid;
          } else {
            debugPrint('❌ Update sem pedido_id — bloqueado');
            erros++;
            continue; // 🚫 NÃO ENVIA
          }
        }

        final res = await http.post(
          Uri.parse('https://toocagroup.com.br/api/criar_pedido.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(dados),
        );

        final resp = jsonSeguro(res.body);

        if (res.statusCode == 200 && resp['status'] == 'ok') {
          enviados++;
          filaAtualizada.remove(raw); // ✅ remove da fila
        } else {
          erros++;
        }
      } catch (e) {
        erros++;
      }
    }

    await prefs.setStringList(chave, filaAtualizada);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sincronização: $enviados enviados, $erros erros'),
        ),
      );
    }
  }


}