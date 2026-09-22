import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:x_video_downloader/src/domain/post_url.dart';
import 'package:x_video_downloader/src/domain/video_resolver.dart';
import 'package:x_video_downloader/src/services/x_web_video_resolver.dart';

void main() {
  test(
    'downloads the highest bitrate MP4 from the syndication response',
    () async {
      final requests = <http.Request>[];
      final mp4Bytes = <int>[0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 1, 2, 3, 4];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.host == 'cdn.syndication.twimg.com') {
          return http.Response(
            jsonEncode({
              'mediaDetails': [
                {
                  'type': 'video',
                  'video_info': {
                    'variants': [
                      {
                        'content_type': 'video/mp4',
                        'bitrate': 256000,
                        'url': 'https://video.twimg.com/low.mp4',
                      },
                      {
                        'content_type': 'application/x-mpegURL',
                        'url': 'https://video.twimg.com/stream.m3u8',
                      },
                      {
                        'content_type': 'video/mp4',
                        'bitrate': 2176000,
                        'url': 'https://video.twimg.com/high.mp4',
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }
        expect(request.url.toString(), 'https://video.twimg.com/high.mp4');
        return http.Response.bytes(mp4Bytes, 200);
      });

      final resolver = XWebVideoResolver(client: client);
      final post = PostUrlParser.parse(
        'https://x.com/user/status/1600009574919962625',
      );
      final result = await resolver.resolve(post);

      expect(result.fileName, 'x-video-1600009574919962625.mp4');
      expect(result.bytes, mp4Bytes);
      expect(requests, hasLength(2));
      expect(requests.first.headers['user-agent'], 'Googlebot');
      expect(requests.first.url.queryParameters['id'], '1600009574919962625');
      expect(requests.first.url.queryParameters['token'], '3vmktiebrx');
    },
  );

  test(
    'reports an unavailable post when syndication returns no media',
    () async {
      final client = MockClient((_) async {
        return http.Response(jsonEncode({'tombstone': 'Not found'}), 200);
      });
      final resolver = XWebVideoResolver(client: client);
      final post = PostUrlParser.parse('https://x.com/user/status/12345');

      await expectLater(
        resolver.resolve(post),
        throwsA(
          isA<VideoResolverException>().having(
            (error) => error.message,
            'message',
            contains('Видео в посте не найдено'),
          ),
        ),
      );
    },
  );
}
