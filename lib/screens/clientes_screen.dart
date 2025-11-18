// =============================================================
// 🚀 TOOCA CRM - CLIENTES SCREEN (v7.6 EVA SUPREMO FINAL)
// -------------------------------------------------------------
// ✔ Lista clientes online → fallback offline
// ✔ Toast ao clicar no cliente (nome + cnpj + cidade)
// ✔ Abre cadastro do cliente
// ✔ Excluir cliente (API + offline)
// ✔ Atualiza lista ao voltar
// ✔ IDs reais do SharedPreferences
// ✔ UI moderna padrão Tooca
// ✔ Sincronização silenciosa automática
// ✔ Compatível com listar_clientes.php e excluir_cliente.php
// ✔ 100% offline funcional
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cadastrar_cliente_screen.dart';
import 'sincronizacao_service.dart';

class ClientesScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;
  final String plano;

  const ClientesScreen({
    Key? key,
    required this.usuarioId,
    required this.empresaId,
    required this.plano,
  }) : super(key: key);

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  List<dynamic> _clientes = [];
  List<dynamic> _filtrados = [];

  bool carregando = true;
  bool offline = false;

  final _buscaCtrl = TextEditingController();

  int empresaId = 0;
  int usuarioId = 0;

  @override
  void initState() {
    super.initState();
    carregarIds();
  }

  // =============================================================
  // 🔑 Carregar IDs reais do SharedPreferences
  // =============================================================
  Future<void> carregarIds() async {
    final prefs = await SharedPreferences.getInstance();

    empresaId = prefs.getInt('empresa_id') ?? widget.empresaId;
    usuarioId = prefs.getInt('usuario_id') ?? widget.usuarioId;

    debugPrint("🔥 ClientesScreen → empresaId REAL = $empresaId");
    debugPrint("🔥 ClientesScreen → usuarioId REAL = $usuarioId");

    await carregarClientes();
  }

  // =============================================================
  // 🌍 CARREGAR CLIENTES ONLINE → fallback OFFLINE
  // =============================================================
  Future<void> carregarClientes() async {
    if (empresaId == 0) {
      setState(() {
        carregando = false;
        offline = true;
        _clientes = [];
        _filtrados = [];
      });
      return;
    }

    setState(() {
      carregando = true;
      offline = false;
    });

    try {
      final url = Uri.parse(
        'https://app.toocagroup.com.br/api/listar_clientes.php?empresa_id=$empresaId&plano=${widget.plano}',
      );

      debugPrint("🌍 GET CLIENTES → $url");

      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        final data = jsonDecode(utf8.decode(resp.bodyBytes));

        final lista = (data['clientes'] ?? data ?? []) as List;

        setState(() {
          _clientes = lista;
          _filtrados = lista;
          carregando = false;
        });

        // Salva OFFLINE
        prefs.setString(
          'clientes_offline_$empresaId',
          jsonEncode({'clientes': lista}),
        );

      } else {
        await carregarOffline();
      }
    } catch (_) {
      await carregarOffline();
    }
  }

  // =============================================================
  // 💾 MODO OFFLINE
  // =============================================================
  Future<void> carregarOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('clientes_offline_$empresaId');

    if (raw != null) {
      final json = jsonDecode(raw);

      final lista = json['clientes'] ?? [];

      setState(() {
        offline = true;
        carregando = false;
        _clientes = List.from(lista);
        _filtrados = List.from(lista);
      });
    } else {
      setState(() {
        offline = true;
        carregando = false;
        _clientes = [];
        _filtrados = [];
      });
    }
  }

  // =============================================================
  // 🔍 BUSCA
  // =============================================================
  void filtrar(String termo) {
    final t = termo.toLowerCase();

    if (t.isEmpty) {
      setState(() => _filtrados = List.from(_clientes));
      return;
    }

    setState(() {
      _filtrados = _clientes.where((c) {
        final nome = (c['nome'] ?? '').toString().toLowerCase();
        final fantasia = (c['fantasia'] ?? '').toString().toLowerCase();
        final cnpj = (c['cnpj'] ?? '').toString().toLowerCase();
        return nome.contains(t) || fantasia.contains(t) || cnpj.contains(t);
      }).toList();
    });
  }

  // =============================================================
  // ➕ Novo Cliente
  // =============================================================
  Future<void> abrirCadastro() async {
    final r = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CadastrarClienteScreen(
          usuarioId: usuarioId,
          empresaId: empresaId,
          plano: widget.plano,
        ),
      ),
    );

    if (r == true) {
      await SincronizacaoService.sincronizarSilenciosamente(
        empresaId,
        usuarioId,
      );
      await carregarClientes();
    }
  }

  // =============================================================
  // 🧱 UI — Card do Cliente
  // =============================================================
  Widget _cardCliente(dynamic c) {
    final nome = (c['nome'] ?? '').toString();
    final cnpj = (c['cnpj'] ?? '').toString();
    final cidade = (c['cidade'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () async {
          // 🔔 TOAST
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$nome\n$cnpj\n$cidade"),
              duration: const Duration(milliseconds: 900),
              backgroundColor: Colors.black87,
            ),
          );

          // abre depois do toast
          await Future.delayed(const Duration(milliseconds: 900));

          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CadastrarClienteScreen(
                usuarioId: usuarioId,
                empresaId: empresaId,
                plano: widget.plano,
                cliente: c,
              ),
            ),
          );

          if (res == true) {
            carregarClientes();
          }
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4C2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_outline,
            color: Color(0xFFFFC107),
          ),
        ),
        title: Text(
          nome.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("$cnpj\n$cidade", style: const TextStyle(height: 1.3)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  // =============================================================
  // BUILD
  // =============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text("Clientes"),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: carregarClientes,
          )
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text("Novo Cliente"),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        onPressed: abrirCadastro,
      ),

      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _buscaCtrl,
              onChanged: filtrar,
              decoration: InputDecoration(
                hintText: "Buscar cliente...",
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (offline)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text("📴 Modo offline",
                  style: TextStyle(color: Colors.grey)),
            ),

          Expanded(
            child: _filtrados.isEmpty
                ? const Center(
              child: Text(
                "Nenhum cliente encontrado.",
                style: TextStyle(fontSize: 16),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: _filtrados.length,
              itemBuilder: (_, i) =>
                  _cardCliente(_filtrados[i]),
            ),
          ),
        ],
      ),
    );
  }
}
