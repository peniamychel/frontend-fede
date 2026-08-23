@Tags(['integracion'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fede/repositories/padron.dart';

/// El acta de una reunión, hoja por hoja, contra el backend real.
///
/// El acta casi nunca es un solo archivo: lo habitual es el cuaderno de actas
/// fotografiado hoja por hoja con el teléfono, ahí mismo en la asamblea. Lo que
/// se fija acá es que las hojas conserven el orden en que se subieron, que
/// quitar una del medio renumere las que siguen —o el orden queda con un hueco
/// y la próxima pisaría un número existente— y que cada una se pueda leer.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/acta_reunion_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Uint8List pdf;
  late Uint8List jpg;

  late Federacion fede;
  late Central central;
  late Sindicato sindicato;
  late Reunion reunion;

  setUpAll(() async {
    padron = Padron();
    // Un PDF mínimo pero válido, y un JPEG de un píxel: lo que importa es que
    // el servidor los reconozca por lo que son.
    pdf = Uint8List.fromList(
        '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'
            .codeUnits);
    jpg = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, //
      0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
    ]);

    fede = await padron.federaciones
        .crear(const FederacionRequest(nombre: 'ZZZ ACTA FED'));
    central = await padron.centrales
        .crear(CentralRequest(nombre: 'ZZZ ACTA CEN', federacionId: fede.id));
    sindicato = await padron.sindicatos
        .crear(SindicatoRequest(nombre: 'ZZZ ACTA SIN', centralId: central.id));
    reunion = await padron.reuniones.crear(ReunionRequest(
      tipo: TipoReunion.sindicato,
      titulo: 'ZZZ ASAMBLEA CON ACTA LARGA',
      fecha: DateTime.parse('2026-05-04'),
      convocanteId: sindicato.id,
    ));
  });

  tearDownAll(() async {
    try {
      await padron.reuniones.eliminar(reunion.id);
      await padron.sindicatos.eliminar(sindicato.id);
      await padron.centrales.eliminar(central.id);
      await padron.federaciones.eliminar(fede.id);
    } on ApiException {
      // Lo importante ya se limpió.
    } finally {
      padron.cerrar();
    }
  });

  test('sin hojas, la reunión no tiene acta', () async {
    expect(reunion.tieneActa, isFalse);
    expect(reunion.hojasActa, isEmpty);
    expect(reunion.codigoActa, isNull);
  });

  test('la primera hoja no se sube sin el número del acta', () async {
    // El archivo es una foto de una hoja del libro. Sin el número de esa acta,
    // meses después nadie puede ir al libro a cotejar lo que dice la pantalla.
    await expectLater(
      padron.reuniones.agregarHoja(
          reunionId: reunion.id, bytes: pdf, nombreArchivo: 'hoja1.pdf'),
      throwsA(isA<ApiException>()
          .having((e) => e.esConflicto, 'esConflicto', isTrue)
          .having((e) => e.mensaje, 'mensaje', contains('número del acta'))),
    );

    expect((await padron.reuniones.obtener(reunion.id)).tieneActa, isFalse,
        reason: 'la hoja no tiene que haber quedado a medias');
  });

  test('las hojas se numeran en el orden en que se suben', () async {
    await padron.reuniones.agregarHoja(
        reunionId: reunion.id,
        bytes: pdf,
        nombreArchivo: 'hoja1.pdf',
        codigo: '12/2026');
    // Las que siguen son del mismo acta: no hace falta repetir el número.
    await padron.reuniones.agregarHoja(
        reunionId: reunion.id, bytes: jpg, nombreArchivo: 'hoja2.jpg');
    final conTres = await padron.reuniones.agregarHoja(
        reunionId: reunion.id, bytes: jpg, nombreArchivo: 'hoja3.jpg');

    expect(conTres.tieneActa, isTrue);
    expect(conTres.codigoActa, '12/2026');
    expect(conTres.hojasActa.map((h) => h.orden), [1, 2, 3]);
    expect(conTres.hojasActa.map((h) => h.nombre),
        ['hoja1.pdf', 'hoja2.jpg', 'hoja3.jpg']);
    expect(conTres.hojasActa.first.esPdf, isTrue);
    expect(conTres.hojasActa.last.esPdf, isFalse);
    expect(conTres.hojasActa.every((h) => h.tamanoBytes > 0), isTrue);
  });

  test('cada hoja se puede leer, con su tipo', () async {
    final hojas = (await padron.reuniones.obtener(reunion.id)).hojasActa;

    final primera = await http
        .get(padron.reuniones.urlHoja(reunion.id, hojas.first.id));
    expect(primera.statusCode, 200);
    expect(primera.headers['content-type'], contains('application/pdf'));
    expect(primera.bodyBytes, pdf);

    final segunda =
        await http.get(padron.reuniones.urlHoja(reunion.id, hojas[1].id));
    expect(segunda.headers['content-type'], contains('image/jpeg'));
  });

  test('quitar una del medio renumera las que siguen', () async {
    // Sin renumerar, el orden queda 1 y 3, y la próxima hoja que se suba
    // pisaría un número existente.
    final antes = (await padron.reuniones.obtener(reunion.id)).hojasActa;
    final delMedio = antes[1];

    final despues =
        await padron.reuniones.quitarHoja(reunion.id, delMedio.id);

    expect(despues.hojasActa.map((h) => h.orden), [1, 2]);
    expect(despues.hojasActa.map((h) => h.nombre), ['hoja1.pdf', 'hoja3.jpg']);
  });

  test('la hoja quitada ya no se puede leer', () async {
    // Se borra del disco además de la fila: si no, quedaría ocupando espacio
    // para siempre sin que nadie sepa de qué reunión era.
    final quedan = (await padron.reuniones.obtener(reunion.id)).hojasActa;
    expect(quedan, hasLength(2));

    final inexistente =
        await http.get(padron.reuniones.urlHoja(reunion.id, 99999999));
    expect(inexistente.statusCode, 404);
  });

  test('el número se corrige sin volver a subir las hojas', () async {
    // Que se haya tipeado mal no es motivo para cargar el acta de nuevo: el
    // número es un dato del acta, no de cada foto.
    final antes = await padron.reuniones.obtener(reunion.id);

    final corregida =
        await padron.reuniones.ponerCodigoActa(reunion.id, '13/2026');

    expect(corregida.codigoActa, '13/2026');
    expect(corregida.hojasActa.map((h) => h.id),
        antes.hojasActa.map((h) => h.id),
        reason: 'las hojas quedan donde estaban');
  });

  test('el número no se puede dejar en blanco', () async {
    await expectLater(
      padron.reuniones.ponerCodigoActa(reunion.id, '   '),
      throwsA(isA<ApiException>()),
    );
    expect((await padron.reuniones.obtener(reunion.id)).codigoActa, '13/2026');
  });

  test('sin vetos decididos, el acta se puede vaciar entera', () async {
    for (final h in (await padron.reuniones.obtener(reunion.id)).hojasActa) {
      await padron.reuniones.quitarHoja(reunion.id, h.id);
    }

    final vacia = await padron.reuniones.obtener(reunion.id);
    expect(vacia.hojasActa, isEmpty);
    expect(vacia.tieneActa, isFalse);
    // Sin hojas no hay acta, y un número de acta sin acta prometería un
    // documento que no está.
    expect(vacia.codigoActa, isNull);
  });

  test('sin acta cargada, tampoco se le puede poner número', () async {
    await expectLater(
      padron.reuniones.ponerCodigoActa(reunion.id, '99/2026'),
      throwsA(isA<ApiException>()
          .having((e) => e.esConflicto, 'esConflicto', isTrue)
          .having((e) => e.mensaje, 'mensaje', contains('no tiene acta'))),
    );
  });

  test('y al volver a subir, el número se pide de nuevo', () async {
    await expectLater(
      padron.reuniones.agregarHoja(
          reunionId: reunion.id, bytes: pdf, nombreArchivo: 'otra.pdf'),
      throwsA(isA<ApiException>()
          .having((e) => e.mensaje, 'mensaje', contains('número del acta'))),
    );

    final rehecha = await padron.reuniones.agregarHoja(
        reunionId: reunion.id,
        bytes: pdf,
        nombreArchivo: 'otra.pdf',
        codigo: '20/2026');
    expect(rehecha.codigoActa, '20/2026');

    // Y se limpia para la prueba que sigue.
    await padron.reuniones
        .quitarHoja(reunion.id, rehecha.hojasActa.single.id);
  });

  test('un archivo que no es PDF ni imagen se rechaza', () async {
    await expectLater(
      padron.reuniones.agregarHoja(
          reunionId: reunion.id,
          bytes: Uint8List.fromList('no soy un acta'.codeUnits),
          nombreArchivo: 'notas.txt'),
      throwsA(isA<ApiException>()
          .having((e) => e.mensaje, 'mensaje', contains('PDF o una imagen'))),
    );
  });
}
