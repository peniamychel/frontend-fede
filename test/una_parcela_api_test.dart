@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Nadie puede tener dos parcelas a su nombre al mismo tiempo.
///
/// Es una regla del padrón: la afiliación va atada a una parcela, y con dos la
/// persona contaría dos veces en las nóminas y en los cupos. Se prueba contra
/// el backend porque es ahí donde tiene que vivir: la pantalla evita ofrecer
/// lo que sabe que va a fallar, pero quien decide es el servidor.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/una_parcela_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Federacion fede;
  late Central central;
  late Sindicato sindicato;

  final productores = <int>[];
  final lotes = <int>[];

  Future<Productor> productor(String nombres) async {
    final p = await padron.productores
        .crear(ProductorRequest(nombres: nombres, sindicatoId: sindicato.id));
    productores.add(p.id);
    return p;
  }

  Future<Lote> lote(String numero, {int? productorId}) async {
    final l = await padron.lotes.crear(LoteRequest(
        sindicatoId: sindicato.id, numero: numero, productorId: productorId));
    lotes.add(l.id);
    return l;
  }

  setUpAll(() async {
    padron = Padron();
    fede = await padron.federaciones
        .crear(const FederacionRequest(nombre: 'ZZZ UNA FEDE'));
    central = await padron.centrales
        .crear(CentralRequest(nombre: 'ZZZ UNA CENTRAL', federacionId: fede.id));
    sindicato = await padron.sindicatos
        .crear(SindicatoRequest(nombre: 'ZZZ UNA SIND', centralId: central.id));
  });

  tearDownAll(() async {
    // Orden obligado: una parcela con tenedor no se borra, y un productor con
    // tierra a su nombre tampoco. Primero se sueltan las tenencias.
    for (final id in lotes) {
      try {
        await padron.lotes
            .traspasar(id, const TraspasoRequest(motivo: MotivoTraspaso.otro));
      } on ApiException {
        // Ya estaba sin tenedor.
      }
      try {
        await padron.lotes.eliminar(id);
      } on ApiException {
        // Ya no estaba.
      }
    }
    for (final id in productores) {
      try {
        await padron.productores.eliminar(id);
      } on ApiException {
        // Ídem.
      }
    }
    try {
      await padron.sindicatos.eliminar(sindicato.id);
      await padron.centrales.eliminar(central.id);
      await padron.federaciones.eliminar(fede.id);
    } on ApiException {
      // Lo importante ya se limpió arriba.
    } finally {
      padron.cerrar();
    }
  });

  test('crear una segunda parcela a su nombre se rechaza', () async {
    final p = await productor('ZZZ CON UNA');
    await lote('ZZZ-A1', productorId: p.id);

    await expectLater(
      lote('ZZZ-A2', productorId: p.id),
      throwsA(isA<ApiException>()
          .having((e) => e.esConflicto, 'esConflicto', isTrue)
          .having((e) => e.mensaje, 'mensaje', contains('ya tiene una parcela'))),
    );
  });

  test('la parcela rechazada no queda dando vueltas', () async {
    // El lote se guarda antes de comprobar la regla, así que si la transacción
    // no deshiciera todo quedaría una parcela huérfana en el sindicato.
    final antes = (await padron.lotes.listar(sindicatoId: sindicato.id)).length;
    final p = await productor('ZZZ HUERFANA');
    await lote('ZZZ-B1', productorId: p.id);

    await expectLater(
      lote('ZZZ-B2', productorId: p.id),
      throwsA(isA<ApiException>()),
    );

    final despues = (await padron.lotes.listar(sindicatoId: sindicato.id)).length;
    expect(despues, antes + 1, reason: 'solo tiene que haber quedado la primera');
  });

  test('traspasarle una segunda tampoco se puede', () async {
    final p = await productor('ZZZ TRASPASO');
    await lote('ZZZ-C1', productorId: p.id);
    final libre = await lote('ZZZ-C2');

    await expectLater(
      padron.lotes.traspasar(libre.id,
          TraspasoRequest(motivo: MotivoTraspaso.otro, productorId: p.id)),
      throwsA(isA<ApiException>()
          .having((e) => e.mensaje, 'mensaje', contains('ya tiene una parcela'))),
    );
  });

  test('si suelta la que tiene, puede recibir otra', () async {
    // Es el caso real: vendió la suya y compró otra.
    final p = await productor('ZZZ VENDE Y COMPRA');
    final primera = await lote('ZZZ-D1', productorId: p.id);
    final segunda = await lote('ZZZ-D2');

    await padron.lotes.traspasar(
        primera.id, const TraspasoRequest(motivo: MotivoTraspaso.venta));
    final recibida = await padron.lotes.traspasar(segunda.id,
        TraspasoRequest(motivo: MotivoTraspaso.venta, productorId: p.id));

    expect(recibida.tenedor?.productorId, p.id);
    // Y la que soltó quedó sin tenedor, no borrada.
    expect((await padron.lotes.obtener(primera.id)).tieneTenedor, isFalse);
  });

  test('dar de baja no borra: el productor sigue y se lo puede reincorporar',
      () async {
    final p = await productor('ZZZ SE VA');

    final baja = await padron.productores.cambiarEstado(p.id, false);
    expect(baja.habilitado, isFalse);

    // Sigue estando: es lo que evita tener que registrarlo de nuevo si vuelve.
    final ficha = await padron.productores.obtener(p.id);
    expect(ficha.productor.nombres, 'ZZZ SE VA');
    expect(ficha.productor.codigo, isNotNull,
        reason: 'conserva su código de credencial');

    final vuelta = await padron.productores.cambiarEstado(p.id, true);
    expect(vuelta.habilitado, isTrue);
  });
}
