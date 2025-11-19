// ============================================================
// 🚫 TOOCA CRM - Tela de Bloqueio (v5.1 EVA SUPREMA SYNC)
// ------------------------------------------------------------
// ✔ Usa globalNavigatorKey
// ✔ Estatuto MASTER não interfere
// ✔ Limpa sessão corretamente
// ✔ Abrir WhatsApp seguro
// ✔ Layout estável e sem exceções
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart';
import 'login_screen.dart';

class TelaBloqueio extends StatelessWidget {
  final String planoEmpresa;
  final String empresaExpira;

  const TelaBloqueio({
    Key? key,
    required this.planoEmpresa,
    required this.empresaExpira,
  }) : super(key: key);

  // ============================================================
  // 📞 ABRIR WHATSAPP — agora 100% seguro
  // ============================================================
  Future<void> abrirWhatsapp() async {
    const numero = "5511942815500";

    final msg = Uri.encodeComponent(
      "Olá! Minha empresa está bloqueada no Tooca CRM.\n"
          "Plano: $planoEmpresa\n"
          "Expiração: $empresaExpira\n"
          "Preciso de ajuda para reativar.",
    );

    final url = Uri.parse("https://wa.me/$numero?text=$msg");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("⚠️ Não foi possível abrir o WhatsApp.");
    }
  }

  // ============================================================
  // 🔄 LIMPAR SESSÃO E VOLTAR AO LOGIN
  // ============================================================
  Future<void> irParaLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    globalNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.red),
                const SizedBox(height: 20),

                const Text(
                  "Período de uso expirado.\nContate o suporte para atualizar sua assinatura.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  "Validade: $empresaExpira",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 30),

                // ============================================================
                // 🟢 BOTÃO WHATSAPP
                // ============================================================
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async => await abrirWhatsapp(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Chamar no WhatsApp",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ============================================================
                // 🟡 BOTÃO LOGIN
                // ============================================================
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async => await irParaLogin(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Fazer login novamente",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
