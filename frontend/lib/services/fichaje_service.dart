import 'api_service.dart';

class FichajeService {
  static Future<void> marcar(String tipo, {double? lat, double? lng}) async {
    await ApiService.post("/fichajes/$tipo", {"lat": lat, "lng": lng});
  }

  static Future<dynamic> obtenerHistorial() async {
    return ApiService.get("/fichajes/");
  }

  static Future<List<dynamic>> getHorasUser(String id) async {
    final res = await ApiService.get("/fichajes/empleado/$id/horas");

    if (res == null) return [];

    if (res is List) return List<Map<String, dynamic>>.from(res);

    if (res is Map<String, dynamic>) return [res];

    return [];
  }

  static Future<Map<String, dynamic>> getUltimo(String id) async {
    final res = await ApiService.get("/fichajes/ultimo/$id");
    return Map<String, dynamic>.from(res);
  }

  static Future<Map<String, double>> getHorasPorSemana(String id) async {
    final res = await ApiService.get("/fichajes/empleado/$id/horas");
    if (res == null || res is! List) return {};

    final horas = List<Map<String, dynamic>>.from(res);
    final Map<String, double> resumenSemanal = {};

    for (var e in horas) {
      final fechaStr = e["fecha"] ?? e["fecha_hora"] ?? "";
      final horasNum = (e["horas"] is num)
          ? e["horas"].toDouble()
          : double.tryParse(e["horas"].toString()) ?? 0.0;

      if (fechaStr.isEmpty) continue;
      DateTime? fecha;
      try {
        fecha = DateTime.parse(fechaStr);
      } catch (_) {
        continue;
      }

      final year = fecha.year;
      final week = _getWeekNumber(fecha);
      final key = "$year-W$week";

      resumenSemanal[key] = (resumenSemanal[key] ?? 0) + horasNum;
    }

    return resumenSemanal;
  }

  static int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirst = date.difference(firstDayOfYear).inDays + 1;
    return ((daysSinceFirst + firstDayOfYear.weekday - 1) / 7).ceil();
  }
}
