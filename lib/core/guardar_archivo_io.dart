import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> guardarArchivo(
  List<int> bytes,
  String nombreArchivo,
  String tipoMime,
) async {
  final ruta = await FilePicker.saveFile(
    dialogTitle: 'Guardar copia de seguridad',
    fileName: nombreArchivo,
    bytes: Uint8List.fromList(bytes),
  );
  // En algunas plataformas file_picker guarda los bytes; en otras solamente
  // devuelve la ruta elegida. Solo se escribe cuando el archivo aún no existe.
  if (ruta != null && !await File(ruta).exists()) {
    await File(ruta).writeAsBytes(bytes, flush: true);
  }
}
