import 'package:flutter/material.dart';

class RegisterEmployeePage extends StatelessWidget {
  const RegisterEmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registro Empleado")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(decoration: InputDecoration(labelText: "Nombre")),
            TextField(decoration: InputDecoration(labelText: "Apellidos")),
            TextField(decoration: InputDecoration(labelText: "DNI")),
            TextField(obscureText: true, decoration: InputDecoration(labelText: "Contraseña")),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Crear cuenta"),
            ),
          ],
        ),
      ),
    );
  }
}
