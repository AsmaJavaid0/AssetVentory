import '../database/app_database.dart';
import '../storage/local_file_storage.dart';
import '../../features/assets/repositories/asset_repository.dart';

class ServiceLocator {
  late final AppDatabase database;
  late final LocalFileStorage fileStorage;
  late final AssetRepository assetRepository;

  void initialize() {
    database = AppDatabase();
    fileStorage = LocalFileStorage();

    assetRepository = AssetRepository(
      database: database,
      fileStorage: fileStorage,
    );
  }

  Future<void> dispose() async {
    await database.close();
  }
}

final serviceLocator = ServiceLocator();