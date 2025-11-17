import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:registro_horario/features/admin/empleado_detalle_page.dart';
import 'package:registro_horario/services/usuario_service.dart';
import 'package:registro_horario/theme_provider.dart';

class EmpleadosPage extends StatefulWidget {
  const EmpleadosPage({super.key});

  @override
  State<EmpleadosPage> createState() => _EmpleadosPageState();
}

class _EmpleadosPageState extends State<EmpleadosPage> {
  List empleados = [];
  List filtered = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    try {
      final data = await EmpleadoService.getEmpleados();
      setState(() {
        empleados = data;
        filtered = data;
        loading = false;
      });
    } catch (_) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Error cargando empleados")),
      );
    }
  }

  void filtrar(String text) {
    setState(() {
      filtered = empleados
          .where(
            (e) =>
                e["nombre"].toLowerCase().contains(text.toLowerCase()) ||
                e["email"].toLowerCase().contains(text.toLowerCase()),
          )
          .toList();
    });
  }

  Color rolColor(String r) =>
      r == "admin" ? Colors.amberAccent : Colors.greenAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(85),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              automaticallyImplyLeading: false,
              elevation: 0,
              backgroundColor: Theme.of(
                context,
              ).scaffoldBackgroundColor.withOpacity(.55),
              centerTitle: false,
              titleSpacing: 20,
              toolbarHeight: 85,

              leading: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: IconButton(
                  splashRadius: 28,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    size: 28,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(.85),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Gestión de empleados",
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "Control y supervisión en tiempo real",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(.6),
                    ),
                  ),
                ],
              ),

              actions: [
                // Botón de refrescar
                IconButton(
                  splashRadius: 24,
                  tooltip: "Recargar",
                  icon: const Icon(Icons.refresh_rounded, size: 24),
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(.85),
                  onPressed: cargar,
                ),

                // Modo claro/oscuro
                IconButton(
                  splashRadius: 24,
                  tooltip: "Cambiar tema",
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 24,
                  ),
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(.85),
                  onPressed: () => Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  ).toggleTheme(),
                ),

                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),

      extendBodyBehindAppBar: true,

      body: Stack(
        children: [
          // Fondo premium
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? [const Color(0xFF0C0F14), const Color(0xFF1B1F29)]
                    : [const Color(0xFFDCE9FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 90),

              /// 🔍 BUSCADOR PREMIUM FLOATING
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.1),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: dark
                              ? Colors.white.withOpacity(.05)
                              : Colors.white.withOpacity(.7),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: dark
                                ? Colors.white.withOpacity(.08)
                                : Colors.black.withOpacity(.05),
                          ),
                        ),
                        child: TextField(
                          onChanged: filtrar,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: "Buscar empleado...",
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              /// 📄 LISTADO
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final e = filtered[i];
                          final inicial = e["nombre"][0].toUpperCase();
                          final rol = e["rol"];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EmpleadoDetallePage(empleado: e),
                                ),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: dark
                                    ? Colors.white.withOpacity(.06)
                                    : Colors.white.withOpacity(.85),
                                border: Border.all(
                                  color: dark
                                      ? Colors.white.withOpacity(.07)
                                      : Colors.black.withOpacity(.05),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: dark
                                        ? Colors.black.withOpacity(.4)
                                        : Colors.blue.withOpacity(.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),

                              child: Row(
                                children: [
                                  // Avatar premium circular
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blueAccent,
                                          Colors.cyanAccent.shade400,
                                        ],
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 27,
                                      backgroundColor: dark
                                          ? Colors.black
                                          : Colors.white,
                                      child: Text(
                                        inicial,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.blueAccent.shade700,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // Nombre + email
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e["nombre"],
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          e["email"],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: theme.colorScheme.onSurface
                                                .withOpacity(.55),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Rol badge pro
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: rolColor(rol).withOpacity(.15),
                                      border: Border.all(
                                        color: rolColor(rol).withOpacity(.5),
                                      ),
                                    ),
                                    child: Text(
                                      rol.toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: rolColor(rol),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 26,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(.35),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
