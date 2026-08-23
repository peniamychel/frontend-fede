import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/inicio.dart';
import 'package:fede/ui/padron_scope.dart';

/// Cada sección se carga la primera vez que se entra, no al abrir la app.
///
/// El armazón usa un IndexedStack para conservar el scroll y los filtros al ir
/// y volver entre secciones. El precio de eso es que construye todos sus hijos
/// de entrada: al abrir la aplicación salían once consultas a la API para
/// dibujar cinco pantallas de las que se ve una.
///
/// Estas pruebas fijan el arreglo. Sin ellas, agregar una sección nueva volvería
/// a sumar sus consultas al arranque sin que nadie se entere.
void main() {
  /// Cliente que anota cada ruta pedida y no llama a ningún servidor.
  late _ApiEspia espia;

  Widget app() => TemaScope(
        preferencia: PreferenciaTema(),
        child: PadronScope(
          padron: Padron(api: espia),
          child: const MaterialApp(home: Inicio()),
        ),
      );

  setUp(() => espia = _ApiEspia());

  testWidgets('al abrir solo consulta la sección visible', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    // Productores es la primera sección: lo suyo sí se pide.
    expect(espia.rutas.any((r) => r.startsWith('/productores')), isTrue,
        reason: 'la sección visible tiene que cargar sus datos');

    // Lo de las otras tres, no.
    for (final ajena in ['/reuniones', '/federaciones']) {
      expect(espia.rutas.any((r) => r.startsWith(ajena)), isFalse,
          reason: 'no se puede consultar $ajena antes de entrar a esa sección');
    }
  });

  testWidgets('entrar a una sección carga la suya, y solo la suya',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    espia.rutas.clear();

    // La tercera pestaña es Reuniones.
    await tester.tap(find.text('Reuniones'));
    await tester.pump();

    expect(espia.rutas.any((r) => r.startsWith('/reuniones')), isTrue);
    expect(espia.rutas.any((r) => r.startsWith('/federaciones')), isFalse,
        reason: 'entrar a una sección no puede arrastrar a las demás');
  });

  testWidgets('volver a una sección ya visitada no la reconstruye',
      (tester) async {
    // Es lo que da el IndexedStack y hay que conservarlo: al volver, el scroll
    // y los filtros siguen donde estaban, sin pedir los datos de nuevo.
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('Reuniones'));
    await tester.pump();
    final tras = espia.rutas.where((r) => r.startsWith('/reuniones')).length;

    await tester.tap(find.text('Productores'));
    await tester.pump();
    await tester.tap(find.text('Reuniones'));
    await tester.pump();

    expect(espia.rutas.where((r) => r.startsWith('/reuniones')).length,
        equals(tras),
        reason: 'volver no puede volver a consultar');
  });
}

/// Un ApiClient que anota las rutas y devuelve listas vacías.
///
/// No hereda de una interfaz porque no hay ninguna: se extiende el cliente real
/// y se interceptan sus cuatro métodos de lectura, que es lo único que las
/// pantallas usan al construirse.
class _ApiEspia extends ApiClient {
  final List<String> rutas = [];

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    rutas.add(ruta);
    // Las pantallas esperan una lista o una página; se devuelve lo mínimo que
    // no rompe el mapeo de ninguna.
    if (ruta.contains('total')) return 0;
    return <dynamic>[];
  }
}
