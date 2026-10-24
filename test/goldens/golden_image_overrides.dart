import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';

final Uint8List goldenImageBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAABUElEQVR4nNXCB1oSAACG4e8k4AQVAQFBEciVaZY7R66Ge1RWjtQrlCs1d24zV1ruzL0v1Tn+93nxGz5LJ2D4Ip0Hxh7pJBp7pZMU1Ced5KB+6aQED0gnNfirdB6GDEonLWRIOo9Ch6WTHvpNOhlhI9J5HDYqnczwMek8CR+XzlPThHSyTJPSyTZPSSfH/F06uRHT0smLmJFOfuSsdAoi56TzLGpeOoVRC9IpsixKp9iyJJ2S6B/SeR69LJ1S60/plFlXpFNuW5VOhW1NOpX2dem8sG9I52XML+m8itmUzmvHlnSqHL+lU+38I50a57Z0al070qlz7UqnPnZPOg2x+9JpdB9Ip8l9KJ1mz1/pvPEcSedt3D/pvIs7lk5L/Il03sefSueD90w6H73n0mlNuJBOW8KldNp9V9Lp8F1L55P/Rjqd/lvpdAXupNMduJf+H8flSR48jW3rAAAAAElFTkSuQmCC',
);

class GoldenHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _GoldenHttpClient();
}

class _GoldenHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _GoldenHttpClientRequest();
}

class _GoldenHttpClientRequest extends Fake implements HttpClientRequest {
  final _headers = _GoldenHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async => _GoldenHttpClientResponse();
}

class _GoldenHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => goldenImageBytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(goldenImageBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _GoldenHttpHeaders extends Fake implements HttpHeaders {
  @override
  List<String>? operator [](String name) => null;

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}
