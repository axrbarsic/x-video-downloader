import 'dart:typed_data';

import 'post_url.dart';

class ResolvedVideo {
  const ResolvedVideo({required this.bytes, this.fileName = 'x-video.mp4'});

  final Uint8List bytes;
  final String fileName;
}

abstract interface class VideoResolver {
  Future<ResolvedVideo> resolve(PostReference post);
}

class VideoResolverException implements Exception {
  const VideoResolverException(this.message);

  final String message;

  @override
  String toString() => message;
}
