import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registro_horario/routers/app_routers.dart';
import 'package:registro_horario/theme_provider.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

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
                    ? [const Color(0xFF0D1117), const Color(0xFF1E2A78)]
                    : [const Color(0xFF001F5C), const Color(0xFF007BFF)],
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
                color: dark ? Colors.yellow.shade300 : Colors.white,
                size: 28,
              ),
              onPressed: () => Provider.of<ThemeProvider>(
                context,
                listen: false,
              ).toggleTheme(),
            ),
          ),

          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 50,
                  ),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withOpacity(.05)
                        : Colors.white.withOpacity(.92),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.25),
                        blurRadius: 25,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 95,
                        color: dark
                            ? Colors.blue.shade300
                            : Colors.blue.shade600,
                      ),

                      const SizedBox(height: 14),

                      Text(
                        "Registro Horario",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: dark ? Colors.white : Colors.grey.shade800,
                        ),
                      ),

                      Text(
                        "Control laboral moderno y eficiente",
                        style: TextStyle(
                          color: dark ? Colors.white60 : Colors.grey.shade600,
                          fontSize: 15,
                        ),
                      ),

                      const SizedBox(height: 40),

                      _btnPrimary(
                        txt: "Iniciar sesión",
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.login),
                      ),
                      const SizedBox(height: 14),

                      _btnSecondary(
                        txt: "Registrar empresa",
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes
                              .plans, // 👉 ahora primero lleva a los planes
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btnPrimary({required String txt, required Function() onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          txt,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _btnSecondary({required String txt, required Function() onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.blue.shade500, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          txt,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.blue.shade600,
          ),
        ),
      ),
    );
  }
}
