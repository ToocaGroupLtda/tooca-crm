// =============================================================
// 🔐 TOOCA CRM - LOGIN SCREEN
// FINAL - ALINHADO COM API SaaS POR EMPRESA
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'home_screen.dart';
import 'TelaBloqueio.dart';

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
  bool lembrarUsuario = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuarioSalvo();
  }

  Future<void> _carregarUsuarioSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final emailSalvo = prefs.getString('email_salvo');
    if (emailSalvo != null && emailSalvo.isNotEmpty) {
      emailCtrl.text = emailSalvo;
    }
  }

  // ==========================================================
  // 🔑 LOGIN
  // ==========================================================
  Future<void> _fazerLogin() async {
    final email = emailCtrl.text.trim();
    final senha = senhaCtrl.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      _msg('Preencha e-mail e senha.');
      return;
    }

    setState(() => carregando = true);

    try {
      final url = Uri.parse('https://toocagroup.com.br/api/login.php');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "senha": senha}),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data['status'] != 'ok') {
        _msg(data['mensagem'] ?? 'Falha no login.');
        setState(() => carregando = false);
        return;
      }

      final int usuarioId = data['usuario_id'];
      final int empresaId = data['empresa_id'];
      final String nomeUser = data['nome'] ?? 'Usuário';

      final String plano = data['plano'] ?? 'free';
      final String empresaStatus = data['empresa_status'] ?? 'ativo';
      final String planoExpira = _normalizarData(data['plano_expira_em'] ?? '');

      // 🚫 BLOQUEIO
      if (empresaStatus != 'ativo' || !_empresaAtiva(planoExpira)) {
        _irPara(
          TelaBloqueio(
            planoEmpresa: plano,
            empresaExpira: planoExpira,
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // 🔁 lembrar usuário
      if (lembrarUsuario) {
        await prefs.setString('email_salvo', email);
      } else {
        await prefs.remove('email_salvo');
      }

      // 🧹 limpa sessão
      await prefs.clear();

      // 💾 salva sessão correta
      await prefs.setInt('usuario_id', usuarioId);
      await prefs.setInt('empresa_id', empresaId);
      await prefs.setString('nome', nomeUser);
      await prefs.setString('email', email);
      await prefs.setString('plano', plano);
      await prefs.setString('empresa_status', empresaStatus);
      await prefs.setString('plano_expira_em', planoExpira);

      // ✅ ENTRA
      _irPara(
        HomeScreen(
          usuarioId: usuarioId,
          empresaId: empresaId,
          plano: plano,
          email: email,
        ),
      );
    } catch (e) {
      debugPrint('❌ Erro login: $e');
      _msg('Erro de conexão.');
    }

    if (mounted) setState(() => carregando = false);
  }

  // ==========================================================
  // HELPERS
  // ==========================================================
  String _normalizarData(String valor) {
    if (valor.isEmpty || valor == '0000-00-00') return '';
    return valor.contains(' ') ? valor.split(' ').first : valor;
  }

  bool _empresaAtiva(String expira) {
    if (expira.isEmpty) return true;
    final dt = DateTime.tryParse(expira);
    if (dt == null) return true;
    return dt.isAfter(DateTime.now());
  }

  void _msg(String txt) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(txt)));
  }

  void _irPara(Widget tela) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => tela),
    );
  }

  // ==========================================================
  // UI
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Text(
                'Tooca CRM',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 36),

              TextField(
                controller: emailCtrl,
                decoration: _campo('E-mail', Icons.email_outlined),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: senhaCtrl,
                obscureText: !mostrarSenha,
                decoration: _campo(
                  'Senha',
                  Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                        mostrarSenha ? Icons.visibility_off : Icons.visibility),
                    onPressed: () =>
                        setState(() => mostrarSenha = !mostrarSenha),
                  ),
                ),
              ),

              Row(
                children: [
                  Checkbox(
                    value: lembrarUsuario,
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (v) =>
                        setState(() => lembrarUsuario = v ?? false),
                  ),
                  const Text('Lembrar usuário'),
                ],
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: carregando ? null : _fazerLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                  ),
                  child: carregando
                      ? const CircularProgressIndicator()
                      : const Text('Entrar'),
                ),
              ),

              const SizedBox(height: 20),
              Text.rich(
                TextSpan(
                  text: 'Fale com a Tooca ',
                  children: [
                    TextSpan(
                      text: 'clicando aqui',
                      style: const TextStyle(
                        color: Colors.green,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = _abrirWhatsapp,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _campo(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _abrirWhatsapp() async {
    final url = Uri.parse(
        'https://wa.me/5511942815500?text=Quero%20o%20Tooca%20CRM');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
