import '../database/app_database.dart';
import '../storage/local_file_storage.dart';

import '../../features/assets/repositories/asset_repository.dart';
import '../../features/assets/repositories/category_repository.dart';

class ServiceLocator {
  late final AppDatabase database;
  late final LocalFileStorage fileStorage;

  late final AssetRepository assetRepository;
  late final CategoryRepository categoryRepository;

  void initialize() {
    database = AppDatabase();
    fileStorage = LocalFileStorage();

    assetRepository = AssetRepository(
      database: database,
      fileStorage: fileStorage,
    );

    categoryRepository = CategoryRepository(
      database: database,
    );
  }

  Future<void> dispose() async {
    await database.close();
  }
}

final serviceLocator = ServiceLocator();