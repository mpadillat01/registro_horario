import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:registro_horario/services/api_service.dart';
import 'package:registro_horario/services/auth_service.dart';
import 'package:registro_horario/services/documento_service.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage>
    with SingleTickerProviderStateMixin {
  int selectedPlan = 1;
  bool loading = false;

  final empresaCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final empleadosCtrl = TextEditingController();

  List documentos = [];
  bool loadingDocs = false;
  String formato = "csv"; 

  Map<String, dynamic>? empresaData;

  List<Map<String, dynamic>> empleados = [];
  Map<String, dynamic>? empleadoSeleccionado;
  bool cargandoEmpleados = false;

  List<Map<String, dynamic>> semanas = [];
  List<Map<String, dynamic>> meses = [];
  Map<String, dynamic>? semanaSeleccionada;
  Map<String, dynamic>? mesSeleccionado;
  String modoSeleccion = "";

  @override
  void initState() {
    super.initState();
    _loadEmpresa();
    cargarEmpleados();

    semanas = [];
    meses = [];
  }

  List<Map<String, dynamic>> generarSemanasDesde(DateTime inicio) {
    List<Map<String, dynamic>> result = [];

    inicio = inicio.subtract(Duration(days: inicio.weekday - 1));

    DateTime hoy = DateTime.now();

    while (inicio.isBefore(hoy)) {
      final lunes = inicio;
      final domingo = lunes.add(const Duration(days: 6));

      result.add({
        "label":
            "Semana ${result.length + 1} · ${lunes.day}/${lunes.month} - ${domingo.day}/${domingo.month}",
        "start": lunes,
        "end": domingo,
      });

      inicio = inicio.add(const Duration(days: 7));
    }

    return result;
  }

  List<Map<String, dynamic>> generarMesesDesde(DateTime inicio) {
    List<Map<String, dynamic>> result = [];

    DateTime fecha = DateTime(inicio.year, inicio.month); 
        DateTime hoy = DateTime.now();

    while (fecha.isBefore(DateTime(hoy.year, hoy.month + 1))) {
      final inicioMes = fecha;
      final finMes = DateTime(
        fecha.year,
        fecha.month + 1,
      ).subtract(const Duration(days: 1));

      result.add({
        "label": "${inicioMes.month}/${inicioMes.year}",
        "start": inicioMes,
        "end": finMes,
      });

      fecha = DateTime(fecha.year, fecha.month + 1);
    }

    return result;
  }

  Future<void> descargarInformeSemanalCSV() async {
    await descargarInforme(); 
  }

  Future<void> descargarInformeMensualCSV() async {
    await descargarInformeMensual(); 
  }

  Future<void> descargarInformeSemanalPDF() async {
    final userId = empleadoSeleccionado!["id"];
    final inicio = semanaSeleccionada!["start"];

    final semanaStr =
        "${inicio.year}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}";

    final url =
        "${ApiService.baseUrl}/documentos/descargar-semanal-pdf/$userId?week=$semanaStr";

    final headers = await ApiService.authHeaders();
    final res = await http.get(Uri.parse(url), headers: headers);

    if (res.statusCode != 200) {
      return _err("Error ${res.statusCode} al descargar PDF semanal");
    }

    final bytes = res.bodyBytes;
    final filename = "informe_$semanaStr.pdf";

    if (!kIsWeb && Platform.isAndroid) {
      final file = File("/storage/emulated/0/Download/$filename");
      await file.writeAsBytes(bytes);
      return;
    }

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url2 = html.Url.createObjectUrlFromBlob(blob);
      final a = html.AnchorElement(href: url2)
        ..setAttribute("download", filename)
        ..click();
      html.Url.revokeObjectUrl(url2);
    }
  }

  Future<void> descargarInformeMensualPDF() async {
    final userId = empleadoSeleccionado!["id"];
    final inicio = mesSeleccionado!["start"];

    final mesStr = "${inicio.year}-${inicio.month.toString().padLeft(2, '0')}";

    final url =
        "${ApiService.baseUrl}/documentos/descargar-mensual-pdf/$userId?month=$mesStr";

    final headers = await ApiService.authHeaders();
    final res = await http.get(Uri.parse(url), headers: headers);

    if (res.statusCode != 200) {
      return _err("Error ${res.statusCode} al descargar PDF mensual");
    }

    final bytes = res.bodyBytes;
    final filename = "informe_mensual_$mesStr.pdf";

    if (!kIsWeb && Platform.isAndroid) {
      final file = File("/storage/emulated/0/Download/$filename");
      await file.writeAsBytes(bytes);
      return;
    }

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url2 = html.Url.createObjectUrlFromBlob(blob);
      final a = html.AnchorElement(href: url2)
        ..setAttribute("download", filename)
        ..click();
      html.Url.revokeObjectUrl(url2);
    }
  }

  Future<void> cargarEmpleados() async {
    setState(() => cargandoEmpleados = true);

    try {
      final res = await ApiService.get("/usuarios/empleados");
      empleados = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print("❌ Error cargando empleados: $e");
    }

    setState(() => cargandoEmpleados = false);
  }

  Future<void> _loadDocumentos() async {
    setState(() => loadingDocs = true);

    try {
      final usuario = await AuthService.getCurrentUser();
      final usuarioId = usuario["id"];

      if (usuarioId == null) {
        documentos = [];
      } else {
        documentos = await DocumentoService.listarDocumentos(
          usuarioId.toString(),
        );
      }
    } catch (e) {
      print("❌ Error cargando documentos: $e");
    }

    if (mounted) setState(() => loadingDocs = false);
  }

  Future<void> _loadEmpresa() async {
    setState(() => loading = true);

    try {
      final headers = await ApiService.authHeaders();
      final res = await http.get(
        Uri.parse("${ApiService.baseUrl}/empresa/datos"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        empresaData = jsonDecode(res.body);

        empresaCtrl.text = empresaData?["nombre"] ?? "";
        emailCtrl.text = empresaData?["email_admin"] ?? "";
        empleadosCtrl.text = (empresaData?["max_empleados"] ?? 0).toString();

        final plan = (empresaData?["plan"] ?? "pro");
        selectedPlan = _planIndex(plan);

        await _loadDocumentos();
      }
    } catch (e) {
      print("❌ Error cargando empresa: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  int _planIndex(String plan) {
    switch (plan.toLowerCase()) {
      case "starter":
        return 0;
      case "enterprise":
        return 2;
      default:
        return 1;
    }
  }

  Future<void> _saveChanges() async {
    setState(() => loading = true);

    final planName = switch (selectedPlan) {
      0 => "starter",
      1 => "pro",
      2 => "enterprise",
      _ => "pro",
    };

    try {
      final headers = await ApiService.authHeaders();

      final body = jsonEncode({
        "nombre": empresaCtrl.text.trim(),
        "nombre_admin": empresaData?["nombre_admin"],
        "email_admin": emailCtrl.text.trim(),
        "plan": planName,
      });

      final res = await http.put(
        Uri.parse("${ApiService.baseUrl}/empresa/actualizar"),
        headers: headers,
        body: body,
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Ajustes actualizados",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.greenAccent.shade400,
          ),
        );
        _loadEmpresa();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ Error (${res.statusCode})",
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.redAccent.shade400,
          ),
        );
      }
    } catch (e) {
      print("❌ Error al guardar: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> descargarInformeMensual() async {
    final userId = empleadoSeleccionado!["id"];
    final inicioMes = mesSeleccionado!["start"];
    final mesStr =
        "${inicioMes.year}-${inicioMes.month.toString().padLeft(2, '0')}";

    final url =
        "${ApiService.baseUrl}/documentos/descargar-mensual/$userId?month=$mesStr";
    final headers = await ApiService.authHeaders();

    try {
      final res = await http.get(Uri.parse(url), headers: headers);

      if (res.statusCode != 200) {
        _err("Error ${res.statusCode}: no se pudo descargar");
        return;
      }

      final bytes = res.bodyBytes;
      final filename = "informe_mensual_$mesStr.csv";

      if (!kIsWeb && Platform.isAndroid) {
        final dir = "/storage/emulated/0/Download";
        final file = File("$dir/$filename");
        await file.writeAsBytes(bytes);
        return;
      }

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'text/csv');
        final url2 = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url2)
          ..setAttribute("download", filename)
          ..click();
        html.Url.revokeObjectUrl(url2);
        return;
      }
    } catch (e) {
      _err("Error descargando: $e");
    }
  }

  Future<void> descargarInforme() async {
    final userId = empleadoSeleccionado!["id"];
    final inicioSemana = semanaSeleccionada!["start"];
    final semanaStr =
        "${inicioSemana.year}-${inicioSemana.month.toString().padLeft(2, '0')}-${inicioSemana.day.toString().padLeft(2, '0')}";

    final url =
        "${ApiService.baseUrl}/documentos/descargar-semanal/$userId?week=$semanaStr";
    final headers = await ApiService.authHeaders();

    try {
      final res = await http.get(Uri.parse(url), headers: headers);

      if (res.statusCode != 200) {
        _err("Error ${res.statusCode}: no se pudo descargar");
        return;
      }

      final bytes = res.bodyBytes;
      final filename = "informe_$semanaStr.csv";

      if (!kIsWeb && Platform.isAndroid) {
        final dir = "/storage/emulated/0/Download";
        final file = File("$dir/$filename");
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("📄 Informe guardado en Descargas"),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'text/csv');
        final url2 = html.Url.createObjectUrlFromBlob(blob);

        final anchor = html.AnchorElement(href: url2)
          ..setAttribute("download", filename)
          ..click();

        html.Url.revokeObjectUrl(url2);
        return;
      }
    } catch (e) {
      _err("Error descargando: $e");
    }
  }

  Widget _buildDocumentosSection(bool dark) {
    final txt = dark ? Colors.white70 : Colors.black87;
    final glass = dark ? Colors.white12 : Colors.white.withOpacity(.85);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: glass,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.folder_copy_rounded,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Documentos de la empresa",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: txt,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: dark ? Colors.white10 : Colors.grey.shade200,
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            modoSeleccion = "semana";
                            semanaSeleccionada = null;
                            mesSeleccionado = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: modoSeleccion == "semana"
                                ? Colors.blueAccent
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              "Semanas",
                              style: GoogleFonts.poppins(
                                color: modoSeleccion == "semana"
                                    ? Colors.white
                                    : txt,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            modoSeleccion = "mes";
                            semanaSeleccionada = null;
                            mesSeleccionado = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: modoSeleccion == "mes"
                                ? Colors.blueAccent
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Text(
                              "Meses",
                              style: GoogleFonts.poppins(
                                color: modoSeleccion == "mes"
                                    ? Colors.white
                                    : txt,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              Text(
                "Selecciona empleado para informe:",
                style: TextStyle(color: txt, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              cargandoEmpleados
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: dark ? Colors.white10 : Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          hint: Text(
                            "Elegir empleado",
                            style: TextStyle(color: txt.withOpacity(.6)),
                          ),
                          value: empleadoSeleccionado,
                          isExpanded: true,
                          items: empleados.map((emp) {
                            return DropdownMenuItem(
                              value: emp,
                              child: Text(
                                emp["nombre"] ?? emp["email"],
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              empleadoSeleccionado = value;

                              final rawFecha =
                                  empleadoSeleccionado!["fecha_creacion"] ??
                                  empleadoSeleccionado!["fecha_registro"] ??
                                  empleadoSeleccionado!["created_at"] ??
                                  empleadoSeleccionado!["fecha"] ??
                                  empleadoSeleccionado!["fecha_creado"];

                              if (rawFecha == null ||
                                  rawFecha.toString().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "❌ El empleado no tiene fecha válida",
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              DateTime fecha;

                              try {
                                fecha = DateTime.parse(
                                  rawFecha.toString().replaceAll(" ", "T"),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      "❌ Fecha inválida: $rawFecha",
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              semanas = generarSemanasDesde(fecha);
                              meses = generarMesesDesde(fecha);

                              semanaSeleccionada = null;
                              mesSeleccionado = null;
                            });
                          },
                        ),
                      ),
                    ),

              const SizedBox(height: 20),
              modoSeleccion != ""
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          modoSeleccion == "semana"
                              ? "Selecciona una semana:"
                              : "Selecciona un mes:",
                          style: TextStyle(
                            color: txt,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: dark ? Colors.white10 : Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              hint: Text(
                                modoSeleccion == "semana"
                                    ? "Elegir semana"
                                    : "Elegir mes",
                                style: TextStyle(color: txt.withOpacity(.6)),
                              ),
                              value: modoSeleccion == "semana"
                                  ? semanaSeleccionada
                                  : mesSeleccionado,
                              isExpanded: true,
                              items:
                                  (modoSeleccion == "semana" ? semanas : meses)
                                      .map(
                                        (x) => DropdownMenuItem(
                                          value: x,
                                          child: Text(x["label"]),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  if (modoSeleccion == "semana") {
                                    semanaSeleccionada = value;
                                  } else {
                                    mesSeleccionado = value;
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(),

              const SizedBox(height: 20),
              Text(
                "Formato del informe:",
                style: TextStyle(color: txt, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => formato = "csv"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: formato == "csv"
                              ? Colors.blueAccent
                              : (dark ? Colors.white10 : Colors.white),
                        ),
                        child: Center(
                          child: Text(
                            "CSV",
                            style: TextStyle(
                              color: formato == "csv" ? Colors.white : txt,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => formato = "pdf"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: formato == "pdf"
                              ? Colors.blueAccent
                              : (dark ? Colors.white10 : Colors.white),
                        ),
                        child: Center(
                          child: Text(
                            "PDF",
                            style: TextStyle(
                              color: formato == "pdf" ? Colors.white : txt,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text("Descargar informe"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () async {
                    if (empleadoSeleccionado == null) {
                      return _err("Selecciona un empleado");
                    }

                    if (modoSeleccion == "") {
                      return _err("Selecciona semana o mes");
                    }

                    if (modoSeleccion == "semana") {
                      if (semanaSeleccionada == null) {
                        return _err("Selecciona una semana");
                      }

                      if (formato == "csv") {
                        await descargarInformeSemanalCSV();
                      } else {
                        await descargarInformeSemanalPDF();
                      }
                      return;
                    }

                    
                    if (modoSeleccion == "mes") {
                      if (mesSeleccionado == null) {
                        return _err("Selecciona un mes");
                      }

                      if (formato == "csv") {
                        await descargarInformeMensualCSV();
                      } else {
                        await descargarInformeMensualPDF();
                      }
                      return;
                    }
                  },
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text("Subir documento / PDF"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () async {
                    final usuario = await AuthService.getCurrentUser();
                    final userId = usuario["id"];

                    if (userId == null) {
                      return _err("No se pudo detectar el usuario");
                    }

                    if (kIsWeb) {
                      final input = html.FileUploadInputElement();
                      input.accept = "*/*";
                      input.click();

                      input.onChange.listen((e) async {
                        final file = input.files!.first;
                        final reader = html.FileReader();

                        reader.readAsArrayBuffer(file);
                        await reader.onLoad.first;

                        final bytes = reader.result as List<int>;
                        final headers = await ApiService.authHeaders();

                        final request = http.MultipartRequest(
                          "POST",
                          Uri.parse("${ApiService.baseUrl}/documentos/subir"),
                        );

                        request.fields["usuario_id"] = userId.toString();
                        request.fields["tipo"] = "empresa";

                        request.files.add(
                          http.MultipartFile.fromBytes(
                            "archivo",
                            bytes,
                            filename: file.name,
                            contentType: MediaType(
                              "application",
                              "octet-stream",
                            ),
                          ),
                        );

                        request.headers.addAll(headers);

                        final streamed = await request.send();
                        final res = await http.Response.fromStream(streamed);

                        if (res.statusCode == 200) {
                          _loadDocumentos();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "📄 Documento subido correctamente",
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          _err("Error subiendo documento (${res.statusCode})");
                        }
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
              loadingDocs
                  ? const Center(child: CircularProgressIndicator())
                  : documentos.isEmpty
                  ? Text(
                      "No hay documentos subidos.",
                      style: TextStyle(color: txt.withOpacity(.6)),
                    )
                  : Column(
                      children: documentos.map((doc) {
                        final nombre = doc["nombre"];
                        final fecha = doc["fecha_subida"];
                        final usuarioId = doc["usuario_id"];
                        final ruta = doc["ruta"];
                        final filename = nombre;

                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: dark ? Colors.white10 : Colors.white,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.description,
                                color: Colors.blueAccent,
                                size: 26,
                              ),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  nombre,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: txt,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              
                              Text(
                                fecha.toString().split("T").first,
                                style: TextStyle(color: txt.withOpacity(.6)),
                              ),

                              const SizedBox(width: 12),

                              
                              IconButton(
                                tooltip: "Descargar",
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: Colors.green,
                                ),
                                onPressed: () async {
                                  final url =
                                      "${ApiService.baseUrl}/documentos/descargar/$usuarioId/$filename";

                                  try {
                                    final headers =
                                        await ApiService.authHeaders();
                                    final res = await http.get(
                                      Uri.parse(url),
                                      headers: headers,
                                    );

                                    if (res.statusCode != 200) {
                                      _err(
                                        "Error al descargar (${res.statusCode})",
                                      );
                                      return;
                                    }

                                    final bytes = res.bodyBytes;
                                    if (kIsWeb) {
                                      final blob = html.Blob([
                                        bytes,
                                      ], 'application/octet-stream');
                                      final url2 = html
                                          .Url.createObjectUrlFromBlob(blob);
                                      final a = html.AnchorElement(href: url2)
                                        ..setAttribute("download", filename)
                                        ..click();
                                      html.Url.revokeObjectUrl(url2);
                                      return;
                                    }

                                    if (!kIsWeb && Platform.isAndroid) {
                                      final file = File(
                                        "/storage/emulated/0/Download/$filename",
                                      );
                                      await file.writeAsBytes(bytes);

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "📄 Archivo guardado en Descargas",
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      return;
                                    }
                                  } catch (e) {
                                    _err("Error descargando archivo: $e");
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: "Enviar a empleado",
                                icon: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () async {
                                  _mostrarDialogoEnviar(doc);
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _mostrarDialogoEnviar(Map<String, dynamic> documento) {
    showDialog(
      context: context,
      builder: (context) {
        Map<String, dynamic>? seleccionado;

        return AlertDialog(
          title: const Text("Enviar documento a empleado"),
          content: SizedBox(
            width: 400,
            child: DropdownButtonFormField<Map<String, dynamic>>(
              decoration: const InputDecoration(
                labelText: "Selecciona empleado",
              ),
              items: empleados.map((emp) {
                return DropdownMenuItem(
                  value: emp,
                  child: Text(emp["nombre"] ?? emp["email"]),
                );
              }).toList(),
              onChanged: (value) => seleccionado = value,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text("Enviar"),
              onPressed: () async {
                if (seleccionado == null) {
                  _err("Selecciona un empleado");
                  return;
                }

                Navigator.pop(context);

                await _enviarDocumentoEmpleado(documento, seleccionado!["id"]);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _enviarDocumentoEmpleado(
    Map<String, dynamic> documento,
    String empleadoId,
  ) async {
    try {
      final headers = await ApiService.authHeaders();

      final body = {
        "titulo": "Nuevo documento disponible",
        "mensaje": "Se te ha enviado el documento: ${documento["nombre"]}",
        "usuario_id": empleadoId,
        "tipo": "documento",
        "archivo": documento["nombre"],
        "origen": "admin",
      };

      final res = await http.post(
        Uri.parse("${ApiService.baseUrl}/notificaciones/enviar"),
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "📨 Documento enviado al empleado",
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        _err("Error enviando documento (${res.statusCode})");
      }
    } catch (e) {
      _err("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final plans = [
      {
        "title": "Starter",
        "subtitle": "Ideal para equipos pequeños",
        "price": "4,95 €/mes",
        "color": const Color(0xFF4ADE80),
        "gradient": const [Color(0xFFa2facf), Color(0xFF64acff)],
        "icon": Icons.auto_awesome,
      },
      {
        "title": "Pro",
        "subtitle": "Para pymes",
        "price": "14,99 €/mes",
        "color": const Color(0xFF2563EB),
        "gradient": const [Color(0xFF667EEA), Color(0xFF764BA2)],
        "icon": Icons.workspace_premium_rounded,
      },
      {
        "title": "Enterprise",
        "subtitle": "Empresas grandes",
        "price": "39,99 €/mes",
        "color": const Color(0xFFF59E0B),
        "gradient": const [Color(0xFFFFD86F), Color(0xFFFBB03B)],
        "icon": Icons.business_center_rounded,
      },
    ];

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0E1117) : const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          "Ajustes de la empresa",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildEmpresaSection(dark),
                  const SizedBox(height: 30),
                  _buildPlanSection(plans, dark),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: loading ? null : _saveChanges,
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    label: Text(
                      "Guardar cambios",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorForPlan(selectedPlan),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildDocumentosSection(dark),
                ],
              ),
            ),
    );
  }

  Widget _buildEmpresaSection(bool dark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: dark
                ? Colors.white.withOpacity(0.05)
                : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorForPlan(selectedPlan).withOpacity(0.8),
                          colorForPlan(selectedPlan).withOpacity(0.4),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    "Datos de la empresa",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _inputField(
                empresaCtrl,
                "Nombre de la empresa",
                dark,
                Icons.business,
              ),
              const SizedBox(height: 14),
              _inputField(emailCtrl, "Correo de contacto", dark, Icons.email),
              const SizedBox(height: 14),
              _inputField(
                empleadosCtrl,
                "Número de empleados",
                dark,
                Icons.people_alt_rounded,
                type: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanSection(List plans, bool dark) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorForPlan(selectedPlan).withOpacity(0.8),
                    colorForPlan(selectedPlan).withOpacity(0.4),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.credit_card_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Text(
              "Plan de suscripción",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 22,
          runSpacing: 22,
          alignment: WrapAlignment.center,
          children: List.generate(plans.length, (i) {
            final p = plans[i];
            final selected = selectedPlan == i;

            return AnimatedScale(
              duration: const Duration(milliseconds: 300),
              scale: selected ? 1.05 : 1,
              child: GestureDetector(
                onTap: () => setState(() => selectedPlan = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 280,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      colors: (p["gradient"] as List<Color>),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: selected
                          ? Colors.white.withOpacity(.9)
                          : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      if (selected)
                        BoxShadow(
                          color: (p["color"] as Color).withOpacity(.4),
                          blurRadius: 25,
                          offset: const Offset(0, 8),
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(p["icon"], color: Colors.white, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        p["title"],
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p["subtitle"],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        p["price"],
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Color colorForPlan(int plan) {
    return switch (plan) {
      0 => const Color(0xFF4ADE80),
      1 => const Color(0xFF3B82F6),
      2 => const Color(0xFFF59E0B),
      _ => const Color(0xFF3B82F6),
    };
  }

  Widget _inputField(
    TextEditingController ctrl,
    String label,
    bool dark,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: GoogleFonts.inter(
        color: dark ? Colors.white : Colors.black,
        fontSize: 15.5,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: dark ? Colors.white70 : Colors.black54),
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          color: dark ? Colors.white70 : Colors.black54,
        ),
        filled: true,
        fillColor: dark ? Colors.white10 : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark ? Colors.white10 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorForPlan(selectedPlan), width: 2),
        ),
      ),
    );
  }
}
