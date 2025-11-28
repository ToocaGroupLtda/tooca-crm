// =============================================================
// 🚀 TOOCA CRM - Novo Pedido Screen (v4.1 SaaS)
// -------------------------------------------------------------
// Compatível com modo offline, multiempresa e sincronização local
// =============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// 💡 IMPORTS INTERNOS (sempre use o nome do pacote do pubspec.yaml)
import 'package:app_tooca_crm/screens/sincronizacao_service.dart';
import 'package:app_tooca_crm/screens/clientes_screen.dart';
import 'package:app_tooca_crm/screens/produtos_screen.dart';
import 'package:app_tooca_crm/screens/home_screen.dart';

class NovoPedidoScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;       // ✅ novo campo
  final String plano;        // ✅ novo campo (ex: 'free' ou 'pro')
  final int? pedidoId;
  final bool isAdmin;
  final Map<String, dynamic>? pedidoRascunho;
  final int? filaIndex;
  final Map<String, dynamic>? pedidoJson; // ✅ adiciona esse campo


  const NovoPedidoScreen({
    Key? key,
    required this.usuarioId,
    required this.empresaId,
    required this.plano,
    this.pedidoId,
    this.isAdmin = false,
    this.pedidoRascunho,
    this.filaIndex,
    this.pedidoJson, // ✅ adiciona aqui
  }) : super(key: key);
  @override
  _NovoPedidoScreenState createState() => _NovoPedidoScreenState();
}

class _NovoPedidoScreenState extends State<NovoPedidoScreen> {
  String? _tabelaSelecionada;

  bool _isOnline = true;
  late final bool _isEditingExisting;
  StreamSubscription<ConnectivityResult>? _connSub;

  List<dynamic> clientes = [];
  /// 🔥 Índice acelerado de clientes (id → texto indexado)
  Map<int, String> clientesIndexados = {};

  List<dynamic> tabelas = [];
  List<dynamic> condicoes = [];
  List<dynamic> produtos = [];
  List<Map<String, dynamic>> itens = [];

  int? clienteId;
  int? tabelaId;
  int? condicaoId;
  double descontoGeral = 0;
  bool carregando = true;
  bool enviando = false;

  final obsCtrl = TextEditingController();
  final buscaCtrl = TextEditingController();
  final clienteBuscaCtrl = TextEditingController();
  List<dynamic> sugestoesClientes = [];

  // --------- Helpers de busca ----------
  String _onlyDigits(String? s) => (s ?? '').replaceAll(RegExp(r'\D'), '');

  String _stripAccents(String s) {
    const withAccents = 'áàâãäÁÀÂÃÄéèêëÉÈÊËíìîïÍÌÎÏóòôõöÓÒÔÕÖúùûüÚÙÛÜçÇ';
    const without     = 'aaaaaAAAAAeeeeEEEEiiiiIIIIoooooOOOOOuuuuUUUUcC';
    var out = s;
    for (var i = 0; i < withAccents.length; i++) {
      out = out.replaceAll(withAccents[i], without[i]);
    }
    return out;
  }

  String _norm(String? s) {
    if (s == null) return '';
    return _stripAccents(s.toLowerCase().trim());
  }

  String _buildIndex(Map c) {
    final fantasia = '${c['fantasia'] ?? ''}';
    final razao    = '${c['razao'] ?? c['razao_social'] ?? ''}';
    final nome     = '${c['nome'] ?? ''}';
    final doc1     = _onlyDigits('${c['cnpj'] ?? ''}');
    final doc2     = _onlyDigits('${c['cpf'] ?? ''}');
    final doc3     = _onlyDigits('${c['cnpj_cpf'] ?? c['documento'] ?? c['doc'] ?? ''}');
    return [
      _norm(fantasia),
      _norm(razao),
      _norm(nome),
      doc1, doc2, doc3
    ].where((e) => e.isNotEmpty).join(' ');
  }
  // -------------------------------------

  String get chaveRascunho => 'rascunho_novo_pedido_${widget.usuarioId}';

  bool get houveAlteracao {
    return itens.isNotEmpty ||
        clienteId != null ||
        tabelaId != null ||
        condicaoId != null ||
        obsCtrl.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();

    _isEditingExisting = (widget.pedidoId != null);

    _connSub = Connectivity().onConnectivityChanged.listen((result) {
      final online = (result != ConnectivityResult.none);
      if (mounted && online != _isOnline) {
        setState(() => _isOnline = online);
      }
    });

    Connectivity().checkConnectivity().then((result) {
      final online = (result != ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = online);
    });


    carregarDadosOffline();
  }

  Future<void> _limparRascunhoSeInvalido() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(chaveRascunho);
    if (raw == null) return;

    try {
      final dados = jsonDecode(raw);

      // Se veio rascunho com pedido_id → rascunho antigo → limpa
      if (dados['pedido_id'] != null) {
        await prefs.remove(chaveRascunho);
        return;
      }

      // Se existirem itens sem produto_id → lixo → limpa
      if (dados['itens'] is List &&
          dados['itens'].any((i) => i['produto_id'] == null)) {
        await prefs.remove(chaveRascunho);
        return;
      }
    } catch (_) {
      await prefs.remove(chaveRascunho);
    }
  }


  @override
  void dispose() {
    _connSub?.cancel();
    obsCtrl.dispose();
    buscaCtrl.dispose();
    clienteBuscaCtrl.dispose();
    super.dispose();
  }

  Future<void> carregarDadosOffline() async {
    setState(() => carregando = true);
// 🔥 LIMPA RASCUNHO ANTIGO QUE CAUSA DUPLICAÇÃO DE ITENS
    await _limparRascunhoSeInvalido();

    clientes = await SincronizacaoService.carregarClientesOffline(widget.empresaId);
// 🔥 PRÉ-INDEXAÇÃO — acelera a busca em até 95%
    clientesIndexados = {};
    for (var c in clientes) {
      final id = int.tryParse('${c['id']}') ?? 0;
      clientesIndexados[id] = _buildIndex(c);
    }


    tabelas  = await SincronizacaoService.carregarTabelasOffline(widget.empresaId);
    // 🔍 Filtra para mostrar apenas as tabelas reais do sistema
    tabelas = tabelas.where((t) {
      final nome = (t['nome'] ?? '').toString().toLowerCase();
      return !(nome.contains('pdf') || nome.contains('excel'));
    }).toList();




    condicoes = await SincronizacaoService.carregarCondicoesOffline(widget.empresaId);

    if (condicoes.isEmpty && _isOnline) {
      try {
        final url = Uri.parse(
            'https://app.toocagroup.com.br/api/listar_condicoes.php?empresa_id=${widget.empresaId}&usuario_id=${widget.usuarioId}&plano=${widget.plano}'
        );
        final res = await http.get(url);
        final data = jsonDecode(res.body);
        if (data['status'] == 'ok') {
          condicoes = List<Map<String, dynamic>>.from(data['condicoes']);
          debugPrint('🌐 Condições carregadas da API (${condicoes.length})');
        }
      } catch (e) {
        debugPrint('❌ Erro ao buscar condições online: $e');
      }
    }
    produtos = await SincronizacaoService.carregarProdutosOffline(widget.empresaId);

    debugPrint('📊 Clientes: ${clientes.length}');
    debugPrint('📊 Tabelas: ${tabelas.length}');
    debugPrint('📊 Condições: ${condicoes.length}');
    debugPrint('📊 Produtos: ${produtos.length}');


    produtos = produtos.map((p) {
      p['nome'] ??= '';
      p['codigo'] ??= '';
      return p;
    }).toList();

    // --- Verifica se há dados mínimos, mas NÃO bloqueia mais ---
    if (clientes.isEmpty || tabelas.isEmpty || condicoes.isEmpty || produtos.isEmpty) {
      debugPrint(
          '⚠️ Dados incompletos, liberando tela: '
              'clientes=${clientes.length}, '
              'tabelas=${tabelas.length}, '
              'condicoes=${condicoes.length}, '
              'produtos=${produtos.length}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Dados incompletos. Você ainda pode criar o pedido.'),
          backgroundColor: Colors.orange,
        ),
      );
      // ❌ Não retorna mais — tela liberada
    }


// --- Garante uma condição padrão se vier vazio ---
    if (condicoes.isEmpty) {
      condicoes = [
        {'id': 1, 'nome': 'À vista', 'dias': 0}
      ];
      debugPrint('⚠️ Nenhuma condição encontrada — adicionando "À vista" padrão.');
    }


    // --- Carregar pedido (existente, rascunho ou novo) ---
    if (widget.pedidoId != null) {
      // 🔥 SE FOR PEDIDO EXISTENTE → NÃO CARREGA RASCUNHO
      await carregarPedidoExistente(widget.pedidoId!);
      setState(() => carregando = false);
      return;
    }

    if (widget.pedidoRascunho != null) {
      carregarDoRascunho(widget.pedidoRascunho!);
    } else {
      await carregarRascunho();
    }


    // 🔥 Após carregar tudo: força preencher o campo de busca do cliente
    if (clienteId != null) {
      final cli = clientes.firstWhere(
            (c) => c['id'].toString() == clienteId.toString(),
        orElse: () => <String, dynamic>{},

      );

      if (cli.isNotEmpty) {
        clienteBuscaCtrl.text = cli['nome'] ?? '';
      }
    }


    setState(() => carregando = false);
  }

  void carregarDoRascunho(Map<String, dynamic> dadosRaw) {
    // aceita tanto plano quanto {dados:{...}}
    final dados = Map<String, dynamic>.from(dadosRaw['dados'] ?? dadosRaw);

    setState(() {
      clienteId = dados['cliente_id'] ?? dados['clienteId'];
      tabelaId = dados['tabela_id'] ?? dados['tabelaId'];
      condicaoId = dados['cond_pagto_id'] ?? dados['condicaoId'];
      descontoGeral = (dados['descontoGeral'] ?? 0).toDouble();
      obsCtrl.text = dados['observacao'] ?? '';
      itens = List<Map<String, dynamic>>.from(dados['itens'] ?? []);
      clienteBuscaCtrl.text = dados['cliente_nome'] ?? '';

      // para manter o dropdown selecionado
      if (tabelaId != null) _tabelaSelecionada = tabelaId.toString();
    });
  }

  Future<void> carregarPedidoExistente(int pedidoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = prefs.getString('pedido_$pedidoId');
      Map<String, dynamic> data;

      if (cache != null) {
        data = jsonDecode(cache);
        debugPrint('📦 Pedido carregado do cache local.');
      } else {
        final res = await http.post(
          Uri.parse('https://app.toocagroup.com.br/api/listar_pedido_detalhes.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'pedido_id': pedidoId,
            'empresa_id': widget.empresaId,
            'usuario_id': widget.usuarioId,
            'plano': widget.plano,
          }),
        );

        data = jsonDecode(utf8.decode(res.bodyBytes));
        debugPrint('🌐 Pedido carregado da API.');
      }

      if (data['pedido'] == null) {
        debugPrint('❌ Nenhum pedido encontrado na resposta: $data');
        return;
      }

      final pedido = data['pedido'];

      final donoPedido = int.tryParse(pedido['usuario_id'].toString()) ?? 0;
      if (!widget.isAdmin && donoPedido != widget.usuarioId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Você não tem permissão para editar este pedido.'),
          ),
        );
        Navigator.pop(context);
        return;
      }

      // =====================================================
// 🟡 NORMALIZAÇÃO — cliente vindo da API
// =====================================================
      final clienteNome = pedido['cliente_nome']
          ?? pedido['nome_cliente']
          ?? pedido['cliente']
          ?? pedido['cliente_nome_app']
          ?? '';

      final tempClienteId = int.tryParse(
          '${pedido['cliente_id']
              ?? pedido['id_cliente']
              ?? pedido['clienteId']
              ?? pedido['clienteIdApp']
              ?? ''}'
      );

// =====================================================
// 🟣 NORMALIZAÇÃO — condição de pagamento
// =====================================================
      final tempCondicaoId = int.tryParse(
          '${pedido['cond_pagto_id']
              ?? pedido['id_condicao']
              ?? pedido['condicao_pagamento_id']
              ?? pedido['condicaoId']
              ?? pedido['pagamento_id']
              ?? ''}'
      );

// =====================================================
// 🔵 NORMALIZAÇÃO — tabela (ID numérico ou texto: excel, pdf, st…)
// =====================================================
      final tabelaRaw = (pedido['tabela_id']
          ?? pedido['tabela']
          ?? pedido['tabela_nome']
          ?? pedido['id_tabela']
          ?? '')
          .toString()
          .trim()
          .toLowerCase();

      String? tempTabelaSelecionada;
      int? tempTabelaId;

      if (['pdf', 'excel', 'st', 'int', 'varejo', 'lotus'].contains(tabelaRaw)) {
        tempTabelaSelecionada = tabelaRaw;
        tempTabelaId = 0;
      } else {
        final parsed = int.tryParse(tabelaRaw);
        if (parsed != null) {
          tempTabelaSelecionada = parsed.toString();
          tempTabelaId = parsed;
        } else {
          tempTabelaSelecionada = null;
          tempTabelaId = null;
        }
      }


      // =====================================================
      // 🧾 Monta os demais dados do pedido
      // =====================================================
      await Future.delayed(const Duration(milliseconds: 50));

      setState(() {
        // CLIENTE
        clienteId = tempClienteId;
        // CORREÇÃO CLIENTE — Limpa possíveis "•" ou itens adicionais
        clienteBuscaCtrl.text = clienteNome.toString().split(' • ').first.trim();


        // TABELA DE PREÇO
        tabelaId = tempTabelaId;
        _tabelaSelecionada = tempTabelaSelecionada;

        // CONDIÇÃO DE PAGAMENTO
        condicaoId = condicoes.any((c) => int.tryParse('${c['id']}') == tempCondicaoId)
            ? tempCondicaoId
            : null;

        // CAMPOS EXTRAS
        descontoGeral = 0;
        obsCtrl.text = pedido['observacao'] ?? '';

        // ITENS
        itens = List<Map<String, dynamic>>.from(pedido['itens'] ?? []).map((item) {
          final produtoId = item['produto_id'];
          final produtoLocal = produtos.firstWhere(
                (p) => int.tryParse('${p['id']}') == produtoId,
            orElse: () => <String, dynamic>{
              'nome': '',
              'codigo': '',
            },

          );

          // Nome e código priorizam o salvo no pedido
          final nome = (item['nome']?.toString().trim().isNotEmpty ?? false)
              ? item['nome']
              : (produtoLocal['nome'] ?? 'Produto sem nome');

          final codigo = (item['codigo']?.toString().trim().isNotEmpty ?? false)
              ? item['codigo']
              : (produtoLocal['codigo'] ?? 'SN');

          final precoFinal = (double.tryParse('${item['preco_unit']}') ?? 0).toDouble();
          final desc = (double.tryParse('${item['desconto']}') ?? 0)
              .toDouble()
              .clamp(0.0, 100.0);

          final precoBase = (desc >= 100.0)
              ? 0.0
              : (precoFinal / (1 - (desc / 100)));

          return {
            'produto_id': produtoId,
            'nome': nome,
            'codigo': codigo,
            'qtd': (double.tryParse('${item['quantidade']}') ?? 1).toDouble(),
            'preco_base': precoBase.isFinite ? precoBase : 0.0,
            'preco': precoFinal,
            'desconto': desc,
          };
        }).toList();
      });


      debugPrint('✅ Pedido #$pedidoId carregado com sucesso.');
    } catch (e) {
      debugPrint('❌ Erro ao carregar pedido existente: $e');
    }
  }


  void recalcPrecosItensPorTabela(int? novaTabelaId) {
    if (novaTabelaId == null || novaTabelaId <= 0) return;

    setState(() {
      for (var i = 0; i < itens.length; i++) {
        final prodId = itens[i]['produto_id'];
        if (prodId == null) continue;

        // Busca o produto local correspondente
        final Map<String, dynamic> prodLocal = produtos.cast<Map<String, dynamic>>().firstWhere(
              (p) => int.tryParse('${p['id']}') == int.tryParse('$prodId'),
          orElse: () => <String, dynamic>{},
        );

        if (prodLocal.isEmpty) continue;


        // Novo preço base pela nova tabela
        final double base = buscarPrecoPorTabela(prodLocal, novaTabelaId);
        if (base <= 0) {
          // Se não houver preço na nova tabela, mantém o base antigo
          // (Se preferir zerar, troque por: itens[i]['preco_base'] = 0.0;)
          continue;
        }

        // Mantém o desconto atual do item
        final double desc = ((itens[i]['desconto'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0);


        itens[i]['preco_base'] = base;
        itens[i]['preco'] = double.parse((base * (1 - (desc / 100))).toStringAsFixed(2));
      }
    });

    salvarRascunho();
  }


// =======================================================
// 🔥 NOVA FUNÇÃO — SUPER RÁPIDA (pré-indexação + loop controlado)
// =======================================================
  void buscarClientesOffline(String termo) {
    final raw = termo.trim();
    final query = _norm(raw);

    // Se vazio → limpa sugestões
    if (query.isEmpty) {
      setState(() => sugestoesClientes = []);
      return;
    }

    // O usuário está digitando números?
    final isNumero = RegExp(r'^\d+$').hasMatch(raw.replaceAll(RegExp(r'\D'), ''));

    final resultados = <dynamic>[];

    // 🔥 Varre rapidamente a lista já indexada
    for (final cli in clientes) {
      final id = int.tryParse('${cli['id']}') ?? 0;
      final idx = clientesIndexados[id] ?? '';

      if (isNumero) {
        final qd = _onlyDigits(raw);
        if (qd.isNotEmpty && idx.contains(qd)) resultados.add(cli);
      } else {
        if (idx.contains(query)) resultados.add(cli);
      }

      // 🔥 Para com 50 resultados → instantâneo!
      if (resultados.length >= 50) break;
    }

    setState(() => sugestoesClientes = resultados);
  }


  Future<void> salvarRascunho() async {
    if (widget.pedidoId != null) return;

    final prefs = await SharedPreferences.getInstance();

    final clienteEncontrado = clientes.firstWhere(
          (c) => c['id'].toString() == clienteId?.toString(),
      orElse: () => <String, dynamic>{'nome': ''},

    );

// LIMPA qualquer endereço/fantasia/detalhes acoplados
    final clienteNomeSelecionado = (clienteEncontrado['nome'] ?? '')
        .toString()
        .split(' • ')
        .first
        .split(',')        // <- remove partes como “, 123”
        .first
        .trim();

    final pedidoJson = jsonEncode({
      'clienteId': clienteId,
      'cliente_nome': clienteNomeSelecionado ?? '',
      'tabelaId': tabelaId,
      'condicaoId': condicaoId,
      'descontoGeral': descontoGeral,
      'observacao': obsCtrl.text,
      'itens': itens,
      'total': calcularTotal(),
    });

    await prefs.setString(chaveRascunho, pedidoJson);
  }

  // --- Salva NOVO pedido offline (com substituição se vier da fila) ---
  Future<void> salvarNovoPedidoOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final chave = 'pedidos_pendentes';
    final fila = prefs.getStringList(chave) ?? <String>[];

    final clienteNomeSelecionado = (clientes.firstWhere(
          (c) => c['id'].toString() == (clienteId?.toString() ?? ''),
      orElse: () => <String, dynamic>{'nome': 'Cliente Offline'},

    )['nome'] ?? 'Cliente Offline');

    final tabelaNomeSelecionada = (tabelas.firstWhere(
          (t) => t['id'].toString() == (tabelaId?.toString() ?? ''),
      orElse: () => {'nome': '---'},
    )['nome'] ?? '---');

    final condicaoNomeSelecionada = (condicoes.firstWhere(
          (c) => c['id'].toString() == (condicaoId?.toString() ?? ''),
      orElse: () => {'nome': '---'},
    )['nome'] ?? '---');

    final dados = {
      'empresa_id': widget.empresaId, // ✅ novo
      'plano': widget.plano,          // ✅ novo
      'usuario_id': widget.usuarioId,
      'cliente_id': clienteId,
      'cliente_nome': clienteNomeSelecionado,
      'tabela_id': tabelaId,
      'tabela': _tabelaSelecionada,
      'tabela_nome': tabelaNomeSelecionada,
      'cond_pagto_id': condicaoId,
      'condicao_nome': condicaoNomeSelecionada,
      'observacao': obsCtrl.text,
      'itens': itens,
      'total': calcularTotal(),
    };

    final registro = {
      'tipo': 'novo',
      'dados': dados,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // substitui se veio com filaIndex
    if (widget.filaIndex != null &&
        widget.filaIndex! >= 0 &&
        widget.filaIndex! < fila.length) {
      fila[widget.filaIndex!] = jsonEncode(registro);
    } else {
      fila.add(jsonEncode(registro));
    }
    await prefs.setStringList(chave, fila);

    await excluirRascunho();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('💾 Pedido salvo OFFLINE. Será criado quando voltar a conexão.')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: widget.plano,
          email: '',
        ),
      ),
          (_) => false,
    );

  }

  Future<void> carregarRascunho() async {
    final prefs = await SharedPreferences.getInstance();
    final rascunhoJson = prefs.getString(chaveRascunho);
    if (rascunhoJson != null) {
      try {
        final dados = jsonDecode(rascunhoJson);

        setState(() {
          clienteId = dados['cliente_id'] ?? dados['clienteId'];
          tabelaId = dados['tabela_id'] ?? dados['tabelaId'];
          condicaoId = dados['cond_pagto_id'] ?? dados['condicaoId'];
          descontoGeral = (dados['descontoGeral'] ?? 0).toDouble();
          obsCtrl.text = dados['observacao'] ?? '';
          itens = List<Map<String, dynamic>>.from(dados['itens'] ?? []);
          clienteBuscaCtrl.text = dados['cliente_nome'] ?? '';
          if (tabelaId != null) _tabelaSelecionada = tabelaId.toString();
        });
      } catch (e) {
        debugPrint('Erro ao carregar rascunho: $e');
      }
    }
  }

  Future<void> excluirRascunho() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(chaveRascunho);
  }

  double buscarPrecoPorTabela(Map produto, int? tabelaIdSelecionada) {
    // Caso o produto já tenha o preço direto (API nova)
    if (produto.containsKey('preco')) {
      final precoDireto = produto['preco'];
      if (precoDireto is num) return precoDireto.toDouble();
      if (precoDireto is String) {
        return double.tryParse(precoDireto.replaceAll(',', '.')) ?? 0.0;
      }
    }

    // Caso o produto tenha lista de preços (modo offline antigo)
    final precos = (produto['precos'] is List)
        ? List<Map<String, dynamic>>.from(produto['precos'])
        : <Map<String, dynamic>>[];

    final precoTabela = precos.firstWhere(
          (p) => p['tabela_id'] == tabelaIdSelecionada,
      orElse: () => const {'preco': 0},
    );

    final preco = precoTabela['preco'];
    return (preco is num) ? preco.toDouble() : 0.0;
  }


  double calcularTotal() {
    double total = 0;
    for (var item in itens) {
      total += item['qtd'] * item['preco'];
    }
    return total;
  }

  void aplicarDescontoGeral() {
    setState(() {
      for (var i = 0; i < itens.length; i++) {
        final base = ((itens[i]['preco_base'] as num?)?.toDouble() ??
            (itens[i]['preco'] as num?)?.toDouble() ?? 0.0);
        final dg = descontoGeral.clamp(0.0, 100.0);
        itens[i]['preco_base'] = base; // garante presença
        itens[i]['desconto']   = dg;   // sobrepõe o desconto do item pelo geral
        itens[i]['preco']      = base * (1 - (dg / 100));
      }
    });
    salvarRascunho();
  }


  void abrirPopupItem({Map<String, dynamic>? produto, int? index, double? precoForcado}) {
    final isEdit = index != null;
    final item = isEdit ? itens[index!] : null;

// Base SEM desconto:
    final double precoBase = isEdit
        ? ((item!['preco_base'] as num?)?.toDouble() ?? (item['preco'] as num?)?.toDouble() ?? 0.0)
        : (precoForcado ?? 0.0);

// Se for novo, sugiro pré-preencher o campo de desconto com o descontoGeral atual
    final qtdCtrl  = TextEditingController(text: isEdit ? '${item!['qtd']}' : '1');
    final descCtrl = TextEditingController(text: isEdit ? '${item!['desconto']}' : (descontoGeral > 0 ? '$descontoGeral' : '0'));

// Preço mostrado é SEMPRE derivado de (preco_base, desconto digitado)
    final double precoInicial = precoBase * (1 - ((double.tryParse(descCtrl.text.replaceAll(',', '.')) ?? 0.0) / 100));
    final precoCtrl = TextEditingController(text: precoInicial.toStringAsFixed(2));


    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isEdit
              ? '${item!['codigo']} - ${item['nome']}'
              : '${produto?['codigo']} - ${produto?['nome']}',
        ),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            void atualizarPreco() {
              final double descValue = (double.tryParse(descCtrl.text.replaceAll(',', '.')) ?? 0.0).clamp(0.0, 100.0);
              final double precoNovo = precoBase * (1 - (descValue / 100));
              precoCtrl.text = precoNovo.toStringAsFixed(2);
            }


            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtdCtrl,
                  decoration: const InputDecoration(labelText: 'Qtd'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: precoCtrl,
                  decoration: const InputDecoration(labelText: 'Preço'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Desconto %'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setStateDialog(atualizarPreco),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00), foregroundColor: Colors.black),
            onPressed: () {
              final qtd  = double.tryParse(qtdCtrl.text.replaceAll(',', '.')) ?? 1;
              final desc = (double.tryParse(descCtrl.text.replaceAll(',', '.')) ?? 0).clamp(0.0, 100.0);

              // Sempre derive o preço final do preco_base (definido acima no abrirPopupItem)
              final double base = precoBase; // <- vem do bloco inicial do abrirPopupItem
              final double precoFinal = base * (1 - (desc / 100));

              final novoItem = {
                'produto_id': isEdit
                    ? item!['produto_id']
                    : (produto!['id'] ?? produto['produto_id']),
                'nome'      : isEdit ? item!['nome']   : (produto!['nome']   ?? ''),
                'codigo'    : isEdit ? item!['codigo'] : (produto!['codigo'] ?? 'SN'),
                'qtd'       : qtd,
                'preco_base': isEdit ? (item!['preco_base'] ?? base) : base,
                'preco'     : double.parse(precoFinal.toStringAsFixed(2)),
                'desconto'  : desc,
              };

              // Se for novo item e não tiver produto_id → erro
              if (!isEdit && novoItem['produto_id'] == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Produto inválido.')),
                );
                return;
              }


              final termoAtual = buscaCtrl.text; // 🔥 salva pesquisa

              setState(() {
                if (isEdit) {
                  itens[index!] = novoItem;
                } else {
                  itens.add(novoItem);
                }
              });

// 🔥 limpa o campo de busca de produtos
              buscaCtrl.clear();
              // 🔥 restaura pesquisa


              salvarRascunho();
              Navigator.pop(context);
            }
            ,
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> salvarCachePedido(int pedidoId) async {
    try {
      final res = await http.get(
        Uri.parse('https://app.toocagroup.com.br/api/listar_pedido_detalhes.php?id=$pedidoId'),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data['status'] == 'ok') {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('pedido_$pedidoId', jsonEncode(data));
      }
    } catch (e) {
      debugPrint('Erro ao salvar cache offline do pedido: $e');
    }
  }

  // --- Salva EDIÇÃO offline (update) com substituição se vier da fila ---
  Future<void> salvarPedidoLocalmente() async {
    final prefs = await SharedPreferences.getInstance();
    final chave = 'pedidos_pendentes';
    final fila = prefs.getStringList(chave) ?? <String>[];

    final clienteNomeSelecionado = (clientes.firstWhere(
          (c) => c['id'].toString() == (clienteId?.toString() ?? ''),
      orElse: () => <String, dynamic>{'nome': 'Cliente Offline'},

    )['nome'] ?? 'Cliente Offline');

    final tabelaNomeSelecionada = (tabelas.firstWhere(
          (t) => t['id'].toString() == (tabelaId?.toString() ?? ''),
      orElse: () => {'nome': '---'},
    )['nome'] ?? '---');

    final condicaoNomeSelecionada = (condicoes.firstWhere(
          (c) => c['id'].toString() == (condicaoId?.toString() ?? ''),
      orElse: () => {'nome': '---'},
    )['nome'] ?? '---');

    final dados = {
      'pedido_id': widget.pedidoId,
      'usuario_id': widget.usuarioId,
      'cliente_id': clienteId,
      'cliente_nome': clienteNomeSelecionado,
      'tabela_id': tabelaId,
      'tabela': _tabelaSelecionada,
      'tabela_nome': tabelaNomeSelecionada,
      'cond_pagto_id': condicaoId,
      'condicao_nome': condicaoNomeSelecionada,
      'observacao': obsCtrl.text,
      'itens': itens,
      'total': calcularTotal(),
    };

    final registro = {
      'tipo': 'update',
      'pedido_id': widget.pedidoId,
      'dados': dados,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (widget.filaIndex != null &&
        widget.filaIndex! >= 0 &&
        widget.filaIndex! < fila.length) {
      fila[widget.filaIndex!] = jsonEncode(registro);
    } else {
      fila.add(jsonEncode(registro));
    }
    await prefs.setStringList(chave, fila);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('💾 Edição salva offline. Será sincronizada quando voltar a conexão.')),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: widget.plano,
          email: '',
        ),
      ),
          (_) => false,
    );

  }

  Future<void> enviarPedido() async {
    if (itens.isEmpty || clienteId == null || tabelaId == null || condicaoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos e adicione itens.')),
      );
      return;
    }

    // 🔒 Limite do plano Free
    if (widget.plano == 'free' && itens.length > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plano Free permite até 5 itens por pedido.')),
      );
      return;
    }

    setState(() => enviando = true);

    // OFFLINE → salva local (novo/update) e sai
    if (!_isOnline) {
      if (widget.pedidoId == null) {
        await salvarNovoPedidoOffline();   // {'tipo':'novo'}
      } else {
        await salvarPedidoLocalmente();     // {'tipo':'update'}
      }
      setState(() => enviando = false);
      return;
    }
    // ONLINE
    final itensJson = itens.map((item) => {
      'produto_id': item['produto_id'],
      'quantidade': item['qtd'],
      'preco_unit': item['preco'],
      'desconto': item['desconto'],
      'nome': item['nome'],
      'codigo': item['codigo'],
    }).toList();

    final body = {
      'empresa_id': widget.empresaId.toString(),  // ✅
      'usuario_id': widget.usuarioId.toString(),
      'plano': widget.plano,                      // ✅
      'cliente_id': clienteId.toString(),
      'tabela_id': tabelaId.toString(),
      'cond_pagto_id': condicaoId.toString(),
      'observacao': obsCtrl.text,
      'itens': jsonEncode(itensJson),
    };
    if (widget.pedidoId != null) body['pedido_id'] = widget.pedidoId.toString();

    try {
      final res = await http.post(
        Uri.parse('https://app.toocagroup.com.br/api/salvar_pedido.php'),
        body: body,
      );
      final data = jsonDecode(res.body);

      if (data['status'] == 'ok') {
        await salvarCachePedido(data['pedido_id']);
        if (widget.pedidoId == null) await excluirRascunho();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Pedido salvo com sucesso!')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              usuarioId: widget.usuarioId,
              empresaId: widget.empresaId,
              plano: widget.plano,
              email: '',
            ),
          ),
              (_) => false,
        );

      } else {
        if (widget.pedidoId == null) {
          await salvarNovoPedidoOffline();
        } else {
          await salvarPedidoLocalmente();
        }
      }
    } catch (_) {
      if (widget.pedidoId == null) {
        await salvarNovoPedidoOffline();
      } else {
        await salvarPedidoLocalmente();
      }
    }

    setState(() => enviando = false);
  }

  Future<bool> confirmarSaida() async {
    if (!houveAlteracao) return true;
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text('Tem certeza que deseja sair? Todas as alterações serão perdidas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00), foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }


    final produtosFiltrados = produtos.where((p) {
      final termo = buscaCtrl.text.toLowerCase();
      return termo.isNotEmpty &&
          (p['nome'].toString().toLowerCase().contains(termo) ||
              p['codigo'].toString().contains(termo));
    }).take(50).toList(); // 🚀 LIMITA A 50 RESULTADOS

    return WillPopScope(
      onWillPop: confirmarSaida,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(widget.pedidoId == null ? 'Novo Pedido' : 'Editar Pedido'),
          backgroundColor: const Color(0xFFFFCC00),
          foregroundColor: Colors.black,
        ),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // =======================
                        // BUSCA CLIENTE
                        // =======================
                        TextField(
                          controller: clienteBuscaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Buscar Cliente por Nome ou CNPJ',
                            suffixIcon: Icon(Icons.search),
                          ),
                          onChanged: buscarClientesOffline,
                        ),

                        if (sugestoesClientes.isNotEmpty)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sugestoesClientes.length,
                            itemBuilder: (context, index) {
                              final cliente = sugestoesClientes[index];
                              return ListTile(
                                title: Text("${cliente['cnpj']} • ${cliente['nome']}"),
                                onTap: () {
                                  setState(() {
                                    clienteId = int.tryParse(cliente['id'].toString());
                                    clienteBuscaCtrl.text = cliente['nome'] ?? '';
                                    sugestoesClientes.clear();
                                  });
                                  salvarRascunho();
                                },
                              );
                            },
                          ),

                        // =======================
                        // TABELA DE PREÇO
                        // =======================
                        DropdownButtonFormField<String>(
                          value: _tabelaSelecionada,
                          decoration: const InputDecoration(labelText: 'Tabela de Preço'),
                          items: [
                            ...tabelas.map((t) {
                              final idStr = '${t['id']}';
                              return DropdownMenuItem(
                                value: idStr,
                                child: Text('${t['nome']}'),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _tabelaSelecionada = value;
                              tabelaId = int.tryParse(value ?? '') ?? 0;
                            });
                            recalcPrecosItensPorTabela(tabelaId);
                            salvarRascunho();
                          },
                        ),

                        const SizedBox(height: 10),

                        // =======================
                        // CONDIÇÃO DE PAGAMENTO
                        // =======================
                        DropdownButtonFormField<int>(
                          value: condicoes.any((c) => int.tryParse('${c['id']}') == condicaoId)
                              ? condicaoId
                              : null,
                          decoration: const InputDecoration(labelText: 'Condição de Pagamento'),
                          items: condicoes.map((c) {
                            final id = int.tryParse('${c['id']}') ?? 0;
                            final nome = c['nome'] ?? '---';

                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(nome),  // ✅ SOMENTE 1 COLUNA
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => condicaoId = v);
                              salvarRascunho();
                            }
                          },
                        ),

                        const SizedBox(height: 10),

                        // =======================
                        // OBSERVAÇÃO
                        // =======================
                        TextField(
                          controller: obsCtrl,
                          decoration: const InputDecoration(labelText: 'Observação'),
                          onChanged: (_) => salvarRascunho(),
                        ),

                        const SizedBox(height: 20),

                        // =======================
                        // BUSCA PRODUTO
                        // =======================
                        TextField(
                          controller: buscaCtrl,
                          decoration: const InputDecoration(labelText: 'Buscar Produto'),
                          onChanged: (_) => setState(() {}),
                        ),

                        if (produtosFiltrados.isNotEmpty)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: produtosFiltrados.length,
                            itemBuilder: (context, idx) {
                              final p = produtosFiltrados[idx];
                              final base = buscarPrecoPorTabela(
                                Map<String, dynamic>.from(p),
                                tabelaId,
                              );

                              return ListTile(
                                title: Text(p['nome'] ?? ''),
                                subtitle: Text(
                                  base > 0
                                      ? 'Cód: ${p['codigo']} | R\$ ${base.toStringAsFixed(2)}'
                                      : 'Cód: ${p['codigo']} • sem preço nesta tabela',
                                ),
                                trailing: const Icon(Icons.add_circle, color: Colors.green),
                                onTap: () {
                                  if (tabelaId == null || tabelaId == 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Selecione a Tabela de Preço.')),
                                    );
                                    return;
                                  }

                                  // ============================
                                  // 🚫 VERIFICA SE JÁ EXISTE
                                  // ============================
                                  final codigo = p['codigo'].toString();
                                  final indexExistente = itens.indexWhere(
                                          (item) => item['codigo'].toString() == codigo);

                                  if (indexExistente != -1) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Item já adicionado'),
                                        content: Text(
                                          'O produto "$codigo - ${p['nome']}" já está no pedido.\n\n'
                                              'Deseja editar o item existente?',
                                        ),
                                        actions: [
                                          TextButton(
                                            child: const Text('Cancelar'),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Color(0xFFFFCC00),
                                              foregroundColor: Colors.black,
                                            ),
                                            child: const Text('Editar'),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              abrirPopupItem(index: indexExistente);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }

                                  // ============================
                                  // ✨ NÃO EXISTE → ADICIONA
                                  // ============================
                                  abrirPopupItem(produto: p, precoForcado: base);
                                },
                              );
                            },
                          ),


                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color: Color(0xFFFFCC00),
                          child: const Text(
                            "Itens do Pedido",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        SizedBox(height: 10),

                        // =======================
                        // ITENS (SEM LISTVIEW)
                        // =======================
                        Column(
                          children: itens.asMap().entries.map((e) {
                            final i = e.key;
                            final item = e.value;
                            final subtotal = item['qtd'] * item['preco'];

                            return ListTile(
                              title: Text("${item['codigo']} - ${item['nome']}"),
                              subtitle: Text(
                                "Qtd: ${item['qtd']} | "
                                    "Unit: R\$ ${item['preco'].toStringAsFixed(2)} | "
                                    "Sub: R\$ ${subtotal.toStringAsFixed(2)}",
                              ),
                              onTap: () => abrirPopupItem(index: i),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setState(() => itens.removeAt(i));
                                  salvarRascunho();
                                },
                              ),
                            );
                          }).toList(),
                        ),

                        const Divider(height: 30),

                        // =======================
                        // DESCONTO GERAL
                        // =======================
                        TextField(
                          decoration: const InputDecoration(labelText: 'Desconto Geral %'),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final novoDesconto =
                                double.tryParse(v.replaceAll(',', '.')) ?? 0;
                            descontoGeral = novoDesconto;
                            aplicarDescontoGeral();
                          },
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'Total: R\$ ${calcularTotal().toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // =======================
                // BOTÃO FINAL FIXO
                // =======================
                ElevatedButton.icon(
                  icon: enviando
                      ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                      : const Icon(Icons.check, color: Colors.black),
                  label: Text(
                    enviando
                        ? 'Salvando...'
                        : (!_isOnline && widget.pedidoId == null
                        ? 'Salvar offline'
                        : (!_isOnline && widget.pedidoId != null
                        ? 'Atualizar offline'
                        : (widget.pedidoId == null
                        ? 'Salvar Pedido'
                        : 'Atualizar Pedido'))),
                    style: const TextStyle(color: Colors.black),
                  ),
                  onPressed: enviando ? null : enviarPedido,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFCC00),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          )

      ),
    );
  }
}
