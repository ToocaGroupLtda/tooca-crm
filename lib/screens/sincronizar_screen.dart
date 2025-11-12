// =============================================================
// 🔄 TOOCA CRM - Tela de Sincronização (v2.0 SaaS Multiempresa)
// -------------------------------------------------------------
// Compatível com parâmetros diretos (empresaId, usuarioId, plano)
// e também com fallback automático via SharedPreferences.
// =============================================================

import 'package:app_tooca_crm/screens/sincronizacao_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SincronizarScreen extends StatefulWidget {
  final int? usuarioId;
  final int? empresaId;
  final String? plano;

  const SincronizarScreen({
    Key? key,
    this.usuarioId,
    this.empresaId,
    this.plano,
  }) : super(key: key);

  @override
  State<SincronizarScreen> createState() => _SincronizarScreenState();
}

class _SincronizarScreenState extends State<SincronizarScreen> {
  bool sincronizando = false;
  String mensagem = 'Pronto para sincronizar.';
  int empresaId = 0;
  int usuarioId = 0;
  String plano = 'free';

  @override
  void initState() {
    super.initState();
    _carregarSessao();
  }

  Future<void> _carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();

    // Se vierem do widget, prioriza eles
    empresaId = widget.empresaId ?? prefs.getInt('empresa_id') ?? 0;
    usuarioId = widget.usuarioId ?? prefs.getInt('usuario_id') ?? 0;
    plano = widget.plano ?? prefs.getString('plano') ?? 'free';

    setState(() {});
    debugPrint('🟢 Sessão ativa → empresa=$empresaId, usuario=$usuarioId, plano=$plano');
  }

  Future<void> _executarSincronizacao() async {
    if (empresaId == 0) {
      setState(() => mensagem = '⚠️ Empresa não identificada. Faça login novamente.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Erro: empresa não identificada. Faça login novamente.')),
      );
      return;
    }

    setState(() {
      sincronizando = true;
      mensagem = '🔄 Sincronizando dados...';
    });

    await SincronizacaoService.sincronizarTudo(context, empresaId);

    setState(() {
      sincronizando = false;
      mensagem = '✅ Sincronização concluída!';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Sincronização'),
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                sincronizando ? Icons.sync : Icons.cloud_done,
                size: 80,
                color: sincronizando ? Colors.amber[800] : Colors.green,
              ),
              const SizedBox(height: 20),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: sincronizando ? null : _executarSincronizacao,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.sync),
                label: Text(
                  sincronizando ? 'Sincronizando...' : 'Sincronizar Agora',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 50),

              // =============================================================
              // 🔎 Identificador da Sessão
              // =============================================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('📦 Empresa ID: $empresaId', style: const TextStyle(color: Colors.black87)),
                    Text('👤 Usuário ID: $usuarioId', style: const TextStyle(color: Colors.black87)),
                    Text('💎 Plano: ${plano.toUpperCase()}', style: const TextStyle(color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
