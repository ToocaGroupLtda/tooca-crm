// ============================================================
// 🚀 TOOCA CRM - Main App (v4.6 SaaS Bolha PHP-style)
// ------------------------------------------------------------
// - Integra login persistente via SharedPreferences
// - Usa SplashScreen enquanto carrega a sessão
// - Tema unificado Tooca (amarelo, preto, branco)
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // ============================================================
  // 🔍 Verifica sessão e define tela inicial
  // ============================================================
  Future<Widget> getInitialScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getInt('usuario_id');
      final empresaId = prefs.getInt('empresa_id');
      final email = prefs.getString('email');
      final plano = prefs.getString('plano') ?? 'free';

      debugPrint(
          '🟡 Sessão carregada → usuario_id=$usuarioId | empresa_id=$empresaId | plano=$plano | email=$email');

      if (usuarioId != null && usuarioId > 0 && empresaId != null && empresaId > 0 && email != null) {
        // ✅ Usuário logado → vai direto pra Home
        return HomeScreen(
          usuarioId: usuarioId,
          empresaId: empresaId,
          plano: plano,
          email: email,
        );
      } else {
        debugPrint('🔒 Nenhuma sessão válida encontrada.');
        return const LoginScreen();
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar sessão: $e');
      return const LoginScreen();
    }
  }

  // ============================================================
  // 🎨 Tema e estrutura principal
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tooca CRM',
      debugShowCheckedModeBanner: false,

      // ========================================================
      // 🎨 Tema Unificado Tooca Group
      // ========================================================
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC107),
          primary: const Color(0xFFFFC107),
          secondary: Colors.black,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFC107),
          foregroundColor: Colors.black,
          elevation: 1,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        fontFamily: 'Segoe UI',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),

      // ========================================================
      // 🚀 Tela inicial dinâmica com Splash
      // ========================================================
      home: FutureBuilder<Widget>(
        future: getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  '❌ Erro ao iniciar o aplicativo:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          } else {
            return snapshot.data ?? const LoginScreen();
          }
        },
      ),
    );
  }
}
