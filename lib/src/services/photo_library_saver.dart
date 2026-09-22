import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import '../domain/video_resolver.dart';

abstract interface class PhotoLibrarySaver {
  Future<void> save(ResolvedVideo video);
}

class PhotoLibraryException implements Exception {
  const PhotoLibraryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PhotoManagerVideoSaver implements PhotoLibrarySaver {
  const PhotoManagerVideoSaver();

  @override
  Future<void> save(ResolvedVideo video) async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      throw const PhotoLibraryException(
        'Нет доступа к медиатеке. Разреши приложению добавлять видео в «Фото» в настройках iPhone.',
      );
    }

    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'x-video-downloader-',
    );
    final file = File(
      '${temporaryDirectory.path}/${_safeFileName(video.fileName)}',
    );
    try {
      await file.writeAsBytes(video.bytes, flush: true);
      await PhotoManager.editor.saveVideo(
        file,
        title: _safeFileName(video.fileName),
      );
    } on Exception catch (error) {
      throw PhotoLibraryException('Не удалось добавить видео в «Фото»: $error');
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  }

  String _safeFileName(String value) {
    final name = value.trim().isEmpty ? 'x-video.mp4' : value.trim();
    return name.toLowerCase().endsWith('.mp4') ? name : '$name.mp4';
  }
}
