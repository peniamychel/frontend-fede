import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> guardarArchivo(
  List<int> bytes,
  String nombreArchivo,
  String tipoMime,
) async {
  // Con bytes, file_picker guarda el archivo en móviles y escritorio.
  // Android puede devolver una referencia como /document/336, que no es una
  // ruta de dart:io. Volver a escribirla provocaría un error tras guardar bien.
  await FilePicker.saveFile(
    dialogTitle: 'Guardar archivo',
    fileName: nombreArchivo,
    bytes: Uint8List.fromList(bytes),
  );
}
