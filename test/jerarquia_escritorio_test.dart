import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/jerarquia/jerarquia_pagina.dart';
import 'package:fede/ui/jerarquia/sindicato_productores_pagina.dart';
import 'package:fede/ui/inicio.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';
import 'package:fede/ui/productores/fila_productor.dart';
import 'package:fede/ui/productores/imagenes_productor.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/sesion_scope.dart';
import 'miniatura_prueba.dart';

Future<void> _editarTelefonoDesdeMenu(
  WidgetTester tester, {
  required String nombre,
  required String actual,
  required String nuevo,
}) async {
  final primeraOpcion = find.byType(PopupMenuItem<String>).first;
  expect(
    tester.widget<PopupMenuItem<String>>(primeraOpcion).value,
    'editarTelefono',
  );
  await tester.tap(primeraOpcion);
  await tester.pumpAndSettle();
  final dialogo = find.byType(AlertDialog);
  expect(
    find.descendant(of: dialogo, matching: find.text(nombre)),
    findsOneWidget,
  );
  final campo = find.widgetWithText(TextFormField, 'Número de teléfono');
  expect(tester.widget<TextFormField>(campo).initialValue, actual);
  final entrada = find.descendant(
    of: campo,
    matching: find.byType(EditableText),
  );
  expect(tester.widget<EditableText>(entrada).focusNode.hasFocus, isTrue);
  await tester.enterText(campo, nuevo);
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
  expect(dialogo, findsNothing);
  expect(find.text('Teléfono actualizado'), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    await (FontLoader('JerarquiaTablet')..addFont(
          Future.value(
            ByteData.sublistView(
              File('test/fixtures/fonts/roboto-regular.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });

  for (final ancho in [430.0, 1400.0]) {
    testWidgets(
      'acciones e informes seleccionan su fila sin navegar por accidente, $ancho px',
      (tester) async {
        tester.view.physicalSize = Size(ancho, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = _ApiSeleccionJerarquia();
        addTearDown(api.cerrar);
        final tema = PreferenciaTema();
        addTearDown(tema.dispose);
        await tester.pumpWidget(
          TemaScope(
            preferencia: tema,
            child: PadronScope(
              padron: Padron(api: api),
              child: const MaterialApp(home: JerarquiaPagina()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final alfa = find.byKey(const ValueKey('central-19'));
        final central = find.byKey(const ValueKey('central-20'));
        expect(find.text('ALF (74311223)'), findsOneWidget);
        expect(tester.widget<ListTile>(alfa).selected, isFalse);
        await tester.tap(
          find.descendant(of: alfa, matching: find.byTooltip('Acciones')),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(alfa).selected, isTrue);
        expect(tester.widget<ListTile>(central).selected, isFalse);
        await _editarTelefonoDesdeMenu(
          tester,
          nombre: 'ALFA CENTRAL',
          actual: '74311223',
          nuevo: '+591 70001001',
        );
        expect(api.telefonos['/centrales/19/directorio'], '+591 70001001');
        expect(find.text('ALF (+591 70001001)'), findsOneWidget);
        expect(tester.widget<ListTile>(alfa).selected, isTrue);

        await tester.tap(
          find.descendant(
            of: central,
            matching: find.byTooltip('Informes y reportes central'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Informes y reportes de la central'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(central).selected, isTrue);
        expect(tester.widget<ListTile>(alfa).selected, isFalse);

        await tester.tap(find.text('CENTRAL DE PRUEBA'));
        await tester.pumpAndSettle();
        final uno = find.byKey(const ValueKey('sindicato-30'));
        final dos = find.byKey(const ValueKey('sindicato-31'));
        expect(
          find.descendant(of: uno, matching: find.text('(74550123)')),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(of: dos, matching: find.byTooltip('Acciones')),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(dos).selected, isTrue);
        await _editarTelefonoDesdeMenu(
          tester,
          nombre: 'SINDICATO DOS',
          actual: '',
          nuevo: '+591 70001002',
        );
        expect(api.telefonos['/sindicatos/31/directorio'], '+591 70001002');
        expect(
          find.descendant(of: dos, matching: find.text('Total: 6')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dos, matching: find.text('(+591 70001002)')),
          findsOneWidget,
        );
        expect(tester.widget<ListTile>(dos).selected, isTrue);
        expect(find.byType(SindicatoProductoresPagina), findsNothing);

        await tester.tap(
          find.descendant(
            of: uno,
            matching: find.byTooltip('Informes y reportes del sindicato'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Informes y reportes del sindicato'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(uno).selected, isTrue);
        expect(tester.widget<ListTile>(dos).selected, isFalse);
        expect(find.byType(SindicatoProductoresPagina), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'el menú de acciones del usuario limitado también selecciona el sindicato',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiSeleccionJerarquia();
      addTearDown(api.cerrar);
      final tema = PreferenciaTema();
      addTearDown(tema.dispose);
      final sesion = SesionControlador(AutenticacionRepository(api));
      addTearDown(sesion.dispose);
      sesion.sesion = Sesion(
        token: 'prueba',
        usuario: 'operador',
        nombreCompleto: 'Operador',
        rol: 'OPERADOR',
        roles: const {},
        permisos: const {'PRODUCTORES_VER', 'LOTES_EDITAR'},
        centralId: 20,
        expiraEn: DateTime(2100),
      );
      await tester.pumpWidget(
        TemaScope(
          preferencia: tema,
          child: PadronScope(
            padron: Padron(api: api),
            child: SesionScope(
              controlador: sesion,
              child: const MaterialApp(home: JerarquiaPagina()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CENTRAL DE PRUEBA'));
      await tester.pumpAndSettle();
      final sindicato = find.byKey(const ValueKey('sindicato-31'));
      await tester.tap(
        find.descendant(of: sindicato, matching: find.byTooltip('Acciones')),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(sindicato).selected, isTrue);
      expect(find.text('Parcelas'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(sindicato).selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final plataforma in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final ancho in [600.0, 768.0, 1024.0]) {
      testWidgets('jerarquía de tablet $plataforma a $ancho px', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = plataforma;
        try {
          tester.view.physicalSize = Size(ancho, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final api = _ApiFichaJerarquia();
          addTearDown(api.cerrar);
          final tema = PreferenciaTema();
          addTearDown(tema.dispose);
          await tester.pumpWidget(
            TemaScope(
              preferencia: tema,
              child: PadronScope(
                padron: Padron(api: api),
                child: MaterialApp(
                  theme: ThemeData(fontFamily: 'JerarquiaTablet'),
                  home: const Inicio(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Centrales'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('CENTRAL DE PRUEBA'));
          await tester.pumpAndSettle();
          if (ancho < 900) {
            expect(
              find
                  .byTooltip('Cambiar central: CENTRAL DE PRUEBA')
                  .hitTestable(),
              findsOneWidget,
            );
          }
          await tester.tap(find.text('SINDICATO UNO'));
          await tester.pumpAndSettle();
          expect(find.byType(FilaProductor), findsNWidgets(2));
          await tester.tap(find.byType(FilaProductor).first);
          await tester.pumpAndSettle();
          final ficha = find.byType(ProductorDetallePagina);
          expect(ficha.hitTestable(), findsOneWidget);
          for (final nombre in ['CENTRAL DE PRUEBA', 'SINDICATO UNO']) {
            expect(
              find
                  .descendant(
                    of: find.byType(RotatedBox),
                    matching: find.text(nombre),
                  )
                  .hitTestable(),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);

          if (ancho == 768) {
            final estadoFicha = tester.state(ficha);
            tester.view.physicalSize = const Size(1280, 800);
            await tester.pumpAndSettle();
            expect(tester.state(ficha), same(estadoFicha));
            expect(find.byType(FilaProductor), findsNWidgets(2));
            tester.view.physicalSize = Size(ancho, 1100);
            await tester.pumpAndSettle();
            expect(tester.state(ficha), same(estadoFicha));
            expect(tester.takeException(), isNull);
          }

          await tester.tap(find.byTooltip('Cambiar sindicato: SINDICATO UNO'));
          await tester.pumpAndSettle();
          expect(ficha, findsNothing);
          expect(find.text('Sindicatos de CENTRAL DE PRUEBA'), findsOneWidget);
          if (ancho < 900) {
            await tester.tap(
              find.byTooltip('Cambiar central: CENTRAL DE PRUEBA'),
            );
            await tester.pumpAndSettle();
            expect(find.text('Centrales de CARRASCO TROPICAL'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }

  for (final centralId in [null, 20]) {
    for (final ancho in [1700.0, 430.0]) {
      testWidgets(
        'fotos y observaciones solo navega a productores y cuenta, central $centralId, $ancho px',
        (tester) async {
          tester.view.physicalSize = Size(ancho, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final api = _ApiFichaJerarquia();
          addTearDown(api.cerrar);
          final sesion = SesionControlador(AutenticacionRepository(api));
          addTearDown(sesion.dispose);
          sesion.sesion = Sesion(
            token: 'prueba',
            usuario: 'fotografo',
            nombreCompleto: 'Fotos y observaciones',
            rol: 'OPERADOR',
            roles: const {'FOTOS_OBSERVACIONES'},
            permisos: const {
              'PRODUCTORES_VER',
              'FOTOS_PRODUCTORES_ACTUALIZAR',
              'PRODUCTORES_OBSERVAR',
            },
            centralId: centralId,
            expiraEn: DateTime(2100),
          );
          final tema = PreferenciaTema();
          addTearDown(tema.dispose);
          await tester.pumpWidget(
            TemaScope(
              preferencia: tema,
              child: PadronScope(
                padron: Padron(api: api),
                child: SesionScope(
                  controlador: sesion,
                  child: const MaterialApp(home: Inicio()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final texto in [
            'Nuevo',
            'Calidad',
            'Reuniones',
            'Carnet',
            'Personal operador',
            'Respaldos',
            'Accesos',
          ]) {
            expect(find.text(texto), findsNothing, reason: texto);
          }
          expect(
            find.byKey(const ValueKey('menu-directorio-federacion')),
            findsNothing,
          );
          expect(find.byTooltip('Papelera de productores'), findsNothing);
          await tester.tap(find.text('Centrales'));
          await tester.pumpAndSettle();
          final central = find.byKey(const ValueKey('central-20'));
          expect(
            find.descendant(
              of: central,
              matching: find.byType(PopupMenuButton<String>),
            ),
            findsNothing,
          );
          expect(find.byTooltip('Informes y reportes central'), findsNothing);
          await tester.tap(find.text('CENTRAL DE PRUEBA'));
          await tester.pumpAndSettle();
          final sindicato = find.ancestor(
            of: find.text('SINDICATO UNO'),
            matching: find.byType(ListTile),
          );
          expect(
            find.descendant(
              of: sindicato,
              matching: find.byType(PopupMenuButton<String>),
            ),
            findsNothing,
          );
          await tester.tap(find.text('SINDICATO UNO'));
          await tester.pumpAndSettle();
          expect(find.byType(FilaProductor), findsNWidgets(2));
          expect(find.text('Nuevo'), findsNothing);
          expect(find.byTooltip('Edición rápida de productores'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final centralId in [null, 20]) {
    for (final ancho in [1700, 430]) {
      testWidgets(
        'registro y revisión sin edición rápida ni directorios, central $centralId, ancho $ancho',
        (tester) async {
          tester.view.physicalSize = Size(ancho.toDouble(), 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final api = _ApiFichaJerarquia();
          final sesion = SesionControlador(AutenticacionRepository(api));
          addTearDown(sesion.dispose);
          sesion.sesion = Sesion(
            token: 'prueba',
            usuario: 'registro',
            nombreCompleto: 'Registro y revisión',
            rol: 'OPERADOR',
            roles: const {'REGISTRO_REVISION'},
            permisos: const {
              'PRODUCTORES_VER',
              'PRODUCTORES_REGISTRAR',
              'PRODUCTORES_EDITAR',
              'PRODUCTORES_ELIMINAR',
              'SIE_REVISAR',
              'FOTOS_PRODUCTORES_EDITAR',
              'PRODUCTORES_OBSERVAR',
              'NUMERO_LOTE_EDITAR',
            },
            centralId: centralId,
            expiraEn: DateTime(2100),
          );
          await tester.pumpWidget(
            TemaScope(
              preferencia: PreferenciaTema(),
              child: PadronScope(
                padron: Padron(api: api),
                child: SesionScope(
                  controlador: sesion,
                  child: const MaterialApp(home: JerarquiaPagina()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final central = find.ancestor(
            of: find.text('CENTRAL DE PRUEBA'),
            matching: find.byType(ListTile),
          );
          final menuCentral = find.descendant(
            of: central,
            matching: find.byType(PopupMenuButton<String>),
          );
          if (centralId == null) {
            await tester.tap(menuCentral);
            await tester.pumpAndSettle();
            expect(find.text('Directorio'), findsNothing);
            expect(find.text('Editar teléfono'), findsNothing);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          } else {
            expect(menuCentral, findsNothing);
          }
          await tester.tap(find.text('CENTRAL DE PRUEBA'));
          await tester.pumpAndSettle();
          final sindicato = find.ancestor(
            of: find.text('SINDICATO UNO'),
            matching: find.byType(ListTile),
          );
          final menu = find.descendant(
            of: sindicato,
            matching: find.byType(PopupMenuButton<String>),
          );
          if (centralId == null) {
            await tester.tap(menu);
            await tester.pumpAndSettle();
            expect(find.text('Edición rápida de productores'), findsNothing);
            expect(find.text('Directorio'), findsNothing);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          } else {
            expect(menu, findsNothing);
          }
          await tester.tap(find.text('SINDICATO UNO'));
          await tester.pumpAndSettle();
          expect(find.byType(SindicatoProductoresPagina), findsOneWidget);
          expect(find.byTooltip('Edición rápida de productores'), findsNothing);
          expect(find.text('Nuevo'), findsOneWidget);
          expect(find.byType(FilaProductor), findsNWidgets(2));
          expect(sesion.puede('PRODUCTORES_EDITAR'), isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final completo in [true, false]) {
    testWidgets('menú central respeta perfil completo: $completo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1700, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiJerarquia();
      final sesion = SesionControlador(AutenticacionRepository(api));
      addTearDown(sesion.dispose);
      sesion.sesion = Sesion(
        token: '',
        usuario: 'operador',
        nombreCompleto: '',
        rol: 'OPERADOR',
        roles: {completo ? 'REGISTRO_PRODUCTORES_CENTRAL' : 'REGISTRO_CENTRAL'},
        permisos: completo
            ? const {
                'PRODUCTORES_VER',
                'PRODUCTORES_EDITAR',
                'SIE_REVISAR',
                'LOTES_EDITAR',
                'IMAGENES_EDITAR',
              }
            : const {
                'PRODUCTORES_VER',
                'FOTOS_PRODUCTORES_EDITAR',
                'PRODUCTORES_OBSERVAR',
                'NUMERO_LOTE_EDITAR',
                'INFORMES_DESCARGAR',
              },
        centralId: 20,
        expiraEn: DateTime(2100),
      );
      await tester.pumpWidget(
        TemaScope(
          preferencia: PreferenciaTema(),
          child: PadronScope(
            padron: Padron(api: api),
            child: SesionScope(
              controlador: sesion,
              child: const MaterialApp(home: JerarquiaPagina()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CENTRAL DE PRUEBA'));
      await tester.pumpAndSettle();
      final sindicato = find.ancestor(
        of: find.text('SINDICATO UNO'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: sindicato,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edición rápida de productores'), findsOneWidget);
      expect(find.text('Parcelas'), completo ? findsOneWidget : findsNothing);
      expect(
        find.text('Lista física del sindicato'),
        completo ? findsOneWidget : findsNothing,
      );
      expect(find.text('Directorio'), findsNothing);
      expect(find.text('Productores vetados'), findsNothing);
      expect(find.text('Estado e impresión de Carnets'), findsNothing);
      expect(find.text('Eliminar'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final ancho in [1700, 1200, 430]) {
    testWidgets('ficha del productor adaptativa a $ancho px', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = Size(ancho.toDouble(), 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = _ApiFichaJerarquia();
        await tester.pumpWidget(
          TemaScope(
            preferencia: PreferenciaTema(),
            child: PadronScope(
              padron: Padron(api: api),
              child: const MaterialApp(home: Inicio()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Centrales'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CENTRAL DE PRUEBA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SINDICATO UNO'));
        await tester.pumpAndSettle();
        final lista = find.byType(SindicatoProductoresPagina);
        await tester.tap(find.byType(FilaProductor).first);
        await tester.pumpAndSettle();
        final ficha = find.byType(ProductorDetallePagina);
        expect(ficha, findsOneWidget);
        expect(find.text('MARÍA'), findsOneWidget);
        expect(tester.takeException(), isNull);

        if (ancho == 430) {
          expect(lista, findsNothing);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(lista, findsOneWidget);
          expect(ficha, findsNothing);
          return;
        }

        expect(
          tester.getRect(lista).right,
          lessThan(tester.getRect(ficha).left),
        );
        expect(
          tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
          isFalse,
        );
        if (ancho == 1700) {
          expect(find.text('Sindicatos de CENTRAL DE PRUEBA'), findsOneWidget);
          final estadoLista = tester.state(lista);
          final estadoFicha = tester.state(ficha);
          tester.view.physicalSize = const Size(1200, 1000);
          await tester.pumpAndSettle();
          expect(tester.state(lista), same(estadoLista));
          expect(tester.state(ficha), same(estadoFicha));
        }
        expect(
          find.byTooltip('Cambiar sindicato: SINDICATO UNO'),
          findsOneWidget,
        );

        // Cambiar de productor no debe conservar el contenido de la ficha anterior.
        await tester.tap(find.byType(FilaProductor).last);
        await tester.pumpAndSettle();
        expect(find.text('JUAN'), findsOneWidget);
        expect(find.text('MARÍA'), findsNothing);
        expect(tester.takeException(), isNull);

        if (ancho == 1700) {
          await tester.tap(find.byTooltip('Marcar como observado'));
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField), 'Revisar datos');
          await tester.tap(find.text('Guardar observación'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FilaProductor>(find.byType(FilaProductor).last)
                .productor
                .observado,
            isTrue,
          );
          expect(ficha, findsOneWidget);
          final estadoLista = tester.state(lista);
          await prepararMiniaturaPrueba(tester, '/miniatura-nueva-42.png');
          api.fotoActualizada = true;
          expect(find.byType(TabBar), findsNothing);
          tester
              .widget<ImagenesProductor>(find.byType(ImagenesProductor))
              .alCambiar();
          await tester.pumpAndSettle();
          final filaConFoto = tester.widget<FilaProductor>(
            find.byType(FilaProductor).last,
          );
          expect(filaConFoto.productor.nombres, 'JUAN ACTUALIZADO');
          expect(filaConFoto.productor.miniaturaUrl, '/miniatura-nueva-42.png');
          expect(tester.state(lista), same(estadoLista));
          expect(ficha, findsOneWidget);
        }

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(ficha, findsNothing);
        expect(lista, findsOneWidget);
        if (ancho == 1700) {
          final fila = tester.widget<FilaProductor>(
            find.byType(FilaProductor).last,
          );
          expect(fila.productor.observado, isTrue);
          expect(fila.seleccionado, isTrue);
        }
        expect(find.text('Sindicatos de CENTRAL DE PRUEBA'), findsOneWidget);
        expect(
          tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
          isTrue,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  for (final ancho in [900, 950, 988, 1099, 1100, 1120, 1156, 1200, 1400]) {
    testWidgets('abre el sindicato con menú lateral a $ancho px', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.physicalSize = Size(ancho.toDouble(), 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final api = _ApiJerarquia();
        await tester.pumpWidget(
          TemaScope(
            preferencia: PreferenciaTema(),
            child: PadronScope(
              padron: Padron(api: api),
              child: const MaterialApp(home: Inicio()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Centrales'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CENTRAL DE PRUEBA'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('SINDICATO UNO'));
        await tester.pumpAndSettle();

        expect(find.byType(SindicatoProductoresPagina), findsOneWidget);
        expect(api.ultimoSindicatoConsultado, 30);
        expect(tester.takeException(), isNull);

        if (ancho == 1400) {
          // Un sindicato abierto también debe seguir visible al estrechar la ventana.
          tester.view.physicalSize = const Size(950, 1000);
          await tester.pumpAndSettle();
          expect(find.byType(SindicatoProductoresPagina), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byType(SindicatoProductoresPagina), findsNothing);
        expect(find.text('SINDICATO UNO'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('trabaja solo con Carrasco Tropical y muestra productores', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final api = _ApiJerarquia();
      await tester.pumpWidget(
        TemaScope(
          preferencia: PreferenciaTema(),
          child: PadronScope(
            padron: Padron(api: api),
            child: const MaterialApp(home: JerarquiaPagina()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Federaciones'), findsNothing);
      expect(find.text('OTRA FEDERACIÓN'), findsNothing);
      expect(find.text('Centrales de CARRASCO TROPICAL'), findsOneWidget);
      expect(find.byTooltip('Avance general de impresión'), findsOneWidget);
      expect(find.byTooltip('Informes y reportes central'), findsNWidgets(2));

      final alfa = find.byKey(const ValueKey('central-19'));
      final central = find.byKey(const ValueKey('central-20'));
      expect(
        tester.getTopLeft(alfa).dy,
        lessThan(tester.getTopLeft(central).dy),
      );

      await tester.tap(
        find.descendant(of: central, matching: find.byTooltip('Fijar arriba')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(central).dy,
        lessThan(tester.getTopLeft(alfa).dy),
      );
      final preferencias = await SharedPreferences.getInstance();
      expect(preferencias.getStringList('jerarquia.central_fijada.carrasco'), [
        '20',
      ]);

      await tester.tap(
        find.descendant(of: alfa, matching: find.byTooltip('Fijar arriba')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 centrales fijadas arriba'), findsOneWidget);
      expect(preferencias.getStringList('jerarquia.central_fijada.carrasco'), [
        '20',
        '19',
      ]);

      await tester.tap(
        find.descendant(
          of: central,
          matching: find.byTooltip('Quitar de arriba'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(alfa).dy,
        lessThan(tester.getTopLeft(central).dy),
      );
      expect(preferencias.getStringList('jerarquia.central_fijada.carrasco'), [
        '19',
      ]);

      await tester.tap(find.byTooltip('Ordenar centrales'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Código membretado'));
      await tester.pumpAndSettle();
      expect(preferencias.getBool('jerarquia.orden_codigo.carrasco'), isTrue);
      await tester.tap(find.byTooltip('Ordenar centrales'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restablecer orden alfabético'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(alfa).dy,
        lessThan(tester.getTopLeft(central).dy),
      );
      expect(
        preferencias.getStringList('jerarquia.central_fijada.carrasco'),
        isNull,
      );

      await tester.tap(find.text('CENTRAL DE PRUEBA'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Lista física del sindicato'), findsNothing);
      expect(find.byTooltip('Directorio del sindicato'), findsNothing);
      expect(find.byTooltip('Parcelas del sindicato'), findsNothing);
      expect(find.textContaining('ubicación'), findsNothing);
      expect(find.text('2 sindicatos · 16 productores'), findsOneWidget);
      expect(find.text('Total: 10'), findsOneWidget);
      expect(find.text('Total: 6'), findsOneWidget);
      expect(find.text('Ver sus productores'), findsNothing);

      await tester.tap(find.byTooltip('Acciones').last);
      await tester.pumpAndSettle();
      expect(find.text('Parcelas'), findsOneWidget);
      expect(find.text('Directorio'), findsOneWidget);
      expect(find.text('Lista física del sindicato'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SINDICATO UNO'));
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('Cambiar federación: CARRASCO TROPICAL'),
        findsNothing,
      );
      expect(
        find.byTooltip('Cambiar central: CENTRAL DE PRUEBA'),
        findsOneWidget,
      );
      expect(find.text('Sindicatos de CENTRAL DE PRUEBA'), findsOneWidget);
      expect(
        find.text('Buscar por nombre, apellido, cédula o código'),
        findsOneWidget,
      );
      expect(
        find.text('Central CENTRAL DE PRUEBA · 0 productores'),
        findsOneWidget,
      );
      expect(api.ultimoSindicatoConsultado, 30);

      await tester.tap(find.text('SINDICATO DOS'));
      await tester.pumpAndSettle();
      expect(api.ultimoSindicatoConsultado, 31);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('muestra ambos avances al pasar sobre centrales y sindicatos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiJerarquia()..faseIniciada = true;
    await tester.pumpWidget(
      TemaScope(
        preferencia: PreferenciaTema(),
        child: PadronScope(
          padron: Padron(api: api),
          child: const MaterialApp(home: JerarquiaPagina()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('CENTRAL DE PRUEBA')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(
      find.text('Datos completos: 63% (10/16)\nAvance de impresión: 44%'),
      findsOneWidget,
    );
    await mouse.removePointer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('CENTRAL DE PRUEBA'));
    await tester.pumpAndSettle();
    expect(find.text('Total: 10'), findsOneWidget);
    expect(find.text('Total: 6'), findsOneWidget);
    expect(
      find.byTooltip('Datos completos: 70% (7/10)\nAvance de impresión: 40%'),
      findsOneWidget,
    );
  });

  testWidgets(
    'muestra el avance del sindicato y la fase cerrada de la central',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiJerarquia()..faseIniciada = true;
      final controlador = JerarquiaControlador();
      addTearDown(controlador.dispose);
      addTearDown(api.cerrar);
      await tester.pumpWidget(
        TemaScope(
          preferencia: PreferenciaTema(),
          child: PadronScope(
            padron: Padron(api: api),
            child: MaterialApp(home: JerarquiaPagina(controlador: controlador)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CENTRAL DE PRUEBA'));
      await tester.pumpAndSettle();
      final primero = find.byKey(const ValueKey('sindicato-30'));
      final segundo = find.byKey(const ValueKey('sindicato-31'));
      Finder estado(Finder fila, String texto) =>
          find.descendant(of: fila, matching: find.text(texto));
      expect(find.textContaining('fase impresión habilitada'), findsOneWidget);
      expect(find.text('Imprimiendo'), findsNothing);
      expect(find.text('Impreso'), findsNothing);

      api.estadoFaseSindicato = 'IMPRIMIENDO';
      controlador.refrescarConteos();
      await tester.pumpAndSettle();
      expect(estado(primero, 'Imprimiendo'), findsOneWidget);
      expect(estado(segundo, 'Imprimiendo'), findsNothing);

      api.estadoFaseSindicato = 'IMPRESO';
      controlador.refrescarConteos();
      await tester.pumpAndSettle();
      expect(estado(primero, 'Impreso'), findsOneWidget);
      expect(find.text('Imprimiendo'), findsNothing);

      api.faseCerrada = true;
      api.estadoFaseSindicato = null;
      controlador.refrescarConteos();
      await tester.pumpAndSettle();
      expect(find.text('Impreso'), findsNothing);
      expect(find.textContaining('fase impresión habilitada'), findsNothing);
      expect(
        estado(find.byKey(const ValueKey('central-20')), 'f1 Impreso'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('conserva el scroll de centrales al entrar y volver', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      TemaScope(
        preferencia: PreferenciaTema(),
        child: PadronScope(
          padron: Padron(api: _ApiScrollCentrales()),
          child: const MaterialApp(home: JerarquiaPagina()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const clave = PageStorageKey<String>('jerarquia-centrales');
    final lista = find.byKey(clave);
    await tester.drag(lista, const Offset(0, -1100));
    await tester.pumpAndSettle();

    final desplazamientoAntes = tester
        .state<ScrollableState>(
          find.descendant(of: lista, matching: find.byType(Scrollable)),
        )
        .position
        .pixels;
    expect(desplazamientoAntes, greaterThan(500));

    await tester.tap(find.byType(ListTile).hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Volver'), findsOneWidget);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    final listaRestaurada = find.byKey(clave);
    final desplazamientoDespues = tester
        .state<ScrollableState>(
          find.descendant(
            of: listaRestaurada,
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .pixels;
    expect(desplazamientoDespues, closeTo(desplazamientoAntes, 1));
  });
}

class _ApiJerarquia extends ApiClient {
  int? ultimoSindicatoConsultado;
  bool faseIniciada = false;
  bool faseCerrada = false;
  String? estadoFaseSindicato;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/federaciones') {
      return [
        {'id': 10, 'nombre': 'CARRASCO TROPICAL'},
        {'id': 99, 'nombre': 'OTRA FEDERACIÓN'},
      ];
    }
    if (ruta == '/federaciones/10/centrales') {
      return [
        {
          'id': 19,
          'nombre': 'ALFA CENTRAL',
          'federacionId': 10,
          'federacionNombre': 'CARRASCO TROPICAL',
        },
        {
          'id': 20,
          'nombre': 'CENTRAL DE PRUEBA',
          'federacionId': 10,
          'federacionNombre': 'CARRASCO TROPICAL',
          if (faseIniciada) 'ultimaFaseImpresionNumero': 1,
          if (faseIniciada && !faseCerrada) 'faseImpresionActivaNumero': 1,
        },
      ];
    }
    if (ruta == '/centrales/20/sindicatos') {
      return [
        {
          'id': 30,
          'nombre': 'SINDICATO UNO',
          'centralId': 20,
          'centralNombre': 'CENTRAL DE PRUEBA',
        },
        {
          'id': 31,
          'nombre': 'SINDICATO DOS',
          'centralId': 20,
          'centralNombre': 'CENTRAL DE PRUEBA',
        },
      ];
    }
    if (ruta == '/centrales/20/credenciales/impresion') {
      return {
        'centralId': 20,
        'central': 'CENTRAL DE PRUEBA',
        'federacion': 'CARRASCO TROPICAL',
        'sindicatos': 2,
        'sindicatosSinSello': 0,
        'total': 16,
        'impresos': 7,
        'pendientes': 9,
        'pendientesConFoto': 4,
        'sinFoto': 5,
        'listosParaImprimir': 4,
        'porcentajeAvance': 43.8,
        'avancesFase': faseIniciada
            ? [
                {'numeroFase': 1, 'porcentajeAvance': 43.8},
              ]
            : [],
        'detalle': [
          {
            'sindicatoId': 30,
            'sindicato': 'SINDICATO UNO',
            'selloCargado': true,
            'total': 10,
            'impresos': 4,
            'pendientes': 6,
            'pendientesConFoto': 3,
            'sinFoto': 3,
            'listosParaImprimir': 3,
            'datosCompletos': 7,
            'porcentajeAvance': 40,
            'estadoImpresionFase': estadoFaseSindicato,
          },
          {
            'sindicatoId': 31,
            'sindicato': 'SINDICATO DOS',
            'selloCargado': true,
            'total': 6,
            'impresos': 3,
            'pendientes': 3,
            'pendientesConFoto': 1,
            'sinFoto': 2,
            'listosParaImprimir': 1,
            'datosCompletos': 3,
            'porcentajeAvance': 50,
          },
        ],
      };
    }
    if (ruta == '/productores') {
      ultimoSindicatoConsultado = query?['sindicatoId'] as int?;
      return {
        'content': <dynamic>[],
        'page': {'size': 25, 'number': 0, 'totalElements': 0, 'totalPages': 0},
      };
    }
    return <dynamic>[];
  }
}

class _ApiSeleccionJerarquia extends _ApiJerarquia {
  final telefonos = <String, String?>{
    '/centrales/19/directorio': '74311223',
    '/sindicatos/30/directorio': '74550123',
    '/sindicatos/31/directorio': null,
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (telefonos.containsKey(ruta)) return _directorio(ruta);
    if (ruta == '/centrales/20/fases-impresion') {
      return {'centralId': 20, 'central': 'CENTRAL DE PRUEBA', 'historial': []};
    }
    if (ruta == '/sindicatos/30/informes/avance') {
      return {'sindicatoId': 30, 'sindicato': 'SINDICATO UNO', 'total': 0};
    }
    if (ruta == '/sindicatos/30/informes/fases') return [];
    if (ruta == '/federaciones/10/centrales' ||
        ruta == '/centrales/20/sindicatos') {
      final recurso = ruta.split('/').last;
      final filas =
          await super.obtener(ruta, query: query) as List<Map<String, Object?>>;
      return [
        for (final fila in filas)
          {
            ...fila,
            if (recurso == 'centrales' && fila['id'] == 19)
              'abreviatura': 'ALF',
            'telefono': telefonos['/$recurso/${fila['id']}/directorio'],
          },
      ];
    }
    return super.obtener(ruta, query: query);
  }

  @override
  Future<Object?> parchear(String ruta, {Object? cuerpo}) async {
    expect(ruta, endsWith('/telefono'));
    final directorio = ruta.substring(0, ruta.length - '/telefono'.length);
    expect(telefonos.containsKey(directorio), isTrue);
    telefonos[directorio] =
        (cuerpo as Map<String, Object?>)['telefono'] as String;
    return _directorio(directorio);
  }

  Map<String, Object?> _directorio(String ruta) => {
    'ambito': ruta.startsWith('/centrales/') ? 'CENTRAL' : 'SINDICATO',
    'ambitoId': int.parse(ruta.split('/')[2]),
    'telefono': telefonos[ruta],
    'puestos': [],
  };

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    if (ruta == '/centrales/20/credenciales/impresion/informe-nominal') {
      return {
        'centralId': 20,
        'central': 'CENTRAL DE PRUEBA',
        'sindicatos': [],
      };
    }
    throw StateError('Solicitud inesperada: $ruta');
  }
}

class _ApiFichaJerarquia extends _ApiJerarquia {
  bool observado = false;
  bool fotoActualizada = false;
  Map<String, dynamic> _productor(int id) => {
    'id': id,
    'nombres': id == 41
        ? 'MARÍA'
        : (fotoActualizada ? 'JUAN ACTUALIZADO' : 'JUAN'),
    'apellidos': 'PÉREZ',
    'nombreCompleto': id == 41
        ? 'MARÍA PÉREZ'
        : (fotoActualizada ? 'JUAN ACTUALIZADO PÉREZ' : 'JUAN PÉREZ'),
    'miniaturaUrl': id == 42 && fotoActualizada
        ? '/miniatura-nueva-42.png'
        : null,
    'ci': '$id',
    'sindicatoId': 30,
    'sindicatoNombre': 'SINDICATO UNO',
    'centralId': 20,
    'centralNombre': 'CENTRAL DE PRUEBA',
    'observado': id == 42 && observado,
    'observacion': id == 42 && observado ? 'Revisar datos' : null,
  };

  @override
  Future<Object?> parchear(String ruta, {Object? cuerpo}) async {
    if (ruta == '/productores/42/observacion') {
      observado = true;
      return _productor(42);
    }
    throw StateError('PATCH inesperado: $ruta');
  }

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores') {
      return {
        'content': [_productor(41), _productor(42)],
        'page': {'size': 25, 'number': 0, 'totalElements': 2, 'totalPages': 1},
      };
    }
    if (ruta == '/productores/41' || ruta == '/productores/42') {
      return {
        'productor': _productor(int.parse(ruta.split('/').last)),
        'lotes': [],
        'imagenes': [],
      };
    }
    return super.obtener(ruta, query: query);
  }
}

class _ApiScrollCentrales extends ApiClient {
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/federaciones') {
      return [
        {'id': 10, 'nombre': 'CARRASCO TROPICAL'},
      ];
    }
    if (ruta == '/federaciones/10/centrales') {
      return [
        for (var numero = 1; numero <= 40; numero++)
          {
            'id': 100 + numero,
            'nombre': 'CENTRAL ${numero.toString().padLeft(2, '0')}',
            'federacionId': 10,
            'federacionNombre': 'CARRASCO TROPICAL',
          },
      ];
    }
    if (RegExp(r'^/centrales/\d+/sindicatos$').hasMatch(ruta)) {
      return <dynamic>[];
    }
    if (RegExp(r'^/centrales/\d+/credenciales/impresion$').hasMatch(ruta)) {
      final centralId = int.parse(ruta.split('/')[2]);
      return {
        'centralId': centralId,
        'central': 'CENTRAL',
        'federacion': 'CARRASCO TROPICAL',
        'sindicatos': 0,
        'sindicatosSinSello': 0,
        'total': 0,
        'impresos': 0,
        'pendientes': 0,
        'pendientesConFoto': 0,
        'sinFoto': 0,
        'listosParaImprimir': 0,
        'porcentajeAvance': 0,
        'detalle': <dynamic>[],
      };
    }
    return <dynamic>[];
  }
}
