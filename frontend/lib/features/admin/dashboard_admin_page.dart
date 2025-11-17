import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registro_horario/routers/app_routers.dart';
import 'package:registro_horario/services/auth_service.dart';
import 'package:registro_horario/theme_provider.dart';

class DashboardAdminPage extends StatelessWidget {
  const DashboardAdminPage({super.key});

  Future<void> logout(BuildContext context) async {
    await AuthService.logout();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? [const Color(0xFF0D1117), const Color(0xFF141A23)]
                    : [const Color(0xFF007BFF), const Color(0xFF001F5C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(color: Colors.black.withOpacity(0.03)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Panel de administración",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Gestión del sistema",
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withOpacity(
                                .6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: "Cambiar tema",
                            icon: Icon(
                              dark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              size: 24,
                              color: theme.colorScheme.onSurface,
                            ),
                            onPressed: () => Provider.of<ThemeProvider>(
                              context,
                              listen: false,
                            ).toggleTheme(),
                          ),
                          IconButton(
                            tooltip: "Cerrar sesión",
                            icon: Icon(
                              Icons.logout_rounded,
                              size: 24,
                              color: dark
                                  ? Colors.red.shade300
                                  : Colors.red.shade600,
                            ),
                            onPressed: () => logout(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // GRID SIN REPORTES
                  Expanded(
                    child: GridView(
                      padding: EdgeInsets.zero,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 1.2,
                            mainAxisSpacing: 22,
                            crossAxisSpacing: 22,
                          ),
                      children: [
                        _dashCard(
                          context,
                          icon: Icons.people_alt_rounded,
                          title: "Empleados",
                          route: AppRoutes.empleados,
                          color: Colors.blueAccent,
                        ),
                        _dashCard(
                          context,
                          icon: Icons.mail_rounded,
                          title: "Invitar",
                          route: AppRoutes.enviarInvitacion,
                          color: Colors.purpleAccent,
                        ),
                        _dashCard(
                          context,
                          icon: Icons.message_rounded,
                          title: "Mensajes",
                          route: AppRoutes.enviarMensaje,
                          color: Colors.tealAccent,
                        ),
                        _dashCard(
                          context,
                          icon: Icons.settings_rounded,
                          title: "Ajustes",
                          route: AppRoutes.adminSettings,
                          color: Color(0xFFE75026), // 🔵 NUEVO COLOR
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: route.isNotEmpty
          ? () => Navigator.pushNamed(context, route)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: dark
              ? Colors.white.withOpacity(.07)
              : Colors.white.withOpacity(.9),
          border: Border.all(
            color: dark
                ? Colors.white.withOpacity(.1)
                : Colors.black.withOpacity(.06),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 8),
              color: color.withOpacity(.25),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withOpacity(.18),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
