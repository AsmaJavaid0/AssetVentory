import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../models/local_category.dart';
import 'interfaces/i_category_repository.dart';

class CategoryRepository implements ICategoryRepository {
  final AppDatabase _database;

  static const Uuid _uuid = Uuid();

  CategoryRepository({
  required this._database,
});
  @override
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

  @override
  Future<List<LocalCategory>> getCategories(String ownerId) async {
    final query = _database.select(_database.categories)
      ..where((category) => category.ownerId.equals(ownerId))
      ..orderBy([
        (category) => OrderingTerm.asc(category.name),
      ]);

    final rows = await query.get();

    return rows.map(_toLocalCategory).toList();
  }

  @override
  Future<LocalCategory?> getCategory(String categoryId) async {
    final query = _database.select(_database.categories)
      ..where((category) => category.id.equals(categoryId));

    final row = await query.getSingleOrNull();

    if (row == null) {
      return null;
    }

    return _toLocalCategory(row);
  }

  @override
  Future<String> createCategoryIfNotExists({
    required String ownerId,
    required String name,
    String? emoji,
  }) async {
    final normalizedName = name.trim();
    final id = _uuid.v4();
    final now = DateTime.now();

    try {
      await _database.into(_database.categories).insert(
            CategoriesCompanion.insert(
              id: id,
              ownerId: ownerId,
              name: normalizedName,
              emoji: Value(emoji),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );

      // If insertOrIgnore didn't insert (because of unique constraint), find the existing one
      final existing = await (_database.select(_database.categories)
            ..where((c) => c.ownerId.equals(ownerId) & c.name.equals(normalizedName)))
          .getSingleOrNull();

      return existing?.id ?? id;
    } catch (e) {
      // Fallback for any other database errors
      final existing = await (_database.select(_database.categories)
            ..where((c) => c.ownerId.equals(ownerId) & c.name.equals(normalizedName)))
          .getSingleOrNull();
      return existing?.id ?? id;
    }
  }

  @override
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

  @override
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