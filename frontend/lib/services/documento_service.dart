import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:registro_horario/services/api_service.dart';

class DocumentoService {
  static Future<bool> subirDocumento(
    String usuarioId,
    String tipo,
    File archivo,
  ) async {
    final uri = Uri.parse(
      "${ApiService.baseUrl}/documentos/subir?usuario_id=$usuarioId&tipo=$tipo",
    );

    final headers = await ApiService.authHeaders();
    headers.remove("Content-Type");

    final req = http.MultipartRequest("POST", uri);
    req.headers["Authorization"] = headers["Authorization"]!;

    req.files.add(
      await http.MultipartFile.fromPath("archivo", archivo.path),
    );

    final res = await req.send();
    return res.statusCode == 200;
  }

  static Future<bool> subirDocumentoWeb(
    String usuarioId,
    String tipo,
    List<int> bytes,
    String fileName,
  ) async {
    final uri = Uri.parse(
      "${ApiService.baseUrl}/documentos/subir?usuario_id=$usuarioId&tipo=$tipo",
    );

    final headers = await ApiService.authHeaders();
    headers.remove("Content-Type");

    final req = http.MultipartRequest("POST", uri);
    req.headers["Authorization"] = headers["Authorization"]!;

    req.files.add(
      http.MultipartFile.fromBytes("archivo", bytes, filename: fileName),
    );

    final res = await req.send();
    return res.statusCode == 200;
  }

  static Future<List<Map<String, dynamic>>> listarDocumentos(
    String usuarioId,
  ) async {
    final res = await ApiService.get("/documentos/listar/$usuarioId");
    if (res == null) return [];

    try {
      return (res as List).map((e) {
        return {
          "id": e["id"],
          "nombre": e["nombre"],            
          "ruta": e["ruta"],
          "tipo": e["tipo"],
          "fecha_subida": e["fecha_subida"],
        };
      }).toList();
    } catch (e) {
      print("❌ Error parseando documentos: $e");
      return [];
    }
  }

  static Future<http.Response> descargarDocumento(
    String usuarioId,
    String nombreArchivo,
  ) async {
    final headers = await ApiService.authHeaders();
    final url =
        "${ApiService.baseUrl}/documentos/descargar/$usuarioId/$nombreArchivo";

    return await http.get(Uri.parse(url), headers: headers);
  }
}
