class PostReference {
  const PostReference({required this.id, required this.canonicalUrl});

  final String id;
  final String canonicalUrl;
}

class PostUrlException implements Exception {
  const PostUrlException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PostUrlParser {
  const PostUrlParser._();

  static const _supportedHosts = {
    'x.com',
    'www.x.com',
    'mobile.x.com',
    'twitter.com',
    'www.twitter.com',
    'mobile.twitter.com',
  };

  static PostReference parse(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      throw const PostUrlException('Вставь ссылку на пост X.');
    }

    final uri = _parseUri(value);
    final host = uri.host.toLowerCase();
    if (!_supportedHosts.contains(host)) {
      throw const PostUrlException(
        'Нужна ссылка с домена x.com или twitter.com.',
      );
    }

    final segments = uri.pathSegments;
    final statusIndex = segments.indexWhere(
      (segment) => segment.toLowerCase() == 'status',
    );
    if (statusIndex < 0 || statusIndex + 1 >= segments.length) {
      throw const PostUrlException(
        'Ссылка должна содержать путь /status/ и ID поста.',
      );
    }

    final id = segments[statusIndex + 1];
    if (!_isValidPostId(id)) {
      throw const PostUrlException('ID поста должен состоять только из цифр.');
    }

    final canonicalPath = '/${segments.join('/')}';
    return PostReference(id: id, canonicalUrl: 'https://x.com$canonicalPath');
  }

  static Uri _parseUri(String value) {
    final withScheme = value.contains('://') ? value : 'https://$value';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) {
      throw const PostUrlException('Ссылка выглядит некорректно.');
    }
    return uri;
  }

  static bool _isValidPostId(String value) {
    if (!RegExp(r'^\d{1,20}$').hasMatch(value)) return false;
    final parsed = int.tryParse(value);
    return parsed != null && parsed > 0;
  }
}
