import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:registro_horario/services/auth_service.dart';

class EnviarMensajePage extends StatefulWidget {
  const EnviarMensajePage({super.key});

  @override
  State<EnviarMensajePage> createState() => _EnviarMensajePageState();
}

class _EnviarMensajePageState extends State<EnviarMensajePage>
    with SingleTickerProviderStateMixin {
  final tituloController = TextEditingController();
  final mensajeController = TextEditingController();
  bool enviando = false;
  bool enviarATodos = true;
  List<Map<String, dynamic>> empleados = [];
  String? empleadoSeleccionado;
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _cargarEmpleados();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cargarEmpleados() async {
    try {
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

    final gradient = dark
        ? const LinearGradient(
            colors: [Color(0xFF0A0E1A), Color(0xFF1E2A78)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF0052D4), Color(0xFF4364F7), Color(0xFF6FB1FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Enviar mensaje",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: FadeTransition(
          opacity: _fadeIn,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(28),
                width: 600,
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Enviar mensaje a empleados",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildInput(
                      controller: tituloController,
                      label: "Título del mensaje",
                      icon: Icons.title_rounded,
                      dark: dark,
                    ),
                    const SizedBox(height: 16),

                    _buildInput(
                      controller: mensajeController,
                      label: "Contenido del mensaje",
                      icon: Icons.message_rounded,
                      dark: dark,
                      maxLines: 8,
                    ),
                    const SizedBox(height: 16),

                    _buildCheckbox(),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: !enviarATodos
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _buildDropdown(dark),
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 30),

                    GestureDetector(
                      onTap: enviando ? null : enviarMensaje,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: enviando
                                ? [Colors.grey, Colors.grey.shade600]
                                : dark
                                    ? [Color(0xFF4A90E2), Color(0xFF007AFF)]
                                    : [Color(0xFF3A7BD5), Color(0xFF00D2FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: enviando
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    offset: const Offset(0, 6),
                                    blurRadius: 15,
                                  ),
                                ],
                        ),
                        child: Center(
                          child: enviando
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  "Enviar mensaje",
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool dark,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 16),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        labelText: label,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade700,
        ),
        filled: true,
        fillColor: dark ? Colors.white10 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return Row(
      children: [
        Checkbox(
          activeColor: Colors.blueAccent,
          value: enviarATodos,
          onChanged: (v) => setState(() => enviarATodos = v ?? true),
        ),
        Text(
          "Enviar a todos los trabajadores",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(bool dark) {
    return DropdownButtonFormField<String>(
      value: empleadoSeleccionado,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.person_outline_rounded),
        labelText: "Seleccionar empleado",
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        filled: true,
        fillColor: dark ? Colors.white10 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      items: empleados
          .map((e) => DropdownMenuItem<String>(
                value: e["id"].toString(),
                child: Text(
                  e["nombre"] ?? "Empleado sin nombre",
                  style: GoogleFonts.inter(fontSize: 15),
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => empleadoSeleccionado = v),
    );
  }
}
