import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:registro_horario/services/fichaje_service.dart';
import 'package:registro_horario/services/auth_service.dart';

// ✅ Utils integrados (lógica común de cálculo)
class FichajeUtils {
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime parseUtcToLocal(String fecha) {
    if (fecha.isEmpty) return DateTime.now();
    final dt = DateTime.parse(fecha);
    return DateTime.utc(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
    ).toLocal();
  }

  static Duration calcularDuracionDia(
    List<Map<String, dynamic>> historial,
    DateTime dia,
  ) {
    final eventos = historial.where((e) => isSameDay(e["dt"], dia)).toList()
      ..sort((a, b) => a["dt"].compareTo(b["dt"]));

    Duration acumulado = Duration.zero;
    DateTime? ultimaEntrada;
    DateTime? ultimaPausa;

    for (final e in eventos) {
      final tipo = e["tipo"];
      final dt = e["dt"] as DateTime;

      if (tipo == "entrada") {
        ultimaEntrada = dt;
      } else if (tipo == "inicio_pausa" && ultimaEntrada != null) {
        acumulado += dt.difference(ultimaEntrada);
        ultimaEntrada = null;
        ultimaPausa = dt;
      } else if (tipo == "fin_pausa") {
        ultimaPausa = null;
        ultimaEntrada = dt;
      } else if (tipo == "salida" && ultimaEntrada != null) {
        acumulado += dt.difference(ultimaEntrada);
        ultimaEntrada = null;
      }
    }

    if (ultimaEntrada != null && ultimaPausa == null) {
      acumulado += DateTime.now().difference(ultimaEntrada);
    }

    return acumulado;
  }

  static Duration calcularTotal(List<Map<String, dynamic>> historial) {
    final dias = <DateTime>{};
    for (final e in historial) {
      final dt = e["dt"] as DateTime;
      dias.add(DateTime(dt.year, dt.month, dt.day));
    }

    Duration total = Duration.zero;
    for (final d in dias) {
      total += calcularDuracionDia(historial, d);
    }
    return total;
  }
}

class FichadoDetallePage extends StatefulWidget {
  const FichadoDetallePage({super.key});

  @override
  State<FichadoDetallePage> createState() => _FichadoDetallePageState();
}

class _FichadoDetallePageState extends State<FichadoDetallePage> {
  bool loading = true;
  List<Map<String, dynamic>> historial = [];
  Map<String, dynamic>? ultimo;
  Timer? timer;
  DateTime? entradaActual;

  @override
  void initState() {
    super.initState();
    cargar();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    timer?.cancel();
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
    }

    setState(() => loading = false);
  }

  // ✅ Total trabajado hoy (acumulado + actual)
  Duration calcularTotalHoy() {
    final hoy = DateTime.now();
    Duration trabajadoHoy = FichajeUtils.calcularDuracionDia(historial, hoy);

    // Si está trabajando ahora, añadir tiempo actual
    if (entradaActual != null && (ultimo?["estado"] == "entrada")) {
      final ahora = DateTime.now();
      trabajadoHoy += ahora.difference(entradaActual!);
    }

    return trabajadoHoy;
  }

  String fmtHM(Duration d) {
    final hh = d.inHours;
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    return "${hh}h ${mm}m";
  }

  String diaCorto(DateTime d) {
    const dias = ["L", "M", "X", "J", "V", "S", "D"];
    return dias[d.weekday - 1];
  }

  Color estadoColor(String e) {
    switch (e) {
      case "entrada":
        return const Color(0xFF3DDC84);
      case "inicio_pausa":
        return const Color(0xFFFFC857);
      case "salida":
        return const Color(0xFFFF6B6B);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E1116),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final estado = ultimo?["estado"] ?? "sin_registro";
    final totalDuracion = FichajeUtils.calcularTotal(historial);

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0E1116) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          "Registro detallado",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(
          children: [
            _glass(context, child: _estadoCard(estado)),
            const SizedBox(height: 16),
            _glass(context, child: _totalCard(totalDuracion)),
            const SizedBox(height: 20),
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
    );
  }

  Widget _glass(BuildContext context, {required Widget child}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(.05)
            : Colors.black.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  String fmtHMS(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hh:$mm:$ss";
  }

  // ✅ Ahora muestra total trabajado HOY en lugar de contador desde la última entrada
  Widget _estadoCard(String estado) {
    return Row(
      children: [
        Icon(
          estado == "entrada"
              ? Icons.play_circle
              : estado == "inicio_pausa"
              ? Icons.pause_circle
              : Icons.stop_circle,
          color: estadoColor(estado),
          size: 48,
        ),
        const SizedBox(width: 14),
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
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(.7),
                ),
              ),
              if (estado == "entrada")
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    fmtHMS(calcularTotalHoy()), // 👈 hh:mm:ss en vivo
                    style: TextStyle(
                      color: estadoColor(estado),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalCard(Duration totalDuracion) {
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
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (totalDuracion.inHours / 40).clamp(0, 1),
          backgroundColor: Colors.white12,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF3DDC84)),
          minHeight: 8,
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
    final dias = <DateTime>{};
    for (final e in historial) {
      final dt = e["dt"] as DateTime;
      final d = DateTime(dt.year, dt.month, dt.day);
      dias.add(d);
    }

    final diasOrdenados = dias.toList()..sort((a, b) => b.compareTo(a));

    return diasOrdenados.map((d) {
      final duracion = FichajeUtils.calcularDuracionDia(historial, d);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _glass(
          context,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white12,
                child: Text(diaCorto(d)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy-MM-dd').format(d),
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (duracion.inHours / 8).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF3DDC84),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                fmtHM(duracion),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
