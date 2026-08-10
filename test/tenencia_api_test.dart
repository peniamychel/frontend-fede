@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Tenencia de lotes y traslado de sistemas, contra el backend real.
///
/// La idea que se verifica acá es la del modelo: **el lote pertenece al
/// sindicato y no se mueve**. Lo que cambia es quién lo tiene, y eso queda
/// como historial en vez de pisar un campo.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/tenencia_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Federacion fed;
  late Central central;
  late Sindicato sindA;
  late Sindicato sindB;
  late Productor ana;
  late Productor bruno;
  late Productor carla;

  final lotes = <int>[];
  final sistemas = <int>[];

  Future<Lote> crearLote(String numero, Sindicato s, {Productor? de}) async {
    final l = await padron.lotes.crear(LoteRequest(
      sindicatoId: s.id,
      productorId: de?.id,
      numero: numero,
    ));
    lotes.add(l.id);
    return l;
  }

  Future<Sistema> crearSistema(String codigo) async {
    final s = await padron.sistemas.crear(SistemaRequest(codigo: codigo));
    sistemas.add(s.id);
    return s;
  }

  setUpAll(() async {
    padron = Padron();
    fed = await padron.federaciones
        .crear(const FederacionRequest(nombre: 'ZZZ FED TENENCIA'));
    central = await padron.centrales
        .crear(CentralRequest(nombre: 'ZZZ CEN T', federacionId: fed.id));
    sindA = await padron.sindicatos
        .crear(SindicatoRequest(nombre: 'ZZZ SIN TA', centralId: central.id));
    sindB = await padron.sindicatos
        .crear(SindicatoRequest(nombre: 'ZZZ SIN TB', centralId: central.id));

    ana = await padron.productores.crear(ProductorRequest(
        nombres: 'ZZZ ANA', apellidos: 'TENENCIA', sindicatoId: sindA.id));
    bruno = await padron.productores.crear(ProductorRequest(
        nombres: 'ZZZ BRUNO', apellidos: 'TENENCIA', sindicatoId: sindA.id));
    carla = await padron.productores.crear(ProductorRequest(
        nombres: 'ZZZ CARLA', apellidos: 'TENENCIA', sindicatoId: sindB.id));
  });

  tearDownAll(() async {
    for (final id in sistemas) {
      try {
        await padron.sistemas
            .trasladar(id, null, const TraspasoRequest(motivo: MotivoTraspaso.otro));
      } on ApiException {
        // Ya estaba retirado.
      }
      await padron.sistemas.eliminar(id);
    }
    for (final id in lotes) {
      try {
        await padron.lotes
            .traspasar(id, const TraspasoRequest(motivo: MotivoTraspaso.otro));
      } on ApiException {
        // Ya estaba sin tenedor.
      }
      await padron.lotes.eliminar(id);
    }
    for (final p in [ana, bruno, carla]) {
      await padron.productores.eliminar(p.id);
    }
    for (final s in [sindA, sindB]) {
      await padron.sindicatos.eliminar(s.id);
    }
    await padron.centrales.eliminar(central.id);
    await padron.federaciones.eliminar(fed.id);
  });

  group('el lote pertenece al sindicato', () {
    test('nace en el sindicato, con o sin tenedor', () async {
      final conDuenio = await crearLote('101', sindA, de: ana);
      final sinDuenio = await crearLote('102', sindA);

      expect(conDuenio.sindicatoId, sindA.id);
      expect(conDuenio.tenedor?.productorId, ana.id);

      // Un lote sin tenedor no es un error: la parcela existe igual, y es
      // preferible tenerla registrada a no tenerla.
      expect(sinDuenio.sindicatoId, sindA.id);
      expect(sinDuenio.tenedor, isNull);
    });

    test('el listado por sindicato trae los lotes aunque nadie los tenga',
        () async {
      final huerfano = await crearLote('103', sindA);

      final delSindicato = await padron.lotes.listar(sindicatoId: sindA.id);

      expect(delSindicato.map((l) => l.id), contains(huerfano.id));
    });

    test('un lote no se muda de sindicato', () async {
      final lote = await crearLote('104', sindA);

      await expectLater(
        padron.lotes.actualizar(
            lote.id, LoteRequest(sindicatoId: sindB.id, numero: '104')),
        throwsA(isA<ApiException>().having(
            (e) => e.mensaje, 'mensaje', contains('no se muda de sindicato'))),
      );
    });
  });

  group('traspaso', () {
    test('cambia de manos y el anterior queda en el historial', () async {
      final lote = await crearLote('201', sindA, de: ana);

      final traspasado = await padron.lotes.traspasar(
        lote.id,
        TraspasoRequest(
          productorId: bruno.id,
          motivo: MotivoTraspaso.venta,
          observaciones: 'Acta 12/2026',
        ),
      );

      expect(traspasado.tenedor?.productorId, bruno.id);

      final historial = await padron.lotes.historial(lote.id);
      expect(historial, hasLength(2));
      expect(historial.first.conQuienId, bruno.id);
      expect(historial.first.vigente, isTrue);
      expect(historial.last.conQuienId, ana.id);
      expect(historial.last.vigente, isFalse);
      expect(historial.last.motivo, MotivoTraspaso.venta);
    });

    test('un período no puede terminar antes de empezar', () async {
      // Traspasar el mismo día en que empezó la tenencia. Cerrar "el día
      // anterior" retrocedería antes del inicio y el período quedaría al revés.
      final lote = await crearLote('202', sindA, de: ana);

      await padron.lotes.traspasar(lote.id,
          TraspasoRequest(productorId: bruno.id, motivo: MotivoTraspaso.correccion));

      final cerrado = (await padron.lotes.historial(lote.id))
          .firstWhere((t) => !t.vigente);
      expect(cerrado.hasta, isNotNull);
      expect(cerrado.hasta!.isBefore(cerrado.desde), isFalse,
          reason: 'el período tiene que cerrar el mismo día que abrió, no antes');
    });

    test('se puede dejar sin tenedor', () async {
      // Pasa de verdad: alguien vendió y el comprador todavía no está cargado.
      final lote = await crearLote('203', sindA, de: ana);

      final libre = await padron.lotes.traspasar(
          lote.id, const TraspasoRequest(motivo: MotivoTraspaso.venta));

      expect(libre.tenedor, isNull);
      expect((await padron.lotes.historial(lote.id)).every((t) => !t.vigente),
          isTrue);
    });

    test('el tenedor tiene que ser del mismo sindicato que la tierra', () async {
      final lote = await crearLote('204', sindA, de: ana);

      await expectLater(
        padron.lotes.traspasar(lote.id,
            TraspasoRequest(productorId: carla.id, motivo: MotivoTraspaso.venta)),
        throwsA(isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)
            .having((e) => e.mensaje, 'mensaje', contains('ZZZ SIN TB'))),
      );
    });

    test('pasárselo a quien ya lo tiene se rechaza', () async {
      final lote = await crearLote('205', sindA, de: ana);

      await expectLater(
        padron.lotes.traspasar(lote.id,
            TraspasoRequest(productorId: ana.id, motivo: MotivoTraspaso.venta)),
        throwsA(isA<ApiException>()
            .having((e) => e.mensaje, 'mensaje', contains('ya está a nombre'))),
      );
    });
  });

  group('el productor no se lleva la tierra', () {
    test('no se puede borrar a alguien que tiene lotes', () async {
      final suyo = await padron.productores.crear(ProductorRequest(
          nombres: 'ZZZ DIEGO', apellidos: 'TENENCIA', sindicatoId: sindA.id));
      final lote = await crearLote('301', sindA, de: suyo);

      await expectLater(
        padron.productores.eliminar(suyo.id),
        throwsA(isA<ApiException>()
            .having((e) => e.mensaje, 'mensaje', contains('lote(s) a su nombre'))),
      );

      // Y una vez traspasado, el lote sigue existiendo y el productor se borra.
      await padron.lotes.traspasar(lote.id,
          TraspasoRequest(productorId: ana.id, motivo: MotivoTraspaso.venta));
      await padron.productores.eliminar(suyo.id);

      final sobrevive = await padron.lotes.obtener(lote.id);
      expect(sobrevive.sindicatoId, sindA.id);
      expect(sobrevive.tenedor?.productorId, ana.id);
    });

    test('la ficha del productor muestra solo los lotes que tiene hoy',
        () async {
      final lote = await crearLote('302', sindA, de: ana);
      await padron.lotes.traspasar(lote.id,
          TraspasoRequest(productorId: bruno.id, motivo: MotivoTraspaso.venta));

      final deAna = await padron.productores.obtener(ana.id);
      expect(deAna.lotes.map((l) => l.id), isNot(contains(lote.id)));

      final deBruno = await padron.productores.obtener(bruno.id);
      expect(deBruno.lotes.map((l) => l.id), contains(lote.id));
    });
  });

  group('sistemas', () {
    test('se instala en un lote y se traslada a otro', () async {
      final sistema = await crearSistema('ZZZ-T1');
      final origen = await crearLote('401', sindA, de: ana);
      final destino = await crearLote('402', sindA, de: bruno);

      final instalado = await padron.sistemas.trasladar(sistema.id, origen.id,
          const TraspasoRequest(motivo: MotivoTraspaso.otro));
      expect(instalado.lote?.loteId, origen.id);
      expect(instalado.lote?.tenedor, contains('ANA'));

      final movido = await padron.sistemas.trasladar(sistema.id, destino.id,
          const TraspasoRequest(motivo: MotivoTraspaso.venta));
      expect(movido.lote?.loteId, destino.id);

      final historial = await padron.sistemas.historial(sistema.id);
      expect(historial, hasLength(2));
      expect(historial.first.conQuienId, destino.id);
      expect(historial.last.conQuienId, origen.id);
      expect(historial.last.vigente, isFalse);
    });

    test('un lote lleva un solo sistema', () async {
      final uno = await crearSistema('ZZZ-T2');
      final otro = await crearSistema('ZZZ-T3');
      final lote = await crearLote('403', sindA, de: ana);

      await padron.sistemas.trasladar(
          uno.id, lote.id, const TraspasoRequest(motivo: MotivoTraspaso.otro));

      await expectLater(
        padron.sistemas.trasladar(
            otro.id, lote.id, const TraspasoRequest(motivo: MotivoTraspaso.otro)),
        throwsA(isA<ApiException>()
            .having((e) => e.mensaje, 'mensaje', contains('un solo sistema'))),
      );
    });

    test('el lote sabe qué sistema tiene', () async {
      final sistema = await crearSistema('ZZZ-T4');
      final lote = await crearLote('404', sindA, de: ana);

      await padron.sistemas.trasladar(sistema.id, lote.id,
          const TraspasoRequest(motivo: MotivoTraspaso.otro));

      final conSistema = await padron.lotes.obtener(lote.id);
      expect(conSistema.tieneSistema, isTrue);
      expect(conSistema.sistema?.codigo, 'ZZZ-T4');
    });

    test('no se puede borrar un lote con un sistema puesto', () async {
      final sistema = await crearSistema('ZZZ-T5');
      final lote = await crearLote('405', sindA, de: ana);
      await padron.sistemas.trasladar(sistema.id, lote.id,
          const TraspasoRequest(motivo: MotivoTraspaso.otro));

      await expectLater(
        padron.lotes.eliminar(lote.id),
        throwsA(isA<ApiException>()
            .having((e) => e.mensaje, 'mensaje', contains('tiene un sistema'))),
      );
    });

    test('el código no se repite', () async {
      await crearSistema('ZZZ-T6');

      await expectLater(
        padron.sistemas.crear(const SistemaRequest(codigo: 'ZZZ-T6')),
        throwsA(isA<ApiException>()
            .having((e) => e.mensaje, 'mensaje', contains('Ya hay un sistema'))),
      );
    });

    test('los disponibles son los que no están en ningún lote', () async {
      final suelto = await crearSistema('ZZZ-T7');
      final puesto = await crearSistema('ZZZ-T8');
      final lote = await crearLote('406', sindA, de: ana);
      await padron.sistemas.trasladar(puesto.id, lote.id,
          const TraspasoRequest(motivo: MotivoTraspaso.otro));

      final disponibles = await padron.sistemas.listar(disponibles: true);

      expect(disponibles.map((s) => s.id), contains(suelto.id));
      expect(disponibles.map((s) => s.id), isNot(contains(puesto.id)));
    });
  });
}
