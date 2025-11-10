import 'package:flutter/material.dart';
import 'package:registro_horario/routers/app_routers.dart';
import 'package:registro_horario/services/auth_service.dart';

class RegisterCompanyPage extends StatefulWidget {
  const RegisterCompanyPage({super.key});

  @override
  State<RegisterCompanyPage> createState() => _RegisterCompanyPageState();
}

class _RegisterCompanyPageState extends State<RegisterCompanyPage>
    with SingleTickerProviderStateMixin {
  final nameCtrl = TextEditingController();
  final adminCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  bool showPass = false;

  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    nameCtrl.dispose();
    adminCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (nameCtrl.text.isEmpty ||
        adminCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Completa todos los campos"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await AuthService.registerCompany(
        nameCtrl.text.trim(),
        adminCtrl.text.trim(),
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.plans);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Error al registrar empresa"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5BC3FF), Color(0xFF4C7EFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.90),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.business_center_rounded,
                    size: 90,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),

                  Text(
                    "Registrar empresa",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade800,
                    ),
                  ),

                  const SizedBox(height: 35),

                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      labelText: "Nombre de la empresa",
                      prefixIcon: const Icon(Icons.apartment_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: adminCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      labelText: "Nombre del administrador",
                      prefixIcon: const Icon(Icons.person_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: passCtrl,
                    obscureText: !showPass,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      labelText: "Contraseña",
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPass ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => showPass = !showPass),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: loading ? null : register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Crear empresa",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.login,
                    ),
                    child: const Text(
                      "Ya tengo una empresa / Iniciar sesión",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
