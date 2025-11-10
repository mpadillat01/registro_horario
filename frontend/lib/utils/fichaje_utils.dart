import 'package:intl/intl.dart';

class FichajeUtils {
  /// Verifica si dos fechas son del mismo día
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Convierte correctamente UTC → hora local
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

  /// ✅ Calcula la duración trabajada en un día (considera pausas)
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

  /// ✅ Calcula el total trabajado en todas las fechas del historial
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

  /// ✅ Calcula el total trabajado entre dos fechas (semana / mes)
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

  /// Formatea duración HH:mm:ss
  static String format(Duration d) {
    final h = d.inHours.toString().padLeft(2, "0");
    final m = (d.inMinutes % 60).toString().padLeft(2, "0");
    final s = (d.inSeconds % 60).toString().padLeft(2, "0");
    return "$h:$m:$s";
  }

  /// Formatea fecha corta
  static String formatFecha(DateTime d) => DateFormat("dd/MM HH:mm").format(d);

  static Map<DateTime, Duration> calcularSemana(List<Map<String, dynamic>> historial) {
    final now = DateTime.now();
    final resultado = <DateTime, Duration>{};

    for (int i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i));
      resultado[d] = calcularDuracionDia(historial, d);
    }

    return resultado;
  }
}
