// =============================================================
// 🔄 TOOCA CRM - Tela de Sincronização (v7.1 EVA SUPREMA)
// -------------------------------------------------------------
// ✔ Checagem local + SaaS antes de abrir
// ✔ Bloqueio global integrado
// ✔ Compatível 100% com SincronizacaoService v7.1
// ✔ Layout Tooca Premium
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
  String planoEmpresa = 'free';
  String empresaExpira = '';

  @override
  void initState() {
    super.initState();
    _carregarSessao();
  }

  // =============================================================
  // 📦 CARREGA DO SHARED PREFERENCES
  // =============================================================
  Future<void> _carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();

    empresaId = widget.empresaId ?? prefs.getInt('empresa_id') ?? 0;
    usuarioId = widget.usuarioId ?? prefs.getInt('usuario_id') ?? 0;
    plano = widget.plano ?? prefs.getString('plano_usuario') ?? 'free';

    planoEmpresa = prefs.getString('plano_empresa') ?? 'free';
    empresaExpira = prefs.getString('empresa_expira') ?? '';

    debugPrint(
        '🟢 Sessão Sincr. → empresa=$empresaId | usuario=$usuarioId | plano_user=$plano | plano_emp=$planoEmpresa | exp=$empresaExpira'
    );

    // Verificação ANTES de mostrar a tela
    await _verificarStatusInicial();
  }

  // =============================================================
  // 🚫 VERIFICAÇÃO LOCAL + SAAS
  // =============================================================
  Future<void> _verificarStatusInicial() async {
    final ativaLocal = await SincronizacaoService.empresaAtivaLocal();

    if (!ativaLocal) {
      _enviarParaBloqueio();
      return;
    }

    // Consulta servidor SaaS
    await SincronizacaoService.consultarStatusEmpresa();

    final ativaDepois = await SincronizacaoService.empresaAtivaLocal();

    if (!ativaDepois) {
      _enviarParaBloqueio();
      return;
    }

    setState(() {});
  }

  // =============================================================
  // 🚪 ENVIA AO BLOQUEIO
  // =============================================================
  void _enviarParaBloqueio() {
    SincronizacaoService.irParaBloqueio(planoEmpresa, empresaExpira);

  }

  // =============================================================
  // 🔄 EXECUTAR SINCRONIZAÇÃO
  // =============================================================
  Future<void> _executarSincronizacao() async {
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

  // =============================================================
  // 🖥️ UI
  // =============================================================
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.sync),
                label: Text(
                  sincronizando ? 'Sincronizando...' : 'Sincronizar Agora',
                  style: const TextStyle(fontSize: 16),
                ),
              ),

              const SizedBox(height: 50),

              // =============================================================
              // 🔎 INFORMAÇÕES DA SESSÃO
              // =============================================================
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text('📦 Empresa ID: $empresaId'),
                    Text('👤 Usuário ID: $usuarioId'),
                    Text('💎 Plano Usuário: ${plano.toUpperCase()}'),
                    Text('🏢 Plano Empresa: ${planoEmpresa.toUpperCase()}'),
                    Text('⏳ Expira: $empresaExpira'),
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
