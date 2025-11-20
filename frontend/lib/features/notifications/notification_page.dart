import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:registro_horario/features/notifications/notification_services.dart';
import 'package:registro_horario/services/api_service.dart';
import 'package:registro_horario/services/auth_service.dart';
import 'dart:html' as html;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> recibidas = [];
  List<Map<String, dynamic>> enviadas = [];
  bool loading = true;
  bool isAdmin = false;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    try {
      setState(() => loading = true);

      final user = await AuthService.getCurrentUser();
      isAdmin = (user["rol"] == "admin");

      _tabController ??= TabController(length: isAdmin ? 2 : 1, vsync: this);

      final recibidasData = await NotificationsService.getNotifications();
      List<Map<String, dynamic>> enviadasData = [];

      if (isAdmin) {
        enviadasData = await NotificationsService.getSentNotifications();
      }

      setState(() {
        recibidas = recibidasData;
        enviadas = enviadasData;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar notificaciones: $e")),
      );
    }
  }

  Icon _icon(String tipo) {
    switch (tipo) {
      case "recordatorio":
        return const Icon(Icons.alarm, color: Colors.orange);
      case "aviso":
        return const Icon(Icons.warning, color: Colors.redAccent);
      case "mensaje_admin":
        return const Icon(Icons.campaign, color: Colors.blueAccent);
      default:
        return const Icon(
          Icons.notifications_active_rounded,
          color: Colors.grey,
        );
    }
  }

  Map<String, List<Map<String, dynamic>>> agruparPorDia(
    List<Map<String, dynamic>> notifs,
  ) {
    final Map<String, List<Map<String, dynamic>>> grupos = {};

    for (var n in notifs) {
      final fecha = DateTime.tryParse(n["fecha_envio"] ?? "");
      if (fecha == null) continue;

      final hoy = DateTime.now();
      final ayer = hoy.subtract(const Duration(days: 1));

      String clave;

      if (_esMismoDia(fecha, hoy)) {
        clave = "Hoy";
      } else if (_esMismoDia(fecha, ayer)) {
        clave = "Ayer";
      } else {
        clave =
            "${fecha.day.toString().padLeft(2, '0')} / ${fecha.month.toString().padLeft(2, '0')} / ${fecha.year}";
      }

      grupos.putIfAbsent(clave, () => []).add(n);
    }

    return grupos;
  }

  bool _esMismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _descargarArchivo(String archivo) async {
    final url =
        "${ApiService.baseUrl}/documentos/descargar-por-nombre/$archivo";

    try {
      final headers = await ApiService.authHeaders();
      final res = await http.get(Uri.parse(url), headers: headers);

      if (res.statusCode != 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error al descargar archivo")));
        return;
      }

      final bytes = res.bodyBytes;

      if (kIsWeb) {
        final blob = html.Blob([bytes], 'application/octet-stream');
        final url2 = html.Url.createObjectUrlFromBlob(blob);
        final a = html.AnchorElement(href: url2)
          ..setAttribute("download", archivo)
          ..click();
        html.Url.revokeObjectUrl(url2);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _lista(List<Map<String, dynamic>> notifs, {bool enviadas = false}) {
    if (notifs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text(
            "⭐ No hay notificaciones",
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ),
      );
    }

    final agrupado = agruparPorDia(notifs);
    final diasKeys = agrupado.keys.toList();

    diasKeys.sort((a, b) {
      if (a == "Hoy") return -1;
      if (b == "Hoy") return 1;
      if (a == "Ayer") return -1;
      if (b == "Ayer") return 1;
      return 0;
    });

    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          ...diasKeys.map((dia) {
            final lista = agrupado[dia]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 15,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              dia,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                ...lista.map((n) {
                  final fecha = DateTime.tryParse(n["fecha_envio"] ?? "");
                  final hora = fecha != null
                      ? "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}"
                      : "";

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Dismissible(
                      key: Key(n["id"]),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) async {
                        await NotificationsService.deleteNotification(n["id"]);
                        _cargarTodo();
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),

                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.05),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _icon(n["tipo"] ?? ""),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n["titulo"] ?? "Sin título",
                                    style: TextStyle(
                                      fontWeight: n["leida"] == true
                                          ? FontWeight.w500
                                          : FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    enviadas
                                        ? "📤 A: ${n["destinatario"] ?? "Empleado"}\n${n["mensaje"] ?? ""}"
                                        : n["mensaje"] ?? "",
                                    style: const TextStyle(
                                      height: 1.3,
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  hora,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                                if (n["archivo"] != null &&
                                    n["archivo"].toString().isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.download_rounded,
                                      color: Colors.blueAccent,
                                      size: 22,
                                    ),
                                    onPressed: () =>
                                        _descargarArchivo(n["archivo"]),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),

        title: const Text(
          "Notificaciones",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),

        actions: [
          if (!loading)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: GestureDetector(
                  onTap: () async {
                    await NotificationsService.markAllRead();
                    _cargarTodo();
                  },
                  child: Text(
                    "Marcar leídas",
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.blueAccent,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.inbox_rounded), text: "Recibidas"),
                ],
              ),

              Container(height: 1, color: Colors.white.withOpacity(0.07)),
            ],
          ),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: [
          _lista(recibidas),
          if (isAdmin) _lista(enviadas, enviadas: true),
        ],
      ),
    );
  }
}
