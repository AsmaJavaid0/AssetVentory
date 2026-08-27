import 'package:get_it/get_it.dart';
import '../database/app_database.dart';
import '../storage/local_file_storage.dart';
import '../storage/app_preferences_service.dart';

import '../../features/assets/repositories/asset_repository.dart';
import '../../features/assets/repositories/asset_document_repository.dart';
import '../../features/assets/repositories/category_repository.dart';
import '../../features/assets/repositories/interfaces/i_asset_repository.dart';
import '../../features/assets/repositories/interfaces/i_category_repository.dart';
import '../../features/assets/repositories/interfaces/i_asset_document_repository.dart';
import '../../features/family/repositories/interfaces/i_family_repository.dart';
import '../../features/family/repositories/family_repository.dart';

import '../../features/tasks/services/task_service.dart';
import '../../features/tasks/services/task_notification_service.dart';
import '../../features/tasks/services/fcm_service.dart';

final getIt = GetIt.instance;

class ServiceLocator {
  IAssetRepository get assetRepository => getIt<IAssetRepository>();
  IAssetDocumentRepository get assetDocumentRepository => getIt<IAssetDocumentRepository>();
  ICategoryRepository get categoryRepository => getIt<ICategoryRepository>();
  IFamilyRepository get familyRepository => getIt<IFamilyRepository>();
  TaskService get taskService => getIt<TaskService>();
  TaskNotificationService get taskNotificationService => getIt<TaskNotificationService>();
  FcmService get fcmService => getIt<FcmService>();
  AppDatabase get database => getIt<AppDatabase>();
  LocalFileStorage get fileStorage => getIt<LocalFileStorage>();
  AppPreferencesService get preferences => getIt<AppPreferencesService>();

  T get<T extends Object>() => getIt<T>();
  T call<T extends Object>() => getIt<T>();
}

final serviceLocator = ServiceLocator();

Future<void> setupServiceLocator() async {
  // Core Services
  getIt.registerLazySingleton<AppDatabase>(() => AppDatabase());
  getIt.registerLazySingleton<LocalFileStorage>(() => LocalFileStorage());
  getIt.registerLazySingleton<AppPreferencesService>(() => AppPreferencesService());

  // Task & Notification Services
  getIt.registerLazySingleton<TaskNotificationService>(() => TaskNotificationService());
  getIt.registerLazySingleton<FcmService>(() => FcmService());
  getIt.registerLazySingleton<TaskService>(() => TaskService());

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

  getIt.registerLazySingleton<IFamilyRepository>(
    () => FamilyRepository(),
  );
}

void disposeServiceLocator() {
  getIt.reset();
}
