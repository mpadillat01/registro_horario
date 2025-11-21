import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../services/auth_service.dart';
import '../../services/fichaje_service.dart';
import '../../services/documento_service.dart';
import '../../theme_provider.dart';
import '../../utils/fichaje_utils.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  Map<String, dynamic>? user;
  double totalHoras = 0, hoy = 0, horasSemana = 0, horasMes = 0;
  DateTime? entradaActual;

  bool cargando = true, editando = false;
  Timer? timer;
  bool _btnPressed = false;
  bool editandoPerfil = false;

  final nombreCtrl = TextEditingController();
  final apellidosCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final dniCtrl = TextEditingController();

  List<Map<String, dynamic>> historial = [];
  List<dynamic> documentos = [];

  @override
  void initState() {
    super.initState();
    cargarDatos();
    timer = Timer.periodic(const Duration(minutes: 1), (_) => cargarDatos());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> cargarDatos() async {
    print("🔵 cargarDatos() INICIO");

    try {
      user ??= await AuthService.getCurrentUser();
      print("🟢 USER = $user");

      if (user == null) {
        print("❌ USER ES NULL");
        return;
      }

      nombreCtrl.text = user!["nombre"] ?? "";
      apellidosCtrl.text = user!["apellidos"] ?? "";
      emailCtrl.text = user!["email"] ?? "";
      dniCtrl.text = user!["dni"] ?? "";

      print("📌 Cargando historial...");
      final data = await FichajeService.obtenerHistorial();
      print("📄 HISTORIAL RAW = $data");

      historial = [];
      if (data != null) {
        historial = List<Map<String, dynamic>>.from(data).map((e) {
          return {
            "tipo": e["tipo"],
            "dt": FichajeUtils.parseUtcToLocal(e["fecha_hora"] ?? ""),
          };
        }).toList()..sort((a, b) => b["dt"].compareTo(a["dt"]));
      }
      print("🟢 HISTORIAL OK");

      print("📌 Cargando último fichaje...");
      final ultimo = await FichajeService.getUltimo(user!["id"]);
      print("🟠 ULTIMO RAW = $ultimo");

      entradaActual = null;

      if (ultimo != null && ultimo is Map && ultimo.isNotEmpty) {
        final estado = (ultimo["estado"] ?? ultimo["tipo"] ?? "")
            .toString()
            .toLowerCase();

        final fecha = ultimo["hora"] ?? ultimo["fecha_hora"];

        if (fecha != null && fecha != "") {
          entradaActual = estado.contains("entrada")
              ? FichajeUtils.parseUtcToLocal(fecha)
              : null;
        }
      }
      print("🟢 entradaActual = $entradaActual");

      DateTime now = DateTime.now();
      double h(Duration d) => d.inHours + (d.inMinutes % 60) / 60.0;

      totalHoras = h(FichajeUtils.calcularTotal(historial));
      hoy = h(FichajeUtils.calcularDuracionDia(historial, now));
      horasSemana = h(
        FichajeUtils.calcularRango(
          historial,
          now.subtract(Duration(days: now.weekday - 1)),
          now,
        ),
      );
      horasMes = h(
        FichajeUtils.calcularRango(
          historial,
          DateTime(now.year, now.month, 1),
          now,
        ),
      );
      print("🟢 METRICAS OK");

      print("📌 Cargando documentos...");
      documentos = await DocumentoService.listarDocumentos(user!["id"]);
      print("🟢 DOCUMENTOS = $documentos");

      if (mounted) setState(() => cargando = false);
      print("🟩 cargarDatos FIN");
    } catch (e, st) {
      print("❌❌❌ ERROR EN cargarDatos()");
      print("ERROR: $e");
      print("STACK: $st");
    }
  }

  String f(double h) => "${h.floor()}h ${(h % 1 * 60).round()}m";

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorPrincipal = entradaActual != null
        ? Colors.greenAccent.shade400
        : Colors.blueAccent.shade400;

    if (cargando) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(.08)
                    : Colors.black.withOpacity(.06),
                width: 1,
              ),
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                centerTitle: true,
                automaticallyImplyLeading: false,

                leading: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 26,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(.9),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                title: Text(
                  "Mi perfil",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),

                actions: [
                  IconButton(
                    tooltip: "Cambiar tema",
                    icon: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 26,
                      color: colorPrincipal,
                    ),
                    onPressed: () =>
                        context.read<ThemeProvider>().toggleTheme(),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [Colors.black, Colors.grey.shade900]
                : [Colors.white, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              _avatar(user!["nombre"], colorPrincipal, isDark),
              const SizedBox(height: 20),

              _datosUsuario(isDark, colorPrincipal),
              const SizedBox(height: 20),

              _chipEstado(entradaActual != null, colorPrincipal),
              const SizedBox(height: 20),

              _bloqueMetricas(isDark, colorPrincipal),
              const SizedBox(height: 30),

              _buildCalendario(isDark),
              const SizedBox(height: 30),

              _buildHistorialCard(isDark),
              const SizedBox(height: 30),

              _logoutButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bloqueMetricas(bool dark, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _metric("Hoy", f(hoy), color, dark)),
            const SizedBox(width: 14),
            Expanded(child: _metric("Semana", f(horasSemana), color, dark)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _metric("Mes", f(horasMes), color, dark)),
            const SizedBox(width: 14),
            Expanded(child: _metric("Total", f(totalHoras), color, dark)),
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
        mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _buildCalendario(bool dark) {
    final txt = dark ? Colors.white70 : Colors.black87;
    final colorPrincipal = entradaActual != null
        ? Colors.greenAccent.shade400
        : Colors.blueAccent.shade400;

    final Map<DateTime, double> horasPorDia = {};
    for (var h in historial) {
      final fecha = DateTime(h["dt"].year, h["dt"].month, h["dt"].day);
      final duracion = FichajeUtils.calcularDuracionDia(historial, fecha);
      horasPorDia[fecha] = duracion.inHours + (duracion.inMinutes % 60) / 60.0;
    }

    final festivos = <DateTime>{
      DateTime(2025, 1, 1),
      DateTime(2025, 1, 6),
      DateTime(2025, 4, 17),
      DateTime(2025, 4, 18),
      DateTime(2025, 4, 21),
      DateTime(2025, 5, 1),
      DateTime(2025, 8, 15),
      DateTime(2025, 10, 12),
      DateTime(2025, 11, 1),
      DateTime(2025, 12, 6),
      DateTime(2025, 12, 8),
      DateTime(2025, 12, 25),
      DateTime(2026, 1, 1),
      DateTime(2026, 1, 6),
      DateTime(2026, 4, 2),
      DateTime(2026, 4, 3),
      DateTime(2026, 4, 6),
      DateTime(2026, 5, 1),
      DateTime(2026, 8, 15),
      DateTime(2026, 10, 12),
      DateTime(2026, 11, 1),
      DateTime(2026, 12, 6),
      DateTime(2026, 12, 8),
      DateTime(2026, 12, 25),
    };

    DateTime diaSeleccionado = DateTime.now();
    List<Map<String, dynamic>> eventosDelDia = [];
    bool inicializado = false;

    return StatefulBuilder(
      builder: (context, setState) {
        if (!inicializado) {
          inicializado = true;
          eventosDelDia =
              historial
                  .where(
                    (e) => FichajeUtils.isSameDay(e["dt"], diaSeleccionado),
                  )
                  .toList()
                ..sort((a, b) => a["dt"].compareTo(b["dt"]));
        }

        void actualizarDia(DateTime selectedDay) {
          setState(() {
            diaSeleccionado = selectedDay;
            eventosDelDia =
                historial
                    .where((e) => FichajeUtils.isSameDay(e["dt"], selectedDay))
                    .toList()
                  ..sort((a, b) => a["dt"].compareTo(b["dt"]));
          });
        }

        final duracionSel = FichajeUtils.calcularDuracionDia(
          historial,
          diaSeleccionado,
        );
        final horasSel = duracionSel.inHours;
        final minutosSel = duracionSel.inMinutes % 60;
        final esFestivo = festivos.any(
          (f) => FichajeUtils.isSameDay(f, diaSeleccionado),
        );

        String resumen;
        Color resumenColor;

        if (esFestivo) {
          resumen = " Día festivo en España";
          resumenColor = Colors.redAccent;
        } else if (eventosDelDia.isEmpty) {
          resumen = " No hay fichajes registrados";
          resumenColor = Colors.grey;
        } else if (duracionSel.inMinutes > 0) {
          resumen = " Has trabajado ${horasSel}h ${minutosSel}m";
          resumenColor = colorPrincipal;
        } else {
          resumen = " Fichajes sin duración";
          resumenColor = Colors.orangeAccent;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Calendario laboral",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: txt,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: dark ? Colors.white10 : Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TableCalendar(
                locale: 'es_ES',
                startingDayOfWeek: StartingDayOfWeek.monday,
                firstDay: DateTime.utc(2024, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: diaSeleccionado,
                selectedDayPredicate: (day) =>
                    FichajeUtils.isSameDay(day, diaSeleccionado),
                onDaySelected: (selectedDay, _) => actualizarDia(selectedDay),

                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: colorPrincipal.withOpacity(.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: colorPrincipal,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(shape: BoxShape.circle),
                ),

                // ⭐⭐ NUEVO: PINTAR DÍAS FESTIVOS ⭐⭐
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final esFestivo = festivos.any(
                      (f) => FichajeUtils.isSameDay(f, day),
                    );

                    if (!esFestivo) return null;

                    // 🎉 ESTILO VISUAL PARA FESTIVOS (rojo suave + texto rojo)
                    return Container(
                      margin: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(.5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "${day.day}",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 10),

            Column(
              children: [
                const SizedBox(height: 10),
                Text(
                  resumen,
                  style: TextStyle(
                    color: resumenColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),

                _buildHistorialDiaSeleccionado(
                  dark,
                  diaSeleccionado,
                  eventosDelDia,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistorialDiaSeleccionado(
    bool dark,
    DateTime diaSeleccionado,
    List<Map<String, dynamic>> eventosDelDia,
  ) {
    final txt = dark ? Colors.white70 : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text(
          "Fichajes del día",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 19,
            color: txt,
          ),
        ),
        const SizedBox(height: 12),

        if (eventosDelDia.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: dark ? Colors.white10 : Colors.grey.shade200,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: txt),
                const SizedBox(width: 10),
                Text("No hay fichajes este día", style: TextStyle(color: txt)),
              ],
            ),
          ),

        ...eventosDelDia.map((e) => _buildEventoFila(e, dark)),
      ],
    );
  }

  Widget _buildHistorialCard(bool dark) {
    final txt = dark ? Colors.white70 : Colors.black87;

    if (historial.isEmpty) {
      return Center(
        child: Text(
          "Sin registros recientes",
          style: TextStyle(color: txt.withOpacity(.7)),
        ),
      );
    }

    final Map<String, List<Map<String, dynamic>>> agrupado = {};

    for (var h in historial) {
      final fecha = h["dt"] as DateTime;
      final key = DateFormat('yyyy-MM-dd').format(fecha);
      agrupado.putIfAbsent(key, () => []).add(h);
    }

    final dias = agrupado.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Historial de fichajes",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: txt,
          ),
        ),
        const SizedBox(height: 14),

        ...dias.map((diaKey) {
          final eventos = agrupado[diaKey]!;
          final fecha = DateTime.parse(diaKey);
          final fechaTexto = DateFormat("EEEE d 'de' MMMM", "es_ES")
              .format(fecha)
              .replaceFirst(
                DateFormat("EEEE", "es_ES").format(fecha)[0],
                DateFormat("EEEE", "es_ES").format(fecha)[0].toUpperCase(),
              );

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: dark ? Colors.white10 : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      Text(
                        fechaTexto,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: txt,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(color: txt.withOpacity(.15)),

                  const SizedBox(height: 10),

                  ...eventos.map((e) => _buildEventoFila(e, dark)),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEventoFila(Map<String, dynamic> e, bool dark) {
    final tipo = e["tipo"].toString().toLowerCase();
    final dt = e["dt"] as DateTime;

    final color =
        {
          "entrada": Colors.greenAccent,
          "salida": Colors.redAccent,
          "inicio_pausa": Colors.orangeAccent,
          "fin_pausa": Colors.cyanAccent,
        }[tipo] ??
        Colors.grey;

    final txt = dark ? Colors.white70 : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: dark ? Colors.white12 : Colors.black.withOpacity(.05),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tipo.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            DateFormat("HH:mm").format(dt),
            style: TextStyle(color: txt, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String nombre, Color colorPrincipal, bool dark) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "U";

    return Column(
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      colorPrincipal.withOpacity(.35),
                      colorPrincipal.withOpacity(.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorPrincipal.withOpacity(0.4),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.transparent,
                  child: Text(
                    inicial,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: colorPrincipal,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() => editandoPerfil = !editandoPerfil);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: dark ? Colors.black : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: colorPrincipal,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: editandoPerfil
              ? _editorInline(dark, colorPrincipal)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _editorInline(bool dark, Color colorPrincipal) {
    return Container(
      key: const ValueKey("editorInline"),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? Colors.black.withOpacity(.25) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorPrincipal.withOpacity(.35), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _campoEditar(
            "Nombre",
            Icons.person_rounded,
            nombreCtrl,
            dark,
            colorPrincipal,
          ),
          const SizedBox(height: 12),

          _campoEditar(
            "Apellidos",
            Icons.person_outline_rounded,
            apellidosCtrl,
            dark,
            colorPrincipal,
          ),
          const SizedBox(height: 12),

          _campoEditar(
            "Email",
            Icons.email_rounded,
            emailCtrl,
            dark,
            colorPrincipal,
          ),
          const SizedBox(height: 12),

          _campoEditar(
            "DNI / NIE",
            Icons.badge_rounded,
            dniCtrl,
            dark,
            colorPrincipal,
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                child: Text(
                  "Cancelar",
                  style: TextStyle(
                    color: dark ? Colors.white70 : Colors.black54,
                  ),
                ),
                onPressed: () => setState(() => editandoPerfil = false),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorPrincipal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  "Guardar",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    user!["nombre"] = nombreCtrl.text;
                    user!["apellidos"] = apellidosCtrl.text;
                    user!["email"] = emailCtrl.text;
                    user!["dni"] = dniCtrl.text;
                    editandoPerfil = false;
                  });
                  _toast("Perfil actualizado");
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _campoEditar(
    String label,
    IconData icon,
    TextEditingController ctrl,
    bool dark,
    Color colorPrincipal,
  ) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: dark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: colorPrincipal, size: 22),
        labelText: label,
        labelStyle: TextStyle(
          color: dark ? Colors.white70 : Colors.black54,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: dark ? Colors.white10 : Colors.grey.shade200.withOpacity(.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorPrincipal.withOpacity(.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorPrincipal, width: 1.6),
        ),
      ),
    );
  }

  Widget _datosUsuario(bool dark, Color color) {
    return Column(
      children: [
        Text(
          user!["nombre"],
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: dark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user!["email"],
          style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
        ),
      ],
    );
  }

  Widget _chipEstado(bool trabajando, Color color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Text(
          trabajando ? "Trabajando" : "Fuera de servicio",
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _logoutButton() => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.redAccent,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: const Icon(Icons.logout),
    label: const Text("Cerrar sesión"),
    onPressed: () async {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
    },
  );

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.greenAccent),
    );
  }
}
