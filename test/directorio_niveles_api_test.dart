@Tags(['integracion'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Directorios de central y federación, contra el backend real.
///
/// Se monta una federación entera desechable —dos centrales, tres sindicatos,
/// cinco productores— y se borra al final. No se toca nada del padrón real,
/// ni siquiera la federación.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/directorio_niveles_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Federacion fed;
  late Central centralA;
  late Central centralB;
  late Sindicato sindA1;
  late Sindicato sindA2;
  late Sindicato sindB1;

  /// ANA y BRUNO en A1, CARLA y DIEGO en A2, ELENA en B1.
  late Productor ana;
  late Productor bruno;
  late Productor carla;
  late Productor diego;
  late Productor elena;

  late Uint8List firma;

  Future<Productor> crear(String nombres, Sindicato sindicato) =>
      padron.productores.crear(
        ProductorRequest(
          nombres: nombres,
          apellidos: 'DEL DIRECTORIO',
          sindicatoId: sindicato.id,
        ),
      );

  setUpAll(() async {
    padron = Padron();
    firma = File('test/fixtures/foto-grande.jpg').readAsBytesSync();

    fed = await padron.federaciones.crear(
      const FederacionRequest(nombre: 'ZZZ FED NIVELES'),
    );
    centralA = await padron.centrales.crear(
      CentralRequest(nombre: 'ZZZ CEN A', federacionId: fed.id),
    );
    centralB = await padron.centrales.crear(
      CentralRequest(nombre: 'ZZZ CEN B', federacionId: fed.id),
    );
    sindA1 = await padron.sindicatos.crear(
      SindicatoRequest(nombre: 'ZZZ SIN A1', centralId: centralA.id),
    );
    sindA2 = await padron.sindicatos.crear(
      SindicatoRequest(nombre: 'ZZZ SIN A2', centralId: centralA.id),
    );
    sindB1 = await padron.sindicatos.crear(
      SindicatoRequest(nombre: 'ZZZ SIN B1', centralId: centralB.id),
    );

    ana = await crear('ZZZ ANA', sindA1);
    bruno = await crear('ZZZ BRUNO', sindA1);
    carla = await crear('ZZZ CARLA', sindA2);
    diego = await crear('ZZZ DIEGO', sindA2);
    elena = await crear('ZZZ ELENA', sindB1);
  });

  /// Cada prueba arranca con los tres directorios vacíos: son un recurso
  /// compartido y sin esto una prueba heredaría lo que dejó la anterior.
  setUp(() async {
    for (final (ambito, id) in [
      (Ambito.federacion, fed.id),
      (Ambito.central, centralA.id),
      (Ambito.central, centralB.id),
      (Ambito.sindicato, sindA1.id),
      (Ambito.sindicato, sindA2.id),
      (Ambito.sindicato, sindB1.id),
    ]) {
      for (final cargo in TipoCargo.vigentes) {
        try {
          await padron.directorios.terminar(
            ambito: ambito,
            id: id,
            cargo: cargo,
          );
        } on ApiException {
          // Vacante o no existe en ese nivel: es lo que se quería.
        }
      }
    }
  });

  tearDownAll(() async {
    for (final p in [ana, bruno, carla, diego, elena]) {
      await padron.productores.eliminar(p.id);
    }
    for (final s in [sindA1, sindA2, sindB1]) {
      await padron.sindicatos.eliminar(s.id);
    }
    for (final c in [centralA, centralB]) {
      await padron.centrales.eliminar(c.id);
    }
    await padron.federaciones.eliminar(fed.id);
  });

  group('cargos de cada nivel', () {
    test(
      'sindicato y central tienen cuatro cargos y la federación cinco',
      () async {
        final s = await padron.directorios.obtener(Ambito.sindicato, sindA1.id);
        final c = await padron.directorios.obtener(Ambito.central, centralA.id);
        final f = await padron.directorios.obtener(Ambito.federacion, fed.id);

        expect(s.puestos.map((p) => p.cargo), [
          TipoCargo.secretarioGeneral,
          TipoCargo.secretarioRelaciones,
          TipoCargo.haciendas,
          TipoCargo.vocal,
        ]);
        expect(c.puestos.map((p) => p.cargo), [
          TipoCargo.secretarioGeneral,
          TipoCargo.secretarioRelaciones,
          TipoCargo.haciendas,
          TipoCargo.vocal,
        ]);
        expect(f.puestos.map((p) => p.cargo), [
          TipoCargo.ejecutivo,
          TipoCargo.secretarioGeneral,
          TipoCargo.secretarioRelaciones,
          TipoCargo.haciendas,
          TipoCargo.vocal,
        ]);
      },
    );

    test('en federación firma únicamente el Ejecutivo', () async {
      final f = await padron.directorios.obtener(Ambito.federacion, fed.id);

      expect(f.puestoDe(TipoCargo.ejecutivo)!.puedeFirmar, isTrue);
      expect(f.puestoDe(TipoCargo.secretarioGeneral)!.puedeFirmar, isFalse);
      expect(f.puestoDe(TipoCargo.secretarioRelaciones)!.puedeFirmar, isFalse);
      expect(f.puestoDe(TipoCargo.haciendas)!.puedeFirmar, isFalse);
      expect(f.puestoDe(TipoCargo.vocal)!.puedeFirmar, isFalse);
    });

    test('un cargo que el nivel no admite se rechaza', () async {
      // La central no tiene Ejecutivo, y pedirlo tiene que decirlo con claridad.
      await expectLater(
        padron.directorios.asignar(
          ambito: Ambito.central,
          id: centralA.id,
          cargo: TipoCargo.ejecutivo,
          productorId: ana.id,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.esConflicto, 'esConflicto', isTrue)
              .having(
                (e) => e.mensaje,
                'mensaje',
                contains('no tiene el cargo'),
              ),
        ),
      );
    });
  });

  group('de dónde salen los candidatos', () {
    test('la central toma de todos sus sindicatos', () async {
      final candidatos = await padron.directorios.candidatos(
        Ambito.central,
        centralA.id,
      );

      // Los cuatro de A1 y A2, y ninguno de la central B.
      expect(
        candidatos.map((p) => p.id),
        containsAll([ana.id, bruno.id, carla.id, diego.id]),
      );
      expect(candidatos.map((p) => p.id), isNot(contains(elena.id)));
    });

    test('la federación toma de todas sus centrales', () async {
      final candidatos = await padron.directorios.candidatos(
        Ambito.federacion,
        fed.id,
      );

      expect(
        candidatos.map((p) => p.id),
        containsAll([ana.id, bruno.id, carla.id, diego.id, elena.id]),
      );
    });

    test('el sindicato solo toma de los suyos', () async {
      final candidatos = await padron.directorios.candidatos(
        Ambito.sindicato,
        sindA1.id,
      );

      expect(candidatos.map((p) => p.id), [ana.id, bruno.id]);
    });

    test('alguien de otra central no puede dirigirla', () async {
      await expectLater(
        padron.directorios.asignar(
          ambito: Ambito.central,
          id: centralA.id,
          cargo: TipoCargo.haciendas,
          productorId: elena.id,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('no pertenece'),
          ),
        ),
      );
    });
  });

  group('nadie ocupa dos cargos a la vez', () {
    test('quien preside un sindicato no puede presidir la central', () async {
      await padron.directorios.asignar(
        ambito: Ambito.sindicato,
        id: sindA1.id,
        cargo: TipoCargo.secretarioGeneral,
        productorId: ana.id,
      );

      await expectLater(
        padron.directorios.asignar(
          ambito: Ambito.central,
          id: centralA.id,
          cargo: TipoCargo.secretarioGeneral,
          productorId: ana.id,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.esConflicto, 'esConflicto', isTrue)
              .having(
                (e) => e.mensaje,
                'mensaje',
                contains('Nadie puede ocupar dos cargos'),
              ),
        ),
      );
    });

    test('el mensaje dice qué cargo tiene ocupado', () async {
      await padron.directorios.asignar(
        ambito: Ambito.central,
        id: centralA.id,
        cargo: TipoCargo.haciendas,
        productorId: diego.id,
      );

      // Sin esto habría que salir a buscar dónde está comprometido.
      await expectLater(
        padron.directorios.asignar(
          ambito: Ambito.federacion,
          id: fed.id,
          cargo: TipoCargo.vocal,
          productorId: diego.id,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.mensaje, 'mensaje', contains('haciendas'))
              .having((e) => e.mensaje, 'mensaje', contains('ZZZ CEN A')),
        ),
      );
    });

    test('quien ya ocupa un cargo desaparece de los candidatos', () async {
      await padron.directorios.asignar(
        ambito: Ambito.sindicato,
        id: sindA1.id,
        cargo: TipoCargo.secretarioGeneral,
        productorId: bruno.id,
      );

      final deLaFederacion = await padron.directorios.candidatos(
        Ambito.federacion,
        fed.id,
      );
      expect(deLaFederacion.map((p) => p.id), isNot(contains(bruno.id)));

      // Y vuelve en cuanto queda libre.
      await padron.directorios.terminar(
        ambito: Ambito.sindicato,
        id: sindA1.id,
        cargo: TipoCargo.secretarioGeneral,
      );
      final despues = await padron.directorios.candidatos(
        Ambito.federacion,
        fed.id,
      );
      expect(despues.map((p) => p.id), contains(bruno.id));
    });

    test('liberar el cargo permite asignarle otro', () async {
      await padron.directorios.asignar(
        ambito: Ambito.sindicato,
        id: sindA2.id,
        cargo: TipoCargo.secretarioRelaciones,
        productorId: carla.id,
      );
      await padron.directorios.terminar(
        ambito: Ambito.sindicato,
        id: sindA2.id,
        cargo: TipoCargo.secretarioRelaciones,
      );

      final directorio = await padron.directorios.asignar(
        ambito: Ambito.federacion,
        id: fed.id,
        cargo: TipoCargo.secretarioGeneral,
        productorId: carla.id,
      );

      expect(
        directorio.cargoDe(TipoCargo.secretarioGeneral)!.productorId,
        carla.id,
      );
    });
  });

  group('firmas', () {
    test('el Secretario General de la central puede cargar su firma', () async {
      final directorio = await padron.directorios.asignar(
        ambito: Ambito.central,
        id: centralA.id,
        cargo: TipoCargo.secretarioGeneral,
        productorId: carla.id,
      );
      final cargoId = directorio.cargoDe(TipoCargo.secretarioGeneral)!.id;

      final actualizado = await padron.directorios.subirImagen(
        cargoId: cargoId,
        tipo: TipoImagenCargo.firma,
        bytes: firma,
        nombreArchivo: 'firma.jpg',
      );

      expect(actualizado.firmaUrl, isNotNull);
      await padron.directorios.eliminarImagen(cargoId, TipoImagenCargo.firma);
    });

    test('haciendas y vocal no admiten firma', () async {
      final central = await padron.directorios.asignar(
        ambito: Ambito.central,
        id: centralA.id,
        cargo: TipoCargo.haciendas,
        productorId: diego.id,
      );
      final federacion = await padron.directorios.asignar(
        ambito: Ambito.federacion,
        id: fed.id,
        cargo: TipoCargo.vocal,
        productorId: elena.id,
      );

      for (final cargoId in [
        central.cargoDe(TipoCargo.haciendas)!.id,
        federacion.cargoDe(TipoCargo.vocal)!.id,
      ]) {
        await expectLater(
          padron.directorios.subirImagen(
            cargoId: cargoId,
            tipo: TipoImagenCargo.firma,
            bytes: firma,
            nombreArchivo: 'firma.jpg',
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.esConflicto, 'esConflicto', isTrue)
                .having(
                  (e) => e.mensaje,
                  'mensaje',
                  contains('no lleva firma'),
                ),
          ),
          reason: 'cargo $cargoId',
        );
      }
    });
  });

  group('historial', () {
    test('cada nivel lleva el suyo, sin mezclarse', () async {
      await padron.directorios.asignar(
        ambito: Ambito.central,
        id: centralA.id,
        cargo: TipoCargo.secretarioGeneral,
        productorId: ana.id,
      );
      await padron.directorios.asignar(
        ambito: Ambito.federacion,
        id: fed.id,
        cargo: TipoCargo.secretarioGeneral,
        productorId: bruno.id,
      );

      final deCentral = await padron.directorios.historial(
        Ambito.central,
        centralA.id,
      );
      final deFederacion = await padron.directorios.historial(
        Ambito.federacion,
        fed.id,
      );

      expect(deCentral.map((c) => c.productorId), contains(ana.id));
      expect(deCentral.map((c) => c.productorId), isNot(contains(bruno.id)));
      expect(deFederacion.map((c) => c.productorId), contains(bruno.id));
      expect(deFederacion.every((c) => c.ambito == Ambito.federacion), isTrue);
    });

    test(
      'el historial del productor dice de qué nivel era cada cargo',
      () async {
        await padron.directorios.asignar(
          ambito: Ambito.federacion,
          id: fed.id,
          cargo: TipoCargo.haciendas,
          productorId: elena.id,
        );

        final cargos = await padron.productores.cargos(elena.id);
        final ultimo = cargos.first;

        expect(ultimo.ambito, Ambito.federacion);
        expect(ultimo.ambitoNombre, 'ZZZ FED NIVELES');
        expect(ultimo.cargo, TipoCargo.haciendas);
      },
    );
  });
}
