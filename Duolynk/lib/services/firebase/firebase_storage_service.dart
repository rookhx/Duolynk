import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  FirebaseStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Reference ref(String path) => _storage.ref().child(path);

  Future<String> uploadData({
    required String path,
    required Uint8List data,
    SettableMetadata? metadata,
    bool returnDownloadUrl = true,
  }) async {
    final snapshot = await ref(path).putData(data, metadata);
    if (!returnDownloadUrl) {
      return snapshot.ref.fullPath;
    }
    return snapshot.ref.getDownloadURL();
  }

  Future<void> delete(String path) => ref(path).delete();
}
