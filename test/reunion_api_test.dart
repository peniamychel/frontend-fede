@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Reuniones y pase de lista, contra el backend real.
///
/// Se monta una federación desechable con dos centrales, tres sindicatos y
/// seis productores, y se le arma un directorio: ANA preside SIN R1, CARLA
/// SIN R2, ELENA SIN R3, y DIEGO preside la central R1. Con eso se pueden
/// verificar las cuatro convocatorias, que son lo esencial de esto.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/reunion_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Federacion fed;
  late Central centralA;
  late Central centralB;
  late Sindicato sindA1;
  late Sindicato sindA2;
  late Sindicato sindB1;
  late Productor ana;
  late Productor bruno;
  late Productor carla;
  late Productor diego;
  late Productor elena;
  late Productor fabio;

  final reuniones = <int>[];

  Future<Productor> crear(String nombres, Sindicato s) =>
      padron.productores.crear(ProductorRequest(
        nombres: nombres,
        apellidos: 'DE REUNION',
        sindicatoId: s.id,
      ));

  Future<Reunion> convocar(TipoReunion tipo, int convocanteId,
      {String titulo = 'ZZZ REUNION'}) async {
    final r = await padron.reuniones.crear(ReunionRequest(
      tipo: tipo,
      convocanteId: convocanteId,
      titulo: titulo,
      fecha: DateTime.now(),
    ));
    reuniones.add(r.id);
    return r;
  }

  /// El código del QR de alguien, que es lo que devuelve el escáner.
  Future<String> codigoDe(Productor p) async =>
      (await padron.productores.listar(texto: p.nombres))
          .contenido
          .firstWhere((x) => x.id == p.id)
          .codigo!;

  setUpAll(() async {
    padron = Padron();
    fed = await padron.federaciones
        .crear(const FederacionRequest(nombre: 'ZZZ FED REUNIONES'));
    centralA = await padron.centrales
        .crear(CentralRequest(nombre: 'ZZZ CEN RA', federacionId: fed.id));
    centralB = await padron.centrales
        .crear(CentralRequest(nombre: 'ZZZ CEN RB', federacionId: fed.id));
    sindA1 = await padron.sindicatos
        .crear(SindicatoRequest(nombre: 'ZZZ SIN RA1', centralId: centralA.id));
    sindA2 = await padron.sindicatos
        .crear(SindicatoRequest(nombre: 'ZZZ SIN RA2', centralId: centralA.id));
    sindB1 = await padron.sindicatos
        .crear(SindicatoRequest(nombre: 'ZZZ SIN RB1', centralId: centralB.id));

    ana = await crear('ZZZ ANA', sindA1);
    bruno = await crear('ZZZ BRUNO', sindA1);
    carla = await crear('ZZZ CARLA', sindA2);
    diego = await crear('ZZZ DIEGO', sindA2);
    elena = await crear('ZZZ ELENA', sindB1);
    fabio = await crear('ZZZ FABIO', sindB1);

    for (final (ambito, id, productor) in [
      (Ambito.sindicato, sindA1.id, ana),
      (Ambito.sindicato, sindA2.id, carla),
      (Ambito.sindicato, sindB1.id, elena),
      (Ambito.central, centralA.id, diego),
    ]) {
      await padron.directorios.asignar(
        ambito: ambito,
        id: id,
        cargo: TipoCargo.presidente,
        productorId: productor.id,
      );
    }
  });

  tearDownAll(() async {
    for (final id in reuniones) {
      try {
        for (final p in [ana, bruno, carla, diego, elena, fabio]) {
          try {
            await padron.reuniones.quitar(id, p.id);
          } on ApiException {
            // No estaba presente: es lo normal.
          }
        }
        await padron.reuniones.eliminar(id);
      } on ApiException {
        // Ya borrada por una prueba.
      }
    }
    for (final p in [ana, bruno, carla, diego, elena, fabio]) {
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

  group('a quiénes convoca cada tipo', () {
    test('la del sindicato, solo a los suyos', () async {
      final r = await convocar(TipoReunion.sindicato, sindA1.id);
      final lista = await padron.reuniones.lista(r.id);

      expect(lista.map((c) => c.productorId), [ana.id, bruno.id]);
      // Asisten como afiliados, no por un cargo.
      expect(lista.every((c) => c.cargo == null), isTrue);
      expect(r.convocados, 2);
    });

    test('el ampliado, a todos los de la central', () async {
      final r = await convocar(TipoReunion.ampliado, centralA.id);
      final lista = await padron.reuniones.lista(r.id);

      expect(lista.map((c) => c.productorId),
          containsAll([ana.id, bruno.id, carla.id, diego.id]));
      expect(lista.map((c) => c.productorId), isNot(contains(elena.id)));
    });

    test('la de dirigentes de la central, solo a los de sus sindicatos',
        () async {
      final r = await convocar(TipoReunion.dirigentesCentral, centralA.id);
      final lista = await padron.reuniones.lista(r.id);

      // ANA y CARLA presiden sindicatos de la central A. DIEGO preside la
      // central misma, y a esta reunión no va: convoca a los de abajo.
      expect(lista.map((c) => c.productorId), [ana.id, carla.id]);
      expect(lista.every((c) => c.cargo != null), isTrue);
      expect(lista.first.cargo, contains('Presidente'));
    });

    test('la de la federación, a los de las centrales y los sindicatos',
        () async {
      final r = await convocar(TipoReunion.dirigentesFederacion, fed.id);
      final lista = await padron.reuniones.lista(r.id);

      // Los tres presidentes de sindicato más el de la central.
      expect(lista.map((c) => c.productorId),
          containsAll([ana.id, carla.id, elena.id, diego.id]));
      expect(lista, hasLength(4));
      expect(lista.map((c) => c.cargo),
          contains(contains('ZZZ CEN RA')));
    });
  });

  group('pasar lista', () {
    test('escanear registra y devuelve quién es', () async {
      final r = await convocar(TipoReunion.sindicato, sindA1.id);

      final registro =
          await padron.reuniones.registrar(r.id, await codigoDe(ana));

      expect(registro.repetido, isFalse);
      expect(registro.persona.productorId, ana.id);
      expect(registro.presentes, 1);
      expect(registro.convocados, 2);
      expect(registro.mensaje, contains('ZZZ ANA'));
    });

    test('escanear dos veces no cuenta doble ni falla', () async {
      // Quien pasa lista escanea de nuevo por las dudas: necesita que se lo
      // confirmen, no un error.
      final r = await convocar(TipoReunion.sindicato, sindA1.id);
      await padron.reuniones.registrar(r.id, await codigoDe(ana));

      final otra = await padron.reuniones.registrar(r.id, await codigoDe(ana));

      expect(otra.repetido, isTrue);
      expect(otra.presentes, 1);
      expect(otra.mensaje, contains('ya estaba'));
    });

    test('quien no está convocado se rechaza diciendo por qué', () async {
      final r = await convocar(TipoReunion.sindicato, sindA1.id);

      await expectLater(
        padron.reuniones.registrar(r.id, await codigoDe(fabio)),
        throwsA(isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)
            .having((e) => e.mensaje, 'mensaje', contains('no está convocado'))
            .having((e) => e.mensaje, 'mensaje',
                contains('productores del sindicato'))),
      );
    });

    test('un afiliado sin cargo no entra a una de dirigentes', () async {
      final r = await convocar(TipoReunion.dirigentesCentral, centralA.id);

      await expectLater(
        padron.reuniones.registrar(r.id, await codigoDe(bruno)),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje',
            contains('presidentes y secretarios'))),
      );
    });

    test('un código inexistente da 404', () async {
      final r = await convocar(TipoReunion.sindicato, sindA1.id);

      await expectLater(
        padron.reuniones.registrar(r.id, 'NOEXISTE00'),
        throwsA(isA<ApiException>()
            .having((e) => e.esNoEncontrado, 'esNoEncontrado', isTrue)),
      );
    });

    test('el código se acepta con espacios y en minúsculas', () async {
      // Lo que se escribe a mano en el campo, con el teclado del teléfono.
      final r = await convocar(TipoReunion.sindicato, sindA1.id);
      final codigo = await codigoDe(bruno);

      final registro =
          await padron.reuniones.registrar(r.id, '  ${codigo.toLowerCase()} ');

      expect(registro.repetido, isFalse);
      expect(registro.persona.productorId, bruno.id);
    });

    test('la lista marca quién llegó y quién falta', () async {
      final r = await convocar(TipoReunion.sindicato, sindA1.id);
      await padron.reuniones.registrar(r.id, await codigoDe(ana));

      final lista = await padron.reuniones.lista(r.id);
      final deAna = lista.firstWhere((c) => c.productorId == ana.id);
      final deBruno = lista.firstWhere((c) => c.productorId == bruno.id);

      expect(deAna.presente, isTrue);
      expect(deAna.registradaEn, isNotNull);
      expect(deBruno.presente, isFalse);
      expect(deBruno.registradaEn, isNull);
    });

    test('se puede quitar a quien se escaneó por error', () async {
      final r = await convocar(TipoReunion.sindicato, sindA1.id);
      await padron.reuniones.registrar(r.id, await codigoDe(ana));

      await padron.reuniones.quitar(r.id, ana.id);

      expect((await padron.reuniones.obtener(r.id)).presentes, 0);
    });
  });

  group('cierre de la lista', () {
    test('cerrada no admite más registros, y reabrir lo permite otra vez',
        () async {
      final r = await convocar(TipoReunion.sindicato, sindA1.id);
      await padron.reuniones.cambiarCierre(r.id, true);

      await expectLater(
        padron.reuniones.registrar(r.id, await codigoDe(ana)),
        throwsA(isA<ApiException>()
            .having((e) => e.mensaje, 'mensaje', contains('está cerrada'))),
      );

      await padron.reuniones.cambiarCierre(r.id, false);
      final registro =
          await padron.reuniones.registrar(r.id, await codigoDe(ana));
      expect(registro.repetido, isFalse);
    });
  });

  group('la convocatoria no se cambia después', () {
    test('cambiar el tipo o el convocante se rechaza', () async {
      // Cambiarlos cambiaría la lista de convocados, y las asistencias ya
      // tomadas quedarían contra una convocatoria que no las llama.
      final r = await convocar(TipoReunion.sindicato, sindA1.id);

      await expectLater(
        padron.reuniones.actualizar(
          r.id,
          ReunionRequest(
            tipo: TipoReunion.ampliado,
            convocanteId: centralA.id,
            titulo: r.titulo,
            fecha: r.fecha,
          ),
        ),
        throwsA(isA<ApiException>().having((e) => e.mensaje, 'mensaje',
            contains('No se puede cambiar el tipo'))),
      );
    });

    test('el título y el lugar sí se corrigen', () async {
      final r = await convocar(TipoReunion.sindicato, sindA1.id);

      final corregida = await padron.reuniones.actualizar(
        r.id,
        ReunionRequest(
          tipo: r.tipo,
          convocanteId: r.convocanteId,
          titulo: 'ZZZ REUNION CORREGIDA',
          fecha: r.fecha,
          lugar: 'Sede sindical',
        ),
      );

      expect(corregida.titulo, 'ZZZ REUNION CORREGIDA');
      expect(corregida.lugar, 'Sede sindical');
    });

    test('borrar una reunión con asistencias se rechaza', () async {
      final r = await convocar(TipoReunion.sindicato, sindA1.id);
      await padron.reuniones.registrar(r.id, await codigoDe(ana));

      await expectLater(
        padron.reuniones.eliminar(r.id),
        throwsA(isA<ApiException>().having(
            (e) => e.mensaje, 'mensaje', contains('asistencia'))),
      );
    });
  });
}
