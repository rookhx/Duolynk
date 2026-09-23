import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  DocumentReference<Map<String, dynamic>> document(String path) {
    return _firestore.doc(path);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(String path) {
    return document(path).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(String path) {
    return collection(path).get();
  }

  Future<void> setDocument(
    String path,
    Map<String, dynamic> data, {
    bool merge = true,
  }) {
    return document(path).set(data, SetOptions(merge: merge));
  }

  Future<void> updateDocument(String path, Map<String, dynamic> data) {
    return document(path).update(data);
  }

  Future<void> deleteDocument(String path) {
    return document(path).delete();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchDocument(String path) {
    return document(path).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchCollection(
    String path, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)?
    builder,
  }) {
    final baseQuery = collection(path);
    return (builder == null ? baseQuery : builder(baseQuery)).snapshots();
  }

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) {
    return _firestore.runTransaction(action);
  }

  WriteBatch batch() => _firestore.batch();

  FieldValue serverTimestamp() => FieldValue.serverTimestamp();
}
