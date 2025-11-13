import 'package:flutter/material.dart';
import 'package:registro_horario/features/notifications/notification_services.dart';
import 'package:registro_horario/services/auth_service.dart';

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

      _tabController ??=
          TabController(length: isAdmin ? 2 : 1, vsync: this);

      final recibidasData = await NotificationsService.getNotifications();
      List<Map<String, dynamic>> enviadasData = [];

      if (isAdmin) {
        enviadasData = await NotificationsService.getSentNotifications();
      }

      print("📬 Recibidas: ${recibidasData.length}");
      print("📤 Enviadas: ${enviadasData.length}");

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
        return const Icon(Icons.notifications, color: Colors.grey);
    }
  }

  Widget _lista(List<Map<String, dynamic>> notifs, {bool enviadas = false}) {
    if (notifs.isEmpty) {
      return const Center(
        child: Text("⭐ No hay notificaciones"),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: ListView.builder(
        itemCount: notifs.length,
        itemBuilder: (_, i) {
          final n = notifs[i];
          final fecha = DateTime.tryParse(n["fecha_envio"] ?? "");
          final hora = fecha != null
              ? "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}"
              : "";

          return Dismissible(
            key: Key(n["id"]),
            direction: DismissDirection.endToStart,
            onDismissed: (_) async {
              await NotificationsService.deleteNotification(n["id"]);
              _cargarTodo();
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: Colors.redAccent,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: ListTile(
              leading: _icon(n["tipo"] ?? ""),
              title: Text(
                n["titulo"] ?? "Sin título",
                style: TextStyle(
                  fontWeight: n["leida"] == true
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              subtitle: Text(
                enviadas
                    ? "📤 A: ${n["destinatario"] ?? "Empleado"}\n${n["mensaje"] ?? ""}"
                    : n["mensaje"] ?? "",
              ),
              isThreeLine: enviadas,
              trailing: Text(
                hora,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tabs = [
      const Tab(text: "📥 Recibidas"),
      if (isAdmin) const Tab(text: "📤 Enviadas"),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notificaciones"),
        bottom: _tabController != null
            ? TabBar(controller: _tabController, tabs: tabs)
            : null,
        actions: [
          if (!loading)
            TextButton(
              onPressed: () async {
                await NotificationsService.markAllRead();
                _cargarTodo();
              },
              child: const Text(
                "Marcar leídas",
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _tabController == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _lista(recibidas),
                if (isAdmin) _lista(enviadas, enviadas: true),
              ],
            ),
    );
  }
}
