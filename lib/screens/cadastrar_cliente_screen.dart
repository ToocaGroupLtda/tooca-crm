// =============================================================
// 🚀 TOOCA CRM - CADASTRAR CLIENTE (v4.3 SaaS)
// -------------------------------------------------------------
// Integra com API SaaS + modo offline e sincronização futura
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CadastrarClienteScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;
  final String plano;

  const CadastrarClienteScreen({
    Key? key,
    required this.usuarioId,
    required this.empresaId,
    required this.plano,
  }) : super(key: key);

  @override
  State<CadastrarClienteScreen> createState() => _CadastrarClienteScreenState();
}

class _CadastrarClienteScreenState extends State<CadastrarClienteScreen> {
  // Controladores
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

  // ==============================================================
  // 🔍 Consulta CNPJ na BrasilAPI
  // ==============================================================
  Future<void> buscarCnpj(String cnpj) async {
    setState(() => buscandoCnpj = true);
    final url = 'https://brasilapi.com.br/api/cnpj/v1/$cnpj';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          razaoCtrl.text = (data['razao_social'] ?? '').toString();
          fantasiaCtrl.text = (data['nome_fantasia'] ?? '').toString();
          enderecoCtrl.text = [
            (data['logradouro'] ?? '').toString(),
            (data['numero'] ?? '').toString()
          ].where((x) => x.isNotEmpty).join(', ');
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
          const SnackBar(content: Text('❌ CNPJ não encontrado na Receita.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao consultar CNPJ: $e')),
      );
    }

    setState(() => buscandoCnpj = false);
  }

  // ==============================================================
  // 💾 Envia cliente para o servidor e atualiza cache offline
  // ==============================================================
  Future<void> salvarCliente() async {
    if (razaoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha a razão social.')),
      );
      return;
    }

    setState(() => enviando = true);

    try {
      final url = Uri.parse('https://app.toocagroup.com.br/api/salvar_cliente.php');
      final response = await http.post(url, body: {
        'usuario_id': widget.usuarioId.toString(),
        'empresa_id': widget.empresaId.toString(),
        'plano': widget.plano,
        'cnpj': cnpjCtrl.text.trim(),
        'razao_social': razaoCtrl.text.trim(),
        'nome_fantasia': fantasiaCtrl.text.trim(),
        'telefone': telefoneCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'endereco': enderecoCtrl.text.trim(),
        'bairro': bairroCtrl.text.trim(),
        'cidade': cidadeCtrl.text.trim(),
        'estado': estadoCtrl.text.trim(),
        'cep': cepCtrl.text.trim(),
      });

      final data = json.decode(response.body);
      debugPrint('📡 RESPOSTA API: $data');

      if (data['sucesso'] == true || data['status'] == 'ok') {
        await _salvarClienteOffline(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Cliente cadastrado com sucesso!')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '❌ Erro ao salvar: ${data['mensagem'] ?? 'Erro desconhecido'}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro no envio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e')),
      );
    }

    setState(() => enviando = false);
  }

  // ==============================================================
  // 💾 Atualiza cache local com novo cliente (modo offline)
  // ==============================================================
  Future<void> _salvarClienteOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = 'clientes_offline_${widget.empresaId}';
    final raw = prefs.getString(chave);

    Map<String, dynamic> jsonData;
    try {
      jsonData = jsonDecode(raw ?? '{}') as Map<String, dynamic>;
    } catch (_) {
      jsonData = {'clientes': []};
    }

    final lista = (jsonData['clientes'] ?? []) as List;

    final novo = {
      'id': data['cliente_id'] ?? DateTime.now().millisecondsSinceEpoch,
      'empresa_id': widget.empresaId,
      'nome': fantasiaCtrl.text.isNotEmpty ? fantasiaCtrl.text : razaoCtrl.text,
      'razao_social': razaoCtrl.text,
      'fantasia': fantasiaCtrl.text,
      'cnpj': cnpjCtrl.text,
      'telefone': telefoneCtrl.text,
      'email': emailCtrl.text,
      'endereco': enderecoCtrl.text,
      'bairro': bairroCtrl.text,
      'cidade': cidadeCtrl.text,
      'estado': estadoCtrl.text,
      'cep': cepCtrl.text,
    };

    lista.insert(0, novo);
    jsonData['clientes'] = lista;

    await prefs.setString(chave, jsonEncode(jsonData));
    debugPrint('💾 Cliente salvo offline (${widget.empresaId})');
  }

  // ==============================================================
  // 🧱 INTERFACE VISUAL TOOCA
  // ==============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Cliente'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _campoTexto(
              cnpjCtrl,
              'CNPJ',
              teclado: TextInputType.number,
              icone: buscandoCnpj
                  ? const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 18,
                  height: 18,
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
                      const SnackBar(content: Text('CNPJ inválido.')),
                    );
                  }
                },
              ),
            ),
            _campoTexto(razaoCtrl, 'Razão Social'),
            _campoTexto(fantasiaCtrl, 'Nome Fantasia'),
            _campoTexto(telefoneCtrl, 'Telefone', teclado: TextInputType.phone),
            _campoTexto(emailCtrl, 'E-mail', teclado: TextInputType.emailAddress),
            _campoTexto(enderecoCtrl, 'Endereço'),
            _campoTexto(bairroCtrl, 'Bairro'),
            _campoTexto(cidadeCtrl, 'Cidade'),
            _campoTexto(estadoCtrl, 'Estado (UF)'),
            _campoTexto(cepCtrl, 'CEP', teclado: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: enviando
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text('Salvar Cliente'),
              onPressed: enviando ? null : salvarCliente,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoTexto(TextEditingController controller, String label,
      {TextInputType teclado = TextInputType.text, Widget? icone}) {
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
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
