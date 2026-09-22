import 'package:flutter_test/flutter_test.dart';
import 'package:x_video_downloader/src/domain/post_url.dart';

void main() {
  group('PostUrlParser', () {
    test('normalizes x.com and extracts the post ID', () {
      final result = PostUrlParser.parse(
        'https://x.com/Alex/status/1234567890123456789?s=20',
      );

      expect(result.id, '1234567890123456789');
      expect(
        result.canonicalUrl,
        'https://x.com/Alex/status/1234567890123456789',
      );
    });

    test('accepts twitter.com and a missing scheme', () {
      final result = PostUrlParser.parse(
        'twitter.com/user/status/12345/photo/1',
      );

      expect(result.id, '12345');
      expect(result.canonicalUrl, 'https://x.com/user/status/12345/photo/1');
    });

    test('rejects unsupported hosts', () {
      expect(
        () => PostUrlParser.parse('https://example.com/user/status/12345'),
        throwsA(isA<PostUrlException>()),
      );
    });

    test('rejects non-post paths and invalid IDs', () {
      expect(
        () => PostUrlParser.parse('https://x.com/user/12345'),
        throwsA(isA<PostUrlException>()),
      );
      expect(
        () => PostUrlParser.parse('https://x.com/user/status/not-a-number'),
        throwsA(isA<PostUrlException>()),
      );
    });
  });
}
