import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final senhaCtrl = TextEditingController();
  bool carregando = false;
  bool mostrarSenha = false;

  // ==========================================================
  // 🔑 Faz login na API SaaS (Multiempresa)
  // ==========================================================
  Future<void> _fazerLogin() async {
    final email = emailCtrl.text.trim();
    final senha = senhaCtrl.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha e-mail e senha.')),
      );
      return;
    }

    setState(() => carregando = true);

    try {
      final url = Uri.parse('https://app.toocagroup.com.br/api/login.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      // 🔍 Tenta decodificar JSON com segurança
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (e) {
        debugPrint('⚠️ Resposta não-JSON: ${response.body}');
        throw Exception('Resposta inválida do servidor.');
      }

      debugPrint('📡 Retorno login: $data');

      if (data['status'] == 'ok') {
        final usuarioId = int.tryParse('${data['usuario_id'] ?? 0}') ?? 0;
        final empresaId = int.tryParse('${data['empresa_id'] ?? 0}') ?? 0;
        final plano = data['plano'] ?? 'free';
        final emailUser = data['email'] ?? '';
        final nomeUser = data['nome'] ?? '';

        // ✅ Salva sessão
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('usuario_id', usuarioId);
        await prefs.setInt('empresa_id', empresaId);
        await prefs.setString('plano', plano);
        await prefs.setString('email', emailUser);
        await prefs.setString('nome', nomeUser);

        debugPrint('🟢 Sessão salva → usuario=$usuarioId empresa=$empresaId plano=$plano');

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              usuarioId: usuarioId,
              empresaId: empresaId,
              plano: plano,
              email: emailUser,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${data['mensagem'] ?? 'Falha no login.'}')),
        );
      }
    } catch (e) {
      debugPrint('❌ Erro login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão com o servidor.')),
      );
    }

    if (mounted) setState(() => carregando = false);
  }

  // ==========================================================
  // 🧱 Interface visual
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/logo_tooca.png',
                height: 100,
                errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 80, color: Colors.amber),
              ),
              const SizedBox(height: 20),
              const Text(
                'Tooca CRM',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              // E-mail
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Senha
              TextField(
                controller: senhaCtrl,
                obscureText: !mostrarSenha,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      mostrarSenha ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => mostrarSenha = !mostrarSenha),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Botão login
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: carregando ? null : _fazerLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: carregando
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                      : const Text(
                    'Entrar',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Text(
                '© Tooca Group 2025',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
