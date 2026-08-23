import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_formulario.dart';

/// El formulario del productor ya no edita los campos de la revisión del
/// padrón: nombres corregidos, apellidos corregidos y rótulo de la fotografía
/// salieron de la pantalla.
///
/// La segunda prueba es la que importa y no se ve a simple vista. El backend
/// asigna esos tres campos sin preguntar en cada actualización, así que dejar
/// de mandarlos no los deja quietos: los borra. Si alguien «limpiara» el
/// formulario quitando también las tres líneas que los arrastran, cada edición
/// de una ficha se llevaría puesta la corrección de nombre que la revisión del
/// padrón había propuesto, en silencio y sin forma de recuperarla.
void main() {
  const sindicato = Sindicato(
    id: 7,
    nombre: 'LIBERTAD',
    centralId: 3,
    centralNombre: 'IVIRGARZAMA',
  );

  const conCorrecciones = Productor(
    id: 42,
    nombres: 'JUAN',
    apellidos: 'MORALES',
    nombreCompleto: 'JUAN MORALES',
    ci: '3434',
    nombresCorregidos: 'JUAN CARLOS',
    apellidosCorregidos: 'MORALES VARGAS',
    fotoDescripcion: 'Juan Morales, Libertad',
    tieneFoto: true,
    marcado: false,
    sindicatoId: 7,
    sindicatoNombre: 'LIBERTAD',
    centralId: 3,
    centralNombre: 'IVIRGARZAMA',
  );

  late _ApiEspia espia;

  /// El formulario es más alto que la ventana con la que arrancan las pruebas
  /// —800 × 600—, y el botón de guardar queda fuera. Se agranda la ventana para
  /// que entre entero en vez de andar desplazándolo.
  void ventanaAlta(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> guardar(WidgetTester tester, String texto) async {
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }

  Widget banco({Productor? productor}) => TemaScope(
    preferencia: PreferenciaTema(),
    child: PadronScope(
      padron: Padron(api: espia),
      child: MaterialApp(
        home: ProductorFormulario(
          productor: productor,
          // Con el sindicato resuelto el formulario abre sin pedir la
          // jerarquía, que acá no es lo que se está probando.
          sindicatoFijo: productor == null ? sindicato : null,
        ),
      ),
    ),
  );

  setUp(() => espia = _ApiEspia());

  testWidgets('la revisión ya no ofrece los tres campos', (tester) async {
    ventanaAlta(tester);
    await tester.pumpWidget(banco(productor: conCorrecciones));
    await tester.pumpAndSettle();

    expect(find.text('Nombres corregidos'), findsNothing);
    expect(find.text('Apellidos corregidos'), findsNothing);
    expect(find.text('Rótulo de la fotografía'), findsNothing);

    // Lo que se pidió sacar son esos tres. La marca de seguimiento se queda.
    expect(find.text('Marcado para seguimiento'), findsOneWidget);
    // Y los datos de la persona siguen editándose.
    expect(find.text('Nombres *'), findsOneWidget);
    expect(find.text('Cédula de identidad'), findsOneWidget);
  });

  testWidgets('editar no borra la corrección que la revisión había propuesto', (
    tester,
  ) async {
    ventanaAlta(tester);
    await tester.pumpWidget(banco(productor: conCorrecciones));
    await tester.pumpAndSettle();

    await guardar(tester, 'Guardar cambios');

    expect(espia.enviado, isNotNull, reason: 'no se guardó nada');
    expect(espia.enviado!['nombresCorregidos'], 'JUAN CARLOS');
    expect(espia.enviado!['apellidosCorregidos'], 'MORALES VARGAS');
    expect(espia.enviado!['fotoDescripcion'], 'Juan Morales, Libertad');
  });

  testWidgets('un productor nuevo no inventa correcciones', (tester) async {
    ventanaAlta(tester);
    await tester.pumpWidget(banco());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.ancestor(
        of: find.text('Cédula de identidad *'),
        matching: find.byType(TextFormField),
      ),
      '9990002',
    );
    await tester.tap(find.byTooltip('Verificar cédula'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.ancestor(
        of: find.text('Nombres *'),
        matching: find.byType(TextFormField),
      ),
      'NUEVO',
    );
    await guardar(tester, 'Registrar');

    expect(espia.enviado, isNotNull, reason: 'no se creó nada');
    // Van ausentes, no vacíos: no hay nada que corregir en un alta.
    expect(espia.enviado!.containsKey('nombresCorregidos'), isFalse);
    expect(espia.enviado!.containsKey('apellidosCorregidos'), isFalse);
    expect(espia.enviado!.containsKey('fotoDescripcion'), isFalse);
  });
}

/// Un ApiClient que anota el cuerpo enviado y devuelve un productor válido.
class _ApiEspia extends ApiClient {
  Map<String, dynamic>? enviado;

  Map<String, dynamic> get _productorJson => {
    'id': 42,
    'nombres': 'JUAN',
    'apellidos': 'MORALES',
    'nombreCompleto': 'JUAN MORALES',
    'sindicatoId': 7,
    'sindicatoNombre': 'LIBERTAD',
    'centralId': 3,
    'centralNombre': 'IVIRGARZAMA',
  };

  /// En edición el formulario reconstruye la cascada central → sindicato para
  /// dejar preseleccionado el del productor, así que hay que devolvérsela: con
  /// listas vacías no habría sindicato que elegir y no llegaría a guardar.
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta.contains('sindicatos')) {
      return [
        {
          'id': 7,
          'nombre': 'LIBERTAD',
          'centralId': 3,
          'centralNombre': 'IVIRGARZAMA',
        },
      ];
    }
    if (ruta.contains('centrales')) {
      return [
        {
          'id': 3,
          'nombre': 'IVIRGARZAMA',
          'federacionId': 1,
          'federacionNombre': 'CARRASCO',
        },
      ];
    }
    return <dynamic>[];
  }

  @override
  Future<Object?> crear(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    if (ruta == '/personas/consulta') {
      return {'estado': 'NO_ENCONTRADA', 'mensaje': 'No existe en SIE'};
    }
    enviado = cuerpo as Map<String, dynamic>;
    return _productorJson;
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    enviado = cuerpo as Map<String, dynamic>;
    return _productorJson;
  }
}
