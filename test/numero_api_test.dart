@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Número de federación y de sindicato, y abreviatura de central, contra el
/// backend real.
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
  final federaciones = <int>[];

  Future<Federacion> federacion(String nombre, {String? numero}) async {
    final f = await padron.federaciones
        .crear(FederacionRequest(nombre: nombre, numero: numero));
    federaciones.add(f.id);
    return f;
  }

  Future<Central> central(String nombre, {String? abreviatura}) async {
    final c = await padron.centrales.crear(CentralRequest(
      nombre: nombre,
      abreviatura: abreviatura,
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
    // Las federaciones van al final: el backend no deja borrar una que todavía
    // tenga centrales colgando.
    for (final id in federaciones) {
      try {
        await padron.federaciones.eliminar(id);
      } on ApiException {
        // Ídem.
      }
    }
  });

  group('federación', () {
    test('se crea con número y vuelve con él', () async {
      final f = await federacion('ZZZ FED CON NUMERO', numero: '9501');

      expect(f.numero, '9501');
      expect((await padron.federaciones.obtener(f.id)).numero, '9501');
    });

    test('el número es opcional', () async {
      final f = await federacion('ZZZ FED SIN NUMERO');

      expect(f.numero, isNull);
    });

    test('dos sin número conviven', () async {
      // La clave única admite varios NULL. Si no fuera así, la segunda alta
      // reventaría acá.
      await federacion('ZZZ FED SIN NUMERO 2');
      await federacion('ZZZ FED SIN NUMERO 3');
    });

    test('un número vacío se guarda como sin número', () async {
      final f = await federacion('ZZZ FED NUMERO VACIO', numero: '   ');

      expect(f.numero, isNull);
    });

    test('repetir el número se rechaza diciendo quién lo tiene', () async {
      await federacion('ZZZ FED DUENA DEL 9502', numero: '9502');

      await expectLater(
        federacion('ZZZ FED QUIERE EL 9502', numero: '9502'),
        throwsA(isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)
            .having((e) => e.mensaje, 'mensaje',
                contains('ZZZ FED DUENA DEL 9502'))),
      );
    });

    test('conservar el número propio al editar no es conflicto', () async {
      final f = await federacion('ZZZ FED EDITABLE', numero: '9503');

      final editada = await padron.federaciones.actualizar(
        f.id,
        FederacionRequest(nombre: 'ZZZ FED EDITADA', numero: '9503'),
      );

      expect(editada.nombre, 'ZZZ FED EDITADA');
      expect(editada.numero, '9503');
    });

    test('se le puede quitar el número', () async {
      final f = await federacion('ZZZ FED PIERDE NUMERO', numero: '9504');

      final sinNumero = await padron.federaciones.actualizar(
        f.id,
        FederacionRequest(nombre: f.nombre),
      );

      expect(sinNumero.numero, isNull);
      // Y el número queda libre para otra.
      final otra = await federacion('ZZZ FED HEREDA EL 9504', numero: '9504');
      expect(otra.numero, '9504');
    });

  });

  group('central', () {
    test('se crea con abreviatura y vuelve con ella', () async {
      final c = await central('ZZZ CON SIGLA', abreviatura: 'ZQA');

      expect(c.abreviatura, 'ZQA');
      expect((await padron.centrales.obtener(c.id)).abreviatura, 'ZQA');
    });

    test('la abreviatura es opcional', () async {
      final c = await central('ZZZ SIN SIGLA');

      expect(c.abreviatura, isNull);
    });

    test('dos sin abreviatura conviven', () async {
      // La clave única admite varios NULL. Si no fuera así, la segunda alta
      // reventaría acá y la mayoría de las centrales no se podrían cargar.
      await central('ZZZ SIN SIGLA 2');
      await central('ZZZ SIN SIGLA 3');
    });

    test('una abreviatura vacía se guarda como sin abreviatura', () async {
      final c = await central('ZZZ SIGLA VACIA', abreviatura: '   ');

      expect(c.abreviatura, isNull);
    });

    test('se guarda en mayúsculas aunque llegue en minúsculas', () async {
      final c = await central('ZZZ SIGLA MINUSCULA', abreviatura: 'zqb');

      expect(c.abreviatura, 'ZQB');
    });

    test('repetir la abreviatura se rechaza diciendo quién la tiene', () async {
      await central('ZZZ DUENA DE ZQC', abreviatura: 'ZQC');

      await expectLater(
        central('ZZZ QUIERE ZQC', abreviatura: 'ZQC'),
        throwsA(isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)
            .having((e) => e.mensaje, 'mensaje',
                contains('ZZZ DUENA DE ZQC'))),
      );
    });

    test('cambiarle la caja no la vuelve otra abreviatura', () async {
      // Es lo que justifica pasar a mayúsculas en el servidor: si "zqd" y "ZQD"
      // entraran como dos siglas distintas, la unicidad no significaría nada.
      await central('ZZZ DUENA DE ZQD', abreviatura: 'ZQD');

      await expectLater(
        central('ZZZ QUIERE ZQD', abreviatura: 'zqd'),
        throwsA(isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)),
      );
    });

    test('con menos de tres caracteres se rechaza', () async {
      await expectLater(
        central('ZZZ SIGLA CORTA', abreviatura: 'ZQ'),
        throwsA(isA<ApiException>()),
      );
    });

    test('acepta números: la sigla de 1RO DE MAYO es 1MO', () async {
      final c = await central('ZZZ SIGLA CON DIGITO', abreviatura: 'Z1A');

      expect(c.abreviatura, 'Z1A');
    });

    test('con signos se rechaza', () async {
      await expectLater(
        central('ZZZ SIGLA CON SIGNO', abreviatura: 'Z-A'),
        throwsA(isA<ApiException>()),
      );
    });

    test('conservar la abreviatura propia al editar no es conflicto', () async {
      final c = await central('ZZZ EDITABLE', abreviatura: 'ZQE');

      final editada = await padron.centrales.actualizar(
        c.id,
        CentralRequest(
          nombre: 'ZZZ EDITADA',
          abreviatura: 'ZQE',
          federacionId: federacionId,
        ),
      );

      expect(editada.nombre, 'ZZZ EDITADA');
      expect(editada.abreviatura, 'ZQE');
    });

    test('se le puede quitar la abreviatura', () async {
      final c = await central('ZZZ PIERDE SIGLA', abreviatura: 'ZQF');

      final sinSigla = await padron.centrales.actualizar(
        c.id,
        CentralRequest(nombre: c.nombre, federacionId: federacionId),
      );

      expect(sinSigla.abreviatura, isNull);
      // Y la sigla queda libre para otra.
      final otra = await central('ZZZ HEREDA ZQF', abreviatura: 'ZQF');
      expect(otra.abreviatura, 'ZQF');
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

  });
}
