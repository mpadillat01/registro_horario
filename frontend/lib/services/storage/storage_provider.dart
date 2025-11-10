import 'storage_service.dart';
import 'storage_service_mobile.dart'
    if (dart.library.html) 'storage_service_web.dart';

// ✅ Instancia global única
final StorageService storage = StorageServiceImpl();
