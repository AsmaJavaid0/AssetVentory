import 'package:drift/drift.dart';
import 'dart:convert';

class CustomFieldsConverter extends TypeConverter<Map<String, String>, String> {
  const CustomFieldsConverter();

  @override
  Map<String, String> fromSql(String fromDb) {
    return Map<String, String>.from(json.decode(fromDb) as Map);
  }

  @override
  String toSql(Map<String, String> value) {
    return json.encode(value);
  }
}

class Assets extends Table {
  TextColumn get id => text()();

  TextColumn get ownerId => text()();

  TextColumn get name => text()();

  TextColumn get categoryId => text().nullable()();

  TextColumn get emoji => text().nullable()();

  TextColumn get imagePath => text().nullable()();

  TextColumn get location => text().nullable()();

  TextColumn get description => text().nullable()();

  BoolColumn get qrEnabled =>
      boolean().withDefault(const Constant(false))();

  TextColumn get customFields => text()
      .map(const CustomFieldsConverter())
      .withDefault(const Constant('{}'))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}