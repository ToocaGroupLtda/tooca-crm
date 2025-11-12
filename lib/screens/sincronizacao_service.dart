// =============================================================
// 🔄 TOOCA CRM - Sincronização de Dados Offline (v4.4 SaaS Final)
// -------------------------------------------------------------
// - Compatível com modo offline, multiempresa e multiusuário
// - Sincroniza cache e envia pedidos pendentes de forma segura
// - Endpoint atualizado para criar_pedido.php
// =============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SincronizacaoService {
  // ============================================================
  // 🔁 SINCRONIZAÇÃO COMPLETA
  // ============================================================
  static Future<void> sincronizarTudo(
      BuildContext context,
      int empresaId,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final plano = prefs.getString('plano') ?? 'free';
    final usuarioId = prefs.getInt('usuario_id') ?? 0;

    int sucesso = 0;
    int falhas = 0;

    final endpoints = {
      'clientes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_clientes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$plano',
      'produtos_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_produtos.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$plano',
      'tabelas_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_tabelas.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$plano',
      'condicoes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_condicoes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$plano',
    };

    try {
      for (final entry in endpoints.entries) {
        final res = await http.get(Uri.parse(entry.value));
        if (res.statusCode == 200) {
          await prefs.setString(entry.key, res.body);
          sucesso++;
          debugPrint('✅ ${entry.key} sincronizado.');
        } else {
          falhas++;
          debugPrint('⚠️ ${entry.key} falhou (${res.statusCode}).');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔄 Sincronização concluída. OK: $sucesso | Falhas: $falhas'),
          backgroundColor: falhas == 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('❌ Erro ao sincronizar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erro inesperado na sincronização.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // 🚀 ENVIO DE PEDIDOS PENDENTES (modo offline)
  // ============================================================
  static Future<void> enviarPedidosPendentes(
      BuildContext context,
      int usuarioId,
      int empresaId,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final plano = prefs.getString('plano') ?? 'free';
    final chave = 'pedidos_pendentes_$empresaId';
    final fila = prefs.getStringList(chave) ?? <String>[];

    if (fila.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Nenhum pedido pendente para enviar.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    int enviados = 0;
    int erros = 0;
    final enviadosComSucesso = <String>[];

    for (final itemJson in fila) {
      try {
        final reg = jsonDecode(itemJson);
        String tipo = 'novo';
        int? pedidoIdUpdate;
        Map<String, dynamic> dados;

        if (reg is Map && reg.containsKey('tipo')) {
          tipo = (reg['tipo'] ?? 'novo').toString();
          pedidoIdUpdate = (reg['pedido_id'] is num)
              ? (reg['pedido_id'] as num).toInt()
              : int.tryParse('${reg['pedido_id']}');
          dados = Map<String, dynamic>.from(reg['dados'] ?? {});
        } else {
          dados = Map<String, dynamic>.from(reg as Map);
        }

        // 🔧 Monta os itens
        final itensList = (dados['itens'] as List<dynamic>? ?? []);
        final itensJson = itensList.map((it) => {
          'produto_id': it['produto_id'] ?? '',
          'quantidade': it['qtd'] ?? it['quantidade'] ?? 0,
          'preco_unit': it['preco'] ?? 0,
          'desconto': it['desconto'] ?? 0,
          'nome': it['nome'] ?? '',
          'codigo': it['codigo'] ?? '',
        }).toList();

        // 💼 Corpo principal
        final body = {
          'usuario_id': '${dados['usuario_id'] ?? usuarioId}',
          'empresa_id': '$empresaId',
          'plano': plano,
          'cliente_id': '${dados['cliente_id'] ?? ''}',
          'tabela_id': '${dados['tabela_id'] ?? 0}',
          'cond_pagto_id': '${dados['cond_pagto_id'] ?? ''}',
          'observacao': '${dados['observacao'] ?? ''}',
          'desconto_geral': '${dados['desconto_geral'] ?? 0}',
          'total': '${dados['total'] ?? 0}',
          'itens': jsonEncode(itensJson),
        };

        if (tipo == 'update' && pedidoIdUpdate != null) {
          body['pedido_id'] = '$pedidoIdUpdate';
        }

        // 🧩 Novo endpoint padronizado
        final resp = await http.post(
          Uri.parse('https://app.toocagroup.com.br/api/criar_pedido.php'),
          body: body,
        );

        final data = jsonDecode(resp.body);
        if (data['status'] == 'ok') {
          enviadosComSucesso.add(itemJson);
          enviados++;
          debugPrint('✅ Pedido sincronizado: ${data['pedido_id']}');
        } else {
          erros++;
          debugPrint('⚠️ Erro: ${data['mensagem'] ?? resp.body}');
        }
      } on SocketException {
        erros++;
        debugPrint('📴 Sem conexão ao enviar pedido.');
      } catch (e) {
        erros++;
        debugPrint('❌ Erro geral: $e');
      }
    }

    // 🧹 Remove enviados com sucesso
    final restante = List<String>.from(fila)
      ..removeWhere(enviadosComSucesso.contains);
    await prefs.setStringList(chave, restante);

    // 📢 Feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📡 Enviados: $enviados | Falhas: $erros'),
        backgroundColor: erros == 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  // ============================================================
  // 🧠 Carregadores de dados offline (multiempresa)
  // ============================================================
  static Future<List<dynamic>> carregarClientesOffline(int empresaId) =>
      _carregarListaOfflineFlex('clientes_offline_$empresaId', ['clientes', 'dados', 'lista_clientes']);

  static Future<List<dynamic>> carregarProdutosOffline(int empresaId) =>
      _carregarListaOfflineFlex('produtos_offline_$empresaId', ['produtos', 'lista_produtos', 'dados']);

  static Future<List<dynamic>> carregarTabelasOffline(int empresaId) =>
      _carregarListaOfflineFlex('tabelas_offline_$empresaId', ['tabelas', 'tabelas_preco', 'dados']);

  static Future<List<dynamic>> carregarCondicoesOffline(int empresaId) =>
      _carregarListaOfflineFlex('condicoes_offline_$empresaId', ['condicoes', 'condicoes_pagamento', 'formas_pagto', 'dados']);

  // ============================================================
  // 🔍 Leitura flexível de JSON offline
  // ============================================================
  static Future<List<dynamic>> _carregarListaOfflineFlex(
      String chave,
      List<String> possiveisCampos,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(chave);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final data = jsonDecode(jsonString);
      if (data is List) return data;

      for (final campo in possiveisCampos) {
        if (data[campo] is List) return List.from(data[campo]);
      }

      for (var key in data.keys) {
        if (data[key] is List) return List.from(data[key]);
      }
    } catch (e) {
      debugPrint('❌ Erro ao ler $chave: $e');
    }
    return [];
  }

  // ============================================================
// 🕶️ SINCRONIZAÇÃO SILENCIOSA (automática, chamada pela Splash)
// ============================================================
  static Future<void> sincronizarSilenciosamente(int empresaId, int usuarioId) async {
    final prefs = await SharedPreferences.getInstance();
    final plano = prefs.getString('plano') ?? 'free';

    final endpoints = {
      'clientes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_clientes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$plano',
      'produtos_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_produtos.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$plano',
      'tabelas_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_tabelas.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$plano',
      'condicoes_offline_$empresaId':
      'https://app.toocagroup.com.br/api/listar_condicoes.php?empresa_id=$empresaId&usuario_id=$usuarioId&plano=$plano',
    };

    try {
      for (final entry in endpoints.entries) {
        final res = await http.get(Uri.parse(entry.value));
        if (res.statusCode == 200) {
          await prefs.setString(entry.key, res.body);
          debugPrint('🤫 Cache atualizado: ${entry.key}');
        }
      }
    } catch (e) {
      debugPrint('❌ Sincronização silenciosa falhou: $e');
    }
  }

}
