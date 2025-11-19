// =============================================================
// 🔐 TOOCA CRM - LOGIN SCREEN (v8.1 EVA SUPREMA FINAL)
// -------------------------------------------------------------
// ✔ Bloqueio somente aqui (e na SincronizarScreen)
// ✔ Usa empresa_status + data_expiracao exatamente como API
// ✔ NÃO bloqueia datas vazias ou inválidas
// ✔ Sessão limpa antes de salvar
// ✔ 100% compatível com Splash, Home e Sincronização v7.6
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
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "senha": senha,
        }),
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
      // ✔ PEGAR DADOS DO JSON
      // ==============================================================
      final usuarioId = data['usuario_id'] ?? 0;
      final empresaId = data['empresa_id'] ?? 0;
      final nomeUser = data['nome'] ?? "Usuário";
      final planoUser = data['plano_usuario'] ?? "free";

      final planoEmpresa = data['plano_empresa'] ?? "free";
      final empresaStatus = data['empresa_status'] ?? 'ativo';

      final expiraRaw = data['data_expiracao'] ?? "";
      final expiraEmpresa = _normalizarData(expiraRaw);

      debugPrint("🔍 planoEmpresa=$planoEmpresa | status=$empresaStatus | expira=$expiraEmpresa");

      // ==============================================================
      // 🛡️ BLOQUEIO SOMENTE NO LOGIN
      // ==============================================================
      // Empresa inativa → bloqueia
      if (empresaStatus != 'ativo') {
        _irPara(TelaBloqueio(
          planoEmpresa: planoEmpresa,
          empresaExpira: expiraEmpresa,
        ));
        return;
      }

      // Empresa expirada → bloqueia
      if (!_empresaAtiva(expiraEmpresa)) {
        _irPara(TelaBloqueio(
          planoEmpresa: planoEmpresa,
          empresaExpira: expiraEmpresa,
        ));
        return;
      }

      // ==============================================================
      // 🧹 LIMPAR SESSÃO
      // ==============================================================
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await prefs.reload();

      // ==============================================================
      // ✔ SALVAR NOVA SESSÃO
      // ==============================================================
      await prefs.setInt('usuario_id', usuarioId);
      await prefs.setInt('empresa_id', empresaId);

      await prefs.setString('email', email);
      await prefs.setString('nome', nomeUser);

      await prefs.setString('plano_usuario', planoUser);
      await prefs.setString('plano_empresa', planoEmpresa);
      await prefs.setString('empresa_status', empresaStatus);
      await prefs.setString('empresa_expira', expiraEmpresa);

      debugPrint("🟢 Sessão salva com sucesso.");

      // ==============================================================
      // ✔ TUDO OK → ENTRA NO APP
      // ==============================================================
      _irPara(
        HomeScreen(
          usuarioId: usuarioId,
          empresaId: empresaId,
          plano: planoUser,
          email: email,
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
    return valor.contains(" ") ? valor.split(" ").first : valor;
  }

  // ==========================================================
  // 🔐 Empresa ativa?
  // ==========================================================
  bool _empresaAtiva(String expira) {
    if (expira.isEmpty) return true; // datas vazias NÃO bloqueiam
    final dt = DateTime.tryParse(expira);
    if (dt == null) return true; // datas inválidas NÃO bloqueiam
    return dt.isAfter(DateTime.now());
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
}
