// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<void> guardarArchivo(
  List<int> bytes,
  String nombreArchivo,
  String tipoMime,
) async {
  final blob = html.Blob([bytes], tipoMime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    html.AnchorElement(href: url)
      ..download = nombreArchivo
      ..style.display = 'none'
      ..click();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
