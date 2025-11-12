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

  static const Duration objetivoDiario = Duration(hours: 8);
  Duration objetivoSemanal = const Duration(hours: 40);

  Duration _pausaHoy = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUser();
    _loadAll();

    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (estadoActual == "entrada") {
        _computeToday();
      }
      if (mounted) setState(() {});
    });

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
    try {
      DateTime dt = DateTime.parse(t);

      final sinZona = !t.contains('Z') && !t.contains('+') && !t.contains('-');
      if (sinZona) {
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
      print(" Error parseando '$t': $e");
      return DateTime.now();
    }
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
          return bd.compareTo(ad);
        });

        estadoActual = historial.first["tipo"];
        ultimaMarca = (historial.first["dt"] as DateTime).toLocal();

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
    final hoyLocal = DateTime.now().toLocal();
    final eventosHoy =
        historial.where((e) => _isSameDay(e["dt"], hoyLocal)).toList()..sort(
          (a, b) => (a["dt"] as DateTime).compareTo(b["dt"] as DateTime),
        );

    if (eventosHoy.isEmpty) {
      _pausaHoy = Duration.zero;
      return;
    }

    final inicio = (eventosHoy.first["dt"] as DateTime).toLocal();
    final totalPasado = hoyLocal.difference(inicio);
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
          ..sort((a, b) => a.date.compareTo(b.date));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trabajando = estadoActual == "entrada";
    final enPausa = estadoActual == "inicio_pausa";
    final baseColor = switch (estadoActual) {
      "entrada" => const Color(0xFF00C853), // verde brillante
      "inicio_pausa" => const Color(0xFFFFC107), // ámbar vivo
      "salida" => const Color(0xFFE53935), // rojo fuerte
      _ => const Color(0xFF1E88E5), // azul principal
    };

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
    ],
  );

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

  Widget _timeLens(Color baseColor, double progreso) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final pausaRatio =
        (_pausaHoy.inSeconds / max(1, (workedToday + _pausaHoy).inSeconds))
            .clamp(0.0, 1.0);

    return GestureDetector(
      onLongPress: _openWhatIfSheet,
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
                  color: baseColor.withOpacity(.15), // color plano sutil
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: baseColor, // borde sólido
                    width: 1.6,
                  ),
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

  Widget _insightCard() {
    final on = Theme.of(context).colorScheme.onSurface;
    DateTime? salidaPrevista;
    if (estadoActual == "entrada" && ultimaMarca != null) {
      final restante = objetivoDiario - workedToday;
      if (!restante.isNegative) {
        salidaPrevista = DateTime.now().add(restante);
      }
    }
    final totalSemana = last7.fold<double>(0, (a, b) => a + b.hours);
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

  Widget _weeklyForecastChart() {
    final labels = last7.map((e) => _d(e.date)).toList();
    final values = last7.map((e) => e.hours).toList();
    final avg = values.isEmpty
        ? 0.0
        : values.sublist(max(0, values.length - 3)).fold(0.0, (a, b) => a + b) /
              max(1, min(3, values.length));
    final predicted = List<double>.from(values);
    if (predicted.isNotEmpty) {
      predicted[predicted.length - 1] = max(values.last, avg);
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 420,
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
          ),
        ),
      ],
    );
  }

  void _openWhatIfSheet() {
    final ahora = DateTime.now().toLocal();
    final trabajando = estadoActual == "entrada";
    int pausaExtra = 0;

    DateTime salidaPrevista;
    if (trabajando && ultimaMarca != null) {
      salidaPrevista = ultimaMarca!.add(const Duration(hours: 8));
    } else {
      salidaPrevista = ahora.add(const Duration(hours: 8));
    }

    Timer? timer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setS) {
            timer ??= Timer.periodic(const Duration(seconds: 30), (_) {
              if (context.mounted) {
                setS(() {});
              } else {
                timer?.cancel();
              }
            });

            final total = workedToday - Duration(minutes: pausaExtra);
            final faltaPara8h = objetivoDiario - total;
            final cumpleHoy = faltaPara8h.isNegative;
            final porcentaje =
                (total.inSeconds / objetivoDiario.inSeconds * 100)
                    .clamp(0, 150)
                    .toStringAsFixed(1);

            final deficitSemana = _deficitSemanalRespectoObjetivo(
              simHoy: total,
            );
            final color = cumpleHoy ? Colors.greenAccent : Colors.amberAccent;
            final onSurface = Theme.of(context).colorScheme.onSurface;

            final textoResumen = trabajando
                ? "Si mantienes tu ritmo actual, cumplirás las 8h a las ${DateFormat('HH:mm').format(salidaPrevista)}."
                : "Tu jornada estimada finalizaría a las ${DateFormat('HH:mm').format(salidaPrevista)} si trabajases 8h.";

            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 10,
                left: 20,
                right: 20,
                top: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface.withOpacity(.98),
                    Theme.of(context).colorScheme.surface.withOpacity(.92),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(.15),
                    blurRadius: 25,
                    spreadRadius: 0,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barra superior de arrastre
                    Container(
                      width: 60,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),

                    // Título
                    Row(
                      children: [
                        Icon(Icons.timeline_rounded, color: color),
                        const SizedBox(width: 10),
                        Text(
                          "Proyección de jornada",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 🌈 Indicador circular premium
                    _buildAnimatedRing(cumpleHoy, color, total, context),

                    const SizedBox(height: 18),

                    // Slider de pausa extra
                    Row(
                      children: [
                        const Icon(Icons.coffee_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: color,
                              inactiveTrackColor: onSurface.withOpacity(.2),
                              thumbColor: color,
                              overlayColor: color.withOpacity(.2),
                            ),
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
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 🌟 Barras de rendimiento premium con destello
                    _barraInfoAvanzada(
                      icon: Icons.timer_rounded,
                      titulo: "Horas trabajadas",
                      valor: _fmtHM(total),
                      color: color,
                      progreso: total.inSeconds / objetivoDiario.inSeconds,
                      subtitulo: total < objetivoDiario
                          ? "Faltan ${_fmtHM(faltaPara8h.abs())} para completar la jornada"
                          : "Has cumplido el objetivo diario 🎯",
                    ),
                    const SizedBox(height: 12),

                    _barraInfoAvanzada(
                      icon: Icons.bolt_rounded,
                      titulo: "Cumplimiento diario",
                      valor: "$porcentaje %",
                      color: color,
                      progreso: total.inSeconds / objetivoDiario.inSeconds,
                      subtitulo: total.inHours < 4
                          ? "Vas a buen ritmo ⚡"
                          : total.inHours < 7
                          ? "Mantén el ritmo 💪"
                          : "Último tramo, casi logras las 8h 🏁",
                    ),
                    const SizedBox(height: 12),

                    _barraInfoAvanzada(
                      icon: Icons.trending_up_rounded,
                      titulo: "Balance semanal",
                      valor:
                          "${deficitSemana.isNegative ? '+' : '-'}${_fmtHM(deficitSemana.abs())}",
                      color: deficitSemana.isNegative
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      progreso:
                          (1 -
                                  (deficitSemana.inSeconds /
                                      objetivoSemanal.inSeconds))
                              .clamp(0.0, 1.0),
                      subtitulo: deficitSemana.isNegative
                          ? "Semana por encima del objetivo 📈"
                          : "Recupera tiempo pendiente 📉",
                    ),

                    const SizedBox(height: 20),

                    // Texto resumen
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        textoResumen,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: onSurface.withOpacity(.85),
                          fontSize: 14,
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // Botón final elegante
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                        shadowColor: color.withOpacity(.4),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 22),
                      label: Text(
                        "Salida prevista: ${DateFormat('HH:mm').format(salidaPrevista)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),

                    const SizedBox(height: 14),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => timer?.cancel());
  }

  Widget _buildAnimatedRing(
    bool cumpleHoy,
    Color color,
    Duration total,
    BuildContext context,
  ) {
    final ringColor = cumpleHoy ? Colors.greenAccent : color;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: total.inSeconds / objetivoDiario.inSeconds),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final percent = (value * 100).clamp(0, 100);

        return SizedBox(
          height: 140,
          width: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 🔵 Fondo base plano
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(.08),
                  shape: BoxShape.circle,
                ),
              ),

              // 🔵 Anillo simple plano
              CustomPaint(
                size: const Size(120, 120),
                painter: _AnimatedRingPainter(
                  progress: value.clamp(0.0, 1.0),
                  color: ringColor,
                ),
              ),

              // 🔵 Texto central
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${percent.toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: ringColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtHM(total),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _barraInfoAvanzada({
    required IconData icon,
    required String titulo,
    required String valor,
    required Color color,
    required double progreso,
    String? subtitulo,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progreso.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, anim, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(.85),
                  ),
                ),
                const Spacer(),
                Text(
                  valor,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 🔥 Barra animada con destello
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: anim,
                    backgroundColor: Colors.white.withOpacity(.05),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
                Positioned(
                  left: (anim * 200).clamp(0, 200),
                  child: Container(
                    width: 14,
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(.8),
                          color.withOpacity(.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitulo,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(.6),
                ),
              ),
            ],
          ],
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

  Duration _simularTotalHoy({
    required DateTime salida,
    required int pausaExtraMin,
  }) {
    Duration total = workedToday;

    total -= Duration(minutes: pausaExtraMin);
    if (total.isNegative) total = Duration.zero;

    return total;
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

class _DayHours {
  final DateTime date;
  double hours;
  _DayHours({required this.date, required this.hours});
}

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

class _PulseGaugePainter extends CustomPainter {
  final double progress;
  final double time;
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

class _EquilibriumRingPainter extends CustomPainter {
  final double workRatio;
  final double pauseRatio;
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

    arc.color = Colors.greenAccent.withOpacity(.9);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      2 * pi * workRatio,
      false,
      arc,
    );
    start += 2 * pi * workRatio;

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

class _AnimatedRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _AnimatedRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    // Fondo del anillo
    final bg = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bg);

    // Anillo de progreso color plano (sin gradiente)
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    final startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedRingPainter old) =>
      old.progress != progress || old.color != color;
}

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
    if (labels.isEmpty || real.isEmpty) return;

    final left = 32.0, right = 12.0, top = 14.0, bottom = 28.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [onSurface.withOpacity(.05), onSurface.withOpacity(.01)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(left, top, w, h));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w, h),
        const Radius.circular(12),
      ),
      bgPaint,
    );

    double toX(int i) => left + (i / max(1, labels.length - 1)) * w;
    double toY(double v) => top + (1 - (v / maxH).clamp(0, 1)) * h;

    final areaPath = Path()..moveTo(toX(0), toY(real[0]));
    for (int i = 1; i < real.length; i++) {
      areaPath.lineTo(toX(i), toY(real[i]));
    }
    areaPath.lineTo(toX(real.length - 1), top + h);
    areaPath.lineTo(toX(0), top + h);
    areaPath.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.greenAccent.withOpacity(.35), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(left, top, w, h));
    canvas.drawPath(areaPath, areaPaint);

    final glow = Paint()
      ..color = Colors.greenAccent.withOpacity(.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final realPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00FF99), Color(0xFF00E0FF)],
      ).createShader(Rect.fromLTWH(left, top, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    final realPath = Path()..moveTo(toX(0), toY(real[0]));
    for (int i = 1; i < real.length; i++) {
      realPath.lineTo(toX(i), toY(real[i]));
    }
    canvas.drawPath(realPath, glow);
    canvas.drawPath(realPath, realPaint);

    if (predicted.isNotEmpty) {
      final predPaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final predPath = Path()..moveTo(toX(0), toY(predicted[0]));
      for (int i = 1; i < predicted.length; i++) {
        predPath.lineTo(toX(i), toY(predicted[i]));
      }
      _dashPath(canvas, predPath, predPaint, 8, 5);
    }

    final dotOuter = Paint()..color = Colors.white.withOpacity(.85);
    final dotInner = Paint()..color = Colors.greenAccent;
    for (int i = 0; i < real.length; i++) {
      final dx = toX(i);
      final dy = toY(real[i]);
      canvas.drawCircle(Offset(dx, dy), 3.2, dotOuter);
      canvas.drawCircle(Offset(dx, dy), 2.0, dotInner);
    }

    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(.1)
      ..strokeWidth = 1.3;
    canvas.drawLine(
      Offset(left, top + h),
      Offset(left + w, top + h),
      axisPaint,
    );

    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    for (int i = 0; i < labels.length; i++) {
      tp.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onSurface.withOpacity(.75),
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(toX(i) - tp.width / 2, top + h + 6));
    }
  }

  void _dashPath(
    Canvas canvas,
    Path path,
    Paint paint,
    double dash,
    double gap,
  ) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = min(dash, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += len + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniForecastPainter old) =>
      old.real != real || old.predicted != predicted;
}

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

    const startAngle = -pi;
    const sweepAngle = pi;

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
