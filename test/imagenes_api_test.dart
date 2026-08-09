@Tags(['integracion'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fede/repositories/padron.dart';

/// Fotos de productores, contra el backend real.
///
/// El diseño es: se sube **una** imagen, del tamaño que sea, y el servidor
/// deriva la foto de consulta y la miniatura, reduciéndolas. Estas pruebas
/// verifican justamente eso — sobre todo que un archivo grande se acepte y se
/// reduzca en vez de rechazarse.
///
/// A diferencia del resto de las pruebas de integración, estas escriben: no hay
/// forma de verificar una subida sin subir. Se crea un productor propio al
/// empezar y se borra al terminar, y el borrado arrastra sus imágenes.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/imagenes_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Uint8List fotoGrande;
  late Uint8List fotoChica;
  late Uint8List conTransparencia;
  late int productorId;

  /// Medio mega: el peso al que el servidor tiene que dejar la foto guardada.
  const topeOriginal = 512 * 1024;

  setUpAll(() async {
    padron = Padron();
    fotoGrande = File('test/fixtures/foto-grande.jpg').readAsBytesSync();
    fotoChica = File('test/fixtures/foto-prueba.png').readAsBytesSync();
    conTransparencia =
        File('test/fixtures/con-transparencia.png').readAsBytesSync();

    final sindicatos = await padron.sindicatos.listar();
    expect(sindicatos, isNotEmpty);

    final creado = await padron.productores.crear(ProductorRequest(
      nombres: 'ZZZ PRUEBA',
      apellidos: 'FOTOS',
      sindicatoId: sindicatos.first.id,
    ));
    productorId = creado.id;
  });

  tearDownAll(() async {
    try {
      await padron.productores.eliminar(productorId);
    } finally {
      padron.cerrar();
    }
  });

  test('una sola subida genera las dos variantes', () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );

    expect(resultado.original.tipo, equals(TipoImagen.original));
    expect(resultado.miniatura.tipo, equals(TipoImagen.miniatura));
    // El usuario mandó un archivo; el servidor devolvió dos imágenes.
    expect(resultado.tamanoSubidoBytes, equals(fotoGrande.length));
  });

  test('una foto grande se acepta y se reduce, no se rechaza', () async {
    // 1,42 MB y 4032x3024: con el diseño anterior esto daba 400 por superar
    // medio mega. Ahora tiene que entrar y salir reducida.
    expect(fotoGrande.length, greaterThan(topeOriginal));

    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );

    expect(resultado.original.tamanoBytes, lessThanOrEqualTo(topeOriginal),
        reason: 'la foto guardada tiene que entrar en medio mega');
    expect(resultado.huboReduccion, isTrue);
    expect(resultado.porcentajeReduccion, greaterThan(0));
  });

  test('la miniatura es mucho más chica que la foto', () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );

    // Su razón de ser es que el listado no baje la foto completa por fila.
    expect(resultado.miniatura.tamanoBytes,
        lessThan(resultado.original.tamanoBytes ~/ 4));
    expect(resultado.miniatura.ancho, lessThanOrEqualTo(320));
    expect(resultado.miniatura.alto, lessThanOrEqualTo(320));
  });

  test('conserva la proporción al reducir', () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );

    final proporcionOrigen = resultado.anchoSubido / resultado.altoSubido;
    final proporcionFoto =
        resultado.original.ancho / resultado.original.alto;
    final proporcionMini =
        resultado.miniatura.ancho / resultado.miniatura.alto;

    expect(proporcionFoto, closeTo(proporcionOrigen, 0.02));
    expect(proporcionMini, closeTo(proporcionOrigen, 0.02));
  });

  test('una imagen ya chica no se agranda', () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoChica,
      nombreArchivo: 'foto-prueba.png',
    );

    // Agrandarla sumaría peso sin sumar detalle.
    expect(resultado.original.ancho, lessThanOrEqualTo(resultado.anchoSubido));
    expect(resultado.original.alto, lessThanOrEqualTo(resultado.altoSubido));
  });

  test('un PNG con transparencia se acepta y sale como JPEG', () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: conTransparencia,
      nombreArchivo: 'con-transparencia.png',
    );

    // Todo se guarda como JPEG: comprime fotografías mucho mejor que PNG.
    expect(resultado.original.tipoMime, equals('image/jpeg'));
    expect(resultado.miniatura.tipoMime, equals('image/jpeg'));
  });

  test('la API devuelve la URL del archivo, no los bytes', () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );

    // Los binarios viven en el almacén del servidor; la base guarda la
    // referencia y la API la devuelve como ruta.
    expect(resultado.original.url, startsWith('/api/v1/archivos/originales/'));
    expect(resultado.miniatura.url, startsWith('/api/v1/archivos/miniaturas/'));
    expect(resultado.original.url, endsWith('.jpg'));

    // El nombre es «aleatorio-nombre-del-productor.jpg»: el identificador
    // aleatorio va primero para que la parte que garantiza la unicidad no
    // quede nunca recortada por el tope de longitud del nombre.
    final archivo = resultado.original.url.split('/').last;
    expect(archivo, matches(RegExp(r'^[0-9a-f]{12}-[a-z0-9-]+\.jpg$')),
        reason: 'formato esperado: 2ab3fb23fb23-juan-morales.jpg');
    expect(archivo, endsWith('zzz-prueba-fotos.jpg'),
        reason: 'el nombre del productor va al final, normalizado');

    // Y las dos variantes tienen identificadores distintos entre sí.
    expect(resultado.original.url.split('/').last.substring(0, 12),
        isNot(equals(resultado.miniatura.url.split('/').last.substring(0, 12))));

    // Relativa a propósito: una URL absoluta ataría los datos al host.
    expect(resultado.original.url, isNot(startsWith('http')));
  });

  test('todas las fotos caen en las mismas dos carpetas', () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );

    // Antes se creaba una carpeta por productor: con 4.051 filas eso son 4.051
    // directorios, y encima quedaban vacíos al borrar. Acá se comprueba que la
    // ruta tenga exactamente un nivel de carpeta.
    for (final imagen in [resultado.original, resultado.miniatura]) {
      final ruta = imagen.url.replaceFirst('/api/v1/archivos/', '');
      expect(ruta.split('/').length, equals(2),
          reason: 'la clave debe ser carpeta/archivo, sin subcarpetas: $ruta');
      expect(ruta.split('/').first, isIn(['miniaturas', 'originales']));
    }
  });

  test('las dos variantes se descargan y son JPEG de verdad', () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );

    for (final imagen in [resultado.original, resultado.miniatura]) {
      final url = Uri.parse(ApiConfig.urlAbsoluta(imagen.url));
      final respuesta = await http.get(url);

      expect(respuesta.statusCode, equals(200),
          reason: 'variante ${imagen.tipo}');
      expect(respuesta.headers['content-type'], contains('image/jpeg'));
      // Cabecera de un JPEG: si viniera un JSON de error, falla acá.
      expect(respuesta.bodyBytes.take(2), equals([0xFF, 0xD8]));
      expect(respuesta.bodyBytes.length, equals(imagen.tamanoBytes));
    }
  });

  test('no se puede salir del almacén por la URL de archivos', () async {
    // Con los archivos en disco, esta es la vía clásica para leer cosas del
    // servidor que no deberían verse. Ninguna variante puede devolver 200.
    const intentos = [
      '/api/v1/archivos/../../pom.xml',
      '/api/v1/archivos/../application.properties',
      '/api/v1/archivos/productores/../../pom.xml',
      '/api/v1/archivos/..%2F..%2Fpom.xml',
    ];

    for (final intento in intentos) {
      final respuesta =
          await http.get(Uri.parse(ApiConfig.urlAbsoluta(intento)));
      expect(respuesta.statusCode, isNot(200), reason: intento);
    }
  });

  test('reemplazar cambia la URL y borra la anterior del servidor', () async {
    final antes = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'primera.jpg',
    );
    final urlVieja = Uri.parse(ApiConfig.urlAbsoluta(antes.original.url));

    final despues = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoChica,
      nombreArchivo: 'segunda.png',
    );

    // Clave nueva en cada subida: por eso la caché del navegador se invalida
    // sola, sin parámetros de versión.
    expect(despues.original.url, isNot(equals(antes.original.url)));
    expect(despues.original.nombreOriginal, equals('segunda.png'));

    // Y el archivo viejo no queda ocupando espacio en el servidor.
    expect((await http.get(urlVieja)).statusCode, equals(404),
        reason: 'la foto reemplazada debe haberse borrado del almacén');

    final imagenes = await padron.productores.imagenes(productorId);
    expect(imagenes.length, equals(2), reason: 'una foto y una miniatura');
  });

  test('el listado trae la URL de la miniatura y se puede pedir', () async {
    await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );

    final pagina = await padron.productores.listar(
      texto: 'ZZZ PRUEBA',
      paginacion: const Paginacion(tamano: 5),
    );
    final nuestro = pagina.contenido.firstWhere((p) => p.id == productorId);

    expect(nuestro.miniaturaUrl, isNotNull);
    expect(nuestro.fotoUrl, isNotNull);
    expect(nuestro.tieneMiniatura, isTrue);

    // La URL del listado tiene que servir tal cual: es la que usa la fila para
    // mostrar el avatar sin bajar la foto completa.
    final respuesta = await http
        .get(Uri.parse(ApiConfig.urlAbsoluta(nuestro.miniaturaUrl!)));
    expect(respuesta.statusCode, equals(200));
    expect(respuesta.bodyBytes.length, lessThan(200 * 1024));
  });

  test('el recorte cambia la proporción de lo guardado', () async {
    final entera = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );
    // La foto de prueba es apaisada, 4032x3024.
    expect(entera.original.ancho, greaterThan(entera.original.alto));

    // Se recorta un rectángulo vertical del centro, como quien encuadra una
    // cara en una foto con mucho fondo.
    final recortada = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
      recorte: const Recorte(x: 1500, y: 200, ancho: 1000, alto: 2600),
    );

    expect(recortada.original.alto, greaterThan(recortada.original.ancho),
        reason: 'un recorte vertical debe dar una imagen vertical');

    final proporcion = recortada.original.ancho / recortada.original.alto;
    expect(proporcion, closeTo(1000 / 2600, 0.02));
  });

  test('el recorte se aplica antes de reducir, no después', () async {
    // Un recorte chico del original sale nítido porque los 1600 píxeles del
    // lado mayor se gastan en esa región. Si se recortara después de reducir,
    // el resultado sería mucho más chico que el tope.
    final recortada = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
      recorte: const Recorte(x: 100, y: 100, ancho: 2000, alto: 2000),
    );

    expect(recortada.original.ancho, equals(1600));
    expect(recortada.original.alto, equals(1600));
  });

  test('el informe reporta el tamaño de lo subido, no el del recorte',
      () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
      recorte: const Recorte(x: 0, y: 0, ancho: 500, alto: 500),
    );

    // Es lo que le permite al usuario entender cuánto se ahorró respecto de
    // SU archivo, que es la referencia que él conoce.
    expect(resultado.tamanoSubidoBytes, equals(fotoGrande.length));
    expect(resultado.anchoSubido, equals(4032));
    expect(resultado.altoSubido, equals(3024));
  });

  test('un recorte fuera de la imagen se rechaza con 400', () async {
    await expectLater(
      padron.productores.subirImagen(
        productorId: productorId,
        bytes: fotoGrande,
        nombreArchivo: 'foto-grande.jpg',
        recorte: const Recorte(x: 4000, y: 3000, ancho: 500, alto: 500),
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.estado, 'estado', 400)
          .having((e) => e.mensaje, 'mensaje', contains('se sale'))),
    );
  });

  test('un recorte de ancho cero se rechaza', () async {
    await expectLater(
      padron.productores.subirImagen(
        productorId: productorId,
        bytes: fotoGrande,
        nombreArchivo: 'foto-grande.jpg',
        recorte: const Recorte(x: 10, y: 10, ancho: 0, alto: 100),
      ),
      throwsA(isA<ApiException>().having((e) => e.estado, 'estado', 400)),
    );
  });

  test('un archivo que no es imagen se rechaza con 400', () async {
    await expectLater(
      padron.productores.subirImagen(
        productorId: productorId,
        bytes: 'esto es texto, no una foto'.codeUnits,
        nombreArchivo: 'trampa.jpg',
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.estado, 'estado', 400)
          .having((e) => e.mensaje, 'mensaje', contains('imagen'))),
    );
  });

  test('borrar se lleva las dos variantes y sus archivos', () async {
    final resultado = await padron.productores.subirImagen(
      productorId: productorId,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );
    final urlFoto = Uri.parse(ApiConfig.urlAbsoluta(resultado.original.url));
    final urlMini = Uri.parse(ApiConfig.urlAbsoluta(resultado.miniatura.url));

    await padron.productores.eliminarImagen(productorId);

    expect(await padron.productores.imagenes(productorId), isEmpty);
    // Y los archivos tampoco quedan en el servidor: borrar la fila sin borrar
    // el archivo dejaría basura acumulándose para siempre.
    expect((await http.get(urlFoto)).statusCode, equals(404));
    expect((await http.get(urlMini)).statusCode, equals(404));
  });

  test('borrar el productor también se lleva sus archivos', () async {
    final sindicatos = await padron.sindicatos.listar();
    final temporal = await padron.productores.crear(ProductorRequest(
      nombres: 'ZZZ BORRADO',
      sindicatoId: sindicatos.first.id,
    ));

    final subida = await padron.productores.subirImagen(
      productorId: temporal.id,
      bytes: fotoGrande,
      nombreArchivo: 'foto-grande.jpg',
    );
    final url = Uri.parse(ApiConfig.urlAbsoluta(subida.original.url));
    expect((await http.get(url)).statusCode, equals(200));

    await padron.productores.eliminar(temporal.id);

    // El cascade de JPA se lleva las filas, pero los archivos no los conoce:
    // si esto falla, cada productor borrado deja fotos huérfanas en el disco.
    expect((await http.get(url)).statusCode, equals(404));
  });
}
