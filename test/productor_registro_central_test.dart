import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/sesion_scope.dart';
import 'package:fede/ui/productores/productor_formulario.dart';
import 'package:fede/ui/app.dart';

const _sindicato = Sindicato(
  id: 7,
  nombre: 'LIBERTAD',
  centralId: 3,
  centralNombre: 'IVIRGARZAMA',
);

Finder _campo(String etiqueta) => find.ancestor(
  of: find.text(etiqueta),
  matching: find.byType(TextFormField),
);

void main() {
  Future<void> abrir(
    WidgetTester tester,
    _ApiRegistro api, {
    bool conLote = true,
    bool sindicatoFijo = true,
    bool perfilCompleto = false,
    bool perfilRegistroRevision = false,
    Productor? productor,
  }) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final padron = Padron(api: api);
    final navegador = GlobalKey<NavigatorState>();
    final sesion = SesionControlador(AutenticacionRepository(api));
    addTearDown(sesion.dispose);
    sesion.sesion = Sesion(
      token: 'prueba',
      usuario: 'registro',
      nombreCompleto: 'Registro de central',
      rol: 'OPERADOR',
      roles: {
        if (perfilRegistroRevision)
          'REGISTRO_REVISION'
        else
          'REGISTRO_PRODUCTORES_CENTRAL',
      },
      permisos: perfilRegistroRevision
          ? const {
              'PRODUCTORES_VER',
              'PRODUCTORES_REGISTRAR',
              'PRODUCTORES_EDITAR',
              'PRODUCTORES_ELIMINAR',
              'SIE_REVISAR',
              'FOTOS_PRODUCTORES_EDITAR',
              'PRODUCTORES_OBSERVAR',
              'NUMERO_LOTE_EDITAR',
            }
          : perfilCompleto
          ? const {
              'PRODUCTORES_VER',
              'PRODUCTORES_EDITAR',
              'SIE_REVISAR',
              'LOTES_EDITAR',
              'IMAGENES_EDITAR',
            }
          : {
              'PRODUCTORES_VER',
              'PRODUCTORES_REGISTRAR',
              if (conLote) 'NUMERO_LOTE_EDITAR',
            },
      centralId: perfilRegistroRevision ? null : 3,
      expiraEn: DateTime(2100),
    );
    await tester.pumpWidget(
      PadronScope(
        padron: padron,
        child: SesionScope(
          controlador: sesion,
          child: MaterialApp(
            navigatorKey: navegador,
            builder: (_, child) =>
                RetrocesoConEscape(navegador: navegador, child: child!),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<bool>(
                      builder: (_) => ProductorFormulario(
                        productor: productor,
                        sindicatoFijo: sindicatoFijo ? _sindicato : null,
                        abrirFichaAlCrear: false,
                      ),
                    ),
                  ),
                  child: const Text('Abrir registro'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir registro'));
    await tester.pumpAndSettle();
  }

  Future<void> datos(WidgetTester tester) async {
    await tester.enterText(_campo('Cédula de identidad *'), '1234567');
    await tester.enterText(_campo('Nombres *'), 'MARÍA');
    await tester.enterText(_campo('Apellidos'), 'PÉREZ');
    await tester.pumpAndSettle();
  }

  testWidgets('alta vacía vuelve sin pedir confirmación', (tester) async {
    await abrir(tester, _ApiRegistro());
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Abrir registro'), findsOneWidget);
    expect(find.text('¿Salir sin registrar al productor?'), findsNothing);
  });

  for (final retroceso in ['flecha', 'sistema', 'escape']) {
    testWidgets(
      '$retroceso pregunta, permite conservar los datos y luego descartar',
      (tester) async {
        final api = _ApiRegistro();
        await abrir(tester, api);
        await datos(tester);
        Future<void> volver() async {
          if (retroceso == 'flecha') await tester.tap(find.byType(BackButton));
          if (retroceso == 'sistema') await tester.binding.handlePopRoute();
          if (retroceso == 'escape') {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          }
          await tester.pumpAndSettle();
        }

        await volver();
        expect(find.text('¿Salir sin registrar al productor?'), findsOneWidget);
        await tester.tap(find.text('Seguir registrando'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(_campo('Nombres *')).controller!.text,
          'MARÍA',
        );
        expect(
          tester
              .widget<TextFormField>(_campo('Cédula de identidad *'))
              .controller!
              .text,
          '1234567',
        );
        expect(api.altas, isEmpty);
        await volver();
        await tester.tap(find.text('Salir sin guardar'));
        await tester.pumpAndSettle();
        expect(find.text('Abrir registro'), findsOneWidget);
        expect(api.altas, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'solo ingresar CI ya protege el registro y borrarla permite salir',
    (tester) async {
      await abrir(tester, _ApiRegistro());
      await tester.enterText(_campo('Cédula de identidad *'), '123');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin registrar al productor?'), findsOneWidget);
      await tester.tap(find.text('Seguir registrando'));
      await tester.pumpAndSettle();
      await tester.enterText(_campo('Cédula de identidad *'), '');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Abrir registro'), findsOneWidget);
    },
  );

  testWidgets(
    'espera la respuesta de guardado y al terminar sale sin aviso ni segunda alta',
    (tester) async {
      final api = _ApiRegistro()..esperaAlta = Completer<void>();
      await abrir(tester, api);
      await datos(tester);
      final registrar = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Registrar'))
          .onPressed!;
      registrar();
      registrar();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(ProductorFormulario), findsOneWidget);
      expect(find.text('¿Salir sin registrar al productor?'), findsNothing);
      expect(api.altas, hasLength(1));
      api.esperaAlta!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Abrir registro'), findsOneWidget);
      expect(find.text('¿Salir sin registrar al productor?'), findsNothing);
      expect(api.altas, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'un fallo de guardado mantiene el aviso al salir y los datos ingresados',
    (tester) async {
      final api = _ApiRegistro()..fallarAlta = true;
      await abrir(tester, api);
      await datos(tester);
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('¿Salir sin registrar al productor?'), findsOneWidget);
      await tester.tap(find.text('Seguir registrando'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(_campo('Nombres *')).controller!.text,
        'MARÍA',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registro manual sin SIE ni clasificación asigna número limitado',
    (tester) async {
      final api = _ApiRegistro();
      await abrir(tester, api);
      expect(find.byTooltip('Verificar cédula'), findsNothing);
      expect(find.text('Marcado para seguimiento'), findsNothing);
      expect(find.text('Clasificación de la parcela'), findsNothing);
      expect(find.text('Existente'), findsNothing);
      await datos(tester);
      await tester.enterText(_campo('N° de lote'), '4 B');
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(api.altas, hasLength(1));
      expect(api.altas.single['nombres'], 'MARÍA');
      expect(api.altas.single['sindicatoId'], 7);
      expect(api.altas.single.containsKey('marcado'), isFalse);
      expect(api.altas.single.containsKey('clasificacion'), isFalse);
      expect(api.lotes.single['numero'], '4 B');
      expect(api.consultas, isEmpty);
      expect(find.text('Abrir registro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sin permiso de lote solo permite registrar identidad', (
    tester,
  ) async {
    final api = _ApiRegistro();
    await abrir(tester, api, conLote: false);
    expect(find.text('N° de lote'), findsNothing);
    await datos(tester);
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    expect(api.altas, hasLength(1));
    expect(api.lotes, isEmpty);
    expect(api.consultas, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alta desde lista general fija la central asignada', (
    tester,
  ) async {
    final api = _ApiRegistro();
    await abrir(tester, api, sindicatoFijo: false);
    expect(api.consultas, ['/centrales', '/centrales/3/sindicatos']);
    final central = tester.widget<DropdownButtonFormField<Central?>>(
      find.byType(DropdownButtonFormField<Central?>),
    );
    expect(central.onChanged, isNull);
    expect(find.text('IVIRGARZAMA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallo de lote no vuelve a crear productor ni pierde el alta', (
    tester,
  ) async {
    final api = _ApiRegistro()..fallarLote = true;
    await abrir(tester, api);
    await datos(tester);
    await tester.enterText(_campo('N° de lote'), '4');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();
    expect(api.altas, hasLength(1));
    expect(find.textContaining('quedó registrado'), findsOneWidget);
    expect(find.text('Abrir registro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'registro y revisión edita identidad sin requerir permisos de parcelas',
    (tester) async {
      final api = _ApiRegistro();
      final p = Productor.desdeJson({
        'id': 42,
        'nombres': 'MARÍA',
        'apellidos': 'PÉREZ',
        'nombreCompleto': 'MARÍA PÉREZ',
        'ci': '1234567',
        'sindicatoId': 7,
        'sindicatoNombre': 'LIBERTAD',
        'centralId': 3,
        'centralNombre': 'IVIRGARZAMA',
      });
      await abrir(tester, api, perfilRegistroRevision: true, productor: p);
      await tester.enterText(_campo('Nombres *'), 'MARÍA ELENA');
      await tester.enterText(_campo('Apellidos'), 'PÉREZ ROJAS');
      await tester.enterText(_campo('Cédula de identidad'), '7654321');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(api.cambios.single['nombres'], 'MARÍA ELENA');
      expect(api.cambios.single['apellidos'], 'PÉREZ ROJAS');
      expect(api.cambios.single['ci'], '7654321');
      expect(api.cambios.single['sindicatoId'], 7);
      expect(api.altas, isEmpty);
      expect(api.lotes, isEmpty);
      expect(find.text('Abrir registro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registro y revisión conserva alta con número limitado sin clasificación',
    (tester) async {
      final api = _ApiRegistro();
      await abrir(tester, api, perfilRegistroRevision: true);
      expect(find.byTooltip('Verificar cédula'), findsOneWidget);
      expect(find.text('Clasificación de la parcela'), findsNothing);
      expect(find.text('Existente'), findsNothing);
      expect(api.consultas, isEmpty);
      await tester.enterText(_campo('Cédula de identidad *'), '1234567');
      await tester.tap(find.byTooltip('Verificar cédula'));
      await tester.pumpAndSettle();
      await tester.enterText(_campo('Nombres *'), 'MARÍA');
      await tester.enterText(_campo('Apellidos'), 'PÉREZ');
      await tester.enterText(_campo('N° de lote'), '4 B');
      await tester.ensureVisible(find.text('Registrar'));
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      expect(api.altas, hasLength(1));
      expect(api.lotes.single['numero'], '4 B');
      expect(api.lotes.single.containsKey('estado'), isFalse);
      expect(api.consultas, isNot(contains('/lotes')));
      expect(api.consultasSie, ['1234567']);
      expect(find.text('Abrir registro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registro de cinco permisos consulta SIE y gestiona clasificación',
    (tester) async {
      final api = _ApiRegistro();
      await abrir(tester, api, perfilCompleto: true);
      expect(find.byTooltip('Verificar cédula'), findsOneWidget);
      await tester.enterText(_campo('Cédula de identidad *'), '1234567');
      await tester.tap(find.byTooltip('Verificar cédula'));
      await tester.pumpAndSettle();
      expect(api.consultas, contains('/productores/por-cedula/1234567'));
      expect(api.consultasSie, ['1234567']);
      await tester.enterText(_campo('Nombres *'), 'MARÍA');
      await tester.enterText(_campo('Apellidos'), 'PÉREZ');
      await tester.ensureVisible(find.text('Nueva'));
      await tester.tap(find.text('Nueva'));
      await tester.pumpAndSettle();
      await tester.enterText(_campo('N° de parcela *'), '4');
      expect(find.text('Clasificación de la parcela'), findsOneWidget);
      await tester.ensureVisible(find.text('Registrar'));
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      expect(api.altas, hasLength(1));
      expect(api.lotes.single['sindicatoId'], 7);
      expect(api.lotes.single['productorId'], 42);
      expect(api.lotes.single['numero'], '4');
      expect(api.lotes.single, contains('estado'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'registro de cinco permisos edita sin cambiar la central asignada',
    (tester) async {
      final api = _ApiRegistro();
      final p = Productor.desdeJson({
        'id': 42,
        'nombres': 'MARÍA',
        'apellidos': 'PÉREZ',
        'nombreCompleto': 'MARÍA PÉREZ',
        'ci': '1234567',
        'sindicatoId': 7,
        'sindicatoNombre': 'LIBERTAD',
        'centralId': 3,
        'centralNombre': 'IVIRGARZAMA',
      });
      await abrir(tester, api, perfilCompleto: true, productor: p);
      final central = tester.widget<DropdownButtonFormField<Central?>>(
        find.byType(DropdownButtonFormField<Central?>),
      );
      expect(central.onChanged, isNull);
      await tester.enterText(_campo('Nombres *'), 'MARÍA ELENA');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(api.cambios.single['nombres'], 'MARÍA ELENA');
      expect(api.cambios.single['sindicatoId'], 7);
      expect(api.altas, isEmpty);
      expect(find.text('Abrir registro'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _ApiRegistro extends ApiClient {
  final consultas = <String>[];
  final altas = <Map<String, dynamic>>[];
  final lotes = <Map<String, dynamic>>[];
  final cambios = <Map<String, dynamic>>[];
  final consultasSie = <String>[];
  bool fallarLote = false;
  bool fallarAlta = false;
  Completer<void>? esperaAlta;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    consultas.add(ruta);
    if (ruta == '/lotes' || ruta.startsWith('/productores/por-cedula/')) {
      return <dynamic>[];
    }
    if (ruta == '/centrales') {
      return [
        {'id': 3, 'nombre': 'IVIRGARZAMA'},
      ];
    }
    if (ruta == '/centrales/3/sindicatos') {
      return [
        {
          'id': 7,
          'nombre': 'LIBERTAD',
          'centralId': 3,
          'centralNombre': 'IVIRGARZAMA',
        },
      ];
    }
    throw StateError('No debe consultar $ruta');
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    if (ruta == '/personas/consulta') {
      consultasSie.add((cuerpo as Map)['ci'] as String);
      return {'estado': 'NO_ENCONTRADA', 'mensaje': 'No encontrada'};
    }
    if (ruta == '/lotes') {
      final datos = Map<String, dynamic>.from(cuerpo as Map);
      lotes.add(datos);
      return {
        ...datos,
        'id': 9,
        'codigo': datos['numero'],
        'sindicatoNombre': 'LIBERTAD',
      };
    }
    expect(ruta, '/productores');
    final datos = Map<String, dynamic>.from(cuerpo as Map);
    altas.add(datos);
    if (fallarAlta) {
      throw const ApiException(estado: 503, mensaje: 'No se pudo guardar');
    }
    if (esperaAlta != null) await esperaAlta!.future;
    return {
      ...datos,
      'id': 42,
      'nombreCompleto': '${datos['nombres']} ${datos['apellidos']}',
      'sindicatoNombre': 'LIBERTAD',
      'centralId': 3,
      'centralNombre': 'IVIRGARZAMA',
      'revisionSiePendiente': true,
    };
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    if (ruta == '/productores/42') {
      final datos = Map<String, dynamic>.from(cuerpo as Map);
      cambios.add(datos);
      return {
        ...datos,
        'id': 42,
        'nombreCompleto': '${datos['nombres']} ${datos['apellidos']}',
        'sindicatoNombre': 'LIBERTAD',
        'centralId': 3,
        'centralNombre': 'IVIRGARZAMA',
      };
    }
    expect(ruta, '/productores/42/numero-lote');
    final datos = Map<String, dynamic>.from(cuerpo as Map);
    lotes.add(datos);
    if (fallarLote) {
      throw const ApiException(estado: 503, mensaje: 'Sin conexión');
    }
    return {
      'id': 9,
      'numero': datos['numero'],
      'codigo': datos['numero'],
      'sindicatoId': 7,
      'sindicatoNombre': 'LIBERTAD',
    };
  }
}
