// SOLO se compila en web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebDownloader {
  static void downloadBytes(String filename, List<int> bytes) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}
