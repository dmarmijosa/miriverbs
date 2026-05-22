import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() {
  final url = 'https://www.youtube.com/watch?v=7dxH6HGHa8I&list=RD7dxH6HGHa8I&start_radio=1';
  final id = YoutubePlayer.convertUrlToId(url);
  print('Parsed ID: "$id"');
}
