import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registro_horario/services/usuario_service.dart';
import 'package:registro_horario/theme_provider.dart';

class EmpleadoDetallePage extends StatefulWidget {
  final Map empleado;
  const EmpleadoDetallePage({super.key, required this.empleado});

  @override
  State<EmpleadoDetallePage> createState() => _EmpleadoDetallePageState();
}

class _EmpleadoDetallePageState extends State<EmpleadoDetallePage> {
  List horas = [];
  bool loading = true;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    cargar();

    // ⏱️ refrescar cada segundo para contar horas en vivo
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await EmpleadoService.cargarEstadoActual(widget.empleado["id"]);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> cargar() async {
    await EmpleadoService.cargarEstadoActual(widget.empleado["id"]);
    final data = await EmpleadoService.getHorasEmpleado(widget.empleado["id"]);
    setState(() {
      horas = data;
      loading = false;
    });
  }

  /// ✅ Formato numérico a "xh ym"
  String f(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return "${hh}h ${mm.toString().padLeft(2, "0")}m";
  }

  /// ✅ Obtener estado actual y horas en vivo
  Map<String, dynamic> getEmpleadoEstado() {
    final estado = EmpleadoService.estadoFromAPI();
    final entradaStr =
        EmpleadoService.ultimoFichajeEstado?["hora"] ??
        EmpleadoService.ultimoFichajeEstado?["fecha_hora"];

    DateTime? entrada;
    if (entradaStr != null) entrada = DateTime.parse(entradaStr).toLocal();

    Duration diff = Duration.zero;
    if (estado == "entrada" && entrada != null) {
      diff = DateTime.now().difference(entrada);
    }

    // Total acumulado
    double total = horas.fold(0.0, (sum, e) => sum + (e["horas"] ?? 0.0));
    if (estado == "entrada" && entrada != null) {
      total += diff.inSeconds / 3600.0;
    }

    // Horas de hoy
    double hoy = 0.0;
    final hoyFecha = DateTime.now();
    for (var h in horas) {
      final d = DateTime.parse(h["fecha"]);
      if (d.year == hoyFecha.year &&
          d.month == hoyFecha.month &&
          d.day == hoyFecha.day) {
        hoy = h["horas"] ?? 0.0;
      }
    }

    // Si está trabajando, sumar tiempo activo ahora
    if (estado == "entrada" && entrada != null) {
      hoy += diff.inSeconds / 3600.0;
    }

    return {
      "estado": estado,
      "entrada": entrada,
      "total": total,
      "hoy": hoy,
      "texto": estado == "entrada"
          ? "Trabajando"
          : estado == "pausa"
          ? "En pausa"
          : "Fuera de jornada",
      "color": estado == "entrada"
          ? Colors.greenAccent
          : estado == "pausa"
          ? Colors.amberAccent
          : Colors.redAccent,
      "icon": estado == "entrada"
          ? Icons.play_arrow_rounded
          : estado == "pausa"
          ? Icons.pause_rounded
          : Icons.stop_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    final data = getEmpleadoEstado();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.empleado["nombre"]),
        actions: [
          IconButton(
            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => Provider.of<ThemeProvider>(
              context,
              listen: false,
            ).toggleTheme(),
          ),
          const SizedBox(width: 6),
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
                    : [const Color(0xFFEAF4FF), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Avatar
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.blueAccent, Colors.cyanAccent],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: dark ? Colors.black : Colors.white,
                          child: Text(
                            widget.empleado["nombre"][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent.shade700,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        widget.empleado["email"],
                        style: TextStyle(
                          fontSize: 15,
                          color: theme.colorScheme.onSurface.withOpacity(.6),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ Estado pill
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: data["color"].withOpacity(.2),
                          border: Border.all(
                            color: data["color"].withOpacity(.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(data["icon"], color: data["color"]),
                            const SizedBox(width: 6),
                            Text(
                              data["texto"],
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: data["color"],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        "Hoy: ${f(data["hoy"])}",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ Total card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: dark
                                ? Colors.white.withOpacity(.05)
                                : Colors.white.withOpacity(.85),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: dark
                                  ? Colors.white.withOpacity(.1)
                                  : Colors.black.withOpacity(.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Total trabajado",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                f(data["total"]),
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: (data["total"] / 40).clamp(0, 1),
                                minHeight: 7,
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Objetivo semanal: 40h",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),
                    Text(
                      "Historial",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (horas.isEmpty)
                      const Center(child: Text("Sin registros")),

                    ...horas.map((h) {
                      double horasDia = h["horas"] * 1.0;

                      final d = DateTime.parse(h["fecha"]);
                      final hoy = DateTime.now();
                      final esHoy =
                          d.year == hoy.year &&
                          d.month == hoy.month &&
                          d.day == hoy.day;

                      if (esHoy) horasDia = data["hoy"];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: dark
                              ? Colors.white.withOpacity(.05)
                              : Colors.white.withOpacity(.9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              h["fecha"],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              f(horasDia),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: horasDia >= 8
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
        ],
      ),
    );
  }
}
