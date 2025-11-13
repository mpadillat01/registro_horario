import 'package:flutter/material.dart';
import 'package:registro_horario/features/admin/admin_settings_page.dart';
import 'package:registro_horario/features/auth/company_plan_page.dart';
import 'package:registro_horario/features/admin/enviar_mensaje_page.dart';
import '../features/landing/landing_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_company_page.dart';
import '../features/invitacion/registro_empleado_page.dart';
import '../features/admin/dashboard_admin_page.dart';
import '../features/admin/empleados_page.dart';
import '../features/admin/invitacion_enviar_page.dart';
import '../features/fichaje/fichaje_page.dart';
import '../features/perfil/perfil_page.dart';

class AppRoutes {
  static const String landing = "/landing";
  static const String login = "/login";
  static const String registerCompany = "/register-company";
  static const String registerEmployee = "/register-employee";
  static const String adminDashboard = "/admin-dashboard";
  static const String empleados = "/empleados";
  static const String enviarInvitacion = "/enviar-invitacion";
  static const String fichaje = "/fichaje";
  static const String perfil = "/perfil";
  static const String plans = "/plans";
  static const String enviarMensaje = "/enviar-mensaje";
  static const adminSettings = '/ajustes';

  static Map<String, WidgetBuilder> routes = {
    landing: (context) => const LandingPage(),
    login: (context) => const LoginPage(),
    registerCompany: (context) => const RegisterCompanyPage(),
    registerEmployee: (context) => const RegisterEmployeePage(),
    adminDashboard: (context) => const DashboardAdminPage(),
    empleados: (context) => const EmpleadosPage(),
    enviarInvitacion: (context) => const InvitacionEnviarPage(),
    fichaje: (context) => const FichajePage(),
    perfil: (context) => const PerfilPage(),
    plans: (context) => const CompanyPlansPage(),
    enviarMensaje: (context) => const EnviarMensajePage(), 
    adminSettings: (_) => const AdminSettingsPage(),
  };
}
