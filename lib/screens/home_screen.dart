// =============================================================
// 🏠 TOOCA CRM - HOME SCREEN (v4.4 SaaS Multiempresa)
// -------------------------------------------------------------
// Tela principal: menu, sincronização e acesso rápido aos módulos
// =============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🧩 Importação das telas
import 'package:app_tooca_crm/screens/sincronizar_screen.dart';
import 'package:app_tooca_crm/screens/pedidos_screen.dart';
import 'package:app_tooca_crm/screens/clientes_screen.dart';
import 'package:app_tooca_crm/screens/novo_pedido_screen.dart';
import 'package:app_tooca_crm/screens/login_screen.dart';

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
  String nomeUsuario = '';

  @override
  void initState() {
    super.initState();
    carregarSessao();
  }

  Future<void> carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getInt('usuario_id') ?? widget.usuarioId;
    final empresaId = prefs.getInt('empresa_id') ?? widget.empresaId;
    final plano = prefs.getString('plano') ?? widget.plano;

    debugPrint('🟢 Sessão ativa → usuario=$usuarioId | empresa=$empresaId | plano=$plano');

    setState(() {
      nomeUsuario = prefs.getString('nome') ?? widget.email.split('@').first;
    });
  }

  Future<void> sair() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFCC00),
        foregroundColor: Colors.black,
        title: const Text(
          'Tooca CRM',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: sair,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '👋 Olá, $nomeUsuario',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [

                  // =====================================================
                  // 🧾 NOVO PEDIDO
                  // =====================================================
                  _buildCard(
                    icon: Icons.note_add_outlined,
                    label: 'Novo Pedido',
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final empresaId = prefs.getInt('empresa_id') ?? widget.empresaId;
                      final usuarioId = prefs.getInt('usuario_id') ?? widget.usuarioId;
                      final plano = prefs.getString('plano') ?? widget.plano;

                      debugPrint('🟡 Novo Pedido → empresa=$empresaId | usuario=$usuarioId | plano=$plano');

                      if (empresaId == 0 || usuarioId == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('⚠️ Sessão inválida. Faça login novamente.')),
                        );
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NovoPedidoScreen(
                            usuarioId: usuarioId,
                            empresaId: empresaId,
                            plano: plano,
                          ),
                        ),
                      );
                    },
                  ),

                  // =====================================================
                  // 📋 PEDIDOS
                  // =====================================================
                  _buildCard(
                    icon: Icons.receipt_long,
                    label: 'Pedidos',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PedidosScreen(
                            usuarioId: widget.usuarioId,
                            empresaId: widget.empresaId,
                            plano: widget.plano, // ✅ adicionado corretamente
                          ),
                        ),
                      );
                    },
                  ),


                  // =====================================================
                  // 👥 CLIENTES
                  // =====================================================
                  _buildCard(
                    icon: Icons.people_outline,
                    label: 'Clientes',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClientesScreen(
                            usuarioId: widget.usuarioId,
                            empresaId: widget.empresaId,
                            plano: widget.plano,
                          ),
                        ),
                      );
                    },
                  ),

                  // =====================================================
                  // 🔄 SINCRONIZAR
                  // =====================================================
                  _buildCard(
                    icon: Icons.sync,
                    label: 'Sincronizar',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SincronizarScreen(
                            usuarioId: widget.usuarioId,
                            empresaId: widget.empresaId,
                            plano: widget.plano,
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
  // 🔧 CARD PADRÃO
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
