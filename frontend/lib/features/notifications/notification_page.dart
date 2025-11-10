import 'package:flutter/material.dart';
import 'package:registro_horario/features/notifications/notification_services.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    cargar();
  }

  Future<void> cargar() async {
    try {
      final data = await NotificationsService.getNotifications();
      setState(() {
        notifications = data;
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
      default:
        return const Icon(Icons.notifications, color: Colors.blueAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notificaciones"),
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationsService.markAllRead();
              cargar();
            },
            child: const Text("Marcar leídas", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),

      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(child: Text("⭐ No tienes notificaciones"))
              : RefreshIndicator(
                  onRefresh: cargar,
                  child: ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (_, i) {
                      final n = notifications[i];
                      final fecha = DateTime.tryParse(n["fecha_envio"] ?? "");
                      final hora = fecha != null
                          ? "${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}"
                          : "";

                      return Dismissible(
                        key: Key(n["id"]),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) async {
                          await NotificationsService.deleteNotification(n["id"]);
                          cargar();
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          leading: _icon(n["tipo"]),
                          title: Text(
                            n["titulo"] ?? "Sin título",
                            style: TextStyle(
                              fontWeight: n["leida"] == true
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(n["mensaje"] ?? ""),
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
                ),
    );
  }
}
