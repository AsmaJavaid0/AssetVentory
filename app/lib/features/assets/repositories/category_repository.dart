import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/local_category.dart';

class CategoryRepository {
  final AppDatabase _database;

  static const Uuid _uuid = Uuid();

  CategoryRepository({
    required AppDatabase database,
  }) : _database = database;

  Future<void> createCategory(LocalCategory category) async {
    await _database.into(_database.categories).insert(
          CategoriesCompanion.insert(
            id: category.id,
            ownerId: category.ownerId,
            name: category.name,
            emoji: Value(category.emoji),
            createdAt: category.createdAt,
            updatedAt: category.updatedAt,
          ),
        );
  }

  Future<List<LocalCategory>> getCategories(String ownerId) async {
    final query = _database.select(_database.categories)
      ..where((category) => category.ownerId.equals(ownerId))
      ..orderBy([
        (category) => OrderingTerm.asc(category.name),
      ]);

    final rows = await query.get();

    return rows.map(_toLocalCategory).toList();
  }

  Future<LocalCategory?> getCategory(String categoryId) async {
    final query = _database.select(_database.categories)
      ..where((category) => category.id.equals(categoryId));

    final row = await query.getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _toLocalCategory(row);
  }

  Future<String> createCategoryIfNotExists({
    required String ownerId,
    required String name,
    String? emoji,
  }) async {
    final normalizedName = name.trim().toLowerCase();

    final existing = await getCategories(ownerId);

    for (final category in existing) {
      if (category.name.trim().toLowerCase() == normalizedName) {
        return category.id;
      }
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    await createCategory(
      LocalCategory(
        id: id,
        ownerId: ownerId,
        name: name.trim(),
        emoji: emoji,
        createdAt: now,
        updatedAt: now,
      ),
    );

    return id;
  }

  Future<void> updateCategory(LocalCategory category) async {
    await (_database.update(_database.categories)
          ..where((row) => row.id.equals(category.id)))
        .write(
      CategoriesCompanion(
        ownerId: Value(category.ownerId),
        name: Value(category.name),
        emoji: Value(category.emoji),
        createdAt: Value(category.createdAt),
        updatedAt: Value(category.updatedAt),
      ),
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    await (_database.delete(_database.categories)
          ..where((category) => category.id.equals(categoryId)))
        .go();

    // Assets are intentionally NOT deleted.
    // Their categoryId will eventually be treated as Uncategorized.
  }

  LocalCategory _toLocalCategory(Category row) {
    return LocalCategory(
      id: row.id,
      ownerId: row.ownerId,
      name: row.name,
      emoji: row.emoji,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}