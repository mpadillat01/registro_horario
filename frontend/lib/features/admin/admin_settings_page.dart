import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:registro_horario/services/web_download.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Map<String, dynamic>? empresaData;

  List<Map<String, dynamic>> empleados = [];
  Map<String, dynamic>? empleadoSeleccionado;
  bool cargandoEmpleados = false;

  @override
  void initState() {
    super.initState();
    _loadEmpresa();
    cargarEmpleados();
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

              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      withData: true,
                    );
                    if (result == null) return;

                    final file = result.files.single;
                    bool ok = false;

                    final user = await AuthService.getCurrentUser();

                    if (kIsWeb) {
                      ok = await DocumentoService.subirDocumentoWeb(
                        user["id"],
                        "empresa",
                        file.bytes!,
                        file.name,
                      );
                    } else {
                      ok = await DocumentoService.subirDocumento(
                        user["id"],
                        "empresa",
                        File(file.path!),
                      );
                    }

                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("📤 Documento subido"),
                          backgroundColor: Colors.greenAccent,
                        ),
                      );
                      _loadDocumentos();
                    }
                  },
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text("Subir documento"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

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
                          items: empleados
                              .map<DropdownMenuItem<Map<String, dynamic>>>((
                                emp,
                              ) {
                                return DropdownMenuItem(
                                  value: emp,
                                  child: Text(
                                    emp["nombre"] ?? emp["email"],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              })
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              empleadoSeleccionado = value;
                            });
                          },
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text("Descargar informe semanal"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () async {
                    if (empleadoSeleccionado == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Selecciona un empleado primero 👇"),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    final empleadoId = empleadoSeleccionado!["id"];
                    print("👤 empleado seleccionado → $empleadoId");

                    DateTime? selected = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );

                    if (selected == null) return;

                    DateTime monday = selected.subtract(
                      Duration(days: selected.weekday - 1),
                    );

                    final weekStr =
                        "${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";

                    final url =
                        "${ApiService.baseUrl}/documentos/descargar-semanal/$empleadoId?week=$weekStr";

                    print("📅 Semana solicitada: $weekStr");
                    print("🔗 URL: $url");

                    if (kIsWeb) {
                      try {
                        final headers = await ApiService.authHeaders();
                        final r = await http.get(
                          Uri.parse(url),
                          headers: headers,
                        );

                        if (r.statusCode != 200) {
                          print("❌ ERROR → ${r.body}");
                          throw Exception();
                        }

                        WebDownloader.downloadBytes(
                          "informe_$weekStr.csv",
                          r.bodyBytes,
                        );
                      } catch (e) {
                        print("💥 ERROR WEB informe: $e");
                      }
                      return;
                    }

                    try {
                      final r = await http.get(Uri.parse(url));

                      if (r.statusCode != 200) {
                        print("❌ ERROR: ${r.body}");
                        throw Exception("Error informe");
                      }

                      Directory? baseDir;

                      if (Platform.isAndroid) {
                        baseDir = Directory("/storage/emulated/0/Download");
                      } else {
                        baseDir = await getDownloadsDirectory();
                      }

                      final path = "${baseDir!.path}/informe_$weekStr.csv";
                      await File(path).writeAsBytes(r.bodyBytes);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("📄 Informe guardado en Descargas"),
                          backgroundColor: Colors.greenAccent.shade400,
                        ),
                      );
                    } catch (e) {
                      print("💥 ERROR móvil/PC: $e");
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
                              Text(
                                fecha.toString().split("T").first,
                                style: TextStyle(color: txt.withOpacity(.6)),
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
