// =============================================================
// 🔐 TOOCA CRM - LOGIN SCREEN (v9.0 EVA SUPREMA FINAL)
// -------------------------------------------------------------
// ✔ Banco 100% fixado no toocagroup.com.br
// ✔ Impede mistura com bancos antigos (app.tooca, etc.)
// ✔ Limpa e recria sessão de forma segura
// ✔ Mantém todas as chaves usadas pelo app atual
// ✔ Fluxo de bloqueio + expiração intacto
// ✔ Compatível com Splash, Home, Pedidos, Sincronização, EVA
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
  // 🔑 LOGIN PRINCIPAL
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
      // ==========================================================
      // 🌐 API FIXADA DEFINITIVA
      // ==========================================================
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

      debugPrint("📡 Retorno login: $data");

      if (data['status'] != 'ok') {
        _msg(data['mensagem'] ?? 'Falha no login.');
        setState(() => carregando = false);
        return;
      }

      // ==========================================================
      // ✔ DADOS RECEBIDOS DO LOGIN
      // ==========================================================
      final int usuarioId = data['usuario_id'] ?? 0;
      final int empresaId = data['empresa_id'] ?? 0;
      final nomeUser = data['nome'] ?? "Usuário";

      final planoUser = data['plano_usuario'] ?? "free";
      final planoEmpresa = data['plano_empresa'] ?? "free";

      final empresaStatus = data['empresa_status'] ?? "ativo";
      final expiraEmpresa = _normalizarData(data['data_expiracao'] ?? "");

      // ==========================================================
      // 🚫 BLOQUEIO DE USUÁRIO INVÁLIDO
      // ==========================================================
      if (usuarioId <= 0) {
        _msg("❌ Usuário inválido. Contate o suporte.");
        setState(() => carregando = false);
        return;
      }

      // ==========================================================
      // 🛡️ BLOQUEIO POR PLANO / EXPIRAÇÃO
      // ==========================================================
      if (empresaStatus != "ativo" || !_empresaAtiva(expiraEmpresa)) {
        _irPara(TelaBloqueio(
          planoEmpresa: planoEmpresa,
          empresaExpira: expiraEmpresa,
        ));
        return;
      }

      // ==========================================================
      // 🧹 LIMPAR SESSÃO ANTES DE SALVAR
      // ==========================================================
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.reload();

      // ==========================================================
      // 💾 SALVAR SESSÃO (100% COMPATÍVEL COM O APP ATUAL)
      // ==========================================================
      await prefs.setInt('usuario_id', usuarioId);
      await prefs.setInt('empresa_id', empresaId);

      await prefs.setString('email', email);
      await prefs.setString('nome', nomeUser);

      await prefs.setString('plano_usuario', planoUser);
      await prefs.setString('plano_empresa', planoEmpresa);
      await prefs.setString('tipo_usuario', data['tipo'] ?? 'vendedor');
      await prefs.setBool('is_master', data['is_master'] == 1);


      await prefs.setString('empresa_status', empresaStatus);
      await prefs.setString('empresa_expira', expiraEmpresa);

      debugPrint("🟢 Sessão salva: usuario=$usuarioId empresa=$empresaId");

      // ==========================================================
      // ✔ ENTRAR NO APP
      // ==========================================================
      _irPara(HomeScreen(
        usuarioId: usuarioId,
        empresaId: empresaId,
        plano: planoUser,
        email: email,
      ));
    } catch (e) {
      debugPrint("❌ Erro login: $e");
      _msg("Erro de conexão com o servidor.");
    }

    if (mounted) setState(() => carregando = false);
  }

  // ==========================================================
  // 📅 Normalização de Data
  // ==========================================================
  String _normalizarData(String valor) {
    if (valor.isEmpty || valor == 'null' || valor == '0000-00-00') return "";
    return valor.contains(" ") ? valor.split(" ").first : valor;
  }

  // ==========================================================
  // 🔐 Empresa ativa?
  // ==========================================================
  bool _empresaAtiva(String expira) {
    if (expira.isEmpty) return true;
    final dt = DateTime.tryParse(expira);
    if (dt == null) return true;
    return dt.isAfter(DateTime.now());
  }

  // ==========================================================
  // 🔊 Mensagem rápida
  // ==========================================================
  void _msg(String txt) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));
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

              const SizedBox(height: 40),

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
                      mostrarSenha ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => mostrarSenha = !mostrarSenha),
                  ),
                ),
              ),

              const SizedBox(height: 28),

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
                      : const Text('Entrar', style: TextStyle(fontSize: 16)),
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

  // ==========================================================
  // 🔧 UI Helper
  // ==========================================================
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
