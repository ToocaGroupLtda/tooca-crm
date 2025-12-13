// =============================================================
// 🚀 TOOCA CRM - CADASTRAR / EDITAR CLIENTE (v7.6 EVA SUPREMO)
// -------------------------------------------------------------
// ✔ Cadastro + Edição + Exclusão
// ✔ Evita clientes duplicados (nome ou CNPJ)
// ✔ Preenche automático via CNPJ (BrasilAPI)
// ✔ 100% compatível com listar_salvar_cliente.php
// ✔ Botão EXCLUIR cliente (API + Offline)
// ✔ Atualiza ClienteScreen ao voltar (Navigator.pop TRUE)
// ✔ Layout Tooca + Código limpo
// ✔ Cache Offline por empresa
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CadastrarClienteScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;
  final String plano;
  final Map<String, dynamic>? cliente; // ← ADICIONADO PARA EDIÇÃO

  const CadastrarClienteScreen({
    Key? key,
    required this.usuarioId,
    required this.empresaId,
    required this.plano,
    this.cliente,
  }) : super(key: key);

  @override
  State<CadastrarClienteScreen> createState() => _CadastrarClienteScreenState();
}

class _CadastrarClienteScreenState extends State<CadastrarClienteScreen> {
  // -----------------------------------------------------------
  // CONTROLADORES
  // -----------------------------------------------------------
  final cnpjCtrl = TextEditingController();
  final razaoCtrl = TextEditingController();
  final fantasiaCtrl = TextEditingController();
  final telefoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final enderecoCtrl = TextEditingController();
  final bairroCtrl = TextEditingController();
  final cidadeCtrl = TextEditingController();
  final estadoCtrl = TextEditingController();
  final cepCtrl = TextEditingController();

  bool enviando = false;
  bool buscandoCnpj = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosSeEdicao();
  }

  // -----------------------------------------------------------
  // SE ESTIVER EDITANDO, PREENCHE OS CAMPOS
  // -----------------------------------------------------------
  void _carregarDadosSeEdicao() {
    if (widget.cliente == null) return;

    final c = widget.cliente!;

    cnpjCtrl.text = c['cnpj'] ?? '';
    razaoCtrl.text = c['razao_social'] ?? c['nome'] ?? '';
    fantasiaCtrl.text = c['fantasia'] ?? c['nome'] ?? '';
    telefoneCtrl.text = c['telefone'] ?? '';
    emailCtrl.text = c['email'] ?? '';
    enderecoCtrl.text = c['endereco'] ?? '';
    bairroCtrl.text = c['bairro'] ?? '';
    cidadeCtrl.text = c['cidade'] ?? '';
    estadoCtrl.text = c['estado'] ?? '';
    cepCtrl.text = c['cep'] ?? '';
  }

  @override
  void dispose() {
    cnpjCtrl.dispose();
    razaoCtrl.dispose();
    fantasiaCtrl.dispose();
    telefoneCtrl.dispose();
    emailCtrl.dispose();
    enderecoCtrl.dispose();
    bairroCtrl.dispose();
    cidadeCtrl.dispose();
    estadoCtrl.dispose();
    cepCtrl.dispose();
    super.dispose();
  }

  // ===========================================================
  // 🔍 CONSULTA CNPJ — BrasilAPI
  // ===========================================================
  Future<void> buscarCnpj(String cnpj) async {
    setState(() => buscandoCnpj = true);

    try {
      final url = Uri.parse("https://brasilapi.com.br/api/cnpj/v1/$cnpj");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          razaoCtrl.text = (data['razao_social'] ?? '').toString();
          fantasiaCtrl.text = (data['nome_fantasia'] ?? '').toString();
          enderecoCtrl.text =
          "${data['logradouro'] ?? ''}, ${data['numero'] ?? ''}";
          bairroCtrl.text = (data['bairro'] ?? '').toString();
          cidadeCtrl.text = (data['municipio'] ?? '').toString();
          estadoCtrl.text = (data['uf'] ?? '').toString();
          cepCtrl.text = (data['cep'] ?? '').toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Dados preenchidos automaticamente.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ CNPJ não encontrado.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao consultar CNPJ: $e")),
      );
    }

    setState(() => buscandoCnpj = false);
  }

  // ===========================================================
  // 🛑 IMPEDIR CLIENTE DUPLICADO (NOME OU CNPJ)
  // ===========================================================
  Future<bool> _existeClienteDuplicado(String nome, String cnpj) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = "clientes_offline_${widget.empresaId}";

    final raw = prefs.getString(chave);
    if (raw == null) return false;

    final data = jsonDecode(raw);
    final lista = List.from(data['clientes'] ?? []);

    return lista.any((c) {
      final mesmoCnpj = c['cnpj']?.toString() == cnpj;
      final nomeBanco = (c['fantasia'] ?? c['nome'] ?? '').toString().trim().toLowerCase();
      final mesmoNome = nomeBanco == nome.toLowerCase();


      // Se for edição, ignora o próprio cliente
      if (widget.cliente != null && c['id'] == widget.cliente!['id']) {
        return false;
      }

      return mesmoCnpj || mesmoNome;
    });
  }

  // ===========================================================
  // 💾 SALVAR CLIENTE (CRIAR OU EDITAR)
  // ===========================================================
  Future<void> salvarCliente() async {
    final nome = fantasiaCtrl.text.isNotEmpty
        ? fantasiaCtrl.text.trim()
        : razaoCtrl.text.trim();
    final cnpj = cnpjCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Preencha o nome.")));
      return;
    }

    // Duplicado?
    if (await _existeClienteDuplicado(nome, cnpj)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Já existe um cliente com esse Nome ou CNPJ."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => enviando = true);

    try {
      final url = Uri.parse(
        'https://toocagroup.com.br/api/listar_salvar_cliente.php',
      );

      final body = jsonEncode({
        "acao": widget.cliente == null ? "salvar" : "editar",
        "cliente_id": widget.cliente?['id'],
        "empresa_id": widget.empresaId,
        "usuario_id": widget.usuarioId,
        "plano": widget.plano,              //  👈🔥  aqui está a correção!
        "nome": nome,
        "fantasia": fantasiaCtrl.text.trim(),
        "razao_social": razaoCtrl.text.trim(),
        "cnpj": cnpj,
        "telefone": telefoneCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "endereco": enderecoCtrl.text.trim(),
        "bairro": bairroCtrl.text.trim(),
        "cidade": cidadeCtrl.text.trim(),
        "uf": estadoCtrl.text.trim(),
        "cep": cepCtrl.text.trim(),
      });


      final resp = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      final data = jsonDecode(resp.body);

      if (data['status'] == 'ok') {
        await _salvarClienteOffline(data, nome, cnpj);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.cliente == null
                ? '🎉 Cliente cadastrado!'
                : '✔ Cliente atualizado!'),
          ),
        );

        Navigator.pop(context, true);
      } else {
        throw Exception(data['mensagem']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar: $e")),
      );
    }

    setState(() => enviando = false);
  }

  // ===========================================================
  // 💾 SALVAR OFFLINE (CRIAR / EDITAR)
  // ===========================================================
  Future<void> _salvarClienteOffline(
      Map<String, dynamic> data,
      String nome,
      String cnpj,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = "clientes_offline_${widget.empresaId}";

    Map<String, dynamic> jsonArmazenado =
    jsonDecode(prefs.getString(chave) ?? '{"clientes": []}');

    List lista = jsonArmazenado["clientes"] ?? [];

    final clienteOffline = {
      "id": data['cliente_id'] ?? widget.cliente?['id'],
      "nome": nome,
      "razao_social": razaoCtrl.text.trim(),
      "fantasia": fantasiaCtrl.text.trim(),
      "cnpj": cnpj,
      "telefone": telefoneCtrl.text.trim(),
      "email": emailCtrl.text.trim(),
      "endereco": enderecoCtrl.text.trim(),
      "bairro": bairroCtrl.text.trim(),
      "cidade": cidadeCtrl.text.trim(),
      "uf": estadoCtrl.text.trim(),
      "cep": cepCtrl.text.trim(),
    };

    // Se edição → substitui
    if (widget.cliente != null) {
      lista.removeWhere((c) => c['id'] == widget.cliente!['id']);
    }

    lista.insert(0, clienteOffline);

    jsonArmazenado["clientes"] = lista;

    await prefs.setString(chave, jsonEncode(jsonArmazenado));
  }

// ===========================================================
// 🗑️ EXCLUIR CLIENTE (CORRIGIDO v7.7 EVA SUPREMO)
// ===========================================================
  Future<void> excluirCliente() async {
    if (widget.cliente == null) return;

    final nomeCliente = widget.cliente!['nome'] ?? "Cliente";

    // 🔔 CONFIRMAÇÃO
    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Excluir Cliente"),
        content: Text(
          "Você deseja realmente excluir o cliente:\n\n$nomeCliente ?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Excluir",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    try {
      final int idCorrigido =
          int.tryParse(widget.cliente!['id'].toString()) ?? 0;
      final int empresaCorrigido =
          int.tryParse(widget.empresaId.toString()) ?? 0;

      final resp = await http.post(
        Uri.parse("https://toocagroup.com.br/api/listar_excluir_cliente.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": idCorrigido,
          "empresa_id": empresaCorrigido,
        }),
      );

      final data = jsonDecode(resp.body);

      if (data['status'] == 'ok') {
        await _removerOffline(idCorrigido);

        // 🎉 AVISO DE SUCESSO
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cliente $nomeCliente excluído do banco."),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        throw Exception(data['mensagem'] ?? "Erro ao excluir");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao excluir: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  // ===========================================================
  // 🗑️ REMOVER DO CACHE OFFLINE
  // ===========================================================
  Future<void> _removerOffline(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = "clientes_offline_${widget.empresaId}";

    final raw = prefs.getString(chave);
    if (raw == null) return;

    final json = jsonDecode(raw);
    final lista = List.from(json["clientes"]);

    lista.removeWhere((c) => c["id"] == id);

    await prefs.setString(
      chave,
      jsonEncode({"clientes": lista}),
    );
  }

  // ===========================================================
  // UI
  // ===========================================================
  @override
  Widget build(BuildContext context) {
    final editando = widget.cliente != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? "Editar Cliente" : "Cadastrar Cliente"),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _campoTexto(
              cnpjCtrl,
              "CNPJ",
              teclado: TextInputType.number,
              icone: buscandoCnpj
                  ? const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  final cnpj =
                  cnpjCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                  if (cnpj.length == 14) {
                    buscarCnpj(cnpj);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("CNPJ inválido (14 dígitos).")),
                    );
                  }
                },
              ),
            ),
            _campoTexto(razaoCtrl, "Razão Social"),
            _campoTexto(fantasiaCtrl, "Nome Fantasia"),
            _campoTexto(telefoneCtrl, "Telefone",
                teclado: TextInputType.phone),
            _campoTexto(emailCtrl, "E-mail",
                teclado: TextInputType.emailAddress),
            _campoTexto(enderecoCtrl, "Endereço"),
            _campoTexto(bairroCtrl, "Bairro"),
            _campoTexto(cidadeCtrl, "Cidade"),
            _campoTexto(estadoCtrl, "Estado (UF)"),
            _campoTexto(cepCtrl, "CEP", teclado: TextInputType.number),

            const SizedBox(height: 22),

            // BOTÃO SALVAR
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: enviando
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : Text(editando ? "Salvar Alterações" : "Cadastrar Cliente"),
              onPressed: enviando ? null : salvarCliente,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            if (editando) const SizedBox(height: 20),

            // BOTÃO EXCLUIR
            if (editando)
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text("Excluir Cliente"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: excluirCliente,
              ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // WIDGET CUSTOMIZADO PARA CAMPOS
  // -----------------------------------------------------------
  Widget _campoTexto(
      TextEditingController controller,
      String label, {
        TextInputType teclado = TextInputType.text,
        Widget? icone,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: icone,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
