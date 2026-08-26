import '../models/local_category.dart';

abstract class ICategoryRepository {
  Future<void> createCategory(LocalCategory category);
  Future<List<LocalCategory>> getCategories(String ownerId);
  Future<LocalCategory?> getCategory(String categoryId);
  Future<String> createCategoryIfNotExists({
    required String ownerId,
    required String name,
    String? emoji,
  });
  Future<void> updateCategory(LocalCategory category);
  Future<void> deleteCategory(String categoryId);
}
