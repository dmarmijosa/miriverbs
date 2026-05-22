void main() {
  final urls = [
    'https://www.youtube.com/watch?v=7dxH6HGHa8I&list=RD7dxH6HGHa8I&start_radio=1',
    'https://www.youtube.com/watch?v=7dxH6HGHa8I',
    'https://youtu.be/7dxH6HGHa8I',
    'https://www.youtube.com/embed/7dxH6HGHa8I',
  ];

  final regexes = [
    RegExp(r"^https:\/\/(?:www\.|m\.)?youtube\.com\/watch\?v=([_\-a-zA-Z0-9]{11}).*$"),
    RegExp(r"^https:\/\/(?:www\.|m\.)?youtube\.com\/embed\/([_\-a-zA-Z0-9]{11}).*$"),
    RegExp(r"^https:\/\/youtu\.be\/([_\-a-zA-Z0-9]{11}).*$")
  ];

  for (var url in urls) {
    String? id;
    for (var exp in regexes) {
      Match? match = exp.firstMatch(url);
      if (match != null && match.groupCount >= 1) {
        id = match.group(1);
        break;
      }
    }
    print('URL: $url -> Parsed ID: "$id"');
  }
}
