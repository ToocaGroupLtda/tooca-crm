// =============================================================
// 🚀 TOOCA CRM - SplashScreen (v5.0 EVA PRIME)
// -------------------------------------------------------------
// ✔ Fluxo 100% correto
// ✔ Validação local → online → bloqueio
// ✔ Usa globalNavigatorKey (navegação universal)
// ✔ Sem risco de entrar na Home sendo expirada
// ✔ Sincronização silenciosa
// =============================================================

import 'package:app_tooca_crm/main.dart';
import 'package:app_tooca_crm/screens/sincronizacao_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'TelaBloqueio.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _carregarFluxo();
  }

  // ============================================================
  // 🔥 FLUXO PRINCIPAL
  // ============================================================
  Future<void> _carregarFluxo() async {
    final prefs = await SharedPreferences.getInstance();

    final usuarioId = prefs.getInt('usuario_id');
    final empresaId = prefs.getInt('empresa_id');
    final email = prefs.getString('email') ?? '';

    String plano = prefs.getString('plano_empresa') ?? 'free';
    String empresaExpira = prefs.getString('empresa_expira') ?? '';

    debugPrint("🟡 SPLASH → usuario=$usuarioId | empresa=$empresaId | plano=$plano | expira=$empresaExpira");

    // ============================================================
    // 1️⃣ SEM LOGIN → TELA LOGIN
    // ============================================================
    if (usuarioId == null || empresaId == null) {
      return _abrir(const LoginScreen());
    }

    // ============================================================
    // 2️⃣ EXPIRAÇÃO LOCAL
    // ============================================================
    DateTime? expiraLocal = DateTime.tryParse(empresaExpira);

    if (expiraLocal == null) {
      return _abrir(const LoginScreen());
    }

    if (expiraLocal.isBefore(DateTime.now())) {
      return _abrir(TelaBloqueio(planoEmpresa: plano, empresaExpira: empresaExpira));
    }

    // ============================================================
    // 3️⃣ CONSULTA ONLINE DO STATUS
    // ============================================================
    debugPrint("🌐 Consultando expiração ONLINE...");
    await SincronizacaoService.consultarStatusEmpresa();

    final prefs2 = await SharedPreferences.getInstance();

    empresaExpira = prefs2.getString('empresa_expira') ?? empresaExpira;
    plano = prefs2.getString('plano_empresa') ?? plano;

    DateTime? expOnline = DateTime.tryParse(empresaExpira);

    if (expOnline == null || expOnline.isBefore(DateTime.now())) {
      return _abrir(TelaBloqueio(planoEmpresa: plano, empresaExpira: empresaExpira));
    }

    // ============================================================
    // 4️⃣ SINCRONIZAÇÃO SILENCIOSA (somente online e ativa)
    // ============================================================
    debugPrint("🟢 Empresa ativa → Sincronizando silenciosamente...");
    await SincronizacaoService.sincronizarSilenciosamente(empresaId, usuarioId);

    // ============================================================
    // 5️⃣ IR PARA HOME
    // ============================================================
    return _abrir(HomeScreen(
      usuarioId: usuarioId,
      empresaId: empresaId,
      plano: plano,
      email: email,
    ));
  }

  // ============================================================
  // 🚀 Navegação usando globalNavigatorKey
  // ============================================================
  void _abrir(Widget tela) {
    if (!mounted) return;

    globalNavigatorKey.currentState?.pushReplacement(
      MaterialPageRoute(builder: (_) => tela),
    );
  }

  // ============================================================
  // 🎨 Layout
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.business_center, size: 90, color: Colors.black),
            SizedBox(height: 20),
            Text(
              'TOOCA CRM',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
