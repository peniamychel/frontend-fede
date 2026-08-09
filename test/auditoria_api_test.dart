@Tags(['integracion'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';

/// Auditoría y estado, contra el backend real.
///
/// Todo se hace sobre registros propios que se crean y se borran. No se toca
/// la jerarquía real.
///
/// ```
/// flutter test --dart-define=API_HOST=localhost test/auditoria_api_test.dart
/// ```
void main() {
  late Padron padron;
  late int federacionId;
  final centrales = <int>[];
  final sindicatos = <int>[];
  final productores = <int>[];

  Future<Central> central(String nombre) async {
    final c = await padron.centrales
        .crear(CentralRequest(nombre: nombre, federacionId: federacionId));
    centrales.add(c.id);
    return c;
  }

  setUpAll(() async {
    padron = Padron();
    federacionId = (await padron.federaciones.listar()).first.id;
  });

  tearDownAll(() async {
    for (final id in productores) {
      await padron.productores.eliminar(id);
    }
    for (final id in sindicatos) {
      await padron.sindicatos.eliminar(id);
    }
    for (final id in centrales) {
      await padron.centrales.eliminar(id);
    }
  });

  group('fechas', () {
    test('un registro nuevo llega con las dos fechas puestas', () async {
      final antes = DateTime.now().subtract(const Duration(minutes: 2));

      final c = await central('ZZZ AUD NUEVA');

      expect(c.auditoria.creadoEn, isNotNull);
      expect(c.auditoria.editadoEn, isNotNull);
      // No es una fecha cualquiera: es de ahora. Si el backend no tuviera la
      // auditoría encendida, vendrían nulas o en el año cero.
      expect(c.auditoria.creadoEn!.isAfter(antes), isTrue);
      expect(c.auditoria.editadoEn!.isAfter(antes), isTrue);
    });

    test('al editar se mueve editadoEn y NO creadoEn', () async {
      final c = await central('ZZZ AUD EDITABLE');
      final creadoOriginal = c.auditoria.creadoEn!;

      // El backend guarda la fecha al segundo, así que hay que esperar uno
      // para que el cambio sea visible.
      await Future<void>.delayed(const Duration(seconds: 2));
      final editada = await padron.centrales.actualizar(
        c.id,
        CentralRequest(nombre: 'ZZZ AUD EDITADA', federacionId: federacionId),
      );

      // creadoEn es updatable=false en el backend: ni un UPDATE la mueve.
      expect(editada.auditoria.creadoEn, creadoOriginal);
      expect(editada.auditoria.editadoEn!.isAfter(creadoOriginal), isTrue,
          reason: 'la respuesta del PUT tiene que traer la fecha ya movida, '
              'no la anterior');
    });

    test('la fecha que devuelve el PUT coincide con la que quedó guardada',
        () async {
      final c = await central('ZZZ AUD COHERENTE');
      await Future<void>.delayed(const Duration(seconds: 2));

      final editada = await padron.centrales.actualizar(
        c.id,
        CentralRequest(nombre: 'ZZZ AUD COHERENTE 2', federacionId: federacionId),
      );
      final releida = await padron.centrales.obtener(c.id);

      // Se compara al segundo: la columna es datetime, sin fracción.
      expect(releida.auditoria.editadoEn!.difference(editada.auditoria.editadoEn!)
          .inSeconds.abs(), lessThanOrEqualTo(1));
    });
  });

  group('estado', () {
    test('nace habilitado', () async {
      expect((await central('ZZZ EST NUEVA')).habilitado, isTrue);
    });

    test('se deshabilita y se vuelve a habilitar', () async {
      final c = await central('ZZZ EST TOGGLE');

      final apagada = await padron.centrales.cambiarEstado(c.id, false);
      expect(apagada.habilitado, isFalse);

      final prendida = await padron.centrales.cambiarEstado(c.id, true);
      expect(prendida.habilitado, isTrue);
    });

    test('deshabilitar no borra ni esconde el registro', () async {
      final c = await central('ZZZ EST VISIBLE');
      await padron.centrales.cambiarEstado(c.id, false);

      // Sigue en el listado, marcado. Si desapareciera no habría manera de
      // volver a habilitarlo.
      final lista = await padron.centrales.listar(federacionId: federacionId);
      final encontrada = lista.where((x) => x.id == c.id);
      expect(encontrada, hasLength(1));
      expect(encontrada.first.habilitado, isFalse);
    });

    test('pedir el mismo estado dos veces no falla', () async {
      final c = await central('ZZZ EST IDEMPOTENTE');

      // El endpoint recibe el valor deseado, no un "alternar": repetir la
      // llamada tras un corte de red deja el registro como se quería.
      await padron.centrales.cambiarEstado(c.id, false);
      final otra = await padron.centrales.cambiarEstado(c.id, false);

      expect(otra.habilitado, isFalse);
    });

    test('funciona igual en sindicatos y productores', () async {
      final c = await central('ZZZ EST JERARQUIA');
      final s = await padron.sindicatos
          .crear(SindicatoRequest(nombre: 'ZZZ EST SIND', centralId: c.id));
      sindicatos.add(s.id);
      final p = await padron.productores.crear(ProductorRequest(
          nombres: 'ZZZ EST', apellidos: 'PRODUCTOR', sindicatoId: s.id));
      productores.add(p.id);

      expect(s.habilitado, isTrue);
      expect(p.habilitado, isTrue);
      expect((await padron.sindicatos.cambiarEstado(s.id, false)).habilitado,
          isFalse);
      expect((await padron.productores.cambiarEstado(p.id, false)).habilitado,
          isFalse);
    });

    test('deshabilitar un padre no toca a sus hijos', () async {
      // Son decisiones separadas: apagar una central no puede dar de baja en
      // silencio a cientos de productores.
      final c = await central('ZZZ EST PADRE');
      final s = await padron.sindicatos
          .crear(SindicatoRequest(nombre: 'ZZZ EST HIJO', centralId: c.id));
      sindicatos.add(s.id);

      await padron.centrales.cambiarEstado(c.id, false);

      expect((await padron.sindicatos.obtener(s.id)).habilitado, isTrue);
    });
  });
}
