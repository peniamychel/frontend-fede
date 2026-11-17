import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fede/core/api_client.dart';
import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';
import 'package:fede/ui/productores/imagenes_productor.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/ui/sesion_scope.dart';
import 'package:fede/ui/lotes/lote_pagina.dart';
import 'package:fede/ui/productores/recortador_imagen.dart';
import 'package:fede/ui/productores/visor_imagen.dart';

const _central = 'CENTRAL REGIONAL DE PRODUCTORES TRECE DE JUNIO';
const _sindicato = 'SINDICATO AGRARIO PRIMERO DE MAYO DE CARRASCO TROPICAL';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // La densidad de esta ficha se verifica con la fuente de la aplicación.
    // Ahem altera el ancho de cada letra y no reproduce un móvil real.
    await (FontLoader('Roboto')..addFont(
          Future.value(
            ByteData.sublistView(
              File('test/fixtures/fonts/roboto-regular.ttf').readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });
  if (const bool.fromEnvironment('capturarFicha')) {
    TestWidgetsFlutterBinding.ensureInitialized();
    setUpAll(() async {
      final fuentes = Platform.environment['EDITOR_FUENTES']!;
      for (final fuente in [('MaterialIcons', 'materialicons-regular.otf')]) {
        await (FontLoader(fuente.$1)..addFont(
              Future.value(
                ByteData.sublistView(
                  File('$fuentes/${fuente.$2}').readAsBytesSync(),
                ),
              ),
            ))
            .load();
      }
    });
  }
  for (final tamano in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('foto pendiente visible en la ficha en $tamano', (
      tester,
    ) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiDetalle(
        conFoto: true,
        conLote: true,
        datosAdicionales: {'fotografiaPendienteEdicion': true},
      );
      addTearDown(api.cerrar);
      await _abrirIntegrada(tester, api);
      expect(find.text('Fotografía pendiente de edición'), findsOneWidget);
      final cuadro = tester.getSize(
        find.descendant(
          of: find.byType(ImagenesProductor),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(cuadro.height, cuadro.width);
      expect(tester.takeException(), isNull);
    });
  }
  for (final tamano in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(640, 360),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1280, 720),
    const Size(1920, 1080),
  ]) {
    testWidgets('ficha completa accesible en $tamano', (tester) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tema = PreferenciaTema();
      addTearDown(tema.dispose);
      final api = _ApiDetalle(conLote: true);
      addTearDown(api.cerrar);
      await tester.pumpWidget(
        TemaScope(
          preferencia: tema,
          child: PadronScope(
            padron: Padron(api: api),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: 'Roboto',
                colorScheme: const bool.fromEnvironment('capturarFicha')
                    ? ColorScheme.fromSeed(
                        seedColor: const Color(0xFF2E6B4F),
                        brightness: Brightness.dark,
                      )
                    : null,
              ),
              home: const ProductorDetallePagina(productorId: 42),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(ImagenesProductor).hitTestable(), findsOneWidget);
      final cuadro = tester.getSize(
        find.descendant(
          of: find.byType(ImagenesProductor),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(cuadro.height, cuadro.width);
      if (const bool.fromEnvironment('capturarFicha')) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../build/ficha-completa/${tamano.width.toInt()}x${tamano.height.toInt()}.png',
          ),
        );
      }
      for (final texto in ['Parcela', 'Revisiones y antecedentes']) {
        await tester.ensureVisible(find.text(texto));
        await tester.pumpAndSettle();
        expect(find.text(texto).hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      final ficha = find.byKey(const ValueKey('ficha-integrada'));
      for (final hijo in [
        find.byType(ImagenesProductor),
        find.text('Parcela'),
        find.text('Revisiones y antecedentes'),
      ]) {
        expect(find.descendant(of: ficha, matching: hijo), findsOneWidget);
      }
      expect(find.byTooltip('Editar').hitTestable(), findsOneWidget);
      expect(find.text('Sindicato: $_sindicato'), findsOneWidget);
      expect(api.creaciones, isEmpty);
    });
  }
  for (final centralId in [null, 3]) {
    for (final conFoto in [false, true]) {
      for (final ancho in [390.0, 1100.0]) {
        testWidgets(
          'fotos y observaciones sin permisos adicionales, central $centralId, foto $conFoto, $ancho px',
          (tester) async {
            tester.view.physicalSize = Size(ancho, 1800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final api = _ApiDetalle(
              conFoto: conFoto,
              conLote: true,
              revisionSiePendiente: true,
            );
            addTearDown(api.cerrar);
            final sesion = SesionControlador(AutenticacionRepository(api));
            addTearDown(sesion.dispose);
            sesion.sesion = Sesion(
              token: 'prueba',
              usuario: 'fotografo',
              nombreCompleto: 'Fotos y observaciones',
              rol: 'OPERADOR',
              roles: const {'FOTOS_OBSERVACIONES'},
              centralId: centralId,
              permisos: const {
                'PRODUCTORES_VER',
                'FOTOS_PRODUCTORES_ACTUALIZAR',
                'PRODUCTORES_OBSERVAR',
              },
              expiraEn: DateTime(2100),
            );
            final tema = PreferenciaTema();
            addTearDown(tema.dispose);
            await tester.pumpWidget(
              TemaScope(
                preferencia: tema,
                child: SesionScope(
                  controlador: sesion,
                  child: PadronScope(
                    padron: Padron(api: api),
                    child: const MaterialApp(
                      home: ProductorDetallePagina(productorId: 42),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final imagenes = tester.widget<ImagenesProductor>(
              find.byType(ImagenesProductor),
            );
            expect(imagenes.editable, isTrue);
            expect(imagenes.borrable, isFalse);
            expect(
              ancho < 740
                  ? find.byTooltip(conFoto ? 'Reemplazar' : 'Subir foto')
                  : find.text(conFoto ? 'Reemplazar' : 'Subir foto'),
              findsOneWidget,
            );
            expect(
              ancho < 740
                  ? find.byTooltip('Editar fotografía')
                  : find.text('Editar'),
              conFoto ? findsOneWidget : findsNothing,
            );
            expect(find.text('Borrar'), findsNothing);
            expect(find.byTooltip('Marcar como observado'), findsOneWidget);
            final descarga = tester.widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Descargar ficha de datos',
              ),
            );
            expect(descarga.onPressed, isNotNull);
            for (final tooltip in [
              'Editar',
              'Eliminar productor',
              'Verificar con SIE',
              'Aceptar sugerencia SIE',
              'Deshabilitar',
              'Habilitar',
              'Agregar para reimpresión',
              'Cancelar reimpresión',
              'Ver e imprimir la credencial',
            ]) {
              expect(find.byTooltip(tooltip), findsNothing, reason: tooltip);
            }
            for (final texto in [
              'Asignar',
              'Cambiar',
              'Cambiar número',
              'Quitarle la parcela',
              'Completar número de lote',
            ]) {
              expect(find.text(texto), findsNothing, reason: texto);
            }
            expect(
              tester
                  .widget<ListTile>(
                    find.widgetWithText(ListTile, 'Número Lote: 15 A'),
                  )
                  .onTap,
              isNull,
            );
            expect(api.lecturas, ['/productores/42']);
            expect(api.creaciones, isEmpty);
            await tester.tap(find.byTooltip('Marcar como observado'));
            await tester.pumpAndSettle();
            expect(find.text('Quitar observación'), findsNothing);
            await tester.enterText(find.byType(TextFormField), 'Revisar foto');
            await tester.tap(find.text('Guardar observación'));
            await tester.pumpAndSettle();
            expect(api.ultimaRuta, '/productores/42/observacion');
            expect(api.ultimoCuerpo, {'texto': 'Revisar foto'});
            expect(find.byTooltip('Editar observación'), findsOneWidget);

            if (centralId == null && conFoto && ancho == 1100) {
              final foto = find
                  .descendant(
                    of: find.byType(ImagenesProductor),
                    matching: find.byType(InkWell),
                  )
                  .first;
              await tester.ensureVisible(foto);
              await tester.tap(foto);
              await tester.pumpAndSettle();
              expect(find.byType(VisorImagen), findsOneWidget);
              expect(find.text('Nombre del archivo'), findsOneWidget);
              expect(find.text('foto.png'), findsOneWidget);
              expect(find.text('Fecha de creación'), findsOneWidget);
              expect(find.text('Última edición'), findsOneWidget);
              await tester.tap(find.byTooltip('Editar fotografía'));
              await tester.pump();
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 200)),
              );
              await tester.pumpAndSettle();
              expect(find.byType(VisorImagen), findsNothing);
              expect(find.byType(RecortadorImagen), findsOneWidget);
              expect(find.text('Recortar y subir'), findsOneWidget);
              expect(api.descargas, ['/productores/42/imagenes/descarga']);
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  for (final tamano in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'revisiones abiertas y completas con texto ampliado en $tamano',
      (tester) async {
        tester.view.physicalSize = tamano;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final motivo = List.filled(
          5,
          'Revisar los datos del productor.',
        ).join(' ');
        final api = _ApiDetalle(
          conFoto: true,
          datosAdicionales: {
            'observado': true,
            'observacion': motivo,
            'ciDuplicada': true,
            'revisionLotePendiente': true,
            'revisionSieEstado': 'NO_ENCONTRADO',
            'revisionSieMensaje': 'No se encontraron datos para esta cédula.',
            'nombresCorregidos': 'MARÍA CORREGIDA',
          },
        );
        addTearDown(api.cerrar);
        await _abrirIntegrada(tester, api, escala: 1.5);
        final ficha = find.byKey(const ValueKey('ficha-integrada'));
        expect(find.text('Volver a la ficha'), findsNothing);
        expect(find.byType(ExpansionTile), findsNothing);
        for (final titulo in [
          'Observación manual',
          'Revisión pendiente: número de lote',
          'No encontrado en SIE',
          'Corrección de nombre sin confirmar',
        ]) {
          final texto = find.text(titulo);
          expect(find.descendant(of: ficha, matching: texto), findsOneWidget);
          await tester.ensureVisible(texto);
          await tester.pumpAndSettle();
          expect(texto.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        expect(tester.widget<Text>(find.text(motivo)).maxLines, isNull);
        expect(find.byTooltip('Editar').hitTestable(), findsOneWidget);
        expect(api.creaciones, isEmpty);
      },
    );
  }

  testWidgets('girar la ficha conserva la foto y no repite consultas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiDetalle(conFoto: true, conLote: true);
    addTearDown(api.cerrar);
    await _abrirIntegrada(tester, api);
    final estadoFoto = tester.state(find.byType(ImagenesProductor));
    final lecturas = List<String>.of(api.lecturas);
    for (final tamano in [
      const Size(1024, 768),
      const Size(844, 390),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = tamano;
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ImagenesProductor)), same(estadoFoto));
      expect(api.lecturas, lecturas);
      expect(find.byType(TabBar), findsNothing);
      await tester.ensureVisible(find.text('Número Lote: 15 A'));
      await tester.pumpAndSettle();
      expect(find.text('Número Lote: 15 A').hitTestable(), findsOneWidget);
      expect(find.text('Revisiones y antecedentes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('central y sindicato legibles en la ficha completa integrada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.reset);
    final api = _ApiDetalle(
      datosAdicionales: {
        'centralNombre': '1RO DE MAYO',
        'sindicatoNombre': 'ALTO TUNARI',
        'revisionLotePendiente': true,
      },
    );
    addTearDown(api.cerrar);
    final tema = PreferenciaTema();
    addTearDown(tema.dispose);
    await tester.pumpWidget(
      TemaScope(
        preferencia: tema,
        child: PadronScope(
          padron: Padron(api: api),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Roboto',
              colorScheme: const bool.fromEnvironment('capturarFicha')
                  ? ColorScheme.fromSeed(
                      seedColor: const Color(0xFF2E6B4F),
                      brightness: Brightness.dark,
                    )
                  : null,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('Jerarquía')),
              bottomNavigationBar: const SizedBox(height: 64),
              body: const Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Sindicato de prueba'),
                    ),
                  ),
                  Expanded(child: ProductorDetallePagina(productorId: 42)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final dato in ['Central: 1RO DE MAYO', 'Sindicato: ALTO TUNARI']) {
      final texto = tester.widget<Text>(find.text(dato));
      expect(texto.style!.fontSize, greaterThanOrEqualTo(18));
      expect(texto.maxLines, isNull);
      expect(find.text(dato).hitTestable(), findsOneWidget);
    }
    final ficha = find.byKey(const ValueKey('ficha-integrada'));
    for (final hijo in [
      find.byType(ImagenesProductor),
      find.text('Parcela'),
      find.text('Revisiones y antecedentes'),
    ]) {
      expect(find.descendant(of: ficha, matching: hijo), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('ficha-antecedentes')));
    await tester.pumpAndSettle();
    expect(
      find.text('Revisiones y antecedentes').hitTestable(),
      findsOneWidget,
    );
    expect(find.byTooltip('Editar').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('capturarFicha')) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/ficha-tipografia/movil-integrado.png'),
      );
    }
  });

  for (final tamano in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('foto cargada y reimpresión visibles juntas en $tamano', (
      tester,
    ) async {
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiDetalle(
        conFoto: true,
        conLote: true,
        datosAdicionales: {
          'auditoria': {'estado': true, 'creadoEn': '2026-08-23T14:05:00'},
          'credencialImpresa': true,
          'credencialImpresiones': 1,
          'credencialLista': true,
          'revisionSieEstado': 'VERIFICADO',
        },
      );
      addTearDown(api.cerrar);
      await _abrirIntegrada(tester, api);
      for (final texto in [
        'Reemplazar',
        'Editar fotografía',
        'Borrar fotografía',
        'Agregar para reimpresión',
      ]) {
        expect(
          find.byTooltip(texto).hitTestable(),
          findsOneWidget,
          reason: texto,
        );
      }
      expect(find.text('Revisiones y antecedentes'), findsOneWidget);
      await tester.ensureVisible(find.text('Número Lote: 15 A'));
      await tester.pumpAndSettle();
      expect(find.text('Número Lote: 15 A').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'texto ampliado conserva datos y acciones dentro del área segura',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
      addTearDown(tester.view.reset);
      final api = _ApiDetalle(conLote: true);
      addTearDown(api.cerrar);
      await _abrirIntegrada(tester, api, escala: 1.5);
      for (final texto in [
        'Central: $_central',
        'Sindicato: $_sindicato',
        'Revisiones y antecedentes',
      ]) {
        await tester.ensureVisible(find.text(texto));
        await tester.pumpAndSettle();
        expect(find.text(texto).hitTestable(), findsOneWidget);
      }
      for (final accion in [
        'Editar',
        'Marcar como observado',
        'Descargar ficha de datos',
      ]) {
        final boton = find.byTooltip(accion);
        expect(boton.hitTestable(), findsOneWidget);
        expect(tester.getRect(boton).bottom, lessThanOrEqualTo(824));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('observación larga aparece completa desde la ficha principal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final motivo = List.filled(
      12,
      'Es necesario revisar los datos y la fotografía.',
    ).join(' ');
    final api = _ApiDetalle(
      conLote: true,
      datosAdicionales: {'observado': true, 'observacion': motivo},
    );
    addTearDown(api.cerrar);
    await _abrirIntegrada(tester, api);
    expect(find.text('Volver a la ficha'), findsNothing);
    expect(find.byType(ImagenesProductor), findsOneWidget);
    expect(find.text('Parcela'), findsOneWidget);
    expect(find.text('Observación manual'), findsOneWidget);
    expect(tester.widget<Text>(find.text(motivo)).maxLines, isNull);
    expect(api.creaciones, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registro completo de central gestiona fotos y abre parcela', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiDetalle(conFoto: true, conLote: true);
    final sesion = SesionControlador(AutenticacionRepository(api));
    sesion.sesion = Sesion(
      token: 'prueba',
      usuario: 'central',
      nombreCompleto: 'Registro',
      rol: 'OPERADOR',
      roles: const {'REGISTRO_PRODUCTORES_CENTRAL'},
      centralId: 3,
      permisos: const {
        'PRODUCTORES_VER',
        'PRODUCTORES_EDITAR',
        'SIE_REVISAR',
        'LOTES_EDITAR',
        'IMAGENES_EDITAR',
      },
      expiraEn: DateTime(2100),
    );
    final tema = PreferenciaTema();
    addTearDown(tema.dispose);
    addTearDown(sesion.dispose);
    await tester.pumpWidget(
      TemaScope(
        preferencia: tema,
        child: SesionScope(
          controlador: sesion,
          child: PadronScope(
            padron: Padron(api: api),
            child: const MaterialApp(
              home: ProductorDetallePagina(productorId: 42),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<ImagenesProductor>(find.byType(ImagenesProductor)).editable,
      isTrue,
    );
    expect(find.text('Reemplazar'), findsOneWidget);
    expect(find.text('Borrar'), findsOneWidget);
    expect(find.text('Cambiar'), findsOneWidget);
    expect(find.text('Quitarle la parcela'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsOneWidget);
    expect(find.byTooltip('Verificar con SIE'), findsOneWidget);
    expect(find.byTooltip('Eliminar'), findsNothing);
    expect(find.byTooltip('Ver e imprimir la credencial'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Número Lote: 15 A'));
    await tester.pumpAndSettle();
    expect(find.byType(LotePagina), findsOneWidget);
    expect(find.text('Cambiar clasificación'), findsOneWidget);
    expect(api.lecturas, contains('/lotes/9/historial'));
    expect(api.lecturas.where((ruta) => ruta.contains('/sistemas')), isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'usuario de central gestiona fotos, observa y cambia número sin SIE ni clasificación',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _ApiDetalle(
        conFoto: true,
        conLote: true,
        revisionSiePendiente: true,
      );
      final sesion = SesionControlador(AutenticacionRepository(api));
      sesion.sesion = Sesion(
        token: 'prueba',
        usuario: 'central',
        nombreCompleto: 'Fotógrafo',
        rol: 'OPERADOR',
        roles: {'REGISTRO_CENTRAL'},
        centralId: 3,
        permisos: {
          'PRODUCTORES_VER',
          'FOTOS_PRODUCTORES_EDITAR',
          'PRODUCTORES_OBSERVAR',
          'NUMERO_LOTE_EDITAR',
        },
        expiraEn: DateTime.now().add(const Duration(hours: 1)),
      );
      final tema = PreferenciaTema();
      addTearDown(tema.dispose);
      addTearDown(sesion.dispose);
      await tester.pumpWidget(
        TemaScope(
          preferencia: tema,
          child: SesionScope(
            controlador: sesion,
            child: PadronScope(
              padron: Padron(api: api),
              child: const MaterialApp(
                home: ProductorDetallePagina(productorId: 42),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reemplazar'), findsOneWidget);
      expect(find.text('Borrar'), findsOneWidget);
      expect(find.text('Cambiar número'), findsOneWidget);
      expect(find.byTooltip('Marcar como observado'), findsOneWidget);
      expect(find.byTooltip('Editar'), findsNothing);
      expect(find.byTooltip('Verificar con SIE'), findsNothing);
      expect(find.byTooltip('Ver e imprimir la credencial'), findsNothing);
      expect(find.text('Cambiar'), findsNothing);
      expect(find.text('Quitarle la parcela'), findsNothing);
      expect(api.creaciones, isEmpty);
      await tester.tap(find.text('Cambiar número'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '25');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar número'));
      await tester.pumpAndSettle();
      expect(api.ultimaRuta, '/productores/42/numero-lote');
      expect(api.ultimoCuerpo, {'numero': '25', 'loteId': 9, 'letra': ''});
      expect(api.creaciones, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('identidad junto a la foto y parcela visibles sin pestañas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tema = PreferenciaTema();
    addTearDown(tema.dispose);
    await tester.pumpWidget(
      TemaScope(
        preferencia: tema,
        child: PadronScope(
          padron: Padron(api: _ApiDetalle(conLote: true)),
          child: const MaterialApp(
            home: ProductorDetallePagina(productorId: 42),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nombres = find.descendant(
      of: find.byKey(const ValueKey('productor-nombres')),
      matching: find.byType(Text),
    );
    final apellidos = find.descendant(
      of: find.byKey(const ValueKey('productor-apellidos')),
      matching: find.byType(Text),
    );
    final cedula = find.descendant(
      of: find.byKey(const ValueKey('productor-cedula')),
      matching: find.byType(Text),
    );
    final codigo = find.descendant(
      of: find.byKey(const ValueKey('productor-codigo')),
      matching: find.byType(Text),
    );
    expect(find.text('MARÍA'), findsOneWidget);
    expect(find.text('PÉREZ'), findsOneWidget);
    expect(find.text('C.I.: 123456'), findsOneWidget);
    expect(find.text('Código: 213J100'), findsOneWidget);
    expect(
      find.widgetWithText(ListTile, 'Número Lote: 15 A').hitTestable(),
      findsOneWidget,
    );
    expect(find.byType(TabBar), findsNothing);

    final textos = [
      tester.widget<Text>(nombres),
      tester.widget<Text>(apellidos),
      tester.widget<Text>(cedula),
      tester.widget<Text>(codigo),
    ];
    expect(textos[0].style?.fontSize, textos[1].style?.fontSize);
    expect(textos[0].style?.fontSize, greaterThan(textos[2].style!.fontSize!));
    expect(textos[3].style?.fontSize, lessThan(textos[2].style!.fontSize!));
    expect(textos[2].style?.fontWeight, FontWeight.w700);
    expect(textos[3].style?.fontWeight, FontWeight.w500);
    expect(textos.every((texto) => texto.maxLines == 1), isTrue);
    expect(
      tester.getTopLeft(nombres).dy,
      lessThan(tester.getTopLeft(apellidos).dy),
    );
    expect(
      tester.getTopLeft(apellidos).dy,
      lessThan(tester.getTopLeft(cedula).dy),
    );
    expect(
      tester.getTopLeft(cedula).dy,
      lessThan(tester.getTopLeft(codigo).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'conserva la ficha integrada al recargar después de subir la foto',
    (tester) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tema = PreferenciaTema();
      addTearDown(tema.dispose);
      final api = _ApiDetalle(conFoto: true);
      await tester.pumpWidget(
        TemaScope(
          preferencia: tema,
          child: PadronScope(
            padron: Padron(api: api),
            child: const MaterialApp(
              home: ProductorDetallePagina(productorId: 42),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final carga = Completer<void>();
      api.esperaDetalle = carga.future;
      tester
          .widget<ImagenesProductor>(find.byType(ImagenesProductor))
          .alCambiar();
      await tester.pump();
      expect(find.byType(ImagenesProductor), findsNothing);
      carga.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ImagenesProductor).hitTestable(), findsOneWidget);
      expect(find.text('Revisiones y antecedentes'), findsOneWidget);
      expect(find.byKey(const ValueKey('ficha-integrada')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('muestra una fotografía sin contar ni describir la miniatura', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final tema = PreferenciaTema();
    addTearDown(tema.dispose);
    await tester.pumpWidget(
      TemaScope(
        preferencia: tema,
        child: PadronScope(
          padron: Padron(api: _ApiDetalle(conFoto: true)),
          child: const MaterialApp(
            home: ProductorDetallePagina(productorId: 42),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsOneWidget);
    for (final texto in [
      'MARÍA',
      'PÉREZ',
      'Central: $_central',
      'Sindicato: $_sindicato',
    ]) {
      expect(
        find.ancestor(
          of: find.text(texto),
          matching: find.byType(SelectionArea),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('Fotografía'), findsOneWidget);
    expect(find.text('Fotografías'), findsNothing);
    expect(find.text('2'), findsNothing);
    expect(find.textContaining('Miniatura', findRichText: true), findsNothing);
    expect(find.textContaining('128 × 128', findRichText: true), findsNothing);
    expect(
      find.textContaining('409 × 409', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('foto.png', findRichText: true), findsOneWidget);
    expect(find.text('Reemplazar'), findsOneWidget);
    expect(find.text('Borrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final ancho in [320.0, 390.0, 1024.0]) {
    for (final escala in [1.0, 1.5]) {
      testWidgets('nombres completos a $ancho px y texto $escala', (
        tester,
      ) async {
        tester.view.physicalSize = Size(ancho, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final tema = PreferenciaTema();
        addTearDown(tema.dispose);
        await tester.pumpWidget(
          TemaScope(
            preferencia: tema,
            child: PadronScope(
              padron: Padron(api: _ApiDetalle()),
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(escala)),
                  child: child!,
                ),
                home: const ProductorDetallePagina(productorId: 42),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final texto in ['Central: $_central', 'Sindicato: $_sindicato']) {
          final finder = find.text(texto);
          expect(finder, findsOneWidget);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final widget = tester.widget<Text>(finder);
          expect(widget.maxLines, isNull);
          expect(widget.softWrap, isTrue);
          expect(widget.overflow, isNot(TextOverflow.ellipsis));
          final textoRenderizado = find.descendant(
            of: finder,
            matching: find.byType(RichText),
          );
          expect(textoRenderizado, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            textoRenderizado,
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final cajas = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: texto.length),
          );
          expect(cajas, isNotEmpty);
          expect(
            cajas.last.bottom,
            lessThanOrEqualTo(paragraph.size.height + 1),
          );
          // La selección de una línea incluye el espacio que provocó el salto,
          // aunque ese espacio se dibuje fuera del ancho. Comprobar las letras.
          for (var i = 0; i < texto.length; i++) {
            if (texto[i].trim().isEmpty) continue;
            final letras = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: i, extentOffset: i + 1),
            );
            for (final caja in letras) {
              expect(caja.right, lessThanOrEqualTo(paragraph.size.width + 1));
            }
          }
        }
        expect(find.byTooltip('Editar'), findsOneWidget);
        expect(find.byTooltip('Verificar con SIE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> _abrirIntegrada(
  WidgetTester tester,
  _ApiDetalle api, {
  double escala = 1,
}) async {
  final tema = PreferenciaTema();
  addTearDown(tema.dispose);
  await tester.pumpWidget(
    TemaScope(
      preferencia: tema,
      child: PadronScope(
        padron: Padron(api: api),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: const ProductorDetallePagina(productorId: 42),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ApiDetalle extends ApiClient {
  _ApiDetalle({
    this.conFoto = false,
    this.conLote = false,
    this.revisionSiePendiente = false,
    this.datosAdicionales = const {},
  });
  final Map<String, Object?> datosAdicionales;
  final bool revisionSiePendiente;
  final creaciones = <String>[];
  final lecturas = <String>[];
  String? ultimaRuta;
  Object? ultimoCuerpo;
  bool observado = false;
  final descargas = <String>[];
  @override
  Future<DescargaBinaria> descargarUrl(Uri url) async {
    expect(url.path, anyOf('/foto.png', '/mini.png'));
    return DescargaBinaria(
      bytes: img.encodePng(img.Image(width: 32, height: 32, numChannels: 4)),
      nombreArchivo: 'foto.png',
      tipoMime: 'image/png',
    );
  }

  @override
  Future<DescargaBinaria> obtenerBytes(
    String ruta, {
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    expect(ruta, '/productores/42/imagenes/descarga');
    descargas.add(ruta);
    return DescargaBinaria(
      bytes: img.encodePng(img.Image(width: 32, height: 32, numChannels: 4)),
      nombreArchivo: 'foto.png',
      tipoMime: 'image/png',
    );
  }

  @override
  Future<Object?> parchear(String ruta, {Object? cuerpo}) async {
    expect(ruta, '/productores/42/observacion');
    ultimaRuta = ruta;
    ultimoCuerpo = cuerpo;
    observado = true;
    return {'id': 42, 'nombres': 'MARÍA', 'observado': true};
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    creaciones.add(ruta);
    return <String, dynamic>{};
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    ultimaRuta = ruta;
    ultimoCuerpo = cuerpo;
    return {
      'id': 9,
      'numero': '25',
      'estado': 'CON_SISTEMA',
      'sindicatoId': 7,
      'sindicatoNombre': _sindicato,
    };
  }

  final bool conFoto;
  final bool conLote;
  Future<void>? esperaDetalle;
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    lecturas.add(ruta);
    if (ruta == '/lotes/9') {
      return {
        'id': 9,
        'numero': '15',
        'codigo': '15 A',
        'estado': 'CON_SISTEMA',
        'sindicatoId': 7,
        'sindicatoNombre': _sindicato,
      };
    }
    if (ruta == '/productores/42') {
      await esperaDetalle;
      return {
        'productor': {
          'id': 42,
          'nombres': 'MARÍA',
          'apellidos': 'PÉREZ',
          'nombreCompleto': 'MARÍA PÉREZ',
          'ci': '123456',
          'codigoPadron': '213J100',
          'sindicatoId': 7,
          'sindicatoNombre': _sindicato,
          'centralId': 3,
          'centralNombre': _central,
          'revisionSiePendiente': revisionSiePendiente,
          'observado': observado,
          if (observado) 'observacion': 'Revisar foto',
          'auditoria': {'estado': false},
          ...datosAdicionales,
        },
        'lotes': [
          if (conLote)
            {
              'id': 9,
              'numero': '15',
              'extension': 'A',
              'codigo': '15 A',
              'estado': 'CON_SISTEMA',
              'sindicatoId': 7,
              'sindicatoNombre': _sindicato,
            },
        ],
        'imagenes': [
          if (conFoto) ...[
            {
              'tipo': 'ORIGINAL',
              'url': '/foto.png',
              'ancho': 409,
              'alto': 409,
              'tamanoBytes': 231424,
              'nombreOriginal': 'foto.png',
              'pendienteEdicion':
                  datosAdicionales['fotografiaPendienteEdicion'] == true,
            },
            {
              'tipo': 'MINIATURA',
              'url': '/mini.png',
              'ancho': 128,
              'alto': 128,
              'tamanoBytes': 25600,
            },
          ],
        ],
      };
    }
    return <dynamic>[];
  }
}
