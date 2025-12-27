// =============================================================
// 🚀 TOOCA CRM - CADASTRAR / EDITAR CLIENTE (v7.9.2 EVA SUPREMO FIXED)
// -------------------------------------------------------------
// ✔ CORREÇÃO: Vinculação de IDs na Fila Offline garantida
// ✔ Adição dos campos: Nome do Contato e Observação
// ✔ MODO OFFLINE agora adiciona na FILA de PENDENTES (update_cliente / novo_cliente)
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


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
  // CONTROLADORES (NOVOS CAMPOS ADICIONADOS AQUI)
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
  final contatoCtrl = TextEditingController(); // ✅ NOVO CAMPO
  final obsCtrl = TextEditingController();     // ✅ NOVO CAMPO

  bool enviando = false;
  bool buscandoCnpj = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosSeEdicao();
  }

  Future<bool> _temInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // -----------------------------------------------------------
  // SE ESTIVER EDITANDO, PREENCHE OS CAMPOS
  // -----------------------------------------------------------
  void _carregarDadosSeEdicao() {
    if (widget.cliente == null) return;

    final c = widget.cliente!;

    cnpjCtrl.text     = c['cnpj'] ?? '';
    razaoCtrl.text    = c['razao_social'] ?? c['nome'] ?? '';
    fantasiaCtrl.text = c['fantasia'] ?? c['nome'] ?? '';
    telefoneCtrl.text = c['telefone'] ?? '';
    emailCtrl.text    = c['email'] ?? '';
    enderecoCtrl.text = c['endereco'] ?? '';
    bairroCtrl.text   = c['bairro'] ?? '';
    cidadeCtrl.text   = c['cidade'] ?? '';
    estadoCtrl.text   = c['uf'] ?? '';
    cepCtrl.text      = c['cep'] ?? '';

    contatoCtrl.text  = c['contato'] ?? '';
    obsCtrl.text      = c['observacao'] ?? '';
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
    contatoCtrl.dispose();
    obsCtrl.dispose();
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
      final mesmoCnpj = c['cnpj']?.toString() == cnpj && cnpj.isNotEmpty;
      final nomeBanco = (c['fantasia'] ?? c['nome'] ?? '').toString().trim().toLowerCase();
      final mesmoNome = nomeBanco == nome.toLowerCase();

      if (widget.cliente != null && c['id'].toString() == widget.cliente!['id'].toString()) {
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

    if (await _existeClienteDuplicado(nome, cnpj)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Já existe um cliente com esse Nome ou CNPJ."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final online = await _temInternet();

    if (!online) {
      await _atualizarCacheCliente(
        widget.cliente?['id'],
        nome,
        cnpj,
      );

      await _adicionarClienteAFilaOffline(
        widget.cliente?['id'],
        nome,
        cnpj,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ Sem internet. Alterações salvas localmente e serão enviadas quando a conexão voltar.",
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true);
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
        "plano": widget.plano,
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
        "contato": contatoCtrl.text.trim(),
        "observacao": obsCtrl.text.trim(),
      });


      final resp = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      final data = jsonDecode(resp.body);

      if (data['status'] == 'ok') {
        final id = data['cliente_id'] ?? widget.cliente?['id'];
        await _atualizarCacheCliente(id, nome, cnpj, syncPendente: false);

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
  // 💾 1/3: ATUALIZA O CACHE DE CLIENTES
  // ===========================================================
  Future<void> _atualizarCacheCliente(
      dynamic id,
      String nome,
      String cnpj, {
        bool syncPendente = true,
      }) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = "clientes_offline_${widget.empresaId}";

    Map<String, dynamic> jsonArmazenado =
    jsonDecode(prefs.getString(chave) ?? '{"clientes": []}');

    List lista = jsonArmazenado["clientes"] ?? [];

    final clienteIdFinal = id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

    final clienteOffline = {
      "id": clienteIdFinal,
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
      "contato": contatoCtrl.text.trim(),
      "observacao": obsCtrl.text.trim(),
      "sync_pendente": syncPendente,
    };


    if (widget.cliente != null) {
      lista.removeWhere((c) => c['id'].toString() == widget.cliente!['id'].toString());
    }

    if (id != null && id.toString().startsWith('temp_')) {
      lista.removeWhere((c) => c['id'].toString() == id.toString());
    }


    lista.insert(0, clienteOffline);
    jsonArmazenado["clientes"] = lista;
    await prefs.setString(chave, jsonEncode(jsonArmazenado));
  }

  // ===========================================================
  // 💾 2/3: ADICIONA A AÇÃO NA FILA DE SINCRONIZAÇÃO (Offline)
  // ===========================================================
  Future<void> _adicionarClienteAFilaOffline(
      dynamic id,
      String nome,
      String cnpj,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    final chaveFila = 'pedidos_pendentes_${widget.empresaId}';
    final isEdit = id != null;

    final clienteDados = {
      "id": id,
      "empresa_id": widget.empresaId, // 🔑 CORREÇÃO: ID da empresa na fila
      "usuario_id": widget.usuarioId, // 🔑 CORREÇÃO: ID do usuário na fila
      "plano": widget.plano,
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
      "contato": contatoCtrl.text.trim(),
      "observacao": obsCtrl.text.trim(),
    };

    final registro = {
      'tipo': isEdit ? 'update_cliente' : 'novo_cliente',
      'dados': clienteDados,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final fila = prefs.getStringList(chaveFila) ?? <String>[];

    if (isEdit) {
      fila.removeWhere((raw) {
        try {
          final reg = jsonDecode(raw);
          return (reg['tipo'] == 'update_cliente' || reg['tipo'] == 'novo_cliente')
              && reg['dados']['id'].toString() == id.toString();
        } catch (_) {
          return false;
        }
      });
    }

    fila.add(jsonEncode(registro));
    await prefs.setStringList(chaveFila, fila);
  }

// ===========================================================
// 🗑️ EXCLUIR CLIENTE
// ===========================================================
  Future<void> excluirCliente() async {
    if (widget.cliente == null) return;

    final nomeCliente = widget.cliente!['nome'] ?? "Cliente";
    final dynamic idOriginal = widget.cliente!['id'];

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

    final online = await _temInternet();

    if (!online) {
      await _removerOffline(idOriginal);
      await _adicionarExclusaoAFilaOffline(idOriginal);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Sem internet. Exclusão salva localmente."),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse("https://toocagroup.com.br/api/listar_excluir_cliente.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": idOriginal,
          "empresa_id": widget.empresaId,
        }),
      );

      final data = jsonDecode(resp.body);

      if (data['status'] == 'ok') {
        await _removerOffline(idOriginal);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Cliente excluído com sucesso."),
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


  Future<void> _removerOffline(dynamic id) async {
    final prefs = await SharedPreferences.getInstance();
    final chave = "clientes_offline_${widget.empresaId}";

    final raw = prefs.getString(chave);
    if (raw == null) return;

    final json = jsonDecode(raw);
    final lista = List.from(json["clientes"]);

    lista.removeWhere((c) => c["id"].toString() == id.toString());

    await prefs.setString(
      chave,
      jsonEncode({"clientes": lista}),
    );
  }

  Future<void> _adicionarExclusaoAFilaOffline(dynamic id) async {
    final prefs = await SharedPreferences.getInstance();
    final chaveFila = 'pedidos_pendentes_${widget.empresaId}';

    final registro = {
      'tipo': 'delete_cliente',
      'dados': {
        'id': id,
        'empresa_id': widget.empresaId // 🔑 CORREÇÃO: Vincula empresa na exclusão
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    final fila = prefs.getStringList(chaveFila) ?? <String>[];

    fila.removeWhere((raw) {
      try {
        final reg = jsonDecode(raw);
        return (reg['tipo'] == 'update_cliente' || reg['tipo'] == 'novo_cliente')
            && reg['dados']['id'].toString() == id.toString();
      } catch (_) {
        return false;
      }
    });

    fila.add(jsonEncode(registro));
    await prefs.setStringList(chaveFila, fila);
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
            _campoTexto(contatoCtrl, "Nome do Contato"),
            _campoTexto(telefoneCtrl, "Telefone", teclado: TextInputType.phone),
            _campoTexto(emailCtrl, "E-mail", teclado: TextInputType.emailAddress),
            _campoTexto(enderecoCtrl, "Endereço"),
            _campoTexto(bairroCtrl, "Bairro"),
            _campoTexto(cidadeCtrl, "Cidade"),
            _campoTexto(estadoCtrl, "Estado (UF)"),
            _campoTexto(cepCtrl, "CEP", teclado: TextInputType.number),
            _campoTexto(obsCtrl, "Observação", maxLines: 3),

            const SizedBox(height: 22),

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

  Widget _campoTexto(
      TextEditingController controller,
      String label, {
        TextInputType teclado = TextInputType.text,
        Widget? icone,
        int maxLines = 1,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: teclado,
        maxLines: maxLines,
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