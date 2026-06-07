/// Cover service — manages local manga cover images (CU-06).
/// Covers are stored entirely on-device, never sent to the server.
library;

import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CoverService extends GetxService {
  late final String _coverDir;

  @override
  void onInit() {
    super.onInit();
    _initCoverDir();
  }

  Future<void> _initCoverDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _coverDir = p.join(appDir.path, 'covers');
    await Directory(_coverDir).create(recursive: true);
  }

  /// Get the cover file path for a manga (may not exist).
  String coverPath(String mangaId) {
    return p.join(_coverDir, '$mangaId.jpg');
  }

  /// Check if a cover exists for a manga.
  bool hasCover(String mangaId) {
    return File(coverPath(mangaId)).existsSync();
  }

  /// Save a cover image for a manga.
  Future<void> saveCover(String mangaId, File imageFile) async {
    final destination = File(coverPath(mangaId));
    await imageFile.copy(destination.path);
  }

  /// Delete a cover image for a manga.
  Future<void> deleteCover(String mangaId) async {
    final file = File(coverPath(mangaId));
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Clean up orphan covers (covers for mangas that no longer exist).
  Future<int> cleanOrphanCovers(List<String> activeMangaIds) async {
    final coverDir = Directory(_coverDir);
    if (!await coverDir.exists()) return 0;

    int cleaned = 0;
    await for (final entity in coverDir.list()) {
      if (entity is File) {
        final fileName = p.basenameWithoutExtension(entity.path);
        if (!activeMangaIds.contains(fileName)) {
          await entity.delete();
          cleaned++;
        }
      }
    }
    return cleaned;
  }
}
