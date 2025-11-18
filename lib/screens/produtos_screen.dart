// =============================================================
// 🛒 TOOCA CRM - PRODUTOS SCREEN (v4.8 SaaS MULTIEMPRESA + BLOQUEIO)
// -------------------------------------------------------------
// ✔ Verifica empresaAtivaLocal() antes de tudo
// ✔ Consulta SaaS ao entrar e ao atualizar
// ✔ Bloqueia imediatamente se expirada / inativa
// ✔ Carrega online → fallback offline
// ✔ Cache separado por empresa
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'sincronizacao_service.dart';

class ProdutosScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;
  final String plano;

  const ProdutosScreen({
    Key? key,
    required this.usuarioId,
    required this.empresaId,
    required this.plano,
  }) : super(key: key);

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  List<Map<String, dynamic>> produtos = [];
  bool carregando = true;
  bool offline = false;

  @override
  void initState() {
    super.initState();
    _validarAntesDeCarregar();
  }

  // ============================================================
  // 🔐 VALIDAÇÃO COMPLETA (Local + SaaS)
  // ============================================================
  Future<void> _validarAntesDeCarregar() async {
    final prefs = await SharedPreferences.getInstance();

    // 1️⃣ LOCAL
    if (!await SincronizacaoService.empresaAtivaLocal()) {
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    // 2️⃣ CONSULTA REAL
    await SincronizacaoService.consultarStatusEmpresa();

    // 3️⃣ LOCAL DE NOVO
    if (!await SincronizacaoService.empresaAtivaLocal()) {
      SincronizacaoService.irParaBloqueio(
        prefs.getString('plano_empresa') ?? 'free',
        prefs.getString('empresa_expira') ?? '',
      );
      return;
    }

    carregarProdutos();
  }

  // ============================================================
  // 🔄 Carrega produtos (tenta online → fallback offline)
  // ============================================================
  Future<void> carregarProdutos() async {
    setState(() {
      carregando = true;
      offline = false;
    });

    final url = Uri.parse(
      'https://app.toocagroup.com.br/api/listar_produtos.php'
          '?empresa_id=${widget.empresaId}&usuario_id=${widget.usuarioId}&plano=${widget.plano}',
    );

    debugPrint('🟡 Produtos → empresa=${widget.empresaId} plano=${widget.plano}');

    try {
      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));

        List<Map<String, dynamic>> lista = [];

        if (data['status'] == 'ok' && data['produtos'] is List) {
          lista = List<Map<String, dynamic>>.from(data['produtos']);
        } else if (data is List) {
          lista = List<Map<String, dynamic>>.from(data);
        }

        setState(() {
          produtos = lista;
          carregando = false;
          offline = false;
        });

        // 📌 Atualiza cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'produtos_offline_${widget.empresaId}',
          jsonEncode({'produtos': lista}),
        );

        debugPrint('💾 Cache atualizado (${lista.length} produtos).');
      } else {
        debugPrint('⚠️ Erro HTTP ${resp.statusCode}');
        await carregarOffline();
      }
    } catch (e) {
      debugPrint('📴 Falha na conexão: $e');
      await carregarOffline();
    }

    setState(() => carregando = false);
  }

  // ============================================================
  // 💾 Carrega produtos do cache local
  // ============================================================
  Future<void> carregarOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('produtos_offline_${widget.empresaId}');

    if (raw != null && raw.isNotEmpty) {
      final data = jsonDecode(raw);
      final lista = (data['produtos'] ?? []) as List;

      setState(() {
        produtos = List<Map<String, dynamic>>.from(lista);
        offline = true;
        carregando = false;
      });

      debugPrint('📦 Offline: ${produtos.length} produtos carregados.');
    } else {
      setState(() {
        produtos = [];
        offline = true;
        carregando = false;
      });
      debugPrint('⚠️ Nenhum cache encontrado.');
    }
  }

  // ============================================================
  // 🧱 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text('Produtos (${widget.plano.toUpperCase()})'),
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _validarAntesDeCarregar,
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : produtos.isEmpty
          ? const Center(child: Text('Nenhum produto encontrado.'))
          : Column(
        children: [
          if (offline)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('📴 Modo offline',
                  style: TextStyle(color: Colors.grey)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: produtos.length,
              itemBuilder: (context, index) {
                final p = produtos[index];
                final codigo = (p['codigo'] ?? '').toString();
                final nome =
                (p['nome'] ?? 'Nome não informado').toString();
                final preco = (p['preco'] ?? '0,00').toString();
                final estoque = (p['estoque'] ?? '-').toString();

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.shopping_cart,
                        color: Colors.black54),
                    title: Text(
                      nome,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Código: $codigo'),
                        Text('Preço: R\$ $preco'),
                        if (widget.plano != 'free')
                          Text('Estoque: $estoque unid.'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
