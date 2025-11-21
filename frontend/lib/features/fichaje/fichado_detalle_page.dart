import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:registro_horario/services/fichaje_service.dart';
import 'package:registro_horario/services/auth_service.dart';
import 'package:registro_horario/utils/fichaje_utils.dart';

class FichadoDetallePage extends StatefulWidget {
  const FichadoDetallePage({super.key});

  @override
  State<FichadoDetallePage> createState() => _FichadoDetallePageState();
}

class _FichadoDetallePageState extends State<FichadoDetallePage>
    with TickerProviderStateMixin {
  bool loading = true;
  List<Map<String, dynamic>> historial = [];
  Map<String, dynamic>? ultimo;
  Timer? timer;
  DateTime? entradaActual;
  Duration trabajadoHoy = Duration.zero;

  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    cargar();
  }

  @override
  void dispose() {
    timer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  Future<void> cargar() async {
    final user = await AuthService.getCurrentUser();
    final uid = user["id"];

    final data = await FichajeService.obtenerHistorial();
    if (data != null && data is List) {
      historial = List<Map<String, dynamic>>.from(data).map((e) {
        return {
          "tipo": e["tipo"],
          "dt": FichajeUtils.parseUtcToLocal(e["fecha_hora"] ?? ""),
        };
      }).toList();
    }

    ultimo = await FichajeService.getUltimo(uid);

    if (ultimo?["estado"] == "entrada") {
      entradaActual = FichajeUtils.parseUtcToLocal(ultimo!["hora"] ?? "");
      _iniciarActualizacionEnVivo();
    }

    setState(() {
      trabajadoHoy = calcularTotalHoy();
      loading = false;
    });
  }

  void _iniciarActualizacionEnVivo() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ultimo?["estado"] == "entrada") {
        setState(() {
          trabajadoHoy = calcularTotalHoy();
        });
      }
    });
  }

  Duration calcularTotalHoy() {
    final hoy = DateTime.now();
    return FichajeUtils.calcularDuracionDia(historial, hoy);
  }

  String fmtHM(Duration d) {
    final hh = d.inHours;
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    return "${hh}h ${mm}m";
  }

  String fmtHMS(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hh:$mm:$ss";
  }

  Color estadoColor(String e) {
    switch (e) {
      case "entrada":
        return const Color(0xFF4B7BFF);
      case "inicio_pausa":
        return const Color(0xFFFFC04D);
      case "salida":
        return const Color(0xFFFF5C5C);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (loading) {
      return Scaffold(
        backgroundColor: dark ? const Color(0xFF0E1116) : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final estado = ultimo?["estado"] ?? "sin_registro";
    final totalDuracion = FichajeUtils.calcularTotal(historial);
    final color = estadoColor(estado);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0E1116) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Registro detallado",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: AnimatedContainer(
        duration: const Duration(seconds: 1),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: dark
                ? [const Color(0xFF11151F), const Color(0xFF1B2330)]
                : [const Color(0xFFF5F6FA), const Color(0xFFE3E7EF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                _glass(context, child: _estadoCard(estado, color)),
                const SizedBox(height: 20),
                _glass(context, child: _totalCard(totalDuracion, color)),
                const SizedBox(height: 26),
                _glass(context, child: _resumenDiario(color)),
                const SizedBox(height: 26),
                Text(
                  "Historial diario",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildHistorialDiario(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resumenDiario(Color color) {
    final objetivo = const Duration(hours: 8);
    final progreso = (trabajadoHoy.inSeconds / objetivo.inSeconds).clamp(
      0.0,
      1.0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Cumplimiento diario",
          style: TextStyle(color: Colors.white.withOpacity(.7)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: progreso,
                      strokeWidth: 8,
                      valueColor: AlwaysStoppedAnimation(color.withOpacity(.8)),
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Text(
                    "${(progreso * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                      color: color.withOpacity(.9),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 2,
              child: Text(
                "Has trabajado ${fmtHM(trabajadoHoy)} de 8h hoy.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(.85),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _glass(BuildContext context, {required Widget child}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(.04)
            : Colors.black.withOpacity(.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _estadoCard(String estado, Color color) {
    return Row(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            RotationTransition(
              turns: _ringController,
              child: CustomPaint(
                size: const Size(70, 70),
                painter: _AnimatedRingPainter(progress: 1, color: color),
              ),
            ),
            Icon(
              estado == "entrada"
                  ? Icons.play_circle_fill_rounded
                  : estado == "inicio_pausa"
                  ? Icons.pause_circle_filled_rounded
                  : Icons.stop_circle_rounded,
              color: color.withOpacity(.9),
              size: 46,
            ),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                estado == "entrada"
                    ? "Trabajando"
                    : estado == "inicio_pausa"
                    ? "En pausa"
                    : "Fuera de jornada",
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fmtHMS(trabajadoHoy),
                style: TextStyle(
                  color: color.withOpacity(.9),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalCard(Duration totalDuracion, Color color) {
    final horas = totalDuracion.inHours;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Total trabajado",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          fmtHM(totalDuracion),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (horas / 40).clamp(0, 1),
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color.withOpacity(.8)),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Objetivo semanal: 40h",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.4),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHistorialDiario() {
    if (historial.isEmpty) {
      return [
        Center(
          child: Text(
            "Sin registros",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(.6),
              fontSize: 16,
            ),
          ),
        ),
      ];
    }

    // 1️⃣ Agrupar por semana (usando el lunes como clave)
    final Map<DateTime, List<Map<String, dynamic>>> semanas = {};

    for (var e in historial) {
      final dt = e["dt"] as DateTime;

      // Lunes de esa semana
      final inicioSemana = DateTime(
        dt.year,
        dt.month,
        dt.day,
      ).subtract(Duration(days: dt.weekday - 1));

      final key = DateTime(
        inicioSemana.year,
        inicioSemana.month,
        inicioSemana.day,
      );

      semanas.putIfAbsent(key, () => []).add(e);
    }

    // 2️⃣ Ordenar semanas de más reciente a más antigua
    final semanasOrdenadas = semanas.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final List<Widget> widgets = [];

    for (final inicioSemana in semanasOrdenadas) {
      final eventosSemana = semanas[inicioSemana]!;
      final finSemana = inicioSemana.add(const Duration(days: 6));

      // 3️⃣ Calcular total semanal
      final diasSemana = <DateTime>{};
      for (var e in eventosSemana) {
        final dt = e["dt"] as DateTime;
        diasSemana.add(DateTime(dt.year, dt.month, dt.day));
      }

      Duration totalSemana = Duration.zero;
      for (var d in diasSemana) {
        totalSemana += FichajeUtils.calcularDuracionDia(historial, d);
      }

      final objetivo = const Duration(hours: 40);
      final progreso = (totalSemana.inSeconds / objetivo.inSeconds).clamp(
        0.0,
        1.0,
      );

      // 4️⃣ Ordenar días dentro de la semana
      final diasOrdenados = diasSemana.toList()..sort((a, b) => a.compareTo(b));

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _glass(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟦 Cabecera semana
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Semana ${DateFormat("dd/MM").format(inicioSemana)} — ${DateFormat("dd/MM").format(finSemana)}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(.9),
                      ),
                    ),
                    Text(
                      fmtHM(totalSemana),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Barra de progreso semanal
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: progreso,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(
                      progreso >= 1 ? Colors.greenAccent : Colors.blueAccent,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 🗓️ Detalle día por día
                ...diasOrdenados.map((d) {
                  final duracion = FichajeUtils.calcularDuracionDia(
                    historial,
                    d,
                  );
                  final color = duracion.inHours >= 8
                      ? Colors.greenAccent
                      : Colors.orangeAccent;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: color.withOpacity(.15),
                          child: Text(
                            DateFormat('EE', 'es_ES').format(d).toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            DateFormat("d MMM", "es_ES").format(d),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          fmtHM(duracion),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}

class _AnimatedRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _AnimatedRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 7.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final bg = Paint()
      ..color = Colors.white.withOpacity(.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bg);

    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: 2 * pi * progress - pi / 2,
      colors: [
        color.withOpacity(.9),
        color.withOpacity(.95),
        color.withOpacity(1.0),
        color.withOpacity(.85),
      ],
      stops: const [0.0, 0.4, 0.8, 1.0],
      transform: const GradientRotation(-pi / 3),
    );

    final paint = Paint()
      ..shader = gradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final startAngle = -pi / 2;
    final sweep = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedRingPainter old) =>
      old.progress != progress || old.color != color;
}
