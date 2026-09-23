import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class StorageAwareImage extends StatelessWidget {
  const StorageAwareImage({
    super.key,
    required this.source,
    this.fit,
    this.placeholder,
  });

  final String source;
  final BoxFit? fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final trimmed = source.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(trimmed, fit: fit);
    }
    if (trimmed.isEmpty) {
      return placeholder ?? const SizedBox.shrink();
    }

    return FutureBuilder<String>(
      future: FirebaseStorage.instance.ref(trimmed).getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          return Image.network(snapshot.data!, fit: fit);
        }
        return placeholder ??
            Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.image_outlined),
            );
      },
    );
  }
}
