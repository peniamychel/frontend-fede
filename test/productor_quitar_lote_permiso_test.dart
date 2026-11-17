import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/productores/asignar_parcela.dart';
import 'package:fede/ui/productores/productor_detalle_pagina.dart';
import 'package:fede/ui/sesion_scope.dart';

const _permisosRegistroRevision = {
  'PRODUCTORES_VER',
  'PRODUCTORES_REGISTRAR',
  'PRODUCTORES_EDITAR',
  'PRODUCTORES_ELIMINAR',
  'SIE_REVISAR',
  'FOTOS_PRODUCTORES_EDITAR',
  'PRODUCTORES_OBSERVAR',
  'NUMERO_LOTE_EDITAR',
  'LOTES_DESASIGNAR',
};

Sesion _sesion(Set<String> permisos) => Sesion(
  token: 'prueba',
  usuario: 'registro',
  nombreCompleto: 'Registro y revisión',
  rol: 'OPERADOR',
  roles: const {'REGISTRO_REVISION'},
  permisos: permisos,
  expiraEn: DateTime(2100),
);

Future<SesionControlador> _abrir(
  WidgetTester tester,
  _ApiQuitarLote api, {
  double ancho = 1100,
  Set<String> permisos = _permisosRegistroRevision,
  bool accionDirecta = false,
}) async {
  tester.view.physicalSize = Size(ancho, 1300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sesion = SesionControlador(AutenticacionRepository(api));
  sesion.sesion = _sesion(permisos);
  addTearDown(sesion.dispose);
  addTearDown(api.cerrar);
  await tester.pumpWidget(
    SesionScope(
      controlador: sesion,
      child: PadronScope(
        padron: Padron(api: api),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  if (accionDirecta) {
                    await quitarParcela(
                      context,
                      Lote.desdeJson(api.lote),
                      Productor.desdeJson(api.productor),
                    );
                  } else {
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const ProductorDetallePagina(productorId: 42),
                      ),
                    );
                  }
                },
                child: const Text('Abrir ficha'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  if (!accionDirecta) {
    await tester.tap(find.text('Abrir ficha'));
    await tester.pumpAndSettle();
  }
  return sesion;
}

Future<void> _abrirConfirmacion(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Quitarle la parcela'));
  await tester.tap(find.text('Quitarle la parcela'));
  await tester.pumpAndSettle();
  expect(find.text('¿Quitarle la parcela?'), findsOneWidget);
}

void main() {
  for (final ancho in [390.0, 1100.0]) {
    testWidgets(
      'registro y revisión quita lote y luego elimina productor a $ancho px',
      (tester) async {
        final api = _ApiQuitarLote();
        await _abrir(tester, api, ancho: ancho);
        expect(find.text('Cambiar número'), findsOneWidget);
        expect(find.text('Quitarle la parcela'), findsOneWidget);
        expect(find.text('Cambiar'), findsNothing);
        expect(find.text('Cambiar clasificación'), findsNothing);

        final lecturasIniciales = api.lecturasDetalle;
        await _abrirConfirmacion(tester);
        await tester.tap(find.text('Quitar'));
        await tester.pumpAndSettle();

        expect(api.reemplazos, ['/lotes/9/desasignacion']);
        expect(api.cuerpos, [<String, dynamic>{}]);
        expect(api.lecturasDetalle, greaterThan(lecturasIniciales));
        expect(find.text('Quitarle la parcela'), findsNothing);
        expect(find.text('N.° de lote: 15 A'), findsNothing);
        expect(find.text('Asignar'), findsOneWidget);

        await tester.ensureVisible(find.byTooltip('Eliminar productor'));
        await tester.tap(find.byTooltip('Eliminar productor'));
        await tester.pumpAndSettle();
        expect(find.text('No se puede eliminar'), findsNothing);
        await tester.tap(find.text('Mover a la papelera'));
        await tester.pumpAndSettle();

        expect(api.eliminaciones, ['/productores/42']);
        expect(find.text('Abrir ficha'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cancelar conserva el lote sin enviar cambios', (tester) async {
    final api = _ApiQuitarLote();
    await _abrir(tester, api);
    final lecturasIniciales = api.lecturasDetalle;
    await _abrirConfirmacion(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.reemplazos, isEmpty);
    expect(api.lecturasDetalle, lecturasIniciales);
    expect(find.text('Quitarle la parcela'), findsOneWidget);
    expect(find.text('N.° de lote: 15 A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error conserva la ficha y permite reintentar quitar', (
    tester,
  ) async {
    final api = _ApiQuitarLote()..fallar = true;
    await _abrir(tester, api);
    await _abrirConfirmacion(tester);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(api.conLote, isTrue);
    expect(find.text('Quitarle la parcela'), findsOneWidget);
    expect(find.text('N.° de lote: 15 A'), findsOneWidget);
    api.fallar = false;
    await _abrirConfirmacion(tester);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(api.reemplazos, [
      '/lotes/9/desasignacion',
      '/lotes/9/desasignacion',
    ]);
    expect(api.conLote, isFalse);
    expect(find.text('Quitarle la parcela'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin permiso no se ofrece quitar aunque permita cambiar número', (
    tester,
  ) async {
    final api = _ApiQuitarLote();
    await _abrir(
      tester,
      api,
      permisos: _permisosRegistroRevision.difference({'LOTES_DESASIGNAR'}),
    );
    expect(find.text('Cambiar número'), findsOneWidget);
    expect(find.text('Quitarle la parcela'), findsNothing);
    expect(api.reemplazos, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desasignar no exige permiso para cambiar número', (
    tester,
  ) async {
    final api = _ApiQuitarLote();
    await _abrir(
      tester,
      api,
      permisos: const {'PRODUCTORES_VER', 'LOTES_DESASIGNAR'},
    );
    expect(find.text('Cambiar número'), findsNothing);
    expect(find.text('Cambiar'), findsNothing);
    await _abrirConfirmacion(tester);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(api.reemplazos, ['/lotes/9/desasignacion']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gestión completa conserva el endpoint de tenencia', (
    tester,
  ) async {
    final api = _ApiQuitarLote();
    await _abrir(
      tester,
      api,
      permisos: const {'PRODUCTORES_VER', 'LOTES_EDITAR'},
    );
    await _abrirConfirmacion(tester);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(api.reemplazos, ['/lotes/9/tenencia']);
    expect(api.conLote, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('la acción comprueba permiso antes de abrir el diálogo', (
    tester,
  ) async {
    final api = _ApiQuitarLote();
    await _abrir(
      tester,
      api,
      permisos: const {'PRODUCTORES_VER'},
      accionDirecta: true,
    );
    await tester.tap(find.text('Abrir ficha'));
    await tester.pumpAndSettle();
    expect(find.text('¿Quitarle la parcela?'), findsNothing);
    expect(api.reemplazos, isEmpty);
  });

  testWidgets('revalida permiso después de confirmar y no envía si se retiró', (
    tester,
  ) async {
    final api = _ApiQuitarLote();
    final sesion = await _abrir(tester, api, accionDirecta: true);
    await tester.tap(find.text('Abrir ficha'));
    await tester.pumpAndSettle();
    expect(find.text('¿Quitarle la parcela?'), findsOneWidget);
    sesion.sesion = _sesion(const {'PRODUCTORES_VER'});
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(api.reemplazos, isEmpty);
    expect(api.conLote, isTrue);
    expect(tester.takeException(), isNull);
  });
}

class _ApiQuitarLote extends ApiClient {
  bool conLote = true;
  bool fallar = false;
  int lecturasDetalle = 0;
  final reemplazos = <String>[];
  final cuerpos = <Object>[];
  final eliminaciones = <String>[];

  Map<String, dynamic> get productor => {
    'id': 42,
    'nombres': 'MARÍA',
    'apellidos': 'PÉREZ',
    'nombreCompleto': 'MARÍA PÉREZ',
    'ci': '123456',
    'codigoPadron': '20122',
    'sindicatoId': 7,
    'sindicatoNombre': 'PRIMERO DE MAYO',
    'centralId': 3,
    'centralNombre': 'TRECE DE JUNIO',
    'clasificacion': 'CON_SISTEMA',
    'numeroLote': conLote ? '15 A' : null,
    'revisionSiePendiente': false,
    'auditoria': {'estado': true},
  };

  Map<String, dynamic> get lote => {
    'id': 9,
    'numero': '15',
    'extension': 'A',
    'codigo': '15 A',
    'estado': 'CON_SISTEMA',
    'sindicatoId': 7,
    'sindicatoNombre': 'PRIMERO DE MAYO',
    if (conLote) 'tenedor': {'productorId': 42, 'nombre': 'MARÍA PÉREZ'},
  };

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    if (ruta == '/productores/42') {
      lecturasDetalle++;
      return {
        'productor': productor,
        'lotes': [if (conLote) lote],
        'imagenes': <dynamic>[],
      };
    }
    if (ruta == '/lotes/9') return lote;
    if (ruta == '/lotes') return [lote];
    return <dynamic>[];
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    reemplazos.add(ruta);
    cuerpos.add(cuerpo);
    if (fallar) {
      throw const ApiException(estado: 503, mensaje: 'Intenta de nuevo');
    }
    if (ruta != '/lotes/9/desasignacion' && ruta != '/lotes/9/tenencia') {
      throw StateError('Escritura no autorizada por esta prueba: $ruta');
    }
    conLote = false;
    return lote;
  }

  @override
  Future<void> eliminar(String ruta) async {
    if (conLote) throw StateError('Todavía tiene lote');
    eliminaciones.add(ruta);
  }
}
