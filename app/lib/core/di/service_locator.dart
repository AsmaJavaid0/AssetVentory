import 'package:get_it/get_it.dart';
import '../database/app_database.dart';
import '../storage/local_file_storage.dart';

import '../../features/assets/repositories/asset_repository.dart';
import '../../features/assets/repositories/asset_document_repository.dart';
import '../../features/assets/repositories/category_repository.dart';
import '../../features/assets/repositories/interfaces/i_asset_repository.dart';
import '../../features/assets/repositories/interfaces/i_category_repository.dart';
import '../../features/assets/repositories/interfaces/i_asset_document_repository.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Core Services
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
  getIt.registerLazySingleton<LocalFileStorage>(() => LocalFileStorage());

  // Repositories - Registered as their interfaces for better testability
  getIt.registerLazySingleton<IAssetRepository>(
    () => AssetRepository(
      database: getIt<AppDatabase>(),
      fileStorage: getIt<LocalFileStorage>(),
    ),
  );

  getIt.registerLazySingleton<IAssetDocumentRepository>(
    () => AssetDocumentRepository(
      database: getIt<AppDatabase>(),
      fileStorage: getIt<LocalFileStorage>(),
    ),
  );

  getIt.registerLazySingleton<ICategoryRepository>(
    () => CategoryRepository(
      database: getIt<AppDatabase>(),
    ),
  );
}

void disposeServiceLocator() {
  getIt.reset();
}
