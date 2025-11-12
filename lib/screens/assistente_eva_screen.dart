import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssistenteEVAScreen extends StatefulWidget {
  final int usuarioId;
  final String email;

  const AssistenteEVAScreen({
    Key? key,
    required this.usuarioId,
    required this.email,
  }) : super(key: key);

  @override
  State<AssistenteEVAScreen> createState() => _AssistenteEVAScreenState();
}

class _AssistenteEVAScreenState extends State<AssistenteEVAScreen> {
  final TextEditingController _mensagemController = TextEditingController();
  List<Map<String, dynamic>> mensagens = [];
  int empresaId = 0;
  String plano = 'free';

  @override
  void initState() {
    super.initState();
    _carregarSessao();
  }

  Future<void> _carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      empresaId = prefs.getInt('empresa_id') ?? 0;
      plano = prefs.getString('plano') ?? 'free';
    });
  }

  void _enviarMensagem() {
    final texto = _mensagemController.text.trim();
    if (texto.isEmpty) return;

    setState(() {
      mensagens.add({'tipo': 'usuario', 'texto': texto});
    });
    _mensagemController.clear();

    // 🔮 Simulação temporária (resposta automática)
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        mensagens.add({
          'tipo': 'eva',
          'texto': '🤖 Olá! Aqui é a EVA, sua assistente Tooca.\n'
              'Estou aprendendo com seus pedidos e logo poderei gerar orçamentos automáticos!'
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Assistente EVA'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: mensagens.length,
              itemBuilder: (context, index) {
                final msg = mensagens[index];
                final isUser = msg['tipo'] == 'usuario';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isUser
                          ? const Color(0xFFFFC107)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg['texto'],
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensagemController,
                    decoration: InputDecoration(
                      hintText: 'Digite uma mensagem...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _enviarMensagem(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _enviarMensagem,
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
