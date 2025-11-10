// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'storage_service.dart';

class StorageServiceImpl extends StorageService {
  @override
  Future<void> saveToken(String token) async {
    html.window.localStorage['token'] = token;
    print("💾 [WEB] Token guardado en localStorage");
  }

  @override
  Future<String?> getToken() async {
    final token = html.window.localStorage['token'];
    print("📤 [WEB] Token leído desde localStorage → $token");
    return token;
  }

  @override
  Future<void> deleteToken() async {
    html.window.localStorage.remove('token');
    print("🗑️ [WEB] Token eliminado de localStorage");
  }
}
