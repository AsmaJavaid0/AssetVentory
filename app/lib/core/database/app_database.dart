import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/assets_table.dart';
import 'tables/categories_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Assets,
    Categories,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(categories);
          }
        },
      );
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'assetventory_database',
  );
}