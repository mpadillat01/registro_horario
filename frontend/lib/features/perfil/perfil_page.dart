import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
  final rolCtrl = TextEditingController();

  List<Map<String, dynamic>> historial = [];

  @override
  void initState() {
    super.initState();
    cargarDatos();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => cargarDatos());
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
    rolCtrl.text = user!["rol"] ?? "";

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
      if (estado.contains("entrada")) {
        entradaActual = FichajeUtils.parseUtcToLocal(fecha ?? "");
      } else {
        entradaActual = null;
      }
    }

    final now = DateTime.now();
    final totalDuracion = FichajeUtils.calcularTotal(historial);
    final hoyDuracion = FichajeUtils.calcularDuracionDia(
      historial,
      DateTime.now(),
    );
    final semanaDuracion = FichajeUtils.calcularRango(
      historial,
      now.subtract(Duration(days: now.weekday - 1)),
      now,
    );
    final mesDuracion = FichajeUtils.calcularRango(
      historial,
      DateTime(now.year, now.month, 1),
      now,
    );

    totalHoras = totalDuracion.inSeconds / 3600.0;
    hoy = hoyDuracion.inSeconds / 3600.0;
    horasSemana = semanaDuracion.inSeconds / 3600.0;
    horasMes = mesDuracion.inSeconds / 3600.0;

    cargando = false;
    if (mounted) setState(() {});
  }

  String f(double h) =>
      "${h.floor()}h ${(((h - h.floor()) * 60).round()).toString().padLeft(2, '0')}m";

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glow = entradaActual != null ? Colors.greenAccent : Colors.blueAccent;
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
      backgroundColor: isDark ? const Color(0xFF0E1116) : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: ShaderMask(
          shaderCallback: (r) => LinearGradient(
            colors: [glow.withOpacity(.9), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(r),
          child: const Text(
            "Mi perfil",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: glow,
            ),
            onPressed: () => Provider.of<ThemeProvider>(
              context,
              listen: false,
            ).toggleTheme(),
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF0E1116), Color(0xFF141823)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFf3f6ff), Color(0xFFe9efff)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            const SizedBox(height: 10),
            _avatar(nombre, glow, isDark),
            const SizedBox(height: 22),

            /// 🟢 Solo nombre/email o modo edición
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: !editando
                  ? Column(
                      children: [
                        Text(
                          nombre,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    )
                  : _editarPerfil(isDark, glow),
            ),

            const SizedBox(height: 26),
            _chipEstado(entradaActual != null, glow),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(child: _metric("Hoy", f(hoy), glow, isDark)),
                const SizedBox(width: 14),
                Expanded(
                  child: _metric("Semana", f(horasSemana), glow, isDark),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _metric("Mes", f(horasMes), glow, isDark)),
                const SizedBox(width: 14),
                Expanded(child: _metric("Total", f(totalHoras), glow, isDark)),
              ],
            ),
            const SizedBox(height: 30),
            _buildHistorialCard(isDark),
            const SizedBox(height: 30),
            _logoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String nombre, Color glow, bool isDark) {
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : "U";

    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glow.withOpacity(.4),
                  blurRadius: 25,
                  spreadRadius: 2,
                ),
              ],
              gradient: LinearGradient(
                colors: [
                  glow.withOpacity(.8),
                  isDark
                      ? Colors.white.withOpacity(.08)
                      : Colors.black.withOpacity(.05),
                ],
              ),
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(.06)
                  : Colors.black.withOpacity(.06),
              child: Text(
                inicial,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                  color: glow,
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
                decoration: BoxDecoration(
                  color: glow,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: glow.withOpacity(.4), blurRadius: 10),
                  ],
                ),
                child: const Icon(Icons.edit, size: 18, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editarPerfil(bool isDark, Color glow) => Column(
    children: [
      _input(nombreCtrl, "Nombre", glow, isDark),
      const SizedBox(height: 12),
      _input(apellidosCtrl, "Apellidos", glow, isDark),
      const SizedBox(height: 12),
      _input(emailCtrl, "Email", glow, isDark),
      const SizedBox(height: 12),
      _input(dniCtrl, "DNI", glow, isDark),
      const SizedBox(height: 12),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: glow,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          _toast("✅ Perfil actualizado correctamente");
          setState(() {
            user!["nombre"] = nombreCtrl.text;
            user!["apellidos"] = apellidosCtrl.text;
            user!["email"] = emailCtrl.text;
            user!["dni"] = dniCtrl.text;
            editando = false;
          });
        },
        icon: const Icon(Icons.save),
        label: const Text("Guardar"),
      ),
    ],
  );

  Widget _input(
    TextEditingController ctrl,
    String label,
    Color glow,
    bool dark, {
    bool enabled = true,
  }) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      style: TextStyle(
        color: enabled
            ? (dark ? Colors.white : Colors.black)
            : Colors.grey.shade500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: glow.withOpacity(.8)),
        filled: true,
        fillColor: enabled
            ? (dark
                  ? Colors.white.withOpacity(.05)
                  : Colors.black.withOpacity(.04))
            : Colors.grey.withOpacity(.1),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: glow.withOpacity(.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: glow, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _chipEstado(bool trabajando, Color glow) {
    final label = trabajando ? "Trabajando" : "Fuera de servicio";
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: glow.withOpacity(.5)),
          color: glow.withOpacity(.12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: glow,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _metric(String title, String value, Color glow, bool dark) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: dark
              ? Colors.white.withOpacity(.05)
              : Colors.black.withOpacity(.04),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: dark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                color: glow,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
      );

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Historial de fichajes",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: txt,
          ),
        ),
        const SizedBox(height: 10),

        // 🔽 Scroll interno para los fichajes
        Container(
          constraints: const BoxConstraints(
            maxHeight: 300,
          ), // puedes ajustar altura
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: dark
                ? Colors.white.withOpacity(.03)
                : Colors.black.withOpacity(.03),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            radius: const Radius.circular(20),
            thickness: 4,
            child: ListView.builder(
              itemCount: historial.length,
              physics: const AlwaysScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final h = historial[index];
                return _buildHistorialItem(h, dark);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorialItem(Map<String, dynamic> h, bool dark) {
    final tipo = (h["tipo"] ?? "").toString().toLowerCase();
    final fecha = h["dt"] as DateTime;
    final color = switch (tipo) {
      "entrada" => Colors.greenAccent,
      "salida" => Colors.redAccent,
      "inicio_pausa" => Colors.amberAccent,
      "fin_pausa" => Colors.blueAccent,
      _ => Colors.grey,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withOpacity(.05)
            : Colors.black.withOpacity(.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_filled, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tipo.toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            DateFormat("dd/MM HH:mm").format(fecha),
            style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
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
