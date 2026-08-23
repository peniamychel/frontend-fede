@Tags(['integracion'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:fede/repositories/padron.dart';

/// Vetos decididos en asamblea, contra el backend real.
///
/// Lo que se fija acá son las reglas que hacen que un veto sea una decisión y
/// no una anotación: hace falta una reunión, esa reunión tiene que tener su
/// acta subida, hay que decir el motivo, y levantarlo se decide en **otra**
/// reunión. Mientras el veto rige, la credencial no se emite.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/veto_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Uint8List acta;

  late Federacion fede;
  late Central central;
  late Sindicato sindicato;
  late Productor productor;
  late Reunion asamblea;
  late Reunion otraAsamblea;

  /// Las que crea alguna prueba suelta, para borrarlas al final.
  final otras = <Reunion>[];

  Future<Reunion> crearReunion(
    String titulo,
    String fecha, {
    bool vetos = true,
  }) => padron.reuniones.crear(
    ReunionRequest(
      tipo: TipoReunion.sindicato,
      titulo: titulo,
      fecha: DateTime.parse(fecha),
      convocanteId: sindicato.id,
      vetosHabilitados: vetos,
    ),
  );

  /// El acta va siempre con su número: es lo que permite volver al libro.
  Future<Reunion> conActa(Reunion r) => padron.reuniones.agregarHoja(
    reunionId: r.id,
    bytes: acta,
    nombreArchivo: 'acta.pdf',
    codigo: 'ZZZ-ACTA-${r.id}',
  );

  setUpAll(() async {
    padron = Padron();
    // Un PDF mínimo pero válido: lo que importa es que el servidor lo acepte
    // como documento y no lo trate como imagen.
    acta = Uint8List.fromList(
      '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n'
          .codeUnits,
    );

    // Con número y sigla a propósito: sin ellos el productor no tiene código
    // del padrón, que es una de las formas en que se lo busca para vetarlo.
    fede = await padron.federaciones.crear(
      const FederacionRequest(nombre: 'ZZZ VETO FED', numero: '88'),
    );
    central = await padron.centrales.crear(
      CentralRequest(
        nombre: 'ZZZ VETO CEN',
        abreviatura: 'VET',
        federacionId: fede.id,
      ),
    );
    sindicato = await padron.sindicatos.crear(
      SindicatoRequest(nombre: 'ZZZ VETO SIN', centralId: central.id),
    );
    productor = await padron.productores.crear(
      ProductorRequest(
        nombres: 'ZZZ OBSERVADO',
        apellidos: 'PRUEBA',
        ci: '99887766',
        sindicatoId: sindicato.id,
      ),
    );

    asamblea = await crearReunion('ZZZ ASAMBLEA QUE VETA', '2026-03-12');
    otraAsamblea = await crearReunion('ZZZ ASAMBLEA QUE LEVANTA', '2026-06-20');
  });

  tearDownAll(() async {
    // El productor primero: sus vetos se van con él por cascada, y recién
    // entonces las reuniones quedan libres para borrarse.
    try {
      await padron.productores.eliminar(productor.id);
    } on ApiException {
      // Ya no estaba.
    }
    for (final r in [asamblea, otraAsamblea, ...otras]) {
      try {
        await padron.reuniones.eliminar(r.id);
      } on ApiException {
        // Ídem.
      }
    }
    try {
      await padron.sindicatos.eliminar(sindicato.id);
      await padron.centrales.eliminar(central.id);
      await padron.federaciones.eliminar(fede.id);
    } on ApiException {
      // Lo importante ya se limpió.
    } finally {
      padron.cerrar();
    }
  });

  test('una reunión no habilitada para vetar no veta, ni con acta', () async {
    // No toda asamblea es para sancionar: la mayoría es informativa, y
    // ofrecer el veto en todas invita a usarlo donde no corresponde.
    final informativa = await crearReunion(
      'ZZZ ASAMBLEA INFORMATIVA',
      '2026-02-01',
      vetos: false,
    );
    otras.add(informativa);
    await conActa(informativa);

    await expectLater(
      padron.vetos.vetar(
        VetoRequest(
          productorId: productor.id,
          reunionId: informativa.id,
          motivo: 'Vendió fuera del cupo',
        ),
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)
            .having(
              (e) => e.mensaje,
              'mensaje',
              contains('no está habilitada'),
            ),
      ),
    );
  });

  test('sin acta no se puede vetar', () async {
    expect(asamblea.tieneActa, isFalse, reason: 'todavía no se subió');
    expect(asamblea.vetosHabilitados, isTrue, reason: 'esta sí puede vetar');

    await expectLater(
      padron.vetos.vetar(
        VetoRequest(
          productorId: productor.id,
          reunionId: asamblea.id,
          motivo: 'Vendió fuera del cupo',
        ),
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)
            .having((e) => e.mensaje, 'mensaje', contains('acta')),
      ),
    );
  });

  test('con el acta subida, el veto se registra', () async {
    final conDocumento = await conActa(asamblea);
    expect(conDocumento.tieneActa, isTrue);
    expect(conDocumento.hojasActa.single.orden, 1);

    final veto = await padron.vetos.vetar(
      VetoRequest(
        productorId: productor.id,
        reunionId: asamblea.id,
        motivo: 'Vendió fuera del cupo autorizado, según el acta',
      ),
    );

    expect(veto.vigente, isTrue);
    expect(veto.motivo, contains('cupo'));
    expect(veto.reunion?.titulo, 'ZZZ ASAMBLEA QUE VETA');
    // Se lo puede reconocer con cualquiera de los tres identificadores.
    expect(veto.ci, '99887766');
    expect(veto.codigo, isNotNull);
  });

  test('mientras rige, la credencial no se emite', () async {
    final previa = await padron.productores.previaCredencial(productor.id);

    expect(previa.completa, isFalse);
    expect(previa.bloqueo, isNotNull);
    expect(previa.bloqueo!.motivo, contains('cupo'));
    expect(previa.bloqueo!.reunion, 'ZZZ ASAMBLEA QUE VETA');

    final respuesta = await http.get(
      padron.productores.urlCredencial(productor.id),
    );
    expect(respuesta.statusCode, 409);
    expect(respuesta.body, contains('observado'));
  });

  group('mientras rige, no hace nada en la organización', () {
    test('no se le puede dar un cargo', () async {
      await expectLater(
        padron.directorios.asignar(
          ambito: Ambito.sindicato,
          id: sindicato.id,
          cargo: TipoCargo.secretarioGeneral,
          productorId: productor.id,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.esConflicto, 'esConflicto', isTrue)
              .having((e) => e.mensaje, 'mensaje', contains('está observado'))
              .having(
                (e) => e.mensaje,
                'mensaje',
                contains('no puede ocupar un cargo'),
              ),
        ),
      );
    });

    test('ni aparece entre los candidatos del directorio', () async {
      // Ofrecerlo sería invitar a elegir a alguien que el servidor va a
      // rechazar, y peor, a discutirlo en la reunión antes de descubrirlo.
      final candidatos = await padron.directorios.candidatos(
        Ambito.sindicato,
        sindicato.id,
      );

      expect(candidatos.map((c) => c.id), isNot(contains(productor.id)));
    });

    test('no se le toma asistencia ni cuenta para el quórum', () async {
      final reunion = await crearReunion(
        'ZZZ ASAMBLEA CON LISTA',
        '2026-04-10',
      );
      otras.add(reunion);
      final llamada = await padron.reuniones.abrirLlamada(reunion.id);

      final codigo = (await padron.productores.obtener(
        productor.id,
      )).productor.codigo!;
      await expectLater(
        padron.reuniones.registrar(llamada.id, codigo),
        throwsA(
          isA<ApiException>()
              .having((e) => e.esConflicto, 'esConflicto', isTrue)
              .having((e) => e.mensaje, 'mensaje', contains('está observado'))
              .having((e) => e.mensaje, 'mensaje', contains('quórum')),
        ),
      );

      // Tampoco figura en la lista: no es un convocado que faltó, es alguien
      // que está suspendido de sus derechos.
      final lista = await padron.reuniones.lista(llamada.id);
      expect(lista.map((c) => c.productorId), isNot(contains(productor.id)));
      expect((await padron.reuniones.obtener(reunion.id)).convocados, 0);
    });

    test('y si ya tenía un cargo, lo deja al quedar observado', () async {
      // La asamblea que suspende a alguien de sus derechos no lo deja al
      // frente del sindicato. No se resuelve rechazando el veto: el veto ya se
      // decidió en la reunión, el sistema registra lo que pasó.
      final dirigente = await padron.productores.crear(
        ProductorRequest(
          nombres: 'ZZZ PRESIDENTE',
          apellidos: 'VETADO',
          ci: '11223399',
          sindicatoId: sindicato.id,
        ),
      );

      await padron.directorios.asignar(
        ambito: Ambito.sindicato,
        id: sindicato.id,
        cargo: TipoCargo.secretarioGeneral,
        productorId: dirigente.id,
      );
      final antes = await padron.directorios.obtener(
        Ambito.sindicato,
        sindicato.id,
      );
      expect(
        antes.cargoDe(TipoCargo.secretarioGeneral)?.productorId,
        dirigente.id,
      );

      await padron.vetos.vetar(
        VetoRequest(
          productorId: dirigente.id,
          reunionId: asamblea.id,
          motivo: 'Usó el cargo para su propio beneficio, según el acta',
        ),
      );

      final despues = await padron.directorios.obtener(
        Ambito.sindicato,
        sindicato.id,
      );
      expect(
        despues.cargoDe(TipoCargo.secretarioGeneral),
        isNull,
        reason:
            'el sindicato queda sin Secretario General hasta que nombren a otro',
      );

      // El período no se borra: queda en el historial con su fecha de cierre.
      final historial = await padron.directorios.historial(
        Ambito.sindicato,
        sindicato.id,
      );
      final suyo = historial.firstWhere((c) => c.productorId == dirigente.id);
      expect(suyo.hasta, isNotNull);

      await padron.productores.eliminar(dirigente.id);
    });
  });

  test('se lo encuentra por cédula, por código y por sindicato', () async {
    expect(
      (await padron.vetos.buscar(texto: '99887766')).single.productorNombre,
      contains('ZZZ OBSERVADO'),
    );

    final porCodigo = await padron.vetos.buscar(
      texto: (await padron.vetos.buscar(texto: '99887766')).single.codigo,
    );
    expect(porCodigo.single.productorId, productor.id);

    expect(
      (await padron.vetos.buscar(texto: 'OBSERVADO')).single.productorId,
      productor.id,
    );
    expect((await padron.vetos.buscar(sindicatoId: sindicato.id)).length, 1);
  });

  test('y también por el código del padrón, igual que en el listado', () async {
    // Quien va a levantar un veto en la asamblea busca a la persona igual que
    // quien la vetó: tener dos búsquedas distintas para el mismo acto sería
    // una trampa.
    final codigo = (await padron.productores.obtener(
      productor.id,
    )).productor.codigoPadron;
    expect(codigo, isNotNull, reason: 'la central de la prueba tiene sigla');

    expect(
      (await padron.vetos.buscar(texto: codigo)).single.productorId,
      productor.id,
    );
  });

  test('la reunión muestra el veto que impuso', () async {
    final decididos = await padron.vetos.deLaReunion(asamblea.id);

    expect(decididos, hasLength(1));
    expect(decididos.single.reunion?.id, asamblea.id);
    expect(decididos.single.reunionLevanta, isNull, reason: 'todavía rige');
  });

  test('no se lo puede vetar dos veces', () async {
    await expectLater(
      padron.vetos.vetar(
        VetoRequest(
          productorId: productor.id,
          reunionId: asamblea.id,
          motivo: 'otro motivo',
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('ya está vetado'),
        ),
      ),
    );
  });

  test('levantarlo en la misma reunión que lo vetó se rechaza', () async {
    final veto = (await padron.vetos.historialDe(productor.id)).first;

    await expectLater(
      padron.vetos.levantar(
        veto.id,
        LevantarVetoRequest(reunionId: asamblea.id, motivo: 'me arrepentí'),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('otra reunión'),
        ),
      ),
    );
  });

  test('y la otra reunión también necesita su acta', () async {
    final veto = (await padron.vetos.historialDe(productor.id)).first;

    await expectLater(
      padron.vetos.levantar(
        veto.id,
        LevantarVetoRequest(
          reunionId: otraAsamblea.id,
          motivo: 'cumplió la sanción',
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('acta'),
        ),
      ),
    );
  });

  test(
    'con acta y en otra reunión, sale de la lista y recupera la credencial',
    () async {
      await conActa(otraAsamblea);
      final veto = (await padron.vetos.historialDe(productor.id)).first;

      final levantado = await padron.vetos.levantar(
        veto.id,
        LevantarVetoRequest(
          reunionId: otraAsamblea.id,
          motivo: 'Cumplió la sanción y regularizó, según el acta',
        ),
      );

      expect(levantado.vigente, isFalse);
      expect(levantado.hasta, isNotNull);
      expect(levantado.reunionLevanta?.titulo, 'ZZZ ASAMBLEA QUE LEVANTA');

      // El veto no se borra: queda cerrado, con las dos decisiones a la vista.
      final historial = await padron.vetos.historialDe(productor.id);
      expect(historial, hasLength(1));
      expect(historial.single.motivo, contains('cupo'));
      expect(historial.single.motivoLevantamiento, contains('Cumplió'));

      // Y la credencial se destraba.
      final previa = await padron.productores.previaCredencial(productor.id);
      expect(previa.bloqueo, isNull);
    },
  );

  test('ya no aparece entre los vigentes, pero sí en el historial', () async {
    expect(await padron.vetos.buscar(texto: '99887766'), isEmpty);
    expect(
      await padron.vetos.buscar(texto: '99887766', vigentes: false),
      hasLength(1),
    );
  });

  test(
    'cada reunión muestra lo que decidió, en la dirección que fue',
    () async {
      // En una asamblea se ponen y se quitan vetos, a veces en la misma sesión.
      // Las dos cosas son decisiones de esa reunión y las dos tienen que verse
      // ahí, o la que levantó parecería no haber hecho nada.
      final enLaQueVeto = await padron.vetos.deLaReunion(asamblea.id);
      expect(enLaQueVeto, hasLength(1));
      expect(enLaQueVeto.single.reunion?.id, asamblea.id);

      final enLaQueLevanto = await padron.vetos.deLaReunion(otraAsamblea.id);
      expect(enLaQueLevanto, hasLength(1));
      expect(enLaQueLevanto.single.reunionLevanta?.id, otraAsamblea.id);
      expect(
        enLaQueLevanto.single.reunion?.id,
        asamblea.id,
        reason: 'es el mismo veto, visto desde la reunión que lo cerró',
      );
    },
  );

  test('a la que levantó tampoco se le puede apagar el veto', () async {
    // El acta que respalda un levantamiento hace la misma falta que la que
    // respalda un veto.
    final actual = await padron.reuniones.obtener(otraAsamblea.id);

    await expectLater(
      padron.reuniones.actualizar(
        otraAsamblea.id,
        ReunionRequest.desde(actual, vetosHabilitados: false),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.mensaje,
          'mensaje',
          contains('se decidieron'),
        ),
      ),
    );
  });

  test(
    'la última hoja del acta de una reunión que vetó no se puede quitar',
    () async {
      final hoja = (await padron.reuniones.obtener(
        asamblea.id,
      )).hojasActa.single;

      await expectLater(
        padron.reuniones.quitarHoja(asamblea.id, hoja.id),
        throwsA(
          isA<ApiException>()
              .having((e) => e.esConflicto, 'esConflicto', isTrue)
              .having((e) => e.mensaje, 'mensaje', contains('última hoja'))
              .having((e) => e.mensaje, 'mensaje', contains('sin respaldo')),
        ),
      );
    },
  );

  test('tampoco se le pueden apagar los vetos', () async {
    // Apagarlos dejaría al veto colgando de una asamblea que, según el
    // sistema, no podía decidirlo.
    final actual = await padron.reuniones.obtener(asamblea.id);

    await expectLater(
      padron.reuniones.actualizar(
        asamblea.id,
        ReunionRequest.desde(actual, vetosHabilitados: false),
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.esConflicto, 'esConflicto', isTrue)
            .having((e) => e.mensaje, 'mensaje', contains('se decidieron')),
      ),
    );
  });
}
