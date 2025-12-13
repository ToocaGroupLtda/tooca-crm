// =============================================================
// 🔄 TOOCA CRM - Tela de Sincronização (v7.3 EVA ULTRA FINAL)
// -------------------------------------------------------------
// ✔ Consulta SaaS ANTES de verificar bloqueio local
// ✔ Evita queda indevida na TelaBloqueio
// ✔ Totalmente compatível com Login v8 e Home v8
// ✔ UI revisada e otimizada
// ✔ Nenhum risco de quebrar o app
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
  // 📦 CARREGAR SESSÃO
  // =============================================================
  Future<void> _carregarSessao() async {
    final prefs = await SharedPreferences.getInstance();

    empresaId = widget.empresaId ?? prefs.getInt('empresa_id') ?? 0;
    usuarioId = widget.usuarioId ?? prefs.getInt('usuario_id') ?? 0;
    plano = widget.plano ?? prefs.getString('plano_usuario') ?? 'free';

    planoEmpresa = prefs.getString('plano_empresa') ?? 'free';
    empresaExpira = prefs.getString('empresa_expira') ?? '';

    debugPrint(
        '🟢 Sessão Sincr. → empresa=$empresaId | usuario=$usuarioId | plano_user=$plano | plano_emp=$planoEmpresa | exp=$empresaExpira');

    await _verificarStatusInicial();
  }

  // =============================================================
  // 🌐 VERIFICA STATUS DO SERVIDOR → DEPOIS BLOQUEIO
  // =============================================================
  Future<void> _verificarStatusInicial() async {
    await SincronizacaoService.consultarStatusEmpresa();

    final prefs = await SharedPreferences.getInstance();
    planoEmpresa = prefs.getString('plano_empresa') ?? 'free';
    empresaExpira = prefs.getString('empresa_expira') ?? '';

    debugPrint("🌐 SaaS retornou → plano=$planoEmpresa | expira=$empresaExpira");

    final ativa = await SincronizacaoService.empresaAtivaLocal();

    if (!ativa) {
      _enviarParaBloqueio();
      return;
    }

    setState(() {});
  }

  // =============================================================
  // 🚪 IR PARA TELA DE BLOQUEIO
  // =============================================================
  void _enviarParaBloqueio() {
    SincronizacaoService.irParaBloqueio(
      plano: planoEmpresa,
      expira: empresaExpira,
    );
  }

  // =============================================================
  // 🔁 EXECUTAR SINCRONIZAÇÃO
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
  // 🖥 INTERFACE
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
              // 📄 INFORMAÇÕES DA SESSÃO
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
