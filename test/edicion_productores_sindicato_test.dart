import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/sesion_scope.dart';
import 'package:fede/ui/jerarquia/edicion_productores_sindicato_pagina.dart';
import 'package:fede/ui/jerarquia/sindicato_productores_pagina.dart';
import 'package:fede/ui/productores/productor_formulario.dart';

final sindicato = Sindicato.desdeJson({
  'id': 30,
  'nombre': 'SINDICATO DE PRUEBA',
  'centralId': 20,
  'centralNombre': 'CENTRAL DE PRUEBA',
});

Finder campo(int id, String nombre) => find.byKey(ValueKey('$id-$nombre'));

Finder campoAlta(String etiqueta) => find.ancestor(
  of: find.text(etiqueta),
  matching: find.byType(TextFormField),
);

Future<void> _registrarNuevo(WidgetTester tester) async {
  await tester.enterText(campoAlta('Cédula de identidad *'), '777');
  await tester.tap(find.byTooltip('Verificar cédula'));
  await tester.pumpAndSettle();
  await tester.enterText(campoAlta('Nombres *'), 'ALBERTO');
  await tester.enterText(campoAlta('Apellidos'), 'NUEVO');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Registrar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Registrar'));
  await tester.pumpAndSettle();
}

Future<void> _abrir(
  WidgetTester tester,
  _ApiEdicion api, {
  SesionControlador? sesion,
  double ancho = 1200,
}) async {
  tester.view.physicalSize = Size(ancho, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget app = MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<bool>(
              builder: (_) =>
                  EdicionProductoresSindicatoPagina(sindicato: sindicato),
            ),
          ),
          child: const Text('Abrir editor'),
        ),
      ),
    ),
  );
  if (sesion != null) app = SesionScope(controlador: sesion, child: app);
  await tester.pumpWidget(
    PadronScope(
      padron: Padron(api: api),
      child: app,
    ),
  );
  await tester.tap(find.text('Abrir editor'));
  await tester.pumpAndSettle();
}

void main() {
  final buscador = find.byKey(const ValueKey('buscar-edicion-productores'));
  testWidgets(
    'nuevo abre el formulario en el sindicato y cancelarlo conserva la búsqueda',
    (tester) async {
      final api = _ApiEdicion();
      await _abrir(tester, api, ancho: 430);
      await tester.enterText(buscador, 'JUAN');
      await tester.tap(find.byTooltip('Nuevo productor'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductorFormulario), findsOneWidget);
      expect(
        find.text('Nuevo productor en SINDICATO DE PRUEBA'),
        findsOneWidget,
      );
      expect(find.text('Central CENTRAL DE PRUEBA'), findsOneWidget);
      final cedula = find.descendant(
        of: campoAlta('Cédula de identidad *'),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(cedula).focusNode.hasFocus, isTrue);
      await tester.tap(find.byType(BackButton).last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(buscador).controller!.text, 'JUAN');
      expect(campo(2, 'nombres'), findsOneWidget);
      expect(api.altas, isEmpty);
      expect(api.consultas.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registrar desde edición rápida vuelve a la tabla, actualiza el total y permite editar',
    (tester) async {
      final api = _ApiEdicion();
      await _abrir(tester, api);
      await tester.tap(find.byTooltip('Ordenar productores'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is PopupMenuItem<OrdenProductores> &&
              widget.value == OrdenProductores.nombres,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nuevo productor'));
      await tester.pumpAndSettle();
      await _registrarNuevo(tester);
      expect(find.byType(ProductorFormulario), findsNothing);
      expect(find.textContaining('3 productores'), findsOneWidget);
      expect(campo(3, 'nombres'), findsOneWidget);
      expect(api.altas.single['sindicatoId'], 30);
      expect(api.altas.single['ci'], '777');
      expect(
        tester.getTopLeft(campo(3, 'nombres')).dy,
        lessThan(tester.getTopLeft(campo(2, 'nombres')).dy),
      );
      await tester.enterText(campo(3, 'nombres'), 'ALBERTO CORREGIDO');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.datos[3]!['nombres'], 'ALBERTO CORREGIDO');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Abrir editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'alta mantiene filtros y borradores con errores y actualiza las letras compartidas',
    (tester) async {
      final api = _ApiEdicion()..fallar = true;
      await _abrir(tester, api);
      await tester.enterText(campo(1, 'ci'), '987');
      await tester.enterText(buscador, 'JUAN');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Nuevo productor'));
      await tester.pumpAndSettle();
      await _registrarNuevo(tester);
      expect(tester.widget<TextField>(buscador).controller!.text, 'JUAN');
      expect(campo(3, 'nombres'), findsNothing);
      expect(find.textContaining('1 de 3 productores'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(campo(1, 'ci')).controller!.text, '987');
      expect(find.text('Cédula vetada'), findsOneWidget);
      expect(
        tester.widget<TextField>(campo(1, 'numeroLote')).controller!.text,
        '10 A',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('nuevo espera los guardados y evita abrir dos formularios', (
    tester,
  ) async {
    final api = _ApiEdicion()..bloqueo = Completer<void>();
    await _abrir(tester, api);
    await tester.enterText(campo(1, 'nombres'), 'MARIA CORREGIDA');
    await tester.tap(find.byTooltip('Nuevo productor'));
    await tester.pump();
    expect(find.byType(ProductorFormulario), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('nuevo-productor-edicion')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Nuevo productor'), warnIfMissed: false);
    await tester.pump();
    api.bloqueo!.complete();
    await tester.pumpAndSettle();
    expect(api.datos[1]!['nombres'], 'MARIA CORREGIDA');
    expect(api.cambios.length, 1);
    expect(find.byType(ProductorFormulario), findsOneWidget);
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    expect(find.byType(ProductorFormulario), findsNothing);
    expect(campo(1, 'nombres'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'si falla refrescar tras el alta se puede reintentar sin duplicar al productor',
    (tester) async {
      final api = _ApiEdicion()..fallarRefrescoAlta = true;
      await _abrir(tester, api);
      await tester.tap(find.byTooltip('Nuevo productor'));
      await tester.pumpAndSettle();
      await _registrarNuevo(tester);
      expect(api.altas.length, 1);
      expect(campo(3, 'nombres'), findsNothing);
      expect(
        find.text('Actualizar lista del productor registrado'),
        findsOneWidget,
      );
      api.fallarRefrescoAlta = false;
      await tester.tap(find.text('Actualizar lista del productor registrado'));
      await tester.pumpAndSettle();
      expect(campo(3, 'nombres'), findsOneWidget);
      expect(api.altas.length, 1);
      expect(
        find.text('Actualizar lista del productor registrado'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'busca nombres y apellidos sin tildes, limpia y no vuelve a consultar',
    (tester) async {
      final api = _ApiEdicion();
      api.datos[1]!['nombres'] = 'MARÍA';
      api.datos[1]!['apellidos'] = 'NUÑEZ PEREZ';
      await _abrir(tester, api);
      for (final texto in ['maria   perez', 'nunez maria', 'ria']) {
        await tester.enterText(buscador, texto);
        await tester.pumpAndSettle();
        expect(campo(1, 'nombres'), findsOneWidget);
        expect(campo(2, 'nombres'), findsNothing);
        expect(find.textContaining('1 de 2 productores'), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(campo(1, 'nombres'), findsOneWidget);
      expect(campo(2, 'nombres'), findsOneWidget);
      expect(api.consultas.length, 2);
      expect(api.cambios, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busca CI solo desde el primer dígito', (tester) async {
    final api = _ApiEdicion();
    api.datos[1]!['ci'] = '2133123';
    api.datos[2]!['ci'] = '5213384';
    await _abrir(tester, api);
    await tester.enterText(buscador, '2133');
    await tester.pumpAndSettle();
    expect(campo(1, 'ci'), findsOneWidget);
    expect(campo(2, 'ci'), findsNothing);
    await tester.enterText(buscador, '521');
    await tester.pumpAndSettle();
    expect(campo(1, 'ci'), findsNothing);
    expect(campo(2, 'ci'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'código numérico requiere coincidencia exacta y muestra búsqueda vacía',
    (tester) async {
      final api = _ApiEdicion();
      api.datos[1]!['codigoPadron'] = '2133';
      api.datos[2]!['codigo'] = '21334';
      await _abrir(tester, api);
      await tester.enterText(buscador, '2133');
      await tester.pumpAndSettle();
      expect(campo(1, 'nombres'), findsOneWidget);
      expect(campo(2, 'nombres'), findsNothing);
      await tester.enterText(buscador, '213');
      await tester.pumpAndSettle();
      expect(find.text('No se encontraron productores.'), findsOneWidget);
      expect(campo(1, 'nombres'), findsNothing);
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(campo(1, 'nombres'), findsOneWidget);
      expect(campo(2, 'nombres'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editar un resultado no hace desaparecer la fila mientras se corrige',
    (tester) async {
      final api = _ApiEdicion();
      await _abrir(tester, api);
      await tester.enterText(buscador, 'MARIA');
      await tester.pumpAndSettle();
      await tester.enterText(campo(1, 'nombres'), 'ANABEL');
      await tester.tap(campo(1, 'apellidos'));
      await tester.pumpAndSettle();
      expect(campo(1, 'ci'), findsOneWidget);
      expect(api.datos[1]!['nombres'], 'ANABEL');
      await tester.enterText(buscador, 'ANABEL');
      await tester.pumpAndSettle();
      expect(campo(1, 'nombres'), findsOneWidget);
      expect(campo(2, 'nombres'), findsNothing);
      await tester.tap(find.byTooltip('Ordenar productores'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Número de lote'));
      await tester.pumpAndSettle();
      expect(campo(1, 'nombres'), findsOneWidget);
      expect(api.cambios.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'filtrar conserva guardados pendientes y borradores con errores',
    (tester) async {
      final api = _ApiEdicion()
        ..bloqueo = Completer<void>()
        ..fallar = true;
      await _abrir(tester, api);
      await tester.enterText(campo(1, 'ci'), '987');
      await tester.enterText(buscador, 'ZARATE');
      await tester.pump();
      expect(campo(1, 'ci'), findsNothing);
      api.bloqueo!.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(campo(1, 'ci')).controller!.text, '987');
      expect(find.text('Cédula vetada'), findsOneWidget);
      api.fallar = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(api.datos[1]!['ci'], '987');
      expect(find.text('Cédula vetada'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('buscador disponible en vista móvil', (tester) async {
    final api = _ApiEdicion();
    await _abrir(tester, api, ancho: 430);
    await tester.enterText(buscador, 'JUAN');
    await tester.pumpAndSettle();
    expect(campo(2, 'nombres'), findsOneWidget);
    expect(campo(1, 'nombres'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final nombre in ['nombres', 'apellidos', 'ci']) {
    testWidgets('fila pendiente deja de ser gris al guardar $nombre', (
      tester,
    ) async {
      final api = _ApiEdicion()..bloqueo = Completer<void>();
      api.datos[1]!['revisionSiePendiente'] = true;
      await _abrir(tester, api);
      final colores = Theme.of(tester.element(campo(1, nombre))).colorScheme;
      Color? fondo() =>
          (tester.widget<Container>(find.byKey(const ValueKey(1))).decoration
                  as BoxDecoration)
              .color;
      expect(fondo(), colores.surfaceContainerHighest);
      for (final c in ['nombres', 'apellidos', 'ci', 'numeroLote']) {
        expect(
          tester.widget<TextField>(campo(1, c)).style?.color,
          colores.outline,
        );
      }
      final posicion = tester.getTopLeft(campo(1, nombre));
      await tester.enterText(
        campo(1, nombre),
        nombre == 'ci' ? '456' : 'CORREGIDO',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(fondo(), colores.surfaceContainerHighest);
      api.bloqueo!.complete();
      await tester.pumpAndSettle();
      expect(fondo(), isNull);
      expect(tester.widget<TextField>(campo(1, nombre)).style, isNull);
      expect(api.datos[1]!['revisionSieEstado'], 'CORREGIDO_MANUAL');
      expect(tester.getTopLeft(campo(1, nombre)), posicion);
      expect(api.verificacionesSie, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final disponible in [true, false]) {
    testWidgets(
      'SIE ${disponible ? 'revisado quita' : 'no disponible conserva'} el gris',
      (tester) async {
        final api = _ApiEdicion()
          ..estadoSie = disponible ? 'VERIFICADA' : 'NO_DISPONIBLE';
        api.datos[1]!['revisionSiePendiente'] = true;
        await _abrir(tester, api);
        final colores = Theme.of(
          tester.element(campo(1, 'nombres')),
        ).colorScheme;
        final posicion = tester.getTopLeft(campo(1, 'nombres'));
        await tester.tap(find.byKey(const ValueKey('sie-1')));
        await tester.pumpAndSettle();
        expect(
          (tester.widget<Container>(find.byKey(const ValueKey(1))).decoration
                  as BoxDecoration)
              .color,
          disponible ? null : colores.surfaceContainerHighest,
        );
        expect(tester.getTopLeft(campo(1, 'nombres')), posicion);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('globo confirma el guardado sin columna ni mover la fila', (
    tester,
  ) async {
    final api = _ApiEdicion()..bloqueo = Completer<void>();
    await _abrir(tester, api);
    expect(find.text('Guardado'), findsNothing);
    expect(find.text('Dato guardado'), findsNothing);
    final posicion = tester.getTopLeft(campo(1, 'nombres'));
    final alto = tester.getSize(find.byKey(const ValueKey(1))).height;
    await tester.enterText(campo(1, 'nombres'), 'ANA');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Dato guardado'), findsNothing);
    api.bloqueo!.complete();
    await tester.pumpAndSettle();
    final globo = find.byKey(const ValueKey('dato-guardado-1'));
    expect(globo, findsOneWidget);
    expect(find.text('Dato guardado'), findsOneWidget);
    expect(tester.getBottomRight(globo).dy, lessThan(posicion.dy));
    expect(tester.getTopLeft(campo(1, 'nombres')), posicion);
    expect(tester.getSize(find.byKey(const ValueKey(1))).height, alto);
    expect(api.cambios.length, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Dato guardado'), findsNothing);
    await tester.tap(campo(1, 'nombres'));
    await tester.tap(campo(1, 'apellidos'));
    await tester.pumpAndSettle();
    expect(api.cambios.length, 1);
    expect(find.text('Dato guardado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('columna de lote compacta admite tres dígitos y letra', (
    tester,
  ) async {
    final api = _ApiEdicion();
    await _abrir(tester, api);
    final anchoLote = tester.getSize(campo(1, 'numeroLote')).width;
    expect(anchoLote, lessThan(90));
    expect(tester.getSize(campo(1, 'ci')).width, greaterThan(anchoLote * 2));
    expect(
      tester.getSize(campo(1, 'nombres')).width,
      greaterThan(anchoLote * 3),
    );
    await tester.enterText(campo(1, 'numeroLote'), '333 B');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(api.lotes, [
      {'numero': '333', 'loteId': null, 'letra': 'B'},
    ]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'carga todas las páginas y guarda por blur y Enter sin duplicar',
    (tester) async {
      final api = _ApiEdicion();
      await _abrir(tester, api);
      expect(campo(1, 'nombres'), findsOneWidget);
      expect(campo(2, 'nombres'), findsOneWidget);
      expect(api.consultas.every((q) => q['sindicatoId'] == 30), isTrue);
      expect(api.consultas.map((q) => q['page']), [0, 1]);
      await tester.enterText(campo(1, 'nombres'), 'MARÍA');
      await tester.tap(campo(1, 'apellidos'));
      await tester.pumpAndSettle();
      expect(api.cambios, [
        {'id': 1, 'campo': 'nombres', 'valor': 'MARÍA'},
      ]);
      expect(find.text('Dato guardado'), findsOneWidget);
      await tester.enterText(campo(1, 'ci'), '987654-1A');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.cambios.length, 2);
      expect(api.datos[1]!['ci'], '987654-1A');
      expect(api.datos[1]!['apellidos'], 'PEREZ');
      expect(api.datos[1]!['clasificacion'], 'FRACCIONADO');
      expect(api.datos[1]!['fotoDescripcion'], 'Foto existente');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ediciones rápidas se serializan y no borran el texto más reciente',
    (tester) async {
      final api = _ApiEdicion()..bloqueo = Completer<void>();
      await _abrir(tester, api);
      await tester.enterText(campo(1, 'nombres'), 'ANA');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Dato guardado'), findsNothing);
      await tester.enterText(campo(1, 'nombres'), 'ANABEL');
      await tester.tap(campo(1, 'apellidos'));
      await tester.enterText(campo(1, 'apellidos'), 'RAMOS');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(api.cambios.length, 1);
      api.bloqueo!.complete();
      await tester.pumpAndSettle();
      expect(api.cambios.length, 3);
      expect(api.datos[1]!['nombres'], 'ANABEL');
      expect(api.datos[1]!['apellidos'], 'RAMOS');
      expect(
        tester.widget<TextField>(campo(1, 'nombres')).controller!.text,
        'ANABEL',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fallo de guardado conserva borrador, permite reintentar y no salir silenciosamente',
    (tester) async {
      final api = _ApiEdicion()..fallar = true;
      api.datos[1]!['revisionSiePendiente'] = true;
      await _abrir(tester, api);
      await tester.enterText(campo(1, 'ci'), '999');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Cédula vetada'), findsOneWidget);
      expect(find.text('Dato guardado'), findsNothing);
      expect(
        tester.widget<TextField>(campo(1, 'ci')).style?.color,
        Theme.of(tester.element(campo(1, 'ci'))).colorScheme.outline,
      );
      expect(api.datos[1]!['ci'], '123');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Hay cambios sin guardar'), findsOneWidget);
      await tester.tap(find.text('Volver a corregir'));
      await tester.pumpAndSettle();
      api.fallar = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(api.datos[1]!['ci'], '999');
      expect(find.text('Cédula vetada'), findsNothing);
    },
  );

  testWidgets('ordena nombres, apellidos y lotes numéricos sin cambiar datos', (
    tester,
  ) async {
    final api = _ApiEdicion();
    await _abrir(tester, api);
    expect(
      tester.getTopLeft(campo(1, 'nombres')).dy,
      lessThan(tester.getTopLeft(campo(2, 'nombres')).dy),
    );
    for (final orden in [
      'Nombres (A–Z)',
      'Número de lote',
      'Apellidos (A–Z)',
    ]) {
      await tester.tap(find.byTooltip('Ordenar productores'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(orden));
      await tester.pumpAndSettle();
      final primero = orden == 'Apellidos (A–Z)' ? 1 : 2;
      expect(
        tester.getTopLeft(campo(primero, 'nombres')).dy,
        lessThan(tester.getTopLeft(campo(3 - primero, 'nombres')).dy),
      );
    }
    expect(api.cambios, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lote admite letra manual y actualiza letras de otras filas', (
    tester,
  ) async {
    final api = _ApiEdicion();
    await _abrir(tester, api);
    await tester.enterText(campo(1, 'numeroLote'), '4 B');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(api.lotes, [
      {'numero': '4', 'loteId': null, 'letra': 'B'},
    ]);
    expect(
      tester.widget<TextField>(campo(1, 'numeroLote')).controller!.text,
      '4 B',
    );
    expect(
      tester.widget<TextField>(campo(2, 'numeroLote')).controller!.text,
      '4 A',
    );
    expect(api.datos[1]!['clasificacion'], 'FRACCIONADO');
  });

  testWidgets(
    'conserva la subdivisión histórica sin duplicarla en el número base',
    (tester) async {
      final api = _ApiEdicion()..extension = 'A';
      api.datos[1]!['numeroLote'] = '22-A';
      await _abrir(tester, api);
      await tester.enterText(campo(1, 'numeroLote'), '23-A B');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(api.lotes, [
        {'numero': '23', 'loteId': 9, 'letra': 'B'},
      ]);
    },
  );

  testWidgets('al salir espera el guardado y pregunta por reimpresión', (
    tester,
  ) async {
    final api = _ApiEdicion()..bloqueo = Completer<void>();
    api.datos[1]!['credencialImpresiones'] = 1;
    await _abrir(tester, api);
    await tester.enterText(campo(1, 'nombres'), 'ANA');
    await tester.binding.handlePopRoute();
    // El indicador de la celda sigue animándose mientras espera al servidor.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Esperando que terminen los guardados…'), findsOneWidget);
    expect(find.text('¿Agregar para reimpresión?'), findsNothing);
    api.bloqueo!.complete();
    await tester.pumpAndSettle();
    expect(find.text('¿Agregar para reimpresión?'), findsOneWidget);
    await tester.tap(find.text('Agregar para reimpresión'));
    await tester.pumpAndSettle();
    expect(api.reimpresiones, [1]);
    expect(find.text('Abrir editor'), findsOneWidget);
  });

  testWidgets(
    'sin fotos, respeta permiso limitado de lote y funciona en móvil',
    (tester) async {
      final api = _ApiEdicion();
      final sesion = SesionControlador(AutenticacionRepository(api));
      addTearDown(sesion.dispose);
      sesion.sesion = Sesion(
        token: '',
        usuario: 'fotografo',
        nombreCompleto: '',
        rol: 'FOTOS',
        roles: const {},
        permisos: const {'PRODUCTORES_VER', 'NUMERO_LOTE_EDITAR'},
        centralId: 20,
        expiraEn: DateTime(2100),
      );
      await _abrir(tester, api, sesion: sesion, ancho: 430);
      expect(tester.widget<TextField>(campo(1, 'nombres')).enabled, isFalse);
      expect(tester.widget<TextField>(campo(1, 'ci')).enabled, isFalse);
      expect(tester.widget<TextField>(campo(1, 'numeroLote')).enabled, isTrue);
      expect(find.byKey(const ValueKey('sie-1')), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byTooltip('Nuevo productor'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Abrir editor'), findsOneWidget);
    },
  );

  testWidgets(
    'rol registro de central crea sin habilitar identidad existente ni SIE',
    (tester) async {
      final api = _ApiEdicion();
      final sesion = SesionControlador(AutenticacionRepository(api));
      addTearDown(sesion.dispose);
      sesion.sesion = Sesion(
        token: '',
        usuario: 'registro',
        nombreCompleto: '',
        rol: 'OPERADOR',
        roles: const {'REGISTRO_PRODUCTORES_CENTRAL'},
        permisos: const {
          'PRODUCTORES_VER',
          'PRODUCTORES_REGISTRAR',
          'NUMERO_LOTE_EDITAR',
        },
        centralId: 20,
        expiraEn: DateTime(2100),
      );
      await _abrir(tester, api, sesion: sesion, ancho: 430);
      expect(tester.widget<TextField>(campo(1, 'nombres')).enabled, isFalse);
      expect(tester.widget<TextField>(campo(1, 'ci')).enabled, isFalse);
      expect(find.byKey(const ValueKey('sie-1')), findsNothing);
      await tester.tap(find.byTooltip('Nuevo productor'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Verificar cédula'), findsNothing);
      await tester.enterText(campoAlta('Cédula de identidad *'), '777');
      await tester.enterText(campoAlta('Nombres *'), 'ALBERTO');
      await tester.enterText(campoAlta('Apellidos'), 'NUEVO');
      await tester.ensureVisible(find.text('Registrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(api.altas, hasLength(1));
      expect(api.verificacionesSie, isEmpty);
      expect(tester.widget<TextField>(campo(3, 'nombres')).enabled, isFalse);
      expect(find.byKey(const ValueKey('sie-3')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('registro completo de central edita identidad y revisa SIE', (
    tester,
  ) async {
    final api = _ApiEdicion();
    final sesion = SesionControlador(AutenticacionRepository(api));
    addTearDown(sesion.dispose);
    sesion.sesion = Sesion(
      token: '',
      usuario: 'registro',
      nombreCompleto: '',
      rol: 'OPERADOR',
      roles: const {'REGISTRO_PRODUCTORES_CENTRAL'},
      permisos: const {
        'PRODUCTORES_VER',
        'PRODUCTORES_EDITAR',
        'SIE_REVISAR',
        'LOTES_EDITAR',
        'IMAGENES_EDITAR',
      },
      centralId: 20,
      expiraEn: DateTime(2100),
    );
    await _abrir(tester, api, sesion: sesion, ancho: 1200);
    expect(tester.widget<TextField>(campo(1, 'nombres')).enabled, isTrue);
    expect(tester.widget<TextField>(campo(1, 'ci')).enabled, isTrue);
    expect(tester.widget<TextField>(campo(1, 'numeroLote')).enabled, isTrue);
    expect(find.byKey(const ValueKey('sie-1')), findsOneWidget);
    await tester.enterText(campo(1, 'nombres'), 'MARÍA ELENA');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(api.cambios.single['campo'], 'nombres');
    expect(api.cambios.single['valor'], 'MARÍA ELENA');
    await tester.tap(find.byKey(const ValueKey('sie-1')));
    await tester.pumpAndSettle();
    expect(api.verificacionesSie, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('se puede entrar desde la lista de un sindicato', (tester) async {
    final api = _ApiEdicion();
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: api),
        child: MaterialApp(
          home: SindicatoProductoresPagina(sindicato: sindicato),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edición rápida de productores'));
    await tester.pumpAndSettle();
    expect(find.byType(EdicionProductoresSindicatoPagina), findsOneWidget);
  });

  testWidgets('SIE espera el guardado de CI y evita consultas duplicadas', (
    tester,
  ) async {
    final api = _ApiEdicion()..bloqueo = Completer<void>();
    await _abrir(tester, api);
    await tester.enterText(campo(1, 'ci'), '888');
    await tester.tap(find.byKey(const ValueKey('sie-1')));
    await tester.pump();
    expect(api.verificacionesSie, isEmpty);
    expect(tester.widget<TextField>(campo(1, 'ci')).enabled, isFalse);
    expect(
      tester.widget<TextButton>(find.byKey(const ValueKey('sie-2'))).onPressed,
      isNull,
    );
    api.bloqueo!.complete();
    await tester.pumpAndSettle();
    expect(api.verificacionesSie, [
      {'id': 1, 'ci': '888'},
    ]);
    expect(find.text('Resultado de revisión SIE'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(find.text('Verificado en SIE'), findsOneWidget);
    expect(tester.widget<TextField>(campo(1, 'ci')).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'aceptar SIE actualiza solo esa fila y mantiene reimpresión al salir',
    (tester) async {
      final api = _ApiEdicion()..estadoSie = 'REQUIERE_CONFIRMACION';
      api.datos[1]!['credencialImpresiones'] = 1;
      await _abrir(tester, api);
      final posicion = tester.getTopLeft(campo(1, 'nombres'));
      await tester.tap(find.byKey(const ValueKey('sie-1')));
      await tester.pumpAndSettle();
      expect(find.text('Datos actuales:'), findsOneWidget);
      expect(find.text('MARIA PEREZ'), findsOneWidget);
      expect(find.text('ELENA ROJAS'), findsOneWidget);
      expect(api.datos[1]!['nombres'], 'MARIA');
      await tester.tap(find.text('Aceptar sugerencia SIE'));
      await tester.pumpAndSettle();
      expect(api.decisionesSie, ['aceptar']);
      expect(
        tester.widget<TextField>(campo(1, 'nombres')).controller!.text,
        'ELENA',
      );
      expect(
        tester.widget<TextField>(campo(1, 'apellidos')).controller!.text,
        'ROJAS',
      );
      expect(
        tester.widget<TextField>(campo(2, 'nombres')).controller!.text,
        'JUAN',
      );
      expect(tester.getTopLeft(campo(1, 'nombres')), posicion);
      expect(api.cambios, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Agregar para reimpresión?'), findsOneWidget);
      await tester.tap(find.text('Ahora no'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('aprobar datos existentes conserva nombres ante diferencia SIE', (
    tester,
  ) async {
    final api = _ApiEdicion()..estadoSie = 'REQUIERE_CONFIRMACION';
    await _abrir(tester, api);
    await tester.tap(find.byKey(const ValueKey('sie-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aprobar datos existentes'));
    await tester.pumpAndSettle();
    expect(api.decisionesSie, ['aprobar']);
    expect(
      tester.widget<TextField>(campo(1, 'nombres')).controller!.text,
      'MARIA',
    );
    expect(find.text('Aprobado manualmente'), findsOneWidget);
    expect(api.datos[1]!['revisionSieBloqueaImpresion'], isFalse);
  });

  testWidgets(
    'dejar pendiente no sustituye identidad ni aprueba automáticamente',
    (tester) async {
      final api = _ApiEdicion()..estadoSie = 'REQUIERE_CONFIRMACION';
      await _abrir(tester, api);
      await tester.tap(find.byKey(const ValueKey('sie-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dejar pendiente'));
      await tester.pumpAndSettle();
      expect(api.decisionesSie, isEmpty);
      expect(find.text('Diferencia pendiente'), findsOneWidget);
      expect(api.datos[1]!['nombres'], 'MARIA');
      expect(api.datos[1]!['revisionSieBloqueaImpresion'], isTrue);
    },
  );

  testWidgets('SIE no encontrado muestra advertencia y no modifica nombres', (
    tester,
  ) async {
    final api = _ApiEdicion()..estadoSie = 'ACEPTADA_SIN_COINCIDENCIA';
    await _abrir(tester, api);
    await tester.tap(find.byKey(const ValueKey('sie-1')));
    await tester.pumpAndSettle();
    expect(find.text('No encontrado en SIE'), findsNWidgets(2));
    expect(find.text('Aceptar sugerencia SIE'), findsNothing);
    await tester.tap(find.text('Dejar pendiente'));
    await tester.pumpAndSettle();
    expect(api.datos[1]!['nombres'], 'MARIA');
    expect(api.decisionesSie, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin CI o con guardado fallido no se consulta SIE', (
    tester,
  ) async {
    final api = _ApiEdicion();
    api.datos[1]!['ci'] = null;
    await _abrir(tester, api);
    await tester.tap(find.byKey(const ValueKey('sie-1')));
    await tester.pumpAndSettle();
    expect(api.verificacionesSie, isEmpty);
    api.fallar = true;
    await tester.enterText(campo(1, 'ci'), '999');
    await tester.tap(find.byKey(const ValueKey('sie-1')));
    await tester.pumpAndSettle();
    expect(api.verificacionesSie, isEmpty);
    expect(find.text('Cédula vetada'), findsOneWidget);
  });

  testWidgets('SIE no disponible permite reintentar sin marcar verificado', (
    tester,
  ) async {
    final api = _ApiEdicion()..estadoSie = 'NO_DISPONIBLE';
    await _abrir(tester, api);
    await tester.tap(find.byKey(const ValueKey('sie-1')));
    await tester.pumpAndSettle();
    expect(find.text('Verificado en SIE'), findsNothing);
    expect(
      tester.widget<TextButton>(find.byKey(const ValueKey('sie-1'))).onPressed,
      isNotNull,
    );
    api.estadoSie = 'VERIFICADA';
    await tester.tap(find.byKey(const ValueKey('sie-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
    expect(api.verificacionesSie.length, 2);
    expect(find.text('Verificado en SIE'), findsOneWidget);
  });

  testWidgets('título incluye el sindicato y la central', (tester) async {
    await _abrir(tester, _ApiEdicion());
    final appBar = find.byType(AppBar);
    expect(
      find.descendant(
        of: appBar,
        matching: find.text('Edición de productores · SINDICATO DE PRUEBA'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: appBar,
        matching: find.text('Central: CENTRAL DE PRUEBA'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'observación exige nota y se puede editar y quitar sin cambiar la ficha',
    (tester) async {
      final api = _ApiEdicion();
      await _abrir(tester, api);
      final boton = find.byKey(const ValueKey('observacion-1'));
      final posicion = tester.getTopLeft(campo(1, 'nombres'));
      await tester.tap(boton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar observación'));
      await tester.pumpAndSettle();
      expect(find.text('Escribí el motivo de la observación'), findsOneWidget);
      expect(api.observaciones, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('motivo-observacion')),
        'Revisar CI original',
      );
      await tester.tap(find.text('Guardar observación'));
      await tester.pumpAndSettle();
      expect(api.observaciones, [
        {'id': 1, 'texto': 'Revisar CI original'},
      ]);
      expect(find.text('Observado'), findsOneWidget);
      expect(api.datos[1]!['observado'], isTrue);
      expect(api.datos[1]!['nombres'], 'MARIA');
      expect(api.datos[1]!['clasificacion'], 'FRACCIONADO');
      expect(api.datos[2]!['observado'], isNull);
      expect(tester.getTopLeft(campo(1, 'nombres')), posicion);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('motivo-observacion')),
            )
            .initialValue,
        'Revisar CI original',
      );
      await tester.enterText(
        find.byKey(const ValueKey('motivo-observacion')),
        'Revisión general',
      );
      await tester.tap(find.text('Guardar observación'));
      await tester.pumpAndSettle();
      expect(api.datos[1]!['observacion'], 'Revisión general');
      await tester.tap(boton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar observación'));
      await tester.pumpAndSettle();
      expect(find.text('Observado'), findsNothing);
      expect(api.datos[1]!['observado'], isFalse);
      expect(api.cambios, isEmpty);
      expect(api.reimpresiones, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('un fallo de observación conserva la nota para reintentar', (
    tester,
  ) async {
    final api = _ApiEdicion()..fallarObservacion = true;
    await _abrir(tester, api);
    final boton = find.byKey(const ValueKey('observacion-1'));
    await tester.tap(boton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('motivo-observacion')),
      'Nota a conservar',
    );
    await tester.tap(find.text('Guardar observación'));
    await tester.pumpAndSettle();
    expect(find.text('Observado'), findsNothing);
    expect(find.text('Nota sin guardar'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hay cambios sin guardar'), findsOneWidget);
    await tester.tap(find.text('Volver a corregir'));
    await tester.pumpAndSettle();
    api.fallarObservacion = false;
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('motivo-observacion')),
          )
          .initialValue,
      'Nota a conservar',
    );
    await tester.tap(find.text('Guardar observación'));
    await tester.pumpAndSettle();
    expect(find.text('Observado'), findsOneWidget);
  });

  testWidgets('marcar observado no pierde borradores de identidad inválidos', (
    tester,
  ) async {
    final api = _ApiEdicion();
    await _abrir(tester, api);
    await tester.enterText(campo(1, 'nombres'), '');
    await tester.tap(find.byKey(const ValueKey('observacion-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('motivo-observacion')),
      'Revisar datos',
    );
    await tester.tap(find.text('Guardar observación'));
    await tester.pumpAndSettle();
    expect(find.text('Observado'), findsOneWidget);
    expect(tester.widget<TextField>(campo(1, 'nombres')).controller!.text, '');
    expect(find.text('Este campo no puede quedar vacío'), findsOneWidget);
  });

  testWidgets(
    'usuario de central puede observar en móvil con teclado, sin otros permisos',
    (tester) async {
      final api = _ApiEdicion();
      final sesion = SesionControlador(AutenticacionRepository(api));
      addTearDown(sesion.dispose);
      sesion.sesion = Sesion(
        token: '',
        usuario: 'fotografo',
        nombreCompleto: '',
        rol: 'FOTOS',
        roles: const {},
        permisos: const {'PRODUCTORES_VER', 'PRODUCTORES_OBSERVAR'},
        centralId: 20,
        expiraEn: DateTime(2100),
      );
      api.datos[1]!['observado'] = true;
      api.datos[1]!['observacion'] = 'Revisar documento';
      await _abrir(tester, api, sesion: sesion, ancho: 430);
      expect(find.text('Central: CENTRAL DE PRUEBA'), findsOneWidget);
      expect(tester.widget<TextField>(campo(1, 'nombres')).enabled, isFalse);
      expect(find.byKey(const ValueKey('sie-1')), findsNothing);
      final boton = find.byKey(const ValueKey('observacion-1'));
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 340);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      final motivo = find.byKey(const ValueKey('motivo-observacion'));
      expect(motivo, findsOneWidget);
      expect(find.text('Quitar observación'), findsNothing);
      await tester.enterText(motivo, 'Revisar fotografía');
      await tester.ensureVisible(find.text('Guardar observación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar observación'));
      await tester.pumpAndSettle();
      expect(api.datos[1]!['observacion'], 'Revisar fotografía');
      expect(tester.takeException(), isNull);
    },
  );
}

class _ApiEdicion extends ApiClient {
  final datos = <int, Map<String, dynamic>>{
    1: _productor(1, 'MARIA', 'PEREZ', '10'),
    2: _productor(2, 'JUAN', 'ZARATE', '2'),
  };
  final consultas = <Map<String, dynamic>>[];
  final cambios = <Map<String, dynamic>>[];
  final lotes = <Object?>[];
  final reimpresiones = <int>[];
  final altas = <Map<String, dynamic>>[];
  bool fallarRefrescoAlta = false;
  Completer<void>? bloqueo;
  bool fallar = false;
  String? extension;
  String estadoSie = 'VERIFICADA';
  final verificacionesSie = <Map<String, dynamic>>[];
  final decisionesSie = <String>[];
  final observaciones = <Map<String, dynamic>>[];
  bool fallarObservacion = false;

  static Map<String, dynamic> _productor(
    int id,
    String nombres,
    String apellidos,
    String lote,
  ) => {
    'id': id,
    'nombres': nombres,
    'apellidos': apellidos,
    'nombreCompleto': '$nombres $apellidos',
    'ci': '123',
    'sindicatoId': 30,
    'sindicatoNombre': 'SINDICATO DE PRUEBA',
    'centralId': 20,
    'centralNombre': 'CENTRAL DE PRUEBA',
    'numeroLote': lote,
    'clasificacion': 'FRACCIONADO',
    'fotoDescripcion': 'Foto existente',
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta.startsWith('/productores/por-cedula/')) return <dynamic>[];
    if (RegExp(r'^/productores/\d+$').hasMatch(ruta)) {
      return {
        'productor': Map<String, dynamic>.of(
          datos[int.parse(ruta.split('/').last)]!,
        ),
        'lotes': [],
        'imagenes': [],
      };
    }
    if (ruta == '/lotes') {
      return extension == null
          ? <dynamic>[]
          : [
              {
                'id': 9,
                'numero': '22',
                'extension': extension,
                'codigo': '22-$extension',
                'sindicatoId': 30,
                'sindicatoNombre': 'SINDICATO DE PRUEBA',
              },
            ];
    }
    if (ruta == '/productores') {
      if (fallarRefrescoAlta && altas.isNotEmpty) {
        throw const ApiException(
          estado: 503,
          mensaje: 'Servidor no disponible',
        );
      }
      consultas.add({...query!});
      final p = (query['page'] as int?) ?? 0;
      final productores = datos.values.toList();
      return {
        'content': p < productores.length
            ? [Map<String, dynamic>.of(productores[p])]
            : <dynamic>[],
        'page': {
          'size': 1,
          'number': p,
          'totalElements': datos.length,
          'totalPages': datos.length,
        },
      };
    }
    throw StateError('Consulta inesperada: $ruta');
  }

  @override
  Future<Object?> parchear(String ruta, {Object? cuerpo}) async {
    final id = int.parse(ruta.split('/')[2]);
    final mapa = cuerpo as Map<String, dynamic>;
    if (ruta.endsWith('/observacion')) {
      if (fallarObservacion) {
        throw const ApiException(
          estado: 500,
          mensaje: 'No se pudo guardar la observación',
        );
      }
      observaciones.add({'id': id, ...mapa});
      datos[id]!['observado'] = true;
      datos[id]!['observacion'] = mapa['texto'];
      return Map<String, dynamic>.of(datos[id]!);
    }
    cambios.add({'id': id, ...mapa});
    if (bloqueo != null) await bloqueo!.future;
    if (fallar) throw const ApiException(estado: 409, mensaje: 'Cédula vetada');
    final valor = (mapa['valor'] as String).toUpperCase();
    if (datos[id]![mapa['campo']] != valor &&
        (datos[id]!['revisionSiePendiente'] == true ||
            datos[id]!['revisionSieEstado'] != null)) {
      datos[id]!['revisionSiePendiente'] = false;
      datos[id]!['revisionSieEstado'] = 'CORREGIDO_MANUAL';
      datos[id]!['revisionSieBloqueaImpresion'] = false;
    }
    datos[id]![mapa['campo']] = valor;
    return Map<String, dynamic>.of(datos[id]!);
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    final mapa = cuerpo as Map<String, dynamic>;
    lotes.add(mapa);
    datos[1]!['numeroLote'] = '4 B';
    datos[2]!['numeroLote'] = '4 A';
    return {
      'id': 1,
      'numero': mapa['numero'],
      'codigo': '4 B',
      'sindicatoId': 30,
      'sindicatoNombre': 'SINDICATO DE PRUEBA',
    };
  }

  @override
  Future<Object?> eliminarConRespuesta(
    String ruta, {
    Map<String, dynamic>? query,
  }) async {
    final id = int.parse(ruta.split('/')[2]);
    datos[id]!['observado'] = false;
    datos[id]!['observacion'] = null;
    return Map<String, dynamic>.of(datos[id]!);
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    if (ruta == '/personas/consulta') {
      return {'estado': 'NO_ENCONTRADA', 'mensaje': 'Sin datos de SIE'};
    }
    if (ruta == '/productores') {
      final mapa = cuerpo as Map<String, dynamic>;
      altas.add(Map<String, dynamic>.of(mapa));
      final id = datos.length + 1;
      datos[1]!['numeroLote'] = '10 A';
      datos[id] = {
        ..._productor(
          id,
          mapa['nombres'] as String,
          mapa['apellidos'] as String,
          '',
        ),
        'ci': mapa['ci'],
        'numeroLote': null,
        'revisionSiePendiente': true,
      };
      return Map<String, dynamic>.of(datos[id]!);
    }
    final id = int.parse(ruta.split('/')[2]);
    final p = datos[id]!;
    if (ruta.endsWith('/verificacion-sie')) {
      verificacionesSie.add({'id': id, 'ci': p['ci']});
      if (estadoSie != 'NO_DISPONIBLE') {
        p['revisionSiePendiente'] = false;
        p['revisionSieEstado'] = estadoSie == 'REQUIERE_CONFIRMACION'
            ? 'DIFERENCIA_PENDIENTE'
            : estadoSie == 'ACEPTADA_SIN_COINCIDENCIA'
            ? 'NO_ENCONTRADO'
            : 'VERIFICADO';
        p['revisionSieBloqueaImpresion'] = estadoSie != 'VERIFICADA';
      }
      return {
        'estado': estadoSie,
        'completada':
            estadoSie != 'NO_DISPONIBLE' &&
            estadoSie != 'REQUIERE_CONFIRMACION',
        'datosModificados': false,
        'mensaje': estadoSie == 'NO_DISPONIBLE'
            ? 'Servicio SIE no disponible'
            : 'Consulta SIE realizada',
        'actuales': {
          'ci': p['ci'],
          'nombres': p['nombres'],
          'apellidos': p['apellidos'],
        },
        'propuestos': {'ci': p['ci'], 'nombres': 'ELENA', 'apellidos': 'ROJAS'},
      };
    }
    if (ruta.endsWith('/revision-sie/confirmacion') ||
        ruta.endsWith('/revision-sie/aprobacion-manual')) {
      final aceptar = ruta.endsWith('/confirmacion');
      decisionesSie.add(aceptar ? 'aceptar' : 'aprobar');
      if (aceptar) {
        p['nombres'] = 'ELENA';
        p['apellidos'] = 'ROJAS';
      }
      p['revisionSieEstado'] = aceptar ? 'CORREGIDO_SIE' : 'APROBADO_MANUAL';
      p['revisionSieBloqueaImpresion'] = false;
      return {
        'estado': aceptar ? 'CORREGIDA' : 'APROBADA_MANUAL',
        'completada': true,
        'datosModificados': aceptar,
        'mensaje': 'Revisión finalizada',
      };
    }
    reimpresiones.add(int.parse(ruta.split('/')[2]));
    return null;
  }
}
