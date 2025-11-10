import 'dart:ui';
import 'package:flutter/material.dart';
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("❌ Error cargando empleados")));
    }
  }

  void filtrar(String text) {
    setState(() {
      filtered = empleados.where((e) =>
          e["nombre"].toLowerCase().contains(text.toLowerCase()) ||
          e["email"].toLowerCase().contains(text.toLowerCase())).toList();
    });
  }

  Color rolColor(String r) => r == "admin" ? Colors.amber : Colors.greenAccent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Empleados"),
        actions: [
          IconButton(
            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () =>
                Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
          )
        ],
      ),

      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 700),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: dark
                    ? [const Color(0xFF0E1116), const Color(0xFF1A1F29)]
                    : [const Color(0xFFE8F2FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: TextField(
                      onChanged: filtrar,
                      decoration: InputDecoration(
                        hintText: "Buscar empleado...",
                        prefixIcon: const Icon(Icons.search, size: 22),
                        filled: true,
                        fillColor: dark
                            ? Colors.white.withOpacity(.06)
                            : Colors.white.withOpacity(.55),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                  builder: (_) => EmpleadoDetallePage(empleado: e),
                                ),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 260),
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: dark
                                    ? Colors.white.withOpacity(.06)
                                    : Colors.white.withOpacity(.9),
                                border: Border.all(
                                  color: dark
                                      ? Colors.white.withOpacity(.1)
                                      : Colors.black.withOpacity(.05),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.08),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  )
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Colors.blueAccent, Colors.cyanAccent],
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 26,
                                      backgroundColor:
                                          dark ? Colors.black : Colors.grey.shade100,
                                      child: Text(
                                        inicial,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueAccent.shade700,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e["nombre"],
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          e["email"],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: theme.colorScheme.onSurface.withOpacity(.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: rolColor(rol).withOpacity(.18),
                                      border: Border.all(color: rolColor(rol).withOpacity(.5)),
                                    ),
                                    child: Text(
                                      rol.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: rolColor(rol),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right_rounded,
                                      color: theme.colorScheme.onSurface.withOpacity(.4))
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
