import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProdutosScreen extends StatefulWidget {
  final int empresaId; // ✅ Campo real
  const ProdutosScreen({Key? key, required this.empresaId}) : super(key: key);

  @override
  State<ProdutosScreen> createState() => _ProdutosScreenState();
}

class _ProdutosScreenState extends State<ProdutosScreen> {
  List<Map<String, dynamic>> produtos = [];
  bool carregando = true;
  String plano = 'free';

  @override
  void initState() {
    super.initState();
    carregarProdutos();
  }

  Future<void> carregarProdutos() async {
    setState(() => carregando = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      plano = prefs.getString('plano') ?? 'free';

      final url = Uri.parse(
        'https://app.toocagroup.com.br/api/listar_produtos.php'
            '?empresa_id=${widget.empresaId}&plano=$plano',
      );

      debugPrint('🌐 Buscando produtos de empresa ${widget.empresaId} ($plano)');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'ok' && data['produtos'] is List) {
          setState(() {
            produtos = List<Map<String, dynamic>>.from(data['produtos']);
          });
        } else if (data is List) {
          // caso a API retorne lista pura
          setState(() {
            produtos = List<Map<String, dynamic>>.from(data);
          });
        } else {
          debugPrint('⚠️ Estrutura inesperada da API: ${response.body}');
          setState(() => produtos = []);
        }
      } else {
        debugPrint('⚠️ Erro HTTP ${response.statusCode}');
        setState(() => produtos = []);
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar produtos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📴 Falha de conexão com o servidor.')),
        );
      }
    }

    setState(() => carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text('Produtos (${plano.toUpperCase()})'),
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: carregarProdutos,
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : produtos.isEmpty
          ? const Center(child: Text('Nenhum produto encontrado.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: produtos.length,
        itemBuilder: (context, index) {
          final produto = produtos[index];
          final codigo = produto['codigo']?.toString() ?? '---';
          final nome = produto['nome']?.toString() ?? 'Nome não informado';
          final preco = produto['preco']?.toString() ?? '0,00';
          final estoque = produto['estoque']?.toString() ?? '-';

          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.shopping_cart, color: Colors.black54),
              title: Text(
                nome,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Código: $codigo'),
                  Text('Preço: R\$ $preco'),
                  if (plano != 'free') Text('Estoque: $estoque unid.'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
