import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_formulario.dart';

/// Pruebas del alta con sindicato ya fijado.
///
/// Corren sin backend a propósito, y de ahí sale la comprobación más fuerte:
/// `flutter_test` bloquea las peticiones, así que cualquier pantalla que
/// consulte la jerarquía termina en el estado de error con «Reintentar». Que el
/// formulario con sindicato fijado llegue a ser usable prueba que no consultó
/// nada.
void main() {
  const libertad = Sindicato(
    id: 16,
    nombre: 'LIBERTAD',
    centralId: 20,
    centralNombre: 'IVIRGARZAMA',
  );

  Widget envolver(Widget hijo, {ApiClient? api}) => PadronScope(
    padron: Padron(api: api),
    child: MaterialApp(home: hijo),
  );

  testWidgets('con sindicato fijado el formulario es usable sin servidor', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(const ProductorFormulario(sindicatoFijo: libertad)),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Si hubiera intentado cargar la jerarquía, acá habría un error.
    expect(find.text('Reintentar'), findsNothing);

    // El formulario está entero y listo para escribir.
    expect(find.text('Nuevo productor en LIBERTAD'), findsOneWidget);
    expect(find.text('Nombres *'), findsOneWidget);
    expect(find.text('Registrar'), findsOneWidget);

    // Con el resumen en lugar de los dos desplegables.
    expect(find.text('Central IVIRGARZAMA'), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);
    expect(find.text('Central *'), findsNothing);
    expect(find.text('Sindicato *'), findsNothing);
  });

  testWidgets('sin sindicato fijado sí consulta la jerarquía', (tester) async {
    await tester.pumpWidget(envolver(const ProductorFormulario()));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // El camino contrario: consultó, falló por no haber backend, y lo dice.
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Nombres *'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('«Cambiar» suelta el sindicato y pasa a los desplegables', (
    tester,
  ) async {
    await tester.pumpWidget(
      envolver(
        const ProductorFormulario(sindicatoFijo: libertad),
        api: _ApiCedulaNoDisponible(),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Cambiar'), findsOneWidget);

    await tester.enterText(
      find.ancestor(
        of: find.text('Cédula de identidad *'),
        matching: find.byType(TextFormField),
      ),
      '9990003',
    );
    await tester.tap(find.byTooltip('Verificar cédula'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar manualmente'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cambiar'));
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Ya no está atrapado en el sindicato: soltó el resumen y se fue a buscar
    // la jerarquía, que sin backend termina en «Reintentar».
    expect(find.text('Cambiar'), findsNothing);
    expect(find.text('Central IVIRGARZAMA'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('en edición se ignora el sindicato fijado', (tester) async {
    const productor = Productor(
      id: 15,
      nombres: 'NINGUNO',
      apellidos: 'NINGUNO',
      nombreCompleto: 'NINGUNO NINGUNO',
      ci: null,
      nombresCorregidos: null,
      apellidosCorregidos: null,
      fotoDescripcion: null,
      tieneFoto: false,
      marcado: false,
      sindicatoId: 16,
      sindicatoNombre: 'LIBERTAD',
      centralId: 20,
      centralNombre: 'IVIRGARZAMA',
    );

    await tester.pumpWidget(
      envolver(
        const ProductorFormulario(
          productor: productor,
          sindicatoFijo: libertad,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Editar incluye poder mover el productor a otro sindicato, así que hace
    // falta la jerarquía aunque venga un sindicato fijado.
    expect(find.text('Editar productor'), findsOneWidget);
    expect(find.text('Cambiar'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ApiCedulaNoDisponible extends ApiClient {
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) {
    if (ruta.startsWith('/productores/por-cedula/')) {
      return Future.value(<dynamic>[]);
    }
    return super.obtener(ruta, query: query);
  }

  @override
  Future<Object?> crear(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) {
    if (ruta == '/personas/consulta') {
      return Future.value({
        'estado': 'NO_DISPONIBLE',
        'mensaje': 'SIE no disponible',
      });
    }
    return super.crear(ruta, cuerpo);
  }
}
