import 'package:app_tooca_crm/screens/sincronizacao_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'login_screen.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarLogin();
  }

  Future<void> _verificarLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getInt('usuario_id');
    final empresaId = prefs.getInt('empresa_id') ?? 0;
    final plano = prefs.getString('plano') ?? 'free';

    // 🔄 Sincronização automática (em background)
    if (empresaId > 0) {
      SincronizacaoService.sincronizarSilenciosamente(empresaId, usuarioId ?? 0);
    }



    await Future.delayed(const Duration(milliseconds: 1500)); // pequena transição

    if (!mounted) return;

    if (usuarioId != null && usuarioId > 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            usuarioId: usuarioId,
            empresaId: empresaId,
            plano: plano,
            email: prefs.getString('email') ?? '',
          ),

        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🟡 Logo Tooca CRM (simples e leve)
            const Icon(Icons.business_center, size: 90, color: Colors.black87),
            const SizedBox(height: 20),
            const Text(
              'TOOCA CRM',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
