// =============================================================
// 🔐 TOOCA CRM - LOGIN SCREEN
// v9.2 EVA SUPREMA FINAL + Lembrar Usuário (CORRIGIDO)
// =============================================================

import 'dart:convert';
import 'dart:async';
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

  // ==========================================================
  // 🔁 INIT
  // ==========================================================
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
      // Não chamo setState aqui, pois o lembrarUsuario é true por padrão.
      // setState(() {});
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

      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw Exception("Resposta inválida do servidor");
      }


      if (data['status'] != 'ok') {
        _msg(data['mensagem'] ?? 'Falha no login.');
        setState(() => carregando = false);
        return;
      }

      final int usuarioId = data['usuario_id'] ?? 0;
      final int empresaId = data['empresa_id'] ?? 0;
      final nomeUser = data['nome'] ?? "Usuário"; // Pego o nome para salvar

      final planoUser = data['plano_usuario'] ?? 'free';
      final planoEmpresa = data['plano_empresa'] ?? 'free';
      final empresaStatus = data['empresa_status'] ?? 'ativo';
      final expiraEmpresa = _normalizarData(data['data_expiracao'] ?? '');

      if (usuarioId <= 0) {
        _msg('Usuário inválido.');
        setState(() => carregando = false);
        return;
      }

      if (empresaStatus != 'ativo' || !_empresaAtiva(expiraEmpresa)) {
        _irPara(
          TelaBloqueio(
            planoEmpresa: planoEmpresa,
            empresaExpira: expiraEmpresa,
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // 1. 🔐 SALVA/REMOVE EMAIL SALVO (Lembrar Usuário)
      if (lembrarUsuario) {
        await prefs.setString('email_salvo', email);
      } else {
        await prefs.remove('email_salvo');
      }

      // 2. 🧹 LIMPA DADOS DE SESSÃO ANTIGA (Chaves específicas)
      await prefs.remove('usuario_id');
      await prefs.remove('empresa_id');
      await prefs.remove('email');
      await prefs.remove('nome');
      await prefs.remove('plano_usuario');
      await prefs.remove('plano_empresa');

      // 3. 💾 SALVAR NOVOS DADOS DE SESSÃO (CORRIGIDO)
      await prefs.setInt('usuario_id', usuarioId);
      await prefs.setInt('empresa_id', empresaId);
      await prefs.setString('email', email);
      await prefs.setString('nome', nomeUser);
      await prefs.setString('plano_usuario', planoUser);
      await prefs.setString('plano_empresa', planoEmpresa);
      await prefs.setString('empresa_status', empresaStatus);
      await prefs.setString('empresa_expira', expiraEmpresa);


      // 4. ✔ ENTRAR NO APP
      _irPara(
        HomeScreen(
          usuarioId: usuarioId,
          empresaId: empresaId,
          plano: planoUser,
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
  // 📞 WHATSAPP
  // ==========================================================
  void _abrirWhatsapp() async {
    const telefone = '5511942815500';
    const mensagem = 'Olá, gostaria de contratar o Tooca CRM!';

    final url = Uri.parse(
      'https://wa.me/$telefone?text=${Uri.encodeComponent(mensagem)}',
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      _msg('Não foi possível abrir o WhatsApp.');
    }
  }

  // ==========================================================
  // 🔧 HELPERS
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(txt)),
    );
  }

  void _irPara(Widget tela) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => tela),
    );
  }

  // ==========================================================
  // 🖥️ UI
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
                decoration: _campoDeco(
                  label: 'E-mail',
                  icon: Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: senhaCtrl,
                obscureText: !mostrarSenha,
                decoration: _campoDeco(
                  label: 'Senha',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      mostrarSenha
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => mostrarSenha = !mostrarSenha),
                  ),
                ),
              ),

              // 🔁 LEMBRAR USUÁRIO
              Row(
                children: [
                  Checkbox(
                    value: lembrarUsuario,
                    activeColor: const Color(0xFFFFC107),
                    onChanged: (v) {
                      setState(() => lembrarUsuario = v ?? false);
                    },
                  ),
                  const Text(
                    'Lembrar usuário',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),

              const SizedBox(height: 12),

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
                    width: 22,
                    height: 22,
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

              const SizedBox(height: 28),

              // ⭐ CARD CONTATO
              Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 260,
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _abrirWhatsapp,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.phone, // Usamos 'Icons.phone' como substituto seguro do WhatsApp
                                color: Colors.green,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Fale com a Tooca',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                text:
                                'Peça seu teste e contrate nosso sistema ',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Clique aqui!',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
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
                  ),
                ),
              ),

              const SizedBox(height: 18),
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

  InputDecoration _campoDeco({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[100],
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }
}