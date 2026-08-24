import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../assets/models/asset_model.dart';
import '../../assets/models/category_model.dart';
import '../../assets/models/document_model.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/models/reminder_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _assetsCollection =>
      _firestore.collection('assets');

  CollectionReference<Map<String, dynamic>> get _categoriesCollection =>
      _firestore.collection('categories');

  CollectionReference<Map<String, dynamic>> get _documentsCollection =>
      _firestore.collection('documents');

  CollectionReference<Map<String, dynamic>> get _remindersCollection =>
      _firestore.collection('reminders');

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore.collection('tasks');

  /// Creates or updates a user document in users/{userId}
  Future<void> createOrUpdateUser({
    required String uid,
    required String name,
    required String email,
    String? photoUrl,
    String? familyId,
  }) async {
    final userDocRef = _usersCollection.doc(uid);
    final userSnapshot = await userDocRef.get();

    final now = DateTime.now();

    if (!userSnapshot.exists) {
      final newUser = UserModel(
        id: uid,
        name: name.isNotEmpty ? name : email.split('@').first,
        email: email,
        photoUrl: photoUrl ?? '',
        createdAt: now,
        updatedAt: now,
        familyId: familyId,
      );
      await userDocRef.set(newUser.toFirestore());
    } else {
      final existingData = userSnapshot.data() ?? {};
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(now),
      };

      if (name.isNotEmpty && existingData['name'] != name) {
        updateData['name'] = name;
      }
      if (email.isNotEmpty && existingData['email'] != email) {
        updateData['email'] = email;
      }
      if (photoUrl != null && photoUrl.isNotEmpty) {
        updateData['photoUrl'] = photoUrl;
      }
      if (familyId != null) {
        updateData['familyId'] = familyId;
      }

      await userDocRef.update(updateData);
    }
  }

  /// Fetches the user profile by UID
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stream of user profile updates
  Stream<UserModel?> streamUser(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    });
  }

  /// Stream all assets owned by user
  Stream<List<AssetModel>> streamUserAssets(String ownerId) {
    return _assetsCollection
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AssetModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Stream top N recent assets
  Stream<List<AssetModel>> streamRecentAssets(String ownerId, {int limit = 5}) {
    return _assetsCollection
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AssetModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list.take(limit).toList();
        });
  }

  /// Stream active upcoming reminders for user
  Stream<List<ReminderModel>> streamUpcomingReminders(
    String ownerId, {
    int limit = 5,
  }) {
    return _remindersCollection
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ReminderModel.fromFirestore(doc))
              .where((r) => r.status == 'active')
              .toList();
          list.sort((a, b) => a.reminderDate.compareTo(b.reminderDate));
          return list.take(limit).toList();
        });
  }

  /// Stream pending tasks for user.
  ///
  /// IMPORTANT: this used to be `_tasksCollection.snapshots()` with no
  /// `.where()` at all, meaning it downloaded and listened to every task
  /// belonging to every user of the app, then filtered client-side. That is
  /// the main source of the app-wide lag: it re-downloads the whole
  /// collection every time this stream is (re)subscribed to. This version
  /// filters on the server using `Filter.or`, so only the documents the
  /// user is actually allowed to see are ever transferred.
  Stream<List<TaskModel>> streamPendingTasks(String uid, {String? familyId}) {
    final hasFamily = familyId != null && familyId.isNotEmpty;

    final filter = hasFamily
        ? Filter.or(
            Filter('createdBy', isEqualTo: uid),
            Filter('assignedTo', isEqualTo: uid),
            Filter('familyId', isEqualTo: familyId),
          )
        : Filter.or(
            Filter('createdBy', isEqualTo: uid),
            Filter('assignedTo', isEqualTo: uid),
          );

    return _tasksCollection.where(filter).snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TaskModel.fromFirestore(doc))
          .where((task) => task.status == 'pending')
          .toList();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    });
  }

  /// Stream every task the user is allowed to see. The client performs the
  /// presentation-level visibility check as a safeguard; Firestore rules must
  /// enforce the same relationship server-side.
  Stream<List<TaskModel>> streamVisibleTasks(String uid, {String? familyId}) {
    final hasFamily = familyId != null && familyId.isNotEmpty;
    final filter = hasFamily
        ? Filter.or(
            Filter('createdBy', isEqualTo: uid),
            Filter('assignedTo', isEqualTo: uid),
            Filter('familyId', isEqualTo: familyId),
          )
        : Filter.or(
            Filter('createdBy', isEqualTo: uid),
            Filter('assignedTo', isEqualTo: uid),
          );

    return _tasksCollection.where(filter).snapshots().map((snapshot) {
      final tasks = snapshot.docs
          .map(TaskModel.fromFirestore)
          .where(
            (task) =>
                task.createdBy == uid ||
                task.assignedTo == uid ||
                (hasFamily &&
                    task.visibility == 'family' &&
                    task.familyId == familyId),
          )
          .toList();
      tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return tasks;
    });
  }

  /// Stream count of family members
  Stream<int> streamFamilyMembersCount(String? familyId) {
    if (familyId == null || familyId.isEmpty) {
      return Stream.value(1); // Default single user
    }
    return _usersCollection
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Stream the profiles eligible to receive a family task assignment.
  Stream<List<UserModel>> streamFamilyMembers(String familyId) {
    return _usersCollection
        .where('familyId', isEqualTo: familyId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(UserModel.fromFirestore).toList());
  }

  /// Add a new asset
  Future<String> addAsset(AssetModel asset) async {
    final docRef = await _assetsCollection.add(asset.toFirestore());
    return docRef.id;
  }

  /// Update an existing asset. `asset.id` must be set.
  Future<void> updateAsset(AssetModel asset) async {
    await _assetsCollection.doc(asset.id).update(asset.toFirestore());
  }

  /// Add a new task
  Future<String> addTask(TaskModel task) async {
    final docRef = await _tasksCollection.add(task.toFirestore());
    return docRef.id;
  }

  /// Creates the task and its optional supporting reminder atomically.
  Future<String> createTask(TaskModel task, {ReminderModel? reminder}) async {
    final taskRef = _tasksCollection.doc();
    final batch = _firestore.batch();
    String? reminderId;

    if (reminder != null) {
      final reminderRef = _remindersCollection.doc();
      reminderId = reminderRef.id;
      batch.set(reminderRef, {
        ...reminder.toFirestore(),
        'taskId': taskRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(taskRef, {
      ...task.toFirestore(),
      'reminderId': reminderId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return taskRef.id;
  }

  Future<void> updateTask(TaskModel task, {ReminderModel? reminder}) async {
    final batch = _firestore.batch();
    final taskRef = _tasksCollection.doc(task.id);

    if (reminder != null) {
      final reminderRef = task.reminderId == null
          ? _remindersCollection.doc()
          : _remindersCollection.doc(task.reminderId);
      batch.set(reminderRef, {
        ...reminder.toFirestore(),
        'taskId': task.id,
        'createdAt': task.reminderId == null
            ? FieldValue.serverTimestamp()
            : reminder.createdAt,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.update(taskRef, {
        ...task.toFirestore(),
        'reminderId': reminderRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      if (task.reminderId != null) {
        batch.delete(_remindersCollection.doc(task.reminderId));
      }
      batch.update(taskRef, {
        ...task.toFirestore(),
        'reminderId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> updateTaskStatus(String taskId, String status) {
    return _tasksCollection.doc(taskId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTask(TaskModel task) async {
    final batch = _firestore.batch();
    batch.delete(_tasksCollection.doc(task.id));
    if (task.reminderId != null) {
      batch.delete(_remindersCollection.doc(task.reminderId));
    }
    await batch.commit();
  }

  /// Deletes only the reminder document and clears reminderId on the parent
  /// task. The Home page reminder stream will update automatically because it
  /// is a live Firestore listener.
  Future<void> deleteReminderOnly(
    String reminderId,
    String taskId,
  ) async {
    final batch = _firestore.batch();
    batch.delete(_remindersCollection.doc(reminderId));
    batch.update(_tasksCollection.doc(taskId), {
      'reminderId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Live stream of a single reminder document. Emits null when the document
  /// does not exist (e.g. after deletion).
  Stream<ReminderModel?> streamReminder(String reminderId) {
    return _remindersCollection.doc(reminderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ReminderModel.fromFirestore(doc);
    });
  }

  /// Delete an asset
  Future<void> deleteAsset(String assetId) async {
    await _assetsCollection.doc(assetId).delete();
  }

  /// Stream categories for a specific user
  Stream<List<CategoryModel>> streamUserCategories(String ownerId) {
    return _categoriesCollection
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => CategoryModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => a.name.compareTo(b.name));
          return list;
        });
  }

  /// Add a new category, reusing an existing one with the same name
  /// (case-insensitive, trimmed) if the user already has one.
  ///
  /// Previously this always inserted a new document, so tapping "Create"
  /// for a name that already existed (e.g. from both the Assets screen and
  /// the Add Asset screen) silently produced duplicate categories. That's
  /// why you can end up with two "Electronics" folders that both show 0
  /// items: assets are filtered by the *exact* category document id, and
  /// only one of the duplicates (if either) actually matches.
  Future<String> addCategory(CategoryModel category) async {
    final normalizedName = category.name.trim().toLowerCase();
    final existing = await _categoriesCollection
        .where('ownerId', isEqualTo: category.ownerId)
        .get();
    for (final doc in existing.docs) {
      final data = doc.data();
      final existingName = (data['name'] as String? ?? '').trim().toLowerCase();
      if (existingName == normalizedName) {
        return doc.id; // Reuse the existing category instead of duplicating.
      }
    }
    final docRef = await _categoriesCollection.add(category.toFirestore());
    return docRef.id;
  }

  /// Update an existing category. The id is deliberately kept out of the
  /// Firestore payload; it is the document reference, not a stored field.
  Future<void> updateCategory(CategoryModel category) async {
    await _categoriesCollection.doc(category.id).update(category.toFirestore());
  }

  /// Delete a category AND unlink it from any assets that reference it.
  ///
  /// Previously deleting a category left `assets.categoryId` pointing at a
  /// document that no longer existed, which silently orphans those assets:
  /// they disappear from every category filter (including a
  /// newly-recreated category with the same name) while still counting
  /// toward "All Assets". This clears the reference so the assets fall
  /// back to "Uncategorized" instead of vanishing from every filter.
  Future<void> deleteCategory(String categoryId) async {
    final batch = _firestore.batch();
    final affectedAssets = await _assetsCollection
        .where('categoryId', isEqualTo: categoryId)
        .get();
    for (final doc in affectedAssets.docs) {
      batch.update(doc.reference, {'categoryId': null});
    }
    batch.delete(_categoriesCollection.doc(categoryId));
    await batch.commit();
  }

  /// Stream documents associated with an asset
  Stream<List<DocumentModel>> streamAssetDocuments(String assetId) {
    return _documentsCollection
        .where('assetId', isEqualTo: assetId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => DocumentModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Add a new document metadata record
  Future<String> addDocument(DocumentModel document) async {
    final docRef = await _documentsCollection.add(document.toFirestore());
    return docRef.id;
  }

  /// Delete a document metadata record
  Future<void> deleteDocument(String documentId) async {
    await _documentsCollection.doc(documentId).delete();
  }
}
