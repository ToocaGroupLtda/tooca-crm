// ============================================================
// 🚀 TOOCA CRM - Main App (v4.9 EVA PRIME)
// ------------------------------------------------------------
// ✔ Fluxo 100% correto: sempre inicia pelo SplashScreen
// ✔ globalNavigatorKey funcional para bloqueio universal
// ✔ Nada de redirecionamento direto para Home
// ✔ Splash decide: Login → Home → Bloqueio
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // ============================================================
  // 🔍 Sessão é carregada apenas quando Splash chamar
  // ============================================================
  Future<Map<String, dynamic>> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'usuario_id': prefs.getInt('usuario_id') ?? 0,
      'empresa_id': prefs.getInt('empresa_id') ?? 0,
      'email': prefs.getString('email') ?? '',
      'plano_empresa': prefs.getString('plano_empresa') ?? 'free',
      'expira': prefs.getString('empresa_expira') ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tooca CRM',
      debugShowCheckedModeBanner: false,
      navigatorKey: globalNavigatorKey,

      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Segoe UI',
        visualDensity: VisualDensity.standard,
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
        ),
      ),

      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },

      // ============================================================
      // 🚀 Fluxo correto: SEMPRE inicia pelo SplashScreen
      // ============================================================
      home: const SplashScreen(),
    );
  }
}
