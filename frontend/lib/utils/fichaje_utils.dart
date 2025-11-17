import 'package:intl/intl.dart';

class FichajeUtils {
  static bool isSameDay(DateTime a, DateTime b) {
    final al = a.toLocal();
    final bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  static DateTime parseUtcToLocal(String fecha) {
    if (fecha.isEmpty) return DateTime.now();

    try {
      bool tieneZona = fecha.contains('Z') || fecha.contains('+');
      DateTime dt = DateTime.parse(fecha);

      if (!tieneZona) {
        dt = DateTime.utc(
          dt.year,
          dt.month,
          dt.day,
          dt.hour,
          dt.minute,
          dt.second,
          dt.millisecond,
          dt.microsecond,
        );
      }
      return dt.toLocal();
    } catch (e) {
      print("❌ Error parseando fecha '$fecha': $e");
      return DateTime.now();
    }
  }

  static Duration calcularDuracionDia(
    List<Map<String, dynamic>> historial,
    DateTime dia,
  ) {
    final diaLocal = dia.toLocal();

    final eventos =
        historial
            .where((e) => isSameDay((e["dt"] as DateTime).toLocal(), diaLocal))
            .toList()
          ..sort(
            (a, b) => (a["dt"] as DateTime).toLocal().compareTo(
              (b["dt"] as DateTime).toLocal(),
            ),
          );

    Duration total = Duration.zero;
    DateTime? entrada;
    bool enPausa = false;

    for (final e in eventos) {
      final tipo = (e["tipo"] ?? "").toString().toLowerCase();
      final dt = (e["dt"] as DateTime).toLocal();

      if (tipo == "entrada" && !enPausa) {
        entrada = dt;
      } else if (tipo == "inicio_pausa" && entrada != null) {
        total += dt.difference(entrada); // 🔥 incluye segundos reales
        entrada = null;
        enPausa = true;
      } else if (tipo == "fin_pausa") {
        entrada = dt;
        enPausa = false;
      } else if (tipo == "salida" && entrada != null) {
        total += dt.difference(entrada); // 🔥 incluye segundos reales
        entrada = null;
      }
    }

    // 🔥 Si sigues trabajando ahora mismo…
    if (entrada != null && !enPausa) {
      total += DateTime.now().toLocal().difference(entrada);
    }

    // 🔥 Seguridad
    if (total.inHours > 24) {
      total = const Duration(hours: 24);
    }

    return total;
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

  static Duration calcularRango(
    List<Map<String, dynamic>> historial,
    DateTime desde,
    DateTime hasta,
  ) {
    Duration total = Duration.zero;
    final inicio = DateTime(desde.year, desde.month, desde.day);
    final fin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);

    final fechas = historial
        .map((e) => e["dt"] as DateTime)
        .where((dt) => dt.isAfter(inicio) && dt.isBefore(fin))
        .map((dt) => DateTime(dt.year, dt.month, dt.day))
        .toSet();

    for (final f in fechas) {
      total += calcularDuracionDia(historial, f);
    }

    return total;
  }

  static String format(Duration d) {
    final h = d.inHours.toString().padLeft(2, "0");
    final m = (d.inMinutes % 60).toString().padLeft(2, "0");
    final s = (d.inSeconds % 60).toString().padLeft(2, "0");
    return "$h:$m:$s";
  }

  static String formatFecha(DateTime d) => DateFormat("dd/MM HH:mm").format(d);

  static Map<DateTime, Duration> calcularSemana(
    List<Map<String, dynamic>> historial,
  ) {
    final now = DateTime.now();
    final resultado = <DateTime, Duration>{};

    for (int i = 0; i < 7; i++) {
      final d = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i));
      resultado[d] = calcularDuracionDia(historial, d);
    }

    return resultado;
  }
}
