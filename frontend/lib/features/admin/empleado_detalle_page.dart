import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:registro_horario/services/usuario_service.dart';
import 'package:registro_horario/theme_provider.dart';
import 'package:registro_horario/utils/fichaje_utils.dart';

class EmpleadoDetallePage extends StatefulWidget {
  final Map empleado;
  const EmpleadoDetallePage({super.key, required this.empleado});

  @override
  State<EmpleadoDetallePage> createState() => _EmpleadoDetallePageState();
}

class _EmpleadoDetallePageState extends State<EmpleadoDetallePage> {
  bool cargando = true;
  Timer? timer;
  List<Map<String, dynamic>> historial = [];

  double horasHoy = 0, horasTotales = 0, horasPromedio = 0;
  String estado = "fuera";
  DateTime? entradaActual;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    timer = Timer.periodic(const Duration(minutes: 1), (_) => _cargarDatos());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      print("🔄 Cargando estado y horas del empleado ${widget.empleado["id"]}");

      await EmpleadoService.cargarEstadoActual(widget.empleado["id"]);

      // 1️⃣ Intentamos primero obtener las horas diarias ya calculadas (si existen)
      final data = await EmpleadoService.getHorasEmpleado(
        widget.empleado["id"],
      );
      print("📊 Datos recibidos: $data");

      // 2️⃣ Si el endpoint devuelve vacío o solo el día actual → reconstruimos desde los fichajes
      if (data == null || data.isEmpty || data.length <= 1) {
        print("⚠️ Datos insuficientes, reconstruyendo desde fichajes...");

        final fichajes = await EmpleadoService.getHistorialEmpleado(
          widget.empleado["id"],
        );

        print("📜 Total fichajes encontrados: ${fichajes.length}");

        final Map<String, double> horasPorDia = {};

        for (var f in fichajes) {
          final entradaStr = f["entrada"] ?? f["fecha_entrada"];
          final salidaStr = f["salida"] ?? f["fecha_salida"];
          if (entradaStr == null || salidaStr == null) continue;

          final entrada = DateTime.parse(entradaStr).toLocal();
          final salida = DateTime.parse(salidaStr).toLocal();
          final diff = salida.difference(entrada).inMinutes / 60.0;

          final fechaKey = DateFormat('yyyy-MM-dd').format(entrada);
          horasPorDia[fechaKey] = (horasPorDia[fechaKey] ?? 0) + diff;
        }

        historial =
            horasPorDia.entries.map((e) {
              return {"fecha": e.key, "horas": e.value};
            }).toList()..sort((a, b) {
              final fechaA = DateTime.parse(a["fecha"] as String);
              final fechaB = DateTime.parse(b["fecha"] as String);
              return fechaB.compareTo(fechaA);
            });

        print("✅ Historial reconstruido con ${historial.length} días.");
      } else {
        // 3️⃣ Si el backend devuelve horas por día correctamente
        historial =
            List<Map<String, dynamic>>.from(data).map((e) {
              final raw = e["horas"];
              final horas = switch (raw) {
                null => 0.0,
                double v => v,
                int v => v.toDouble(),
                String s => double.tryParse(s.replaceAll(',', '.')) ?? 0.0,
                _ => 0.0,
              };

              return {"fecha": e["fecha"] ?? e["fecha_hora"], "horas": horas};
            }).toList()..sort(
              (a, b) => DateTime.parse(
                b["fecha"],
              ).compareTo(DateTime.parse(a["fecha"])),
            );
      }

      // 4️⃣ Estado actual (trabajando, pausa, fuera)
      estado = EmpleadoService.estadoFromAPI();
      final entradaStr =
          EmpleadoService.ultimoFichajeEstado?["hora"] ??
          EmpleadoService.ultimoFichajeEstado?["fecha_hora"];
      if (entradaStr != null) {
        final fecha = FichajeUtils.parseUtcToLocal(entradaStr);
        entradaActual = estado == "entrada" ? fecha : null;
      }

      // 5️⃣ Cálculos de métricas
      final now = DateTime.now();
      final hoyKey = DateFormat('yyyy-MM-dd').format(now);

      horasTotales = historial.fold(0.0, (sum, e) => sum + (e["horas"] ?? 0.0));

      final diasActivos = historial
          .where((e) => (e["horas"] ?? 0) > 0)
          .map(
            (e) => DateFormat('yyyy-MM-dd').format(DateTime.parse(e["fecha"])),
          )
          .toSet();

      horasHoy = historial
          .where(
            (e) =>
                DateFormat('yyyy-MM-dd').format(DateTime.parse(e["fecha"])) ==
                hoyKey,
          )
          .fold(0.0, (sum, e) => sum + (e["horas"] ?? 0.0));

      horasPromedio = diasActivos.isEmpty
          ? 0
          : horasTotales / diasActivos.length;

      // Si está trabajando ahora → añadir tiempo en curso
      if (estado == "entrada" && entradaActual != null) {
        final diff = now.difference(entradaActual!);
        final horasEnCurso = diff.inMinutes / 60.0;
        horasHoy += horasEnCurso;
        horasTotales += horasEnCurso;
      }

      print("✅ Datos cargados correctamente con ${historial.length} días.");
    } catch (e, st) {
      print("❌ Error cargando datos: $e");
      print(st);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  String f(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return "${hh}h ${mm.toString().padLeft(2, "0")}m";
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colorEstado = switch (estado) {
      "entrada" => Colors.greenAccent,
      "pausa" => Colors.amberAccent,
      _ => Colors.redAccent,
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.empleado["nombre"],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              dark ? Icons.light_mode : Icons.dark_mode,
              color: colorEstado,
            ),
            onPressed: () => Provider.of<ThemeProvider>(
              context,
              listen: false,
            ).toggleTheme(),
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? [const Color(0xFF0D1117), const Color(0xFF1C2232)]
                : [const Color(0xFFF6F8FF), const Color(0xFFE4EBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 20,
                ),
                physics: const BouncingScrollPhysics(),
                children: [
                  _avatar(widget.empleado["nombre"], colorEstado, dark),
                  const SizedBox(height: 16),
                  _chipEstado(estado, colorEstado),
                  const SizedBox(height: 26),
                  _metricas(dark, colorEstado),
                  const SizedBox(height: 26),
                  _buildHistorialVisual(dark),
                ],
              ),
      ),
    );
  }

  // ----------------------------------------------------------
  // UI ELEMENTOS
  // ----------------------------------------------------------
  Widget _avatar(String nombre, Color color, bool dark) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "U";
    return Center(
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Colors.blueAccent, Colors.cyanAccent],
          ),
        ),
        child: CircleAvatar(
          radius: 48,
          backgroundColor: dark ? Colors.black : Colors.white,
          child: Text(
            inicial,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipEstado(String estado, Color color) {
    String label = switch (estado) {
      "entrada" => "🟢 Trabajando",
      "pausa" => "🟡 En pausa",
      _ => "🔴 Fuera de jornada",
    };
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color),
          color: color.withOpacity(.1),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _metricas(bool dark, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _metric("Hoy", f(horasHoy), color, dark)),
            const SizedBox(width: 14),
            Expanded(child: _metric("Total", f(horasTotales), color, dark)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _metric("Promedio", f(horasPromedio), color, dark)),
          ],
        ),
      ],
    );
  }

  Widget _metric(String title, String value, Color color, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: dark ? Colors.white10 : Colors.white,
      ),
      child: Column(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: dark ? Colors.white60 : Colors.black54,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // HISTORIAL VISUAL (con barra de progreso)
  // ----------------------------------------------------------
  Widget _buildHistorialVisual(bool dark) {
    final theme = Theme.of(context);

    if (historial.isEmpty) {
      return Center(
        child: Text(
          "Sin registros recientes",
          style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(.7)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Historial agrupado por días",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...historial.map((h) {
          final fecha = DateTime.parse(h["fecha"]);
          final hoy = DateTime.now();
          final esHoy = FichajeUtils.isSameDay(fecha, hoy);
          final horasDia = esHoy ? horasHoy : (h["horas"] ?? 0.0);
          final cumplido = horasDia >= 8.0;
          final color = cumplido
              ? Colors.greenAccent
              : (horasDia >= 6 ? Colors.amberAccent : Colors.redAccent);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: dark
                  ? Colors.white.withOpacity(.04)
                  : Colors.black.withOpacity(.03),
              border: Border.all(
                color: esHoy
                    ? Colors.blueAccent.withOpacity(.5)
                    : Colors.transparent,
                width: esHoy ? 1.4 : 0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: color),
                    const SizedBox(width: 8),
                    Text(
                      esHoy
                          ? "Hoy (${DateFormat('d MMM', 'es_ES').format(fecha)})"
                          : DateFormat("EEEE d MMM", 'es_ES')
                                .format(fecha)
                                .replaceFirstMapped(
                                  RegExp(r'^\w'),
                                  (m) => m.group(0)!.toUpperCase(),
                                ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (horasDia / 8).clamp(0.0, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  valueColor: AlwaysStoppedAnimation(color),
                  backgroundColor: color.withOpacity(.15),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Horas trabajadas",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(.7),
                      ),
                    ),
                    Text(
                      f(horasDia),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    cumplido
                        ? "✅ Objetivo diario cumplido"
                        : "⏳ Por debajo del objetivo",
                    style: TextStyle(
                      color: color.withOpacity(.9),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
