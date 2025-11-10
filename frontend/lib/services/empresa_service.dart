import 'api_service.dart';

class EmpresaService {
  static Future<List<dynamic>> getEmployees() async {
    return await ApiService.get("/empresa/empleados");
  }

  static Future<void> sendInvite(String email) async {
    await ApiService.post("/empresa/invitar", {"email": email});
  }
}
