import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage_service.dart';

class StorageServiceImpl extends StorageService {
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> saveToken(String token) async {
    await _storage.write(key: "token", value: token);
    print("💾 [MOBILE] Token guardado correctamente en SecureStorage");
  }

  @override
  Future<String?> getToken() async {
    final token = await _storage.read(key: "token");
    print("📤 [MOBILE] Token leído desde SecureStorage → $token");
    return token;
  }

  @override
  Future<void> deleteToken() async {
    await _storage.delete(key: "token");
    print("🗑️ [MOBILE] Token eliminado de SecureStorage");
  }
}
