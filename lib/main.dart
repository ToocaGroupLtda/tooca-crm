// =============================================================
// 🚀 TOOCA CRM - Main App (v6.0 EVA SUPREMA GOLD)
// -------------------------------------------------------------
// ✔ Sem SplashScreen
// ✔ Home NUNCA bloqueia
// ✔ Login + Sincronizar controlam bloqueio
// ✔ Main apenas decide se existe sessão válida
// ✔ Proteção contra sessão corrompida ou banco antigo
// ✔ Remove usuário_id fantasma (>5)
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
    DeviceOrientation.portraitDown,

  ]);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // NOVO: Tela de carregamento exibindo o nome Tooca CRM em fundo branco.
  Widget _startScreen = const Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Você pode colocar um Icon(Icons.business) ou o seu logo aqui!
          Text(
            'Tooca CRM',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black54, // Cor suave para o texto
            ),
          ),
          SizedBox(height: 20),
          // MANTEMOS UM INDICADOR SUTIL (opcional, mas recomendado)
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFFC107), // Cor da marca (Amarelo)
            ),
          ),
        ],
      ),
    ),
  );
  // ...

  @override
  void initState() {
    super.initState();
    _carregarSessaoInicial();
  }

  // =============================================================
  // 🔥 Carregar sessão inicial com proteção anti-banco-antigo
  // =============================================================
  Future<void> _carregarSessaoInicial() async {
    final prefs = await SharedPreferences.getInstance();

    int? usuarioId = prefs.getInt('usuario_id');
    int? empresaId = prefs.getInt('empresa_id');
    String email = prefs.getString('email') ?? '';
    String? planoEmpresa = prefs.getString("plano_empresa");

    // 🛑 Proteção anti-sessão corrompida → evita banco errado
    if (usuarioId == null || empresaId == null || usuarioId <= 0 || empresaId <= 0) {
      await prefs.clear();
      setState(() => _startScreen = const LoginScreen());
      return;
    }

    // 🛑 Proteção anti-usuário fantasma (id > 999 ou negativo)
    if (usuarioId > 999 || empresaId > 999) {
      await prefs.clear();
      setState(() => _startScreen = const LoginScreen());
      return;
    }

    // 🟢 Sessão válida → vai para Home (sem bloqueio)
    setState(() {
      _startScreen = HomeScreen(
        usuarioId: usuarioId,
        empresaId: empresaId,
        plano: planoEmpresa ?? 'desconhecido',
        email: email,
      );

    });
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
