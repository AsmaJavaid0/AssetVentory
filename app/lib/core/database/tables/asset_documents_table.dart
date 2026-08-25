import 'package:drift/drift.dart';

class AssetDocuments extends Table {
  TextColumn get id => text()();

  TextColumn get assetId => text()();

  TextColumn get name => text()();

  TextColumn get filePath => text()();

  TextColumn get fileType => text().nullable()();

  IntColumn get fileSize => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
