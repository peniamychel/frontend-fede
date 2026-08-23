@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// El código del padrón: 2-IVI-1.
///
/// Se arma con el número de la federación, la sigla de la central y el número
/// del productor dentro de esa central. Todo se hace sobre una federación
/// propia, creada al empezar y borrada al terminar: la jerarquía real no se
/// toca, y así estas pruebas pueden poner número y sigla sin pisar los de nadie.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/codigo_padron_api_test.dart
/// ```
void main() {
  late Padron padron;
  late Federacion fede;

  final productores = <int>[];
  final sindicatos = <int>[];
  final centrales = <int>[];

  Future<Central> central(String nombre, String abreviatura) async {
    final c = await padron.centrales.crear(CentralRequest(
      nombre: nombre,
      abreviatura: abreviatura,
      federacionId: fede.id,
    ));
    centrales.add(c.id);
    return c;
  }

  Future<Sindicato> sindicato(String nombre, int centralId) async {
    final s = await padron.sindicatos
        .crear(SindicatoRequest(nombre: nombre, centralId: centralId));
    sindicatos.add(s.id);
    return s;
  }

  Future<Productor> productor(String nombres, int sindicatoId) async {
    final p = await padron.productores.crear(
        ProductorRequest(nombres: nombres, sindicatoId: sindicatoId));
    productores.add(p.id);
    return p;
  }

  setUpAll(() async {
    padron = Padron();
    fede = await padron.federaciones
        .crear(const FederacionRequest(nombre: 'ZZZ COD FEDE', numero: '77'));
  });

  tearDownAll(() async {
    for (final id in productores) {
      try {
        await padron.productores.eliminar(id);
      } on ApiException {
        // Puede haberse borrado antes dentro de una prueba.
      }
    }
    for (final id in sindicatos) {
      try {
        await padron.sindicatos.eliminar(id);
      } on ApiException {
        // Ídem.
      }
    }
    for (final id in centrales) {
      try {
        await padron.centrales.eliminar(id);
      } on ApiException {
        // Ídem.
      }
    }
    try {
      await padron.federaciones.eliminar(fede.id);
    } on ApiException {
      // Ídem.
    }
  });

  test('el primero de una central lleva el 1', () async {
    final c = await central('ZZZ COD UNO', 'CUN');
    final s = await sindicato('ZZZ COD SIND UNO', c.id);

    final p = await productor('ZZZ PRIMERO', s.id);

    expect(p.codigoPadron, '77-CUN-1');
  });

  test('el siguiente sigue la cuenta, aunque sea de otro sindicato', () async {
    // El número es de la central, no del sindicato: dos sindicatos de la misma
    // central comparten la numeración.
    final c = await central('ZZZ COD DOS', 'CDO');
    final unoS = await sindicato('ZZZ COD SIND A', c.id);
    final otroS = await sindicato('ZZZ COD SIND B', c.id);

    final primero = await productor('ZZZ SEGUNDO A', unoS.id);
    final segundo = await productor('ZZZ SEGUNDO B', otroS.id);

    expect(primero.codigoPadron, '77-CDO-1');
    expect(segundo.codigoPadron, '77-CDO-2');
  });

  test('cada central arranca de nuevo en 1', () async {
    final unaC = await central('ZZZ COD TRES', 'CTR');
    final otraC = await central('ZZZ COD CUATRO', 'CCU');
    final unaS = await sindicato('ZZZ COD SIND C', unaC.id);
    final otraS = await sindicato('ZZZ COD SIND D', otraC.id);

    final aca = await productor('ZZZ TERCERO ACA', unaS.id);
    final alla = await productor('ZZZ TERCERO ALLA', otraS.id);

    expect(aca.codigoPadron, '77-CTR-1');
    expect(alla.codigoPadron, '77-CCU-1');
  });

  test('sin sigla en la central no hay código', () async {
    // Es el estado de todas las centrales hasta que alguien les ponga la sigla.
    final c = await padron.centrales.crear(
        CentralRequest(nombre: 'ZZZ COD SIN SIGLA', federacionId: fede.id));
    centrales.add(c.id);
    final s = await sindicato('ZZZ COD SIND E', c.id);

    final p = await productor('ZZZ SIN CODIGO', s.id);

    expect(p.codigoPadron, isNull,
        reason: 'antes que un código a medias, ninguno');
  });

  test('ponerle la sigla a la central le da código a los que ya estaban',
      () async {
    // Por esto se guarda el número y no la cadena armada: los productores
    // cargados antes de definir la sigla no hay que tocarlos.
    final c = await padron.centrales.crear(
        CentralRequest(nombre: 'ZZZ COD TARDIA', federacionId: fede.id));
    centrales.add(c.id);
    final s = await sindicato('ZZZ COD SIND F', c.id);
    final p = await productor('ZZZ ESPERA SIGLA', s.id);
    expect(p.codigoPadron, isNull);

    await padron.centrales.actualizar(
      c.id,
      CentralRequest(
          nombre: c.nombre, abreviatura: 'CTA', federacionId: fede.id),
    );

    final conCodigo = await padron.productores.obtener(p.id);
    expect(conCodigo.productor.codigoPadron, '77-CTA-1');
  });

  test('mudarse a otra central da número nuevo allá', () async {
    final origen = await central('ZZZ COD ORIGEN', 'COR');
    final destino = await central('ZZZ COD DESTINO', 'CDE');
    final sOrigen = await sindicato('ZZZ COD SIND G', origen.id);
    final sDestino = await sindicato('ZZZ COD SIND H', destino.id);

    // El destino ya tiene a alguien, así que el 1 está ocupado.
    await productor('ZZZ YA ESTABA', sDestino.id);
    final viajero = await productor('ZZZ SE MUDA', sOrigen.id);
    expect(viajero.codigoPadron, '77-COR-1');

    final mudado = await padron.productores.actualizar(
      viajero.id,
      ProductorRequest(nombres: viajero.nombres, sindicatoId: sDestino.id),
    );

    expect(mudado.codigoPadron, '77-CDE-2',
        reason: 'el número que traía era de la central que dejó');
  });

  test('cambiar de sindicato dentro de la misma central no lo toca', () async {
    // Su credencial impresa sigue sirviendo.
    final c = await central('ZZZ COD QUIETO', 'CQU');
    final unaS = await sindicato('ZZZ COD SIND I', c.id);
    final otraS = await sindicato('ZZZ COD SIND J', c.id);

    final p = await productor('ZZZ NO SE MUEVE', unaS.id);
    final antes = p.codigoPadron;

    final despues = await padron.productores.actualizar(
      p.id,
      ProductorRequest(nombres: p.nombres, sindicatoId: otraS.id),
    );

    expect(despues.codigoPadron, antes);
  });

  test('mudar el sindicato entero renumera a su gente', () async {
    final origen = await central('ZZZ COD ORIGEN 2', 'CO2');
    final destino = await central('ZZZ COD DESTINO 2', 'CD2');
    final s = await sindicato('ZZZ COD SIND K', origen.id);

    final uno = await productor('ZZZ MUDANZA A', s.id);
    final dos = await productor('ZZZ MUDANZA B', s.id);
    expect(uno.codigoPadron, '77-CO2-1');
    expect(dos.codigoPadron, '77-CO2-2');

    await padron.sindicatos.actualizar(
      s.id,
      SindicatoRequest(nombre: 'ZZZ COD SIND K', centralId: destino.id),
    );

    // Llegan a una central vacía, así que arrancan de 1 y conservan el orden.
    expect((await padron.productores.obtener(uno.id)).productor.codigoPadron,
        '77-CD2-1');
    expect((await padron.productores.obtener(dos.id)).productor.codigoPadron,
        '77-CD2-2');
  });

  group('buscar por código', () {
    test('el código del padrón encuentra a su dueño', () async {
      // Es lo que está impreso en la credencial y lo que la gente lee en voz
      // alta en la asamblea, así que tiene que servir para buscar.
      final c = await central('ZZZ COD BUSCA', 'CBU');
      final s = await sindicato('ZZZ COD SIND BUSCA', c.id);
      final p = await productor('ZZZ BUSCAME', s.id);
      expect(p.codigoPadron, '77-CBU-1');

      final hallados =
          (await padron.productores.listar(texto: '77-CBU-1')).contenido;

      expect(hallados.map((x) => x.id), [p.id]);
    });

    test('el código de la credencial también, y sin importar mayúsculas',
        () async {
      final c = await central('ZZZ COD QR', 'CQR');
      final s = await sindicato('ZZZ COD SIND QR', c.id);
      final p = await productor('ZZZ DEL QR', s.id);
      final codigo = (await padron.productores.obtener(p.id)).productor.codigo!;

      final hallados = (await padron.productores
              .listar(texto: codigo.toLowerCase()))
          .contenido;

      expect(hallados.map((x) => x.id), [p.id]);
    });

    test('un código de otra central no lo trae', () async {
      // Sin esto, buscar «77-CBU-1» traería al 1 de cada central.
      final c = await central('ZZZ COD OTRA', 'COT');
      final s = await sindicato('ZZZ COD SIND OTRA', c.id);
      final ajeno = await productor('ZZZ EL OTRO UNO', s.id);
      expect(ajeno.codigoPadron, '77-COT-1');

      final hallados =
          (await padron.productores.listar(texto: '77-COT-1')).contenido;

      expect(hallados.map((x) => x.id), [ajeno.id]);
    });

    test('buscar por nombre y por cédula sigue andando', () async {
      final c = await central('ZZZ COD NOMBRE', 'CNO');
      final s = await sindicato('ZZZ COD SIND NOMBRE', c.id);
      final p = await padron.productores.crear(ProductorRequest(
        nombres: 'ZZZ POR NOMBRE',
        apellidos: 'APELLIDADO',
        ci: '55443322',
        sindicatoId: s.id,
      ));
      productores.add(p.id);

      expect(
          (await padron.productores.listar(texto: 'ZZZ POR NOMBRE'))
              .contenido
              .map((x) => x.id),
          contains(p.id));
      expect(
          (await padron.productores.listar(texto: 'APELLIDADO'))
              .contenido
              .map((x) => x.id),
          contains(p.id));
      expect(
          (await padron.productores.listar(texto: '55443322'))
              .contenido
              .map((x) => x.id),
          contains(p.id));
    });
  });
}
