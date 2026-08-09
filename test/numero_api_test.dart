@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Número de central y de sindicato, contra el backend real.
///
/// Todo se hace sobre centrales y sindicatos propios, creados al empezar y
/// borrados al terminar. No se toca la jerarquía real.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/numero_api_test.dart
/// ```
void main() {
  late Padron padron;
  late int federacionId;
  final centrales = <int>[];
  final sindicatos = <int>[];

  Future<Central> central(String nombre, {String? numero}) async {
    final c = await padron.centrales.crear(CentralRequest(
      nombre: nombre,
      numero: numero,
      federacionId: federacionId,
    ));
    centrales.add(c.id);
    return c;
  }

  Future<Sindicato> sindicato(String nombre, int centralId,
      {String? numero}) async {
    final s = await padron.sindicatos.crear(SindicatoRequest(
      nombre: nombre,
      numero: numero,
      centralId: centralId,
    ));
    sindicatos.add(s.id);
    return s;
  }

  setUpAll(() async {
    padron = Padron();
    final federaciones = await padron.federaciones.listar();
    expect(federaciones, isNotEmpty);
    federacionId = federaciones.first.id;
  });

  tearDownAll(() async {
    for (final id in sindicatos) {
      try {
        await padron.sindicatos.eliminar(id);
      } on ApiException {
        // Puede haberse borrado antes dentro de una prueba.
      }
    }
    for (final id in centrales) {
      try {
        await padron.centrales.eliminar(id);
      } on ApiException {
        // Ídem.
      }
    }
  });

  group('central', () {
    test('se crea con número y vuelve con él', () async {
      final c = await central('ZZZ CON NUMERO', numero: '9001');

      expect(c.numero, '9001');
      expect((await padron.centrales.obtener(c.id)).numero, '9001');
    });

    test('el número es opcional', () async {
      final c = await central('ZZZ SIN NUMERO');

      expect(c.numero, isNull);
    });

    test('dos sin número conviven', () async {
      // La clave única admite varios NULL. Si no fuera así, la segunda alta
      // reventaría acá y la mayoría de las centrales no se podrían cargar.
      await central('ZZZ SIN NUMERO 2');
      await central('ZZZ SIN NUMERO 3');
    });

    test('un número vacío se guarda como sin número', () async {
      final c = await central('ZZZ NUMERO VACIO', numero: '   ');

      expect(c.numero, isNull);
    });

    test('repetir el número se rechaza diciendo quién lo tiene', () async {
      await central('ZZZ DUENA DEL 9002', numero: '9002');

      await expectLater(
        central('ZZZ QUIERE EL 9002', numero: '9002'),
        throwsA(isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)
            .having((e) => e.mensaje, 'mensaje',
                contains('ZZZ DUENA DEL 9002'))),
      );
    });

    test('conservar el número propio al editar no es conflicto', () async {
      final c = await central('ZZZ EDITABLE', numero: '9003');

      final editada = await padron.centrales.actualizar(
        c.id,
        CentralRequest(
          nombre: 'ZZZ EDITADA',
          numero: '9003',
          federacionId: federacionId,
        ),
      );

      expect(editada.nombre, 'ZZZ EDITADA');
      expect(editada.numero, '9003');
    });

    test('se le puede quitar el número', () async {
      final c = await central('ZZZ PIERDE NUMERO', numero: '9004');

      final sinNumero = await padron.centrales.actualizar(
        c.id,
        CentralRequest(nombre: c.nombre, federacionId: federacionId),
      );

      expect(sinNumero.numero, isNull);
      // Y el número queda libre para otra.
      final otra = await central('ZZZ HEREDA EL 9004', numero: '9004');
      expect(otra.numero, '9004');
    });
  });

  group('sindicato', () {
    test('se crea con número dentro de su central', () async {
      final c = await central('ZZZ CENTRAL DE SINDICATOS');
      final s = await sindicato('ZZZ SIND CON NUMERO', c.id, numero: '8001');

      expect(s.numero, '8001');
      expect((await padron.sindicatos.obtener(s.id)).numero, '8001');
    });

    test('el número es único entre todos, no solo dentro de la central',
        () async {
      final unaCentral = await central('ZZZ CENTRAL UNO');
      final otraCentral = await central('ZZZ CENTRAL DOS');
      await sindicato('ZZZ DUENO DEL 8002', unaCentral.id, numero: '8002');

      // El nombre sí puede repetirse entre centrales; el número no.
      await expectLater(
        sindicato('ZZZ QUIERE EL 8002', otraCentral.id, numero: '8002'),
        throwsA(isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)
            .having((e) => e.mensaje, 'mensaje',
                contains('ZZZ DUENO DEL 8002'))),
      );
    });

    test('un sindicato y una central pueden tener el mismo número', () async {
      // Son numeraciones distintas: que la central 7001 exista no impide que
      // haya un sindicato 7001.
      final c = await central('ZZZ CENTRAL 7001', numero: '7001');
      final s = await sindicato('ZZZ SIND 7001', c.id, numero: '7001');

      expect(c.numero, '7001');
      expect(s.numero, '7001');
    });
  });
}
