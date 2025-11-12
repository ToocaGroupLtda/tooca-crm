// =============================================================
// 🚀 TOOCA CRM - CLIENTES SCREEN (v4.4 SaaS)
// -------------------------------------------------------------
// - Lista clientes online/offline
// - Busca por nome, fantasia ou CNPJ
// - Botão para cadastrar novo cliente
// - Popup de detalhes limpo e moderno
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tooca_crm/screens/cadastrar_cliente_screen.dart';
import 'package:app_tooca_crm/screens/sincronizacao_service.dart';

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

  @override
  void initState() {
    super.initState();
    carregarClientes();
  }

  // ============================================================
  // 🔄 Carrega clientes (tenta online → fallback offline)
  // ============================================================
  Future<void> carregarClientes() async {
    setState(() {
      carregando = true;
      offline = false;
    });

    try {
      final url = Uri.parse(
          'https://app.toocagroup.com.br/api/listar_clientes.php?empresa_id=${widget.empresaId}&plano=${widget.plano}');
      final resp = await http.get(url);

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final lista = (data['clientes'] ?? data ?? []) as List;

        setState(() {
          _clientes = lista;
          _filtrados = lista;
          carregando = false;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'clientes_offline_${widget.empresaId}', jsonEncode({'clientes': lista}));
        debugPrint('💾 Cache atualizado (${lista.length} clientes)');
      } else {
        debugPrint('⚠️ Erro HTTP: ${resp.statusCode}');
        await _carregarOffline();
      }
    } catch (e) {
      debugPrint('📴 Falha na conexão: $e');
      await _carregarOffline();
    }
  }

  // ============================================================
  // 💾 Carrega clientes do cache offline
  // ============================================================
  Future<void> _carregarOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('clientes_offline_${widget.empresaId}');
    if (raw != null && raw.isNotEmpty) {
      final data = jsonDecode(raw);
      final lista = (data['clientes'] ?? []) as List;
      setState(() {
        _clientes = lista;
        _filtrados = lista;
        offline = true;
        carregando = false;
      });
      debugPrint('📦 Modo offline: ${lista.length} clientes');
    } else {
      setState(() {
        _clientes = [];
        _filtrados = [];
        offline = true;
        carregando = false;
      });
      debugPrint('⚠️ Nenhum cache local encontrado');
    }
  }

  // ============================================================
  // 🔍 Busca em tempo real
  // ============================================================
  void filtrar(String termo) {
    termo = termo.toLowerCase().trim();
    if (termo.isEmpty) {
      setState(() => _filtrados = List.from(_clientes));
    } else {
      setState(() {
        _filtrados = _clientes.where((c) {
          final nome = (c['nome'] ?? '').toString().toLowerCase();
          final fantasia = (c['fantasia'] ?? '').toString().toLowerCase();
          final cnpj = (c['cnpj'] ?? '').toString().toLowerCase();
          return nome.contains(termo) ||
              fantasia.contains(termo) ||
              cnpj.contains(termo);
        }).toList();
      });
    }
  }

  // ============================================================
  // ➕ Abre tela de cadastro de cliente
  // ============================================================
  Future<void> _abrirCadastro() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CadastrarClienteScreen(
          usuarioId: widget.usuarioId,
          empresaId: widget.empresaId,
          plano: widget.plano,
        ),
      ),
    );

    if (resultado == true) {
      await SincronizacaoService.sincronizarSilenciosamente(widget.empresaId);
      await carregarClientes();
    }
  }

  // ============================================================
  // 👁️ Popup de detalhes simples e limpo
  // ============================================================
  void _mostrarDetalhesCliente(Map<String, dynamic> c) {
    final nome = (c['fantasia'] ?? c['nome'] ?? 'Sem nome').toString();
    final cnpj = (c['cnpj'] ?? '').toString();
    final cidade = (c['cidade'] ?? '').toString();
    final estado = (c['estado'] ?? '').toString();
    final telefone = (c['telefone'] ?? '').toString();
    final email = (c['email'] ?? '').toString();
    final endereco = (c['endereco'] ?? '').toString();
    final obs = (c['observacao'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                nome,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              _info('📇 CNPJ', cnpj),
              _info('📍 Endereço', '$endereco, $cidade - $estado'),
              _info('📞 Telefone', telefone),
              _info('✉️ E-mail', email),
              if (obs.isNotEmpty) _info('🗒 Observação', obs),
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.black54),
                  label: const Text('Fechar',
                      style: TextStyle(color: Colors.black54)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(String titulo, String valor) {
    if (valor.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
          Text(
            valor,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 🧱 UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar lista',
            onPressed: carregarClientes,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirCadastro,
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add),
        label: const Text('Novo Cliente'),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _clientes.isEmpty
          ? const Center(
        child: Text(
          'Nenhum cliente encontrado.',
          style: TextStyle(fontSize: 16),
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: TextField(
              controller: _buscaCtrl,
              onChanged: filtrar,
              decoration: InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          if (offline)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '📴 Modo offline',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: carregarClientes,
              child: ListView.builder(
                itemCount: _filtrados.length,
                itemBuilder: (context, i) {
                  final c = _filtrados[i];
                  final nome = (c['fantasia'] ??
                      c['nome'] ??
                      'Sem nome')
                      .toString();
                  final cnpj = (c['cnpj'] ?? '').toString();
                  final cidade = (c['cidade'] ?? '').toString();

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                    child: ListTile(
                      title: Text(
                        nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      subtitle: Text(
                        '$cnpj\n$cidade',
                        style: const TextStyle(fontSize: 13),
                      ),
                      isThreeLine: true,
                      leading: const Icon(Icons.person_outline,
                          color: Colors.amber),
                      trailing: const Icon(Icons.info_outline,
                          color: Colors.grey),
                      onTap: () => _mostrarDetalhesCliente(c),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
