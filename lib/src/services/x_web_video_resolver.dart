import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/post_url.dart';
import '../domain/video_resolver.dart';

/// Resolves public X post media through the same unauthenticated syndication
/// endpoint used by the public web embed flow.
///
/// This intentionally does not contain X API credentials or cookies. The
/// endpoint is public, can change without notice, and is limited to media that
/// X exposes through syndication.
class XWebVideoResolver implements VideoResolver {
  XWebVideoResolver({http.Client? client}) : _client = client ?? http.Client();

  static const _userAgent = 'Googlebot';
  static const _timeout = Duration(seconds: 25);

  final http.Client _client;

  @override
  Future<ResolvedVideo> resolve(PostReference post) async {
    final status = await _loadSyndicationStatus(post.id);
    final variants = _extractMp4Variants(status);
    if (variants.isEmpty) {
      throw const VideoResolverException(
        'Видео в посте не найдено. Пост может быть недоступен, не содержать видео или отдавать только HLS-поток.',
      );
    }

    final selected = variants.first;
    final response = await _get(
      Uri.parse(selected.url),
      errorMessage: 'Не удалось скачать MP4 из поста.',
    );
    final bytes = response.bodyBytes;
    if (!_looksLikeMp4(bytes)) {
      throw const VideoResolverException(
        'X вернул не MP4-файл. Попробуйте другой пост или повторите позже.',
      );
    }

    return ResolvedVideo(bytes: bytes, fileName: 'x-video-${post.id}.mp4');
  }

  Future<dynamic> _loadSyndicationStatus(String postId) async {
    final token = _generateSyndicationToken(postId);
    final uri = Uri.https('cdn.syndication.twimg.com', '/tweet-result', {
      'id': postId,
      'token': token,
    });
    final response = await _get(
      uri,
      errorMessage: 'Не удалось получить данные поста X.',
    );

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded.isNotEmpty) {
        return decoded;
      }
    } on FormatException {
      // Convert malformed or blocked responses to the same user-facing error.
    }

    throw const VideoResolverException(
      'X не вернул данные этого поста. Возможно, пост удалён, закрыт или временно недоступен.',
    );
  }

  Future<http.Response> _get(Uri uri, {required String errorMessage}) async {
    try {
      final response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const _RequestFailure();
      }
      return response;
    } on _RequestFailure {
      throw VideoResolverException(errorMessage);
    } on Object {
      throw VideoResolverException(errorMessage);
    }
  }

  List<_Mp4Variant> _extractMp4Variants(dynamic root) {
    final byUrl = <String, _Mp4Variant>{};
    _visit(root, (value) {
      if (value is! Map) return;
      for (final infoKey in const ['video_info', 'media_info']) {
        final info = value[infoKey];
        if (info is! Map || info['variants'] is! List) continue;
        for (final rawVariant in info['variants'] as List) {
          if (rawVariant is! Map) continue;
          final url = rawVariant['url'];
          if (url is! String || !_isMp4Url(url)) continue;
          final bitrate = rawVariant['bitrate'];
          byUrl[url] = _Mp4Variant(
            url: url,
            bitrate: bitrate is num ? bitrate.toInt() : -1,
          );
        }
      }
    });

    final variants = byUrl.values.toList()
      ..sort((left, right) => right.bitrate.compareTo(left.bitrate));
    return variants;
  }

  void _visit(dynamic value, void Function(dynamic value) visitor) {
    visitor(value);
    if (value is Map) {
      for (final child in value.values) {
        _visit(child, visitor);
      }
    } else if (value is List) {
      for (final child in value) {
        _visit(child, visitor);
      }
    }
  }

  bool _isMp4Url(String url) {
    final uri = Uri.tryParse(url);
    final content = uri?.path.toLowerCase() ?? url.toLowerCase();
    return content.endsWith('.mp4');
  }

  bool _looksLikeMp4(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70;
  }

  String _generateSyndicationToken(String postId) {
    final value = (double.parse(postId) / 1e15) * math.pi;
    final integerPart = value.floor();
    final fraction = value - integerPart;
    final result = StringBuffer(_toBase36(integerPart));

    if (fraction > 0) {
      result.write('.');
      var remainder = fraction;
      // X post IDs are Snowflake IDs in the 18-19 digit range. Eight base36
      // fractional digits match the public web client's token format for
      // those IDs.
      for (var index = 0; index < 8 && remainder > 0; index++) {
        remainder *= 36;
        final digit = remainder.floor();
        result.write(_base36Digits[digit]);
        remainder -= digit;
      }
    }

    return result.toString().replaceAll(RegExp(r'(0+|\.)'), '');
  }

  String _toBase36(int value) {
    if (value == 0) return '0';
    var remaining = value;
    final digits = StringBuffer();
    while (remaining > 0) {
      digits.write(_base36Digits[remaining % 36]);
      remaining ~/= 36;
    }
    return digits.toString().split('').reversed.join();
  }
}

class _Mp4Variant {
  const _Mp4Variant({required this.url, required this.bitrate});

  final String url;
  final int bitrate;
}

class _RequestFailure implements Exception {
  const _RequestFailure();
}

const _base36Digits = '0123456789abcdefghijklmnopqrstuvwxyz';
