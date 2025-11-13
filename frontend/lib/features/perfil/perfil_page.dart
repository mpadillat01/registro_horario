import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:registro_horario/utils/fichaje_utils.dart';
import '../../services/auth_service.dart';
import '../../services/fichaje_service.dart';
import '../../theme_provider.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});
  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  Map<String, dynamic>? user;
  double totalHoras = 0, hoy = 0, horasSemana = 0, horasMes = 0;
  DateTime? entradaActual;
  Timer? timer;
  bool cargando = true, editando = false;

  final nombreCtrl = TextEditingController();
  final apellidosCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final dniCtrl = TextEditingController();

  List<Map<String, dynamic>> historial = [];

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
    if (user == null) user = await AuthService.getCurrentUser();
    if (user == null) return;

    nombreCtrl.text = user!["nombre"] ?? "";
    apellidosCtrl.text = user!["apellidos"] ?? "";
    emailCtrl.text = user!["email"] ?? "";
    dniCtrl.text = user!["dni"] ?? "";

    final data = await FichajeService.obtenerHistorial();
    if (data != null && data.isNotEmpty) {
      historial = List<Map<String, dynamic>>.from(data).map((e) {
        return {
          "tipo": e["tipo"],
          "dt": FichajeUtils.parseUtcToLocal(e["fecha_hora"] ?? ""),
        };
      }).toList()..sort((a, b) => b["dt"].compareTo(a["dt"]));
    }

    final ultimo = await FichajeService.getUltimo(user!["id"]);
    if (ultimo != null) {
      final estado = (ultimo["estado"] ?? ultimo["tipo"] ?? "")
          .toString()
          .toLowerCase();
      final fecha = ultimo["hora"] ?? ultimo["fecha_hora"];
      entradaActual = estado.contains("entrada")
          ? FichajeUtils.parseUtcToLocal(fecha)
          : null;
    }

    final now = DateTime.now();

    double toHorasConDecimales(Duration d) =>
        d.inHours + (d.inMinutes % 60) / 60.0;

    final totalDur = FichajeUtils.calcularTotal(historial);
    final hoyDur = FichajeUtils.calcularDuracionDia(historial, now);
    final semanaDur = FichajeUtils.calcularRango(
      historial,
      now.subtract(Duration(days: now.weekday - 1)),
      now,
    );
    final mesDur = FichajeUtils.calcularRango(
      historial,
      DateTime(now.year, now.month, 1),
      now,
    );

    totalHoras = toHorasConDecimales(totalDur);
    hoy = toHorasConDecimales(hoyDur);
    horasSemana = toHorasConDecimales(semanaDur);
    horasMes = toHorasConDecimales(mesDur);

    if (mounted) setState(() => cargando = false);
  }

  String f(double h) => "${h.floor()}h ${(h % 1 * 60).round()}m";

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorPrincipal = entradaActual != null
        ? Colors.greenAccent.shade400
        : Colors.blueAccent.shade400;
    final nombre = user?["nombre"] ?? "Usuario";
    final email = user?["email"] ?? "";

    if (cargando) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0E1116) : Colors.white,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.greenAccent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Mi perfil",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: colorPrincipal,
            ),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0D1117), const Color(0xFF1C2232)]
                : [const Color(0xFFF6F8FF), const Color(0xFFE4EBFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              _avatar(nombre, colorPrincipal, isDark),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !editando
                    ? Column(
                        children: [
                          Text(
                            nombre,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      )
                    : _editarPerfil(isDark, colorPrincipal),
              ),
              const SizedBox(height: 26),
              _chipEstado(entradaActual != null, colorPrincipal),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _metric("Hoy", f(hoy), colorPrincipal, isDark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _metric(
                      "Semana",
                      f(horasSemana),
                      colorPrincipal,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _metric("Mes", f(horasMes), colorPrincipal, isDark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _metric(
                      "Total",
                      f(totalHoras),
                      colorPrincipal,
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildCalendario(isDark),
              const SizedBox(height: 40),
              _buildHistorialCard(isDark),
              const SizedBox(height: 40),
              _logoutButton(),
            ],
          ),
        ),
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
          resumen = "🎉 Día festivo en España";
          resumenColor = Colors.redAccent;
        } else if (eventosDelDia.isEmpty) {
          resumen = "🚫 No hay fichajes registrados";
          resumenColor = Colors.grey;
        } else if (duracionSel.inMinutes > 0) {
          resumen = "💼 Has trabajado ${horasSel}h ${minutosSel}m";
          resumenColor = colorPrincipal;
        } else {
          resumen = "📋 Fichajes sin duración (en pausa o sin salida)";
          resumenColor = Colors.orangeAccent;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Calendario laboral",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: txt,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: dark ? Colors.white10 : Colors.white,
              ),
              child: SizedBox(
                height: 420,
                child: TableCalendar(
                  locale: 'es_ES',
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: diaSeleccionado,
                  selectedDayPredicate: (day) =>
                      FichajeUtils.isSameDay(day, diaSeleccionado),
                  onDaySelected: (selectedDay, _) => actualizarDia(selectedDay),
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: colorPrincipal.withOpacity(.35),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: colorPrincipal,
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: const TextStyle(color: Colors.redAccent),
                    defaultTextStyle: TextStyle(
                      color: dark ? Colors.white : Colors.black,
                    ),
                    outsideDaysVisible: false,
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      color: dark ? Colors.white70 : Colors.black87,
                    ),
                    weekendStyle: const TextStyle(color: Colors.redAccent),
                  ),
                  headerStyle: HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                    titleTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: colorPrincipal,
                    ),
                    leftChevronIcon: Icon(
                      Icons.chevron_left,
                      color: colorPrincipal,
                    ),
                    rightChevronIcon: Icon(
                      Icons.chevron_right,
                      color: colorPrincipal,
                    ),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, _) {
                      final isFestivo = festivos.any(
                        (f) => FichajeUtils.isSameDay(f, day),
                      );
                      final horas = horasPorDia[day] ?? 0;

                      Color bgColor = Colors.transparent;
                      if (isFestivo) {
                        bgColor = Colors.redAccent.withOpacity(.25);
                      } else if (horas > 0) {
                        bgColor = Colors.greenAccent.withOpacity(.15);
                      } else if (day.weekday >= 6) {
                        bgColor = Colors.blueAccent.withOpacity(.08);
                      }

                      return Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: dark ? Colors.white : Colors.black,
                            fontWeight: horas > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                resumen,
                style: TextStyle(
                  color: resumenColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (eventosDelDia.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                "Fichajes del ${DateFormat('d MMMM', 'es_ES').format(diaSeleccionado)}",
                style: TextStyle(
                  color: txt,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...eventosDelDia.map((e) {
                final tipo = (e["tipo"] ?? "").toString().toLowerCase();
                final fecha = e["dt"] as DateTime;
                final color = switch (tipo) {
                  "entrada" => Colors.greenAccent.shade400,
                  "salida" => Colors.redAccent.shade400,
                  "inicio_pausa" => Colors.amberAccent.shade400,
                  "fin_pausa" => Colors.cyanAccent.shade400,
                  _ => Colors.grey,
                };
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: dark
                        ? Colors.white10
                        : Colors.black.withOpacity(.04),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: color, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tipo.toUpperCase(),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat("HH:mm").format(fecha),
                        style: TextStyle(
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }

  Widget _avatar(String nombre, Color color, bool dark) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "U";
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? Colors.white10 : Colors.black12,
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: dark
                  ? Colors.white12
                  : Colors.black.withOpacity(.06),
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
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => editando = !editando),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.edit, size: 18, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editarPerfil(bool dark, Color color) => Column(
    children: [
      _input(nombreCtrl, "Nombre", color, dark),
      const SizedBox(height: 12),
      _input(apellidosCtrl, "Apellidos", color, dark),
      const SizedBox(height: 12),
      _input(emailCtrl, "Email", color, dark),
      const SizedBox(height: 12),
      _input(dniCtrl, "DNI", color, dark),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          _toast("✅ Perfil actualizado correctamente");
          setState(() => editando = false);
        },
        icon: const Icon(Icons.save),
        label: const Text("Guardar"),
      ),
    ],
  );

  Widget _input(
    TextEditingController ctrl,
    String label,
    Color color,
    bool dark,
  ) {
    return TextField(
      controller: ctrl,
      style: TextStyle(color: dark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color),
        filled: true,
        fillColor: dark ? Colors.white10 : Colors.black.withOpacity(.04),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color.withOpacity(.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _chipEstado(bool trabajando, Color color) {
    final label = trabajando ? "Trabajando" : "Fuera de servicio";
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color),
          color: color.withOpacity(.1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
            fontSize: 18,
            color: txt,
          ),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: dias.length,
          itemBuilder: (context, i) {
            final diaKey = dias[i];
            final eventos = agrupado[diaKey]!;
            final fecha = DateTime.parse(diaKey);
            final esHoy = FichajeUtils.isSameDay(fecha, DateTime.now());

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: dark ? Colors.white12 : Colors.black.withOpacity(.04),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: Colors.amberAccent.shade400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          esHoy
                              ? "Hoy (${DateFormat('d MMM', 'es_ES').format(fecha)})"
                              : DateFormat("EEEE d MMM", 'es_ES').format(fecha),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.amberAccent.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...eventos.map((e) => _buildHistorialItem(e, dark)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHistorialItem(Map<String, dynamic> h, bool dark) {
    final tipo = (h["tipo"] ?? "").toString().toLowerCase();
    final fecha = h["dt"] as DateTime;
    final color = switch (tipo) {
      "entrada" => Colors.greenAccent.shade400,
      "salida" => Colors.redAccent.shade400,
      "inicio_pausa" => Colors.amberAccent.shade400,
      "fin_pausa" => Colors.cyanAccent.shade400,
      _ => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: dark ? Colors.white10 : Colors.black.withOpacity(.03),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_filled, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tipo.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            DateFormat("HH:mm").format(fecha),
            style: TextStyle(
              color: dark ? Colors.white70 : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() => ElevatedButton.icon(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.redAccent.shade400,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: const Icon(Icons.logout_rounded),
    label: const Text(
      "Cerrar sesión",
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    onPressed: () async {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
    },
  );

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.greenAccent.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
