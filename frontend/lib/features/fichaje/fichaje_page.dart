// ---------------------------
// FICHAJE PAGE — TIMELENS 2.0 (proactivo + visual)
// ---------------------------

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:registro_horario/utils/fichaje_utils.dart';
import 'package:registro_horario/theme_provider.dart';
import 'package:registro_horario/features/notifications/notification_page.dart';
import 'package:registro_horario/features/fichaje/fichado_detalle_page.dart'
    hide FichajeUtils;
import 'package:registro_horario/services/fichaje_service.dart';
import 'package:registro_horario/services/auth_service.dart';

class FichajePage extends StatefulWidget {
  const FichajePage({super.key});
  @override
  State<FichajePage> createState() => _FichajePageState();
}

class _FichajePageState extends State<FichajePage> with WidgetsBindingObserver {
  bool loading = false;

  String estadoActual = "Sin registrar";
  DateTime? ultimaMarca;
  Timer? _tick;

  List<Map<String, dynamic>> historial = [];
  Duration workedToday = Duration.zero;
  List<_DayHours> last7 = [];
  Map<String, dynamic>? userData;

  // Objetivos
  static const Duration objetivoDiario = Duration(hours: 8);
  Duration objetivoSemanal = const Duration(hours: 40);

  // Para el anillo de equilibrio (trabajo vs pausa)
  Duration _pausaHoy = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _loadAll();

    // Ticks para pulso/gauge y contador vivo
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (estadoActual == "entrada") {
        _computeToday();
      }
      if (mounted) setState(() {});
    });

    // Recalcular semana y predicciones cada minuto
    Timer.periodic(const Duration(minutes: 1), (_) async {
      if (!mounted) return;
      _computeWeek();
      setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadAll();
  }

  Future<void> _loadUser() async {
    userData = await AuthService.getCurrentUser();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateTime _parse(String t) {
    final dt = DateTime.parse(t);
    return DateTime.utc(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
    ).toLocal();
  }

  Future<void> _loadAll() async {
    try {
      final data = await FichajeService.obtenerHistorial();
      if (data != null && data.isNotEmpty) {
        historial = data.map<Map<String, dynamic>>((e) {
          final d = _parse(e["fecha_hora"]);
          return {"tipo": e["tipo"], "dt": d};
        }).toList();

        historial.sort((a, b) {
          final ad = a["dt"] as DateTime?;
          final bd = b["dt"] as DateTime?;
          if (ad == null || bd == null) return 0;
          return bd.compareTo(ad); // más nuevo primero
        });

        estadoActual = historial.first["tipo"];
        ultimaMarca = historial.first["dt"];
        _computeToday();
        _computeWeek();
      } else {
        estadoActual = "Sin registrar";
        ultimaMarca = null;
        workedToday = Duration.zero;
        _pausaHoy = Duration.zero;
        last7 = _seedEmptyWeek();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al cargar: $e")));
    }
  }

  void _computeToday() {
    workedToday = FichajeUtils.calcularDuracionDia(historial, DateTime.now());
    // Pausa estimada hoy: diferencia entre (tiempo desde primer evento del día) - workedToday
    final hoy = DateTime.now();
    final eventosHoy = historial.where((e) => _isSameDay(e["dt"], hoy)).toList()
      ..sort((a, b) => (a["dt"] as DateTime).compareTo(b["dt"] as DateTime));

    if (eventosHoy.isEmpty) {
      _pausaHoy = Duration.zero;
      return;
    }
    final inicio = eventosHoy.first["dt"] as DateTime;
    final totalPasado = hoy.difference(inicio);
    final pausaAprox = totalPasado - workedToday;
    _pausaHoy = pausaAprox.isNegative ? Duration.zero : pausaAprox;
  }

  void _computeWeek() {
    final map = FichajeUtils.calcularSemana(historial);
    last7 =
        map.entries
            .map(
              (e) => _DayHours(date: e.key, hours: e.value.inSeconds / 3600.0),
            )
            .toList()
          ..sort(
            (a, b) => a.date.compareTo(b.date),
          ); // de más antiguo a más nuevo
  }

  List<_DayHours> _seedEmptyWeek() {
    final now = DateTime.now();
    return List.generate(
      7,
      (i) => _DayHours(
        date: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: 6 - i)),
        hours: 0,
      ),
    );
  }

  Future<void> _marcar(String tipo) async {
    HapticFeedback.mediumImpact();
    setState(() => loading = true);
    try {
      await FichajeService.marcar(tipo);
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("✅ $tipo registrado")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
      if (e.toString().contains("auth")) {
        await AuthService.logout();
        Navigator.pushReplacementNamed(context, "/login");
      }
    }
    setState(() => loading = false);
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trabajando = estadoActual == "entrada";
    final enPausa = estadoActual == "inicio_pausa";
    final baseColor = trabajando
        ? Colors.greenAccent.shade400
        : enPausa
        ? Colors.amberAccent.shade400
        : Colors.blueAccent.shade400;

    final progreso = (workedToday.inSeconds / objetivoDiario.inSeconds).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Control horario",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "¿Y si...?",
            icon: Icon(
              Icons.help_center_outlined,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: _openWhatIfSheet,
          ),
          IconButton(
            icon: Icon(
              theme.brightness == Brightness.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => Provider.of<ThemeProvider>(
              context,
              listen: false,
            ).toggleTheme(),
          ),
          IconButton(
            tooltip: "Notificaciones",
            icon: Icon(
              Icons.notifications_rounded,
              color: theme.colorScheme.onSurface,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsPage()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 40),
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              onSelected: (value) async {
                if (value == "perfil") {
                  Navigator.pushNamed(context, "/perfil");
                } else if (value == "detalle") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FichadoDetallePage(),
                    ),
                  );
                } else if (value == "logout") {
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    "/login",
                    (_) => false,
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: "perfil",
                  child: Row(
                    children: const [
                      Icon(Icons.person),
                      SizedBox(width: 10),
                      Text("Perfil"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: "detalle",
                  child: Row(
                    children: const [
                      Icon(Icons.access_time),
                      SizedBox(width: 10),
                      Text("Detalles"),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: "logout",
                  child: Row(
                    children: const [
                      Icon(Icons.logout, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Text(
                        "Cerrar sesión",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white10,
                child: Text(
                  (userData?["nombre"]?[0]?.toUpperCase() ?? "U"),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Fondo Aurora animado
          const _AuroraBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final isWeb = c.maxWidth > 900;
                final maxW = 1100.0;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: isWeb
                          ? _web(baseColor, progreso, trabajando, enPausa)
                          : _mobile(baseColor, progreso, trabajando, enPausa),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _web(Color base, double progreso, bool t, bool p) =>
      SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _glass(_timeLens(base, progreso))),
                const SizedBox(width: 22),
                Expanded(child: _glass(_actions(base, t, p))),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _glass(_insightCard())),
                const SizedBox(width: 22),
                Expanded(child: _glass(_weeklyForecastChart())),
              ],
            ),
            const SizedBox(height: 22),
            _glass(_shadowTimelineSection()),
          ],
        ),
      );

  Widget _mobile(Color base, double progreso, bool t, bool p) => ListView(
    children: [
      _glass(_timeLens(base, progreso)),
      const SizedBox(height: 16),
      _glass(_actions(base, t, p)),
      const SizedBox(height: 16),
      _glass(_insightCard()),
      const SizedBox(height: 16),
      _glass(_weeklyForecastChart()),
      const SizedBox(height: 16),
      _glass(_shadowTimelineSection()),
    ],
  );

  // ---- Tarjeta de cristal
  Widget _glass(Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.surface.withOpacity(.10),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.08),
          ),
        ),
        child: child,
      ),
    ),
  );

  // =========================
  // TimeLens (gauge pulso + anillo equilibrio)
  // =========================
  Widget _timeLens(Color baseColor, double progreso) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final pausaRatio =
        (_pausaHoy.inSeconds / max(1, (workedToday + _pausaHoy).inSeconds))
            .clamp(0.0, 1.0);

    return GestureDetector(
      onLongPress: _openWhatIfSheet, // abrir simulador
      child: Column(
        children: [
          Text("Hoy", style: TextStyle(color: onSurface, fontSize: 15)),
          const SizedBox(height: 10),
          SizedBox(
            height: 240,
            width: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gauge con pulso
                CustomPaint(
                  size: const Size(220, 220),
                  painter: _PulseGaugePainter(
                    progress: progreso,
                    color: baseColor,
                    background: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(.1),
                    time: DateTime.now().millisecondsSinceEpoch / 1000.0,
                  ),
                ),
                // Anillo de equilibrio (fino)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: CustomPaint(
                      painter: _EquilibriumRingPainter(
                        workRatio: 1.0 - pausaRatio,
                        pauseRatio: pausaRatio,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _fmtHMS(workedToday),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Objetivo: ${_fmtHM(objetivoDiario)}",
                      style: TextStyle(color: onSurface.withOpacity(.6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _badgeEstado(),
        ],
      ),
    );
  }

  Widget _badgeEstado() {
    Color c;
    String t;
    switch (estadoActual) {
      case "entrada":
        c = Colors.greenAccent.shade400;
        t = "Trabajando";
        break;
      case "inicio_pausa":
        c = Colors.amberAccent.shade400;
        t = "En pausa";
        break;
      default:
        c = Colors.blueAccent.shade400;
        t = "Fuera de jornada";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(.4)),
      ),
      child: Text(t, style: TextStyle(color: c, fontSize: 13)),
    );
  }

  // =========================
  // Acciones principales
  // =========================
  Widget _actions(Color baseColor, bool trabajando, bool enPausa) {
    final txt = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        TweenAnimationBuilder(
          tween: Tween(begin: 0.97, end: 1.0),
          duration: const Duration(seconds: 2),
          builder: (c, val, _) => Transform.scale(
            scale: val,
            child: InkWell(
              onTap: loading
                  ? null
                  : () => _marcar(trabajando ? "salida" : "entrada"),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: baseColor, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withOpacity(.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: loading
                    ? const CircularProgressIndicator()
                    : Text(
                        trabajando ? "Terminar jornada" : "Iniciar jornada",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: baseColor,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (trabajando || enPausa)
          SizedBox(
            width: 200,
            child: OutlinedButton.icon(
              icon: Icon(enPausa ? Icons.play_arrow : Icons.pause),
              label: Text(enPausa ? "Reanudar" : "Pausa"),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: txt.withOpacity(.2)),
                foregroundColor: txt.withOpacity(.7),
              ),
              onPressed: loading
                  ? null
                  : () => _marcar(enPausa ? "fin_pausa" : "inicio_pausa"),
            ),
          ),
        const SizedBox(height: 18),
        if (ultimaMarca != null)
          Column(
            children: [
              Text(
                trabajando ? "Entrada" : "Último fichaje",
                style: TextStyle(color: txt.withOpacity(.6), fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('HH:mm').format(ultimaMarca!),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: baseColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // =========================
  // Insight predictivo
  // =========================
  Widget _insightCard() {
    final on = Theme.of(context).colorScheme.onSurface;
    // Predicción simple: ritmo actual -> hora estimada para cumplir 8h
    DateTime? salidaPrevista;
    if (estadoActual == "entrada" && ultimaMarca != null) {
      final restante = objetivoDiario - workedToday;
      if (!restante.isNegative) {
        salidaPrevista = DateTime.now().add(restante);
      }
    }
    // Proyección semanal
    final totalSemana = last7.fold<double>(
      0,
      (a, b) => a + b.hours,
    ); // horas reales
    final objetivoSemana = objetivoSemanal.inHours.toDouble();
    final ratioSemana = (totalSemana / max(1.0, objetivoSemana)).clamp(0, 1);

    final texto1 = salidaPrevista != null
        ? "Si mantienes el ritmo, cumples a las ${DateFormat('HH:mm').format(salidaPrevista)}."
        : "No estás en jornada; inicia para proyectar salida.";
    final texto2 = totalSemana >= objetivoSemana
        ? "Semana por encima del objetivo (+${_h(totalSemana - objetivoSemana)})."
        : "Te faltan ${_h(objetivoSemana - totalSemana)} esta semana.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.cyanAccent.shade400),
            const SizedBox(width: 6),
            Text(
              "Insight predictivo",
              style: TextStyle(color: on, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(texto1, style: TextStyle(color: on.withOpacity(.85))),
        const SizedBox(height: 6),
        Text(texto2, style: TextStyle(color: on.withOpacity(.7))),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: ratioSemana.toDouble(),
          minHeight: 8,
          backgroundColor: on.withOpacity(.1),
          valueColor: AlwaysStoppedAnimation<Color>(
            totalSemana >= objetivoSemana
                ? Colors.greenAccent
                : Colors.orangeAccent,
          ),
        ),
      ],
    );
  }

  // =========================
  // Mini Forecast semanal (real + predicción simple)
  // =========================
  Widget _weeklyForecastChart() {
    final labels = last7.map((e) => _d(e.date)).toList();
    final values = last7.map((e) => e.hours).toList();
    // predicción naive: promedio de los últimos 3 días
    final avg = values.isEmpty
        ? 0.0
        : values.sublist(max(0, values.length - 3)).fold(0.0, (a, b) => a + b) /
              max(1, min(3, values.length));
    final predicted = List<double>.from(values);
    if (predicted.isNotEmpty) {
      predicted[predicted.length - 1] = max(
        values.last,
        avg,
      ); // empuja al último con media si es menor
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Tendencia semanal",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _MiniForecastPainter(
              labels: labels,
              real: values,
              predicted: predicted,
              maxH: 10,
              onSurface: Theme.of(
                context,
              ).colorScheme.onSurface.withOpacity(.7),
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // Shadow timeline de la tarjeta inferior
  // =========================
  Widget _shadowTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Línea temporal con sombra de futuro",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 70,
          child: CustomPaint(
            painter: _ShadowTimelinePainterV2(
              worked: workedToday,
              objetivo: objetivoDiario,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Mantén pulsado el círculo de horas para abrir el simulador.",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _openWhatIfSheet() {
    final now = DateTime.now();
    final trabajando = estadoActual == "entrada";
    DateTime salidaSimulada = now.add(const Duration(hours: 1));
    int pausaExtra = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(.98),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setS) {
            // 🔹 Simula total trabajado realista
            final totalSimulado = _simularTotalHoy(
              salida: salidaSimulada,
              pausaExtraMin: pausaExtra,
            );

            final faltaPara8h = objetivoDiario - totalSimulado;
            final cumpleHoy = faltaPara8h.isNegative;
            final porcentaje =
                (totalSimulado.inSeconds / objetivoDiario.inSeconds * 100)
                    .clamp(0, 150)
                    .toStringAsFixed(1);

            final deficitSemana = _deficitSemanalRespectoObjetivo(
              simHoy: totalSimulado,
            );

            // 🔹 Mensaje predictivo más humano
            String textoResumen;
            if (cumpleHoy) {
              textoResumen =
                  "Si sales a las ${DateFormat('HH:mm').format(salidaSimulada)}, habrás completado ${_fmtHM(totalSimulado)} de trabajo (🟢 ${porcentaje}%) y acumularás ${_fmtHM(deficitSemana.abs())} de ${deficitSemana.isNegative ? 'excedente' : 'déficit'} semanal.";
            } else {
              textoResumen =
                  "Si sales a las ${DateFormat('HH:mm').format(salidaSimulada)}, habrás trabajado ${_fmtHM(totalSimulado)} (${porcentaje}%) y te faltarán ${_fmtHM(faltaPara8h.abs())} para cumplir las 8h.";
            }

            final color = cumpleHoy ? Colors.greenAccent : Colors.amberAccent;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                left: 20,
                right: 20,
                top: 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded),
                        const SizedBox(width: 8),
                        Text(
                          "Simulador de jornada",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 🔹 Selector de hora real
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Hora de salida simulada:"),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(
                                salidaSimulada,
                              ),
                            );
                            if (picked != null) {
                              setS(() {
                                salidaSimulada = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  picked.hour,
                                  picked.minute,
                                );
                              });
                            }
                          },
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            DateFormat('HH:mm').format(salidaSimulada),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 🔹 Pausa extra
                    Row(
                      children: [
                        const Icon(Icons.coffee_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: pausaExtra.toDouble(),
                            min: 0,
                            max: 90,
                            divisions: 9,
                            label: "${pausaExtra} min pausa",
                            onChanged: (v) =>
                                setS(() => pausaExtra = v.round()),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 🔹 Barras de progreso
                    _barraInfo(
                      "Horas totales simuladas",
                      _fmtHM(totalSimulado),
                      color,
                      totalSimulado.inSeconds / objetivoDiario.inSeconds,
                    ),
                    const SizedBox(height: 10),
                    _barraInfo(
                      "Cumplimiento del objetivo diario",
                      "$porcentaje %",
                      color,
                      totalSimulado.inSeconds / objetivoDiario.inSeconds,
                    ),
                    const SizedBox(height: 10),
                    _barraInfo(
                      "Balance semanal estimado",
                      "${deficitSemana.isNegative ? '+' : '-'}${_fmtHM(deficitSemana.abs())}",
                      deficitSemana.isNegative
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      (1 -
                              (deficitSemana.inSeconds /
                                  objetivoSemanal.inSeconds))
                          .clamp(0.0, 1.0),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      textoResumen,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.flash_on),
                      label: Text(
                        cumpleHoy
                            ? "Salir a las ${DateFormat('HH:mm').format(salidaSimulada)}"
                            : "Continuar hasta ${DateFormat('HH:mm').format(salidaSimulada)}",
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        if (estadoActual == "entrada" &&
                            cumpleHoy &&
                            salidaSimulada.isBefore(
                              DateTime.now().add(const Duration(minutes: 5)),
                            )) {
                          _marcar("salida");
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _barraInfo(String titulo, String valor, Color color, double progreso) {
    progreso = progreso.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            Text(
              valor,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progreso,
            minHeight: 6,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // =========================
  // Helpers de simulación/presentación
  // =========================
  Duration _simularTotalHoy({
    required DateTime salida,
    required int pausaExtraMin,
  }) {
    final hoy = DateTime.now();
    Duration base = FichajeUtils.calcularDuracionDia(historial, hoy);

    final estaTrabajando = estadoActual == "entrada";
    if (estaTrabajando &&
        ultimaMarca != null &&
        _isSameDay(ultimaMarca!, hoy)) {
      final desdeEntrada = DateTime.now().difference(ultimaMarca!);
      base -= desdeEntrada; // quitar tramo real actual
      base += salida.difference(ultimaMarca!); // añadir tramo simulado
    }
    base -= Duration(minutes: pausaExtraMin);
    if (base.isNegative) base = Duration.zero;
    return base;
  }

  Duration _deficitSemanalRespectoObjetivo({required Duration simHoy}) {
    final totalSemanaReal = last7.fold<Duration>(
      Duration.zero,
      (a, d) => a + Duration(minutes: (d.hours * 60).round()),
    );
    final hoyReal = workedToday;
    final semanaConHoySim = totalSemanaReal - hoyReal + simHoy;
    return objetivoSemanal - semanaConHoySim;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _chipInfo(String t, String v, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: c.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: TextStyle(color: c.withOpacity(.9), fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              v,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Formatters
  String _fmtHM(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  String _fmtHMS(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$hh:$mm:$ss";
  }

  String _h(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return "${hh}h ${mm.toString().padLeft(2, "0")}m";
  }

  String _d(DateTime d) {
    const dias = ["L", "M", "X", "J", "V", "S", "D"];
    return dias[d.weekday - 1];
  }
}

// =========================
// MODELOS
// =========================
class _DayHours {
  final DateTime date;
  double hours;
  _DayHours({required this.date, required this.hours});
}

// =========================
// AURORA BACKGROUND
// =========================
class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground();
  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                const Color(0xFF00FFE0).withOpacity(.18 + .12 * _c.value),
                const Color(0xFF0057FF).withOpacity(.18 + .12 * (1 - _c.value)),
                Theme.of(context).scaffoldBackgroundColor,
              ],
              center: Alignment(.6 - _c.value * .2, -.4 + _c.value * .2),
              radius: 1.2,
            ),
          ),
        );
      },
    );
  }
}

// =========================
// PAINTERS VISUALES
// =========================

// Gauge con pulso (borde late según el tiempo)
class _PulseGaugePainter extends CustomPainter {
  final double progress; // 0..1
  final double time; // segundos
  final Color color;
  final Color background;

  _PulseGaugePainter({
    required this.progress,
    required this.time,
    required this.color,
    required this.background,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - 8;

    final bg = Paint()
      ..color = background
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;

    // Pulso: 0.9..1.1
    final pulse = 1 + 0.06 * sin(time * 2 * pi);
    final w = 12 * pulse;

    final fg = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(.7), color],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;

    canvas.drawCircle(center, radius, bg);

    final start = -pi / 2;
    final sweep = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      fg,
    );

    // Partículas leves
    final pCount = 14;
    final dotPaint = Paint()..color = color.withOpacity(.55);
    for (int i = 0; i < pCount; i++) {
      final t = (i / pCount) * sweep + start + (time * .8);
      final r = radius + 3 * sin(time + i);
      final pos = Offset(center.dx + r * cos(t), center.dy + r * sin(t));
      canvas.drawCircle(pos, 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulseGaugePainter old) =>
      old.progress != progress || old.time != time;
}

// Anillo fino: proporción trabajo/pausa
class _EquilibriumRingPainter extends CustomPainter {
  final double workRatio; // 0..1
  final double pauseRatio; // 0..1
  _EquilibriumRingPainter({required this.workRatio, required this.pauseRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = min(size.width, size.height) / 2 - 2;
    final base = Paint()
      ..color = Colors.white.withOpacity(.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(c, r, base);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    double start = -pi / 2;

    // Trabajo (verde)
    arc.color = Colors.greenAccent.withOpacity(.9);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      2 * pi * workRatio,
      false,
      arc,
    );
    start += 2 * pi * workRatio;

    // Pausa (ámbar)
    arc.color = Colors.amberAccent.withOpacity(.9);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      2 * pi * pauseRatio,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _EquilibriumRingPainter old) =>
      old.workRatio != workRatio || old.pauseRatio != pauseRatio;
}

// Mini Forecast (línea real + punteada predicción)
class _MiniForecastPainter extends CustomPainter {
  final List<String> labels;
  final List<double> real;
  final List<double> predicted;
  final double maxH;
  final Color onSurface;

  _MiniForecastPainter({
    required this.labels,
    required this.real,
    required this.predicted,
    required this.maxH,
    required this.onSurface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;

    final left = 28.0, right = 8.0, top = 8.0, bottom = 22.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    final bg = Paint()..color = onSurface.withOpacity(.06);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w, h),
        const Radius.circular(10),
      ),
      bg,
    );

    final toX = (int i) =>
        left + (i / max(1, labels.length - 1)) * w; // puntos equiespaciados
    double toY(double v) => top + (1 - (v / maxH).clamp(0, 1)) * h;

    // Real (línea sólida)
    final realPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final pr = Path()..moveTo(toX(0), toY(real[0]));
    for (int i = 1; i < real.length; i++) {
      pr.lineTo(toX(i), toY(real[i]));
    }
    canvas.drawPath(pr, realPaint);

    // Predicción (punteada)
    final predPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final pp = Path()..moveTo(toX(0), toY(predicted[0]));
    for (int i = 1; i < predicted.length; i++) {
      pp.lineTo(toX(i), toY(predicted[i]));
    }
    // punteado manual
    _dashPath(canvas, pp, predPaint, 6, 5);

    // Etiquetas
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    for (int i = 0; i < labels.length; i++) {
      tp.text = TextSpan(
        text: labels[i],
        style: TextStyle(fontSize: 11, color: onSurface.withOpacity(.8)),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(toX(i) - tp.width / 2, top + h + 4),
      ); // bajo del área
    }
  }

  void _dashPath(Canvas c, Path p, Paint paint, double dash, double gap) {
    final pm = p.computeMetrics().first;
    double dist = 0;
    while (dist < pm.length) {
      final next = min(dash, pm.length - dist);
      c.drawPath(pm.extractPath(dist, dist + next), paint);
      dist += next + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _MiniForecastPainter old) =>
      old.real != real || old.predicted != predicted;
}

// Timeline compacta (trabajado vs objetivo)
class _ShadowTimelinePainterV2 extends CustomPainter {
  final Duration worked;
  final Duration objetivo;

  _ShadowTimelinePainterV2({required this.worked, required this.objetivo});

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = Colors.white12;
    final workedP = Paint()..color = Colors.greenAccent.withOpacity(.85);

    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height / 2 - 8, size.width, 16),
      const Radius.circular(12),
    );
    canvas.drawRRect(r, base);

    final total = max(1, objetivo.inSeconds);
    final w = (worked.inSeconds / total).clamp(0.0, 1.0) * size.width;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height / 2 - 8, w, 16),
        const Radius.circular(12),
      ),
      workedP,
    );
  }

  @override
  bool shouldRepaint(covariant _ShadowTimelinePainterV2 old) =>
      old.worked != worked || old.objetivo != objetivo;
}

// Dial semicírculo del What-If
class _DialPainterV2 extends CustomPainter {
  final double progress; // 0..1
  _DialPainterV2({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 10);
    final radius = size.width / 2.2;

    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = Colors.lightBlueAccent.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    const startAngle = -pi; // izquierda
    const sweepAngle = pi; // semicirculo

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainterV2 old) => old.progress != progress;
}
