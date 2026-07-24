import 'package:doudou/services/constant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('constants', () {
    test('kSidebarMinWidth is 640', () {
      expect(kSidebarMinWidth, 640);
    });

    test('domain is the YouTube Music origin', () {
      expect(domain, 'https://music.youtube.com/');
    });

    test('baseUrl extends domain with the API path', () {
      expect(baseUrl, '${domain}youtubei/v1/');
    });

    test('fixedParms contains the API key and json alt', () {
      expect(fixedParms, contains('alt=json'));
      expect(fixedParms, contains('key='));
      expect(fixedParms, contains('prettyPrint=false'));
    });

    test('userAgent looks like a Chrome desktop UA string', () {
      expect(userAgent, contains('Chrome'));
      expect(userAgent, contains('Windows NT 10.0'));
    });
  });
}
