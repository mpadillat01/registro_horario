import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:registro_horario/services/empresa_service.dart';

class InvitacionEnviarPage extends StatefulWidget {
  const InvitacionEnviarPage({super.key});

  @override
  State<InvitacionEnviarPage> createState() => _InvitacionEnviarPageState();
}

class _InvitacionEnviarPageState extends State<InvitacionEnviarPage> {
  final emailCtrl = TextEditingController();
  bool loading = false;

  Future<void> enviar() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty || !email.contains("@")) {
      _toast("⚠️ Introduce un email válido", error: true);
      return;
    }

    setState(() => loading = true);

    try {
      await EmpresaService.sendInvite(email);
      _toast("✅ Invitación enviada correctamente");
      Navigator.pop(context);
    } catch (e) {
      _toast("❌ Error al enviar la invitación", error: true);
    } finally {
      setState(() => loading = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 15)),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.blueAccent;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1116),
      appBar: AppBar(
        title: const Text("Invitar empleado",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(26),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 30,
                      color: color.withOpacity(.25),
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mail_outline_rounded,
                        size: 58, color: color.withOpacity(.9)),
                    const SizedBox(height: 20),

                    const Text(
                      "Enviar invitación",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Introduce el email del empleado para invitarlo a la empresa.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 26),

                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "ejemplo@empresa.com",
                        hintStyle: const TextStyle(color: Colors.white38),
                        labelText: "Email del empleado",
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon:
                            const Icon(Icons.email_rounded, color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Colors.white24, width: 1.3),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              BorderSide(color: color.withOpacity(.8), width: 1.6),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(.04),
                      ),
                    ),

                    const SizedBox(height: 26),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : enviar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                          shadowColor: color.withOpacity(.4),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: loading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Enviar invitación",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
