import 'package:drift/drift.dart';

class Assets extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  TextColumn get name => text()();

  TextColumn get categoryId => text().nullable()();

  TextColumn get emoji => text().nullable()();

  TextColumn get description => text().nullable()();

  TextColumn get location => text().nullable()();

  TextColumn get serialNumber => text().nullable()();

  TextColumn get imagePath => text().nullable()();

  BoolColumn get qrEnabled =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}