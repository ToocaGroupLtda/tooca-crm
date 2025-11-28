// =============================================================
// 🚀 TOOCA CRM - Main App (v5.1 EVA SUPREMA SEM BLOQUEIO)
// -------------------------------------------------------------
// ✔ Sem SplashScreen
// ✔ Home NUNCA bloqueia
// ✔ Login controla bloqueio
// ✔ Sincronizar controla bloqueio
// ✔ Main só verifica se existe sessão
// =============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Widget _startScreen = const Center(
    child: CircularProgressIndicator(color: Colors.black),
  );

  @override
  void initState() {
    super.initState();
    _carregarSessaoInicial();
  }

  // ============================================================
  // 🔥 Carregar sessão e decidir tela inicial
  // ============================================================
  Future<void> _carregarSessaoInicial() async {
    final prefs = await SharedPreferences.getInstance();

    final usuarioId = prefs.getInt('usuario_id');
    final empresaId = prefs.getInt('empresa_id');
    final email = prefs.getString('email') ?? '';
    final planoUser = prefs.getString("plano_usuario") ?? "user";

    // 1️⃣ Não logado → Login
    if (usuarioId == null || empresaId == null) {
      setState(() => _startScreen = const LoginScreen());
      return;
    }

    // 2️⃣ Logado → Home (SEM BLOQUEIO)
    setState(() => _startScreen = HomeScreen(
      usuarioId: usuarioId,
      empresaId: empresaId,
      plano: planoUser,
      email: email,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Tooca CRM',

      theme: ThemeData(
        useMaterial3: false,
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFC107),
          foregroundColor: Colors.black,
          centerTitle: true,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC107),
        ),
      ),

      home: _startScreen,
    );
  }
}
