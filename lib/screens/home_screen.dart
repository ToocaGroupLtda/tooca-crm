// =============================================================
// 🏠 TOOCA CRM - HOME SCREEN (v8.2 EVA SUPREMA FINAL)
// -------------------------------------------------------------
// ✔ NUNCA consulta SaaS automaticamente (somente no Sincronizar)
// ✔ Bloqueio 100% alinhado com Login + Splash
// ✔ Usa apenas empresa_status + empresa_expira
// ✔ Nunca sobrescreve sessão válida com dados antigos
// ✔ Fluxo estável e sem quedas na TelaBloqueio
// =============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_tooca_crm/screens/sincronizacao_service.dart';
import 'package:app_tooca_crm/screens/sincronizar_screen.dart';
import 'package:app_tooca_crm/screens/pedidos_screen.dart';
import 'package:app_tooca_crm/screens/clientes_screen.dart';
import 'package:app_tooca_crm/screens/novo_pedido_screen.dart';
import 'package:app_tooca_crm/screens/login_screen.dart';

import 'TelaBloqueio.dart';

class HomeScreen extends StatefulWidget {
  final int usuarioId;
  final int empresaId;
  final String plano;
  final String email;

  const HomeScreen({
    Key? key,
    required this.usuarioId,
    required this.empresaId,
    required this.plano,
    required this.email,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String nomeUsuario = "";
  String planoEmpresa = "free";
  String empresaExpira = "";

  @override
  void initState() {
    super.initState();
    carregarSessao();
  }

  // =============================================================
  // 🔍 CARREGAR DADOS DA SESSÃO (SEM CONSULTAR NADA)
  // =============================================================
  Future<void> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();

    nomeUsuario = prefs.getString("nome") ?? "";
    planoEmpresa = prefs.getString("plano_empresa") ?? "free";
    empresaExpira = prefs.getString("data_expiracao") ?? "";


    debugPrint(
        "🏠 HOME v8.2 Sessão carregada → "
            "user=${widget.usuarioId} | empresa=${widget.empresaId} | plano=$planoEmpresa | expira=$empresaExpira"
    );

    setState(() {});
  }

  // =============================================================
  // ✔ VALIDAÇÃO OFICIAL (SEM RECONSULTAR SAAS)
  // =============================================================
  Future<bool> validarEmpresa() async {
    final ativa = await SincronizacaoService.empresaAtivaLocal();
    if (!ativa) {
      _bloquear();
      return false;
    }
    return true;
  }

  // =============================================================
  // 🚫 IR PARA TELA DE BLOQUEIO (GLOBAL)
  // =============================================================
  void _bloquear() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TelaBloqueio(
          planoEmpresa: planoEmpresa,
          empresaExpira: empresaExpira,
        ),
      ),
    );
  }

  // =============================================================
  // 🚪 SAIR DO APP
  // =============================================================
  Future<void> sair() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  // =============================================================
  // 🖥️ UI / MENU
  // =============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        title: const Text(
          'Tooca CRM',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: sair),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "👋 Olá, $nomeUsuario",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  // =============================================================
                  // 🟡 NOVO PEDIDO
                  // =============================================================
                  _buildCard(
                    icon: Icons.note_add_outlined,
                    label: "Novo Pedido",
                    onTap: () async {
                      if (!await validarEmpresa()) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NovoPedidoScreen(
                            usuarioId: widget.usuarioId,
                            empresaId: widget.empresaId,
                            plano: planoEmpresa,
                          ),
                        ),
                      );
                    },
                  ),

                  // =============================================================
                  // 🧾 PEDIDOS
                  // =============================================================
                  _buildCard(
                    icon: Icons.receipt_long,
                    label: "Pedidos",
                    onTap: () async {
                      if (!await validarEmpresa()) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PedidosScreen(
                            usuarioId: widget.usuarioId,
                            empresaId: widget.empresaId,
                            plano: planoEmpresa,
                          ),
                        ),
                      );
                    },
                  ),

                  // =============================================================
                  // 👥 CLIENTES
                  // =============================================================
                  _buildCard(
                    icon: Icons.people_outline,
                    label: "Clientes",
                    onTap: () async {
                      if (!await validarEmpresa()) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientesScreen(
                            usuarioId: widget.usuarioId,
                            empresaId: widget.empresaId,
                            plano: planoEmpresa,
                          ),
                        ),
                      );
                    },
                  ),

                  // =============================================================
                  // 🔄 SINCRONIZAR
                  // =============================================================
                  _buildCard(
                    icon: Icons.sync,
                    label: "Sincronizar",
                    onTap: () async {
                      if (!await validarEmpresa()) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SincronizarScreen(
                            usuarioId: widget.usuarioId,
                            empresaId: widget.empresaId,
                            plano: planoEmpresa,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================================
  // 💛 CARD DO MENU
  // =============================================================
  Widget _buildCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.amber[800], size: 48),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
