import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registro_horario/routers/app_routers.dart';
import 'package:registro_horario/services/auth_service.dart';
import 'package:registro_horario/theme_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passController = TextEditingController();
  bool loading = false;
  bool showPassword = false;

  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    emailController.dispose();
    passController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Rellena todos los campos")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final data = await AuthService.login(
        emailController.text.trim(),
        passController.text,
      );

      final rol = data["user"]["rol"];

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        rol == "admin" ? AppRoutes.adminDashboard : AppRoutes.fichaje,
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Credenciales incorrectas")),
      );
    }

    setState(() => loading = false);
  }

  InputDecoration _decor(String hint, IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(.07)
          : Colors.grey.shade100,
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white54
            : Colors.grey.shade600,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? [
                        const Color(0xFF0D1117),
                        const Color(0xFF1E2A78),
                      ]
                    : [
                        const Color(0xFF001F5C),
                        const Color(0xFF007BFF),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Icon(
                dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: dark ? Colors.yellow.shade400 : Colors.white,
                size: 28,
              ),
              onPressed: () => Provider.of<ThemeProvider>(
                context,
                listen: false,
              ).toggleTheme(),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 420,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 40,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white.withOpacity(.04)
                          : Colors.white.withOpacity(.9),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.25),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_clock_rounded,
                          size: 90,
                          color: dark
                              ? Colors.blue.shade300
                              : Colors.blue.shade600,
                        ),

                        const SizedBox(height: 10),

                        Text(
                          "Bienvenido",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : Colors.grey.shade800,
                          ),
                        ),

                        const SizedBox(height: 35),

                        TextField(
                          controller: emailController,
                          style: TextStyle(
                            color: dark ? Colors.white : Colors.black87,
                          ),
                          decoration: _decor("Email", Icons.email_rounded),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: passController,
                          obscureText: !showPassword,
                          style: TextStyle(
                            color: dark ? Colors.white : Colors.black87,
                          ),
                          decoration: _decor("Contraseña", Icons.lock_rounded)
                              .copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    showPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () => setState(
                                    () => showPassword = !showPassword,
                                  ),
                                ),
                              ),
                        ),

                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: loading ? null : login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: loading
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "Iniciar sesión",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        TextButton(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            AppRoutes.plans,
                          ),
                          child: Text(
                            "Registrar empresa",
                            style: TextStyle(
                              fontSize: 14,
                              color: dark
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade700,
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
        ],
      ),
    );
  }
}
