import 'package:drift/drift.dart';

class Categories extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  TextColumn get name => text().collate(Collate.nocase)();

  TextColumn get emoji => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [{ownerId, name}];
}