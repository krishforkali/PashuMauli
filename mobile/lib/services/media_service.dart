import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Media source
enum MediaSource { camera, gallery }

/// Media capture result
sealed class MediaResult {
  const MediaResult();
}

class MediaSuccess extends MediaResult {
  final String localPath;
  const MediaSuccess({required this.localPath});
}

class MediaCancelled extends MediaResult {
  const MediaCancelled();
}

class MediaError extends MediaResult {
  final String message;
  const MediaError({required this.message});
}

/// Media service — camera/gallery selection abstraction.
/// Stores media in stable application documents directory.
/// Phase 4 will upload to S3; Phase 3 only creates pending_media records.
class MediaService {
  final ImagePicker _picker;
  final Uuid _uuid;

  MediaService({ImagePicker? picker, Uuid? uuid})
      : _picker = picker ?? ImagePicker(),
        _uuid = uuid ?? const Uuid();

  /// Capture/pick an image and copy it to stable local storage.
  Future<MediaResult> pickImage(MediaSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source == MediaSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (xFile == null) return const MediaCancelled();

      // Copy to stable documents directory (survives app restart)
      final stableDir = await _stableMediaDir();
      final filename = '${_uuid.v4()}${p.extension(xFile.path)}';
      final destPath = p.join(stableDir.path, filename);
      await File(xFile.path).copy(destPath);

      return MediaSuccess(localPath: destPath);
    } catch (e) {
      return MediaError(message: e.toString());
    }
  }

  /// Get or create the stable media storage directory.
  /// Uses application documents directory so it survives app restarts.
  Future<Directory> _stableMediaDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docsDir.path, 'pm_media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }
}
