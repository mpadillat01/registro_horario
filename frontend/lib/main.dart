import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registro_horario/routers/app_routers.dart';
import 'package:registro_horario/theme_provider.dart';
import 'package:intl/date_symbol_data_local.dart'; // 👈 Importa esto

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 Inicializa los datos regionales para formatear fechas en español
  await initializeDateFormatting('es_ES', null);

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
