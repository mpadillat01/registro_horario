import 'package:flutter/material.dart';
import 'package:registro_horario/services/auth_service.dart';

class EnviarMensajePage extends StatefulWidget {
  const EnviarMensajePage({super.key});

  @override
  State<EnviarMensajePage> createState() => _EnviarMensajePageState();
}

class _EnviarMensajePageState extends State<EnviarMensajePage> {
  final tituloController = TextEditingController();
  final mensajeController = TextEditingController();
  bool enviando = false;
  bool enviarATodos = true;

  List<Map<String, dynamic>> empleados = [];
  String? empleadoSeleccionado;

  @override
  void initState() {
    super.initState();
    _cargarEmpleados();
  }

  Future<void> _cargarEmpleados() async {
    try {
      // 👉 obtiene todos los empleados (asegúrate que este método exista)
      final lista = await AuthService.getEmployees();
      setState(() => empleados = List<Map<String, dynamic>>.from(lista));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al cargar empleados: $e")),
      );
    }
  }

  Future<void> enviarMensaje() async {
    if (tituloController.text.isEmpty || mensajeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Rellena todos los campos")),
      );
      return;
    }

    if (!enviarATodos && empleadoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Selecciona un empleado")),
      );
      return;
    }

    setState(() => enviando = true);

    try {
      await AuthService.sendMessageToEmployees(
        titulo: tituloController.text.trim(),
        mensaje: mensajeController.text.trim(),
        todos: enviarATodos,
        usuarioId: enviarATodos ? null : empleadoSeleccionado,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Mensaje enviado correctamente")),
      );

      tituloController.clear();
      mensajeController.clear();
      setState(() => empleadoSeleccionado = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al enviar: $e")),
      );
    }

    setState(() => enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Enviar mensaje a empleados"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: tituloController,
              decoration: InputDecoration(
                labelText: "Título",
                filled: true,
                fillColor: dark ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mensajeController,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: "Mensaje",
                alignLabelWithHint: true,
                filled: true,
                fillColor: dark ? Colors.white10 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: enviarATodos,
                  onChanged: (v) => setState(() => enviarATodos = v ?? true),
                ),
                const Text("Enviar a todos los trabajadores"),
              ],
            ),
            if (!enviarATodos) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: empleadoSeleccionado,
                decoration: InputDecoration(
                  labelText: "Seleccionar empleado",
                  filled: true,
                  fillColor: dark ? Colors.white10 : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: empleados
                    .map((e) => DropdownMenuItem<String>(
                          value: e["id"].toString(),
                          child: Text(e["nombre"] ?? "Empleado sin nombre"),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => empleadoSeleccionado = v),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: enviando ? null : enviarMensaje,
                icon: const Icon(Icons.send_rounded),
                label: enviando
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      )
                    : const Text(
                        "Enviar mensaje",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
