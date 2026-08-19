import 'dart:convert';
import 'dart:io';
import 'package:doudou/services/stream_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const videoId = '_WGQMtwU7kw';

void log(String msg) => print('[ytm-audio-test] $msg');

void main() async {
  log('Starting YTM audio test for $videoId');

  final provider = await StreamProvider.fetch(videoId);

  log('playable: ${provider.playable}');
  log('status: ${provider.statusMSG}');

  if (!provider.playable || provider.audioFormats == null || provider.audioFormats!.isEmpty) {
    log('No playable audio formats');
    exit(1);
  }

  final formats = provider.audioFormats!;
  log('audio format count: ${formats.length}');

  for (final f in formats) {
    log('  itag=${f.itag} codec=${f.audioCodec} bitrate=${f.bitrate} size=${f.size}');
  }

  final audio = provider.highestQualityAudio ?? formats.first;
  log('selected itag: ${audio.itag}');
  log('selected url: ${audio.url}');

  final request = await HttpClient().headUrl(Uri.parse(audio.url));
  final response = await request.close();
  await response.drain<void>();
  log('HEAD status: ${response.statusCode}');

  if (response.statusCode != 200) {
    log('Stream not reachable, aborting playback');
    exit(1);
  }

  final ua = YoutubeApiClient.visionos.payload['context']['client']['userAgent'].toString();
  log('Starting mpv with User-Agent: $ua');

  final process = await Process.start('mpv', [
    '--no-video',
    '--user-agent=$ua',
    '--referrer=https://www.youtube.com/',
    audio.url,
  ]);

  process.stdout.transform(utf8.decoder).listen(stdout.write);
  process.stderr.transform(utf8.decoder).listen(stderr.write);

  final code = await process.exitCode;
  log('mpv exited with code $code');
}
