import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:web/web.dart' as web;

void suprimirMenuNativoImagen() {
  const evento = 'contextmenu';
  final cancelar = ((web.Event event) => event.preventDefault()).toJS;
  web.window.addEventListener(
    evento,
    cancelar,
    web.AddEventListenerOptions(capture: true, once: true),
  );
  Timer(const Duration(milliseconds: 700), () {
    web.window.removeEventListener(evento, cancelar, true.toJS);
  });
}

Future<void> copiarImagenPortapapeles(Uint8List bytes) async {
  if (!web.window.isSecureContext) {
    throw UnsupportedError(
      'Para copiar imágenes en la web, abrí FEDERA por HTTPS.',
    );
  }
  final imagen = img.decodeImage(bytes);
  if (imagen == null) throw StateError('No se pudo abrir la fotografía.');
  final png = img.encodePng(img.bakeOrientation(imagen));
  final blob = web.Blob(
    [png.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final item = web.ClipboardItem({'image/png': blob}.jsify()! as JSObject);
  await web.window.navigator.clipboard.write([item].toJS).toDart;
}
