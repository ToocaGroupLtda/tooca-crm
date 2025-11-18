// =============================================================
// 🔐 TOOCA CRM - LOGIN SCREEN (v8.0 EVA SUPREMA FINAL)
// -------------------------------------------------------------
// ✔ Leitura correta da API login.php
// ✔ Usa exatamente os campos reais: plano_empresa + data_expiracao
// ✔ Bloqueio imediato somente se realmente expirado
// ✔ Sessão limpa antes de salvar (sem cache velho)
// ✔ Totalmente compatível com Splash + Home + Sincronização v7
// =============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  // ==========================================================
  // 🔑 LOGIN (v8.0)
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

      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw Exception("Resposta inválida do servidor");
      }

      debugPrint("📡 Retorno login: $data");

      if (data['status'] != 'ok') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${data['mensagem'] ?? 'Falha no login.'}')),
        );
        setState(() => carregando = false);
        return;
      }

      // ==============================================================
      // ✔ DADOS DO USUÁRIO
      // ==============================================================
      final usuarioId = data['usuario_id'] ?? 0;
      final empresaId = data['empresa_id'] ?? 0;
      final emailUser = email;
      final nomeUser = data['nome'] ?? "Usuário";
      final planoUser = data['plano_usuario'] ?? "free";

      // ==============================================================
      // ✔ DADOS REAIS DE PLANO/EXPIRAÇÃO DA EMPRESA
      // (EXATAMENTE COMO A API ENVIA)
      // ==============================================================
      String planoEmpresa = data['plano_empresa'] ?? "free";

      // A API retorna SEMPRE neste campo:
      String expiraBruta = data['data_expiracao'] ?? "";

      // Normaliza formato YYYY-MM-DD
      String expiraEmpresa = _normalizarData(expiraBruta);

      debugPrint("🔍 Plano Empresa = $planoEmpresa | Expira = $expiraEmpresa");

      // ==============================================================
      // 🧹 LIMPAR CACHE ANTIGO PARA EVITAR SALVAR VALORES VELHOS
      // ==============================================================
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('plano_empresa');
      await prefs.remove('empresa_expira');
      await prefs.remove('plano_usuario');
      await prefs.remove('usuario_id');
      await prefs.remove('empresa_id');

      // ==============================================================
      // ✔ SALVAR SESSÃO NOVA
      // ==============================================================
      await prefs.setInt('usuario_id', usuarioId);
      await prefs.setInt('empresa_id', empresaId);

      await prefs.setString('email', emailUser);
      await prefs.setString('nome', nomeUser);
      await prefs.setString('plano_usuario', planoUser);

      await prefs.setString('plano_empresa', planoEmpresa);
      await prefs.setString('empresa_expira', expiraEmpresa);

      debugPrint("🟢 Sessão salva com sucesso.");

      // ==============================================================
      // ✔ BLOQUEAR SE REALMENTE EXPIRADO
      // ==============================================================
      if (!_empresaAtiva(expiraEmpresa)) {
        debugPrint("⛔ Empresa expirada → TelaBloqueio");
        _irPara(
          TelaBloqueio(
            planoEmpresa: planoEmpresa,
            empresaExpira: expiraEmpresa,
          ),
        );
        return;
      }

      // ==============================================================
      // ✔ LOGIN OK → IR PARA HOME
      // ==============================================================
      _irPara(
        HomeScreen(
          usuarioId: usuarioId,
          empresaId: empresaId,
          plano: planoUser,
          email: emailUser,
        ),
      );

    } catch (e) {
      debugPrint("❌ Erro login: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro de conexão com o servidor.")),
      );
    }

    if (mounted) setState(() => carregando = false);
  }

  // ==========================================================
  // 🧹 Normalizar datas
  // ==========================================================
  String _normalizarData(String valor) {
    if (valor.isEmpty || valor == 'null' || valor == '0000-00-00') return "";

    if (valor.contains(" ")) {
      valor = valor.split(" ").first;
    }

    return valor;
  }

  // ==========================================================
  // 🔐 Empresa ativa?
  // ==========================================================
  bool _empresaAtiva(String expira) {
    if (expira.isEmpty) return false;
    final exp = DateTime.tryParse(expira);
    if (exp == null) return false;
    return exp.isAfter(DateTime.now());
  }

  // ==========================================================
  // ⛳ Navegar
  // ==========================================================
  void _irPara(Widget tela) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => tela),
    );
  }

  // ==========================================================
  // 🖥️ INTERFACE
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
              Image.asset(
                'assets/logo_tooca.png',
                height: 100,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.business, size: 80, color: Colors.amber),
              ),
              const SizedBox(height: 20),

              const Text(
                'Tooca CRM',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 40),

              // EMAIL
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

              // SENHA
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
                        mostrarSenha ? Icons.visibility_off : Icons.visibility),
                    onPressed: () =>
                        setState(() => mostrarSenha = !mostrarSenha),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // BOTÃO LOGIN
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
