import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registro_horario/routers/app_routers.dart';
import 'theme_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const RegistroHorarioApp(),
    ),
  );
}

class RegistroHorarioApp extends StatelessWidget {
  const RegistroHorarioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: "Registro Horario",
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.landing,
      routes: AppRoutes.routes,

      themeMode: themeProvider.themeMode,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blueAccent,
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
      ),
    );
  }
}
