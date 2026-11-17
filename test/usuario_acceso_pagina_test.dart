import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/administracion/accesos_pagina.dart';
import 'package:fede/ui/administracion/usuario_acceso_pagina.dart';

void main() {
  Future<void> abrir(
    WidgetTester tester,
    _ApiUsuarios api, {
    bool listado = false,
  }) async {
    await tester.pumpWidget(
      PadronScope(
        padron: Padron(api: api),
        child: MaterialApp(
          home: listado
              ? const AccesosPagina()
              : const UsuarioAccesoPagina(usuarioId: 9),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pulsar(WidgetTester tester, String texto) async {
    await tester.scrollUntilVisible(
      find.text(texto),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
  }

  testWidgets('eliminar requiere confirmación y permite cancelar', (
    tester,
  ) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'Eliminar usuario');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.eliminado, isFalse);
    await pulsar(tester, 'Eliminar usuario');
    await tester.tap(find.text('Eliminar definitivamente'));
    await tester.pumpAndSettle();
    expect(api.eliminado, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('administrador no tiene habilitada la eliminación', (
    tester,
  ) async {
    final api = _ApiUsuarios();
    api.usuario['roles'] = ['ADMIN'];
    await abrir(tester, api);
    await tester.scrollUntilVisible(
      find.text('Eliminar usuario'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final boton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Eliminar usuario'),
    );
    expect(boton.onPressed, isNull);
    expect(
      find.text('No se puede eliminar a un administrador.'),
      findsOneWidget,
    );
    expect(api.eliminado, isFalse);
  });

  testWidgets('pulsar usuario abre su configuración guardada', (tester) async {
    final api = _ApiUsuarios();
    await abrir(tester, api, listado: true);
    await tester.tap(find.text('Fotógrafo'));
    await tester.pumpAndSettle();
    expect(find.text('Configuración del usuario'), findsOneWidget);
    expect(find.text('CENTRAL PRUEBA'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Seleccionados: 1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Seleccionados: 1'), findsOneWidget);
    final elegido = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'SINDICATO A'),
    );
    expect(elegido.value, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guarda varios sindicatos y permisos individuales', (
    tester,
  ) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'SINDICATO B');
    await pulsar(tester, 'Personalizar permisos de este usuario');
    await pulsar(tester, 'Editar fotografías');
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado?['todosSindicatos'], isFalse);
    expect(api.guardado?['sindicatoIds'], unorderedEquals([7, 8]));
    expect(api.guardado?['permisosPersonalizados'], isTrue);
    expect(
      api.guardado?['permisos'],
      unorderedEquals([
        'PRODUCTORES_VER',
        'PRODUCTORES_OBSERVAR',
        'NUMERO_LOTE_EDITAR',
        'INFORMES_DESCARGAR',
      ]),
    );
    expect(api.guardado?['centralId'], 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('todos los sindicatos elimina la selección particular', (
    tester,
  ) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'Todos los sindicatos');
    expect(find.text('SINDICATO A'), findsNothing);
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado?['todosSindicatos'], isTrue);
    expect(api.guardado?['sindicatoIds'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rol de registro se asigna solo con alcance de central', (
    tester,
  ) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'Registro de productores');
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado?['roles'], unorderedEquals([4, 5]));
    expect(api.guardado?['centralId'], 3);
    expect(api.guardado?['sindicatoIds'], [7]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('registro limitado no se ofrece para acceso general', (
    tester,
  ) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'Acceso solo a una central');
    expect(find.text('Registro de productores'), findsNothing);
    expect(find.text('Fotos, observaciones y número de lote'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final alcance in ['general', 'uno', 'varios', 'todos']) {
    testWidgets('fotos y observaciones se asigna con alcance $alcance', (
      tester,
    ) async {
      final api = _ApiUsuarios();
      await abrir(tester, api);
      if (alcance == 'general') {
        await pulsar(tester, 'Acceso solo a una central');
      } else {
        if (alcance == 'varios') {
          await pulsar(tester, 'SINDICATO B');
        } else if (alcance == 'todos') {
          await pulsar(tester, 'Todos los sindicatos');
        }
        await pulsar(tester, 'Fotos, observaciones y número de lote');
      }
      await pulsar(tester, 'Fotos y observaciones');
      await pulsar(tester, 'Personalizar permisos de este usuario');
      await pulsar(tester, 'Guardar configuración');
      expect(api.guardado?['roles'], [7]);
      expect(api.guardado?['centralId'], alcance == 'general' ? null : 3);
      expect(
        api.guardado?['todosSindicatos'],
        alcance == 'general' || alcance == 'todos',
      );
      expect(
        api.guardado?['sindicatoIds'],
        unorderedEquals(switch (alcance) {
          'uno' => [7],
          'varios' => [7, 8],
          _ => <int>[],
        }),
      );
      expect(
        api.guardado?['permisos'],
        unorderedEquals([
          'PRODUCTORES_VER',
          'FOTOS_PRODUCTORES_ACTUALIZAR',
          'PRODUCTORES_OBSERVAR',
        ]),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gestor se asigna a una central y un sindicato', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'Fotos, observaciones y número de lote');
    await pulsar(tester, 'Gestor de productores');
    await pulsar(tester, 'Personalizar permisos de este usuario');
    for (final nombre in ['Eliminar productores', 'Quitar parcela asignada']) {
      await tester.scrollUntilVisible(
        find.text(nombre),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, nombre),
            )
            .value,
        isTrue,
      );
    }
    expect(find.text('Editar directorios'), findsNothing);
    expect(find.text('Imprimir carnets'), findsNothing);
    expect(find.text('Importar padrón'), findsNothing);
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado?['roles'], [6]);
    expect(api.guardado?['centralId'], 3);
    expect(api.guardado?['todosSindicatos'], isFalse);
    expect(api.guardado?['sindicatoIds'], [7]);
    expect(
      api.guardado?['permisos'],
      unorderedEquals([
        'PRODUCTORES_VER',
        'PRODUCTORES_REGISTRAR',
        'PRODUCTORES_EDITAR',
        'PRODUCTORES_ELIMINAR',
        'SIE_REVISAR',
        'FOTOS_PRODUCTORES_EDITAR',
        'PRODUCTORES_OBSERVAR',
        'NUMERO_LOTE_EDITAR',
        'LOTES_DESASIGNAR',
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('gestor permite varios sindicatos de la central', (tester) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'SINDICATO B');
    await pulsar(tester, 'Fotos, observaciones y número de lote');
    await pulsar(tester, 'Gestor de productores');
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado?['roles'], [6]);
    expect(api.guardado?['centralId'], 3);
    expect(api.guardado?['todosSindicatos'], isFalse);
    expect(api.guardado?['sindicatoIds'], unorderedEquals([7, 8]));
    expect(api.guardado?['permisosPersonalizados'], isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gestor permite todos los sindicatos de la central', (
    tester,
  ) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'Todos los sindicatos');
    await pulsar(tester, 'Fotos, observaciones y número de lote');
    await pulsar(tester, 'Gestor de productores');
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado?['roles'], [6]);
    expect(api.guardado?['centralId'], 3);
    expect(api.guardado?['todosSindicatos'], isTrue);
    expect(api.guardado?['sindicatoIds'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gestor sigue disponible sin exigir acceso a una central', (
    tester,
  ) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'Acceso solo a una central');
    await pulsar(tester, 'Gestor de productores');
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado?['roles'], [6]);
    expect(api.guardado?['centralId'], isNull);
    expect(api.guardado?['todosSindicatos'], isTrue);
    expect(api.guardado?['sindicatoIds'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'gestor personalizado con permisos ajenos no se ofrece en central',
    (tester) async {
      final api = _ApiUsuarios()
        ..permisosGestor = [
          ..._ApiUsuarios.permisosGestorBase,
          'DIRECTORIOS_EDITAR',
        ];
      await abrir(tester, api);
      await pulsar(tester, 'Personalizar permisos de este usuario');
      expect(find.text('Gestor de productores'), findsNothing);
      expect(find.text('Editar directorios'), findsNothing);
      expect(find.text('Imprimir carnets'), findsNothing);
      expect(find.text('Importar padrón'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('registro puede añadirse como permiso individual de central', (
    tester,
  ) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'Personalizar permisos de este usuario');
    await pulsar(tester, 'Registrar productores nuevos');
    await pulsar(tester, 'Guardar configuración');
    expect(
      api.guardado?['permisos'],
      unorderedEquals([
        'PRODUCTORES_VER',
        'FOTOS_PRODUCTORES_EDITAR',
        'PRODUCTORES_OBSERVAR',
        'NUMERO_LOTE_EDITAR',
        'INFORMES_DESCARGAR',
        'PRODUCTORES_REGISTRAR',
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('roles reales de fotos y registro son combinables en central', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await tester.scrollUntilVisible(
      find.text('Fotos, observaciones y número de lote'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(
              CheckboxListTile,
              'Fotos, observaciones y número de lote',
            ),
          )
          .value,
      isTrue,
    );
    await pulsar(tester, 'Registro de productores');
    await pulsar(tester, 'Personalizar permisos de este usuario');
    await tester.scrollUntilVisible(
      find.text('Descargar informes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Descargar informes'),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Revisar SIE'),
          )
          .value,
      isFalse,
    );
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado?['roles'], unorderedEquals([4, 5]));
    expect(
      api.guardado?['permisos'],
      unorderedEquals([
        'PRODUCTORES_VER',
        'FOTOS_PRODUCTORES_EDITAR',
        'PRODUCTORES_OBSERVAR',
        'NUMERO_LOTE_EDITAR',
        'INFORMES_DESCARGAR',
        'PRODUCTORES_REGISTRAR',
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rol registro con los cinco permisos del registro general', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = _ApiUsuarios()..registroCompleto = true;
    await abrir(tester, api);
    await pulsar(tester, 'Fotos, observaciones y número de lote');
    await pulsar(tester, 'Registro de productores');
    await pulsar(tester, 'Personalizar permisos de este usuario');
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado?['roles'], [5]);
    expect(api.guardado?['centralId'], 3);
    expect(api.guardado?['sindicatoIds'], [7]);
    expect(
      api.guardado?['permisos'],
      unorderedEquals([
        'PRODUCTORES_VER',
        'PRODUCTORES_EDITAR',
        'SIE_REVISAR',
        'LOTES_EDITAR',
        'IMAGENES_EDITAR',
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no guarda una selección de sindicatos vacía', (tester) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'SINDICATO A');
    await pulsar(tester, 'Guardar configuración');
    expect(api.guardado, isNull);
    expect(
      find.textContaining('Seleccioná al menos un sindicato'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambia el código manual desde el panel', (tester) async {
    final api = _ApiUsuarios();
    await abrir(tester, api);
    await pulsar(tester, 'Ingresar código manualmente');
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      'aBcDe234FgHi567JkLmN89pq',
    );
    await tester.tap(find.text('Guardar código'));
    await tester.pumpAndSettle();
    expect(api.codigo, 'aBcDe234FgHi567JkLmN89pq');
    expect(find.text('Código de acceso guardado'), findsOneWidget);
    expect(find.text('aBcDe234FgHi567JkLmN89pq'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel usable en móvil sin desbordar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await abrir(tester, _ApiUsuarios());
    await pulsar(tester, 'Personalizar permisos de este usuario');
    await pulsar(tester, 'Generar código seguro');
    await tester.tap(find.text('Generar'));
    await tester.pumpAndSettle();
    expect(find.text('AbCdE234FgHi567JkLmN89pq'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ApiUsuarios extends ApiClient {
  static const permisosGestorBase = [
    'PRODUCTORES_VER',
    'PRODUCTORES_REGISTRAR',
    'PRODUCTORES_EDITAR',
    'PRODUCTORES_ELIMINAR',
    'SIE_REVISAR',
    'FOTOS_PRODUCTORES_EDITAR',
    'PRODUCTORES_OBSERVAR',
    'NUMERO_LOTE_EDITAR',
    'LOTES_DESASIGNAR',
  ];
  List<String> permisosGestor = permisosGestorBase;
  bool eliminado = false;
  bool registroCompleto = false;
  @override
  Future<void> eliminar(String ruta) async {
    expect(ruta, '/administracion/accesos/usuarios/9');
    eliminado = true;
  }

  Map<String, dynamic>? guardado;
  String? codigo;
  final usuario = <String, dynamic>{
    'id': 9,
    'nombreCompleto': 'Fotógrafo',
    'activo': true,
    'roles': ['REGISTRO_CENTRAL'],
    'centralId': 3,
    'centralNombre': 'CENTRAL PRUEBA',
    'todosSindicatos': false,
    'sindicatoIds': [7],
    'permisosPersonalizados': false,
    'permisos': <String>[],
    'codigoConfigurado': true,
  };
  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    switch (ruta) {
      case '/administracion/accesos/usuarios':
        return [usuario];
      case '/administracion/accesos/usuarios/9':
        return usuario;
      case '/administracion/accesos/roles':
        return [
          {
            'id': 4,
            'codigo': 'REGISTRO_CENTRAL',
            'nombre': 'Fotos, observaciones y número de lote',
            'activo': true,
            'permisos': [
              'PRODUCTORES_VER',
              'FOTOS_PRODUCTORES_EDITAR',
              'PRODUCTORES_OBSERVAR',
              'NUMERO_LOTE_EDITAR',
              'INFORMES_DESCARGAR',
            ],
          },
          {
            'id': 5,
            'codigo': 'REGISTRO_PRODUCTORES_CENTRAL',
            'nombre': 'Registro de productores',
            'activo': true,
            'permisos': registroCompleto
                ? [
                    'PRODUCTORES_VER',
                    'PRODUCTORES_EDITAR',
                    'SIE_REVISAR',
                    'LOTES_EDITAR',
                    'IMAGENES_EDITAR',
                  ]
                : [
                    'PRODUCTORES_VER',
                    'PRODUCTORES_REGISTRAR',
                    'NUMERO_LOTE_EDITAR',
                  ],
          },
          {
            'id': 6,
            'codigo': 'REGISTRO_REVISION',
            'nombre': 'Gestor de productores',
            'activo': true,
            'permisos': permisosGestor,
          },
          {
            'id': 7,
            'codigo': 'FOTOS_OBSERVACIONES',
            'nombre': 'Fotos y observaciones',
            'activo': true,
            'permisos': [
              'PRODUCTORES_VER',
              'FOTOS_PRODUCTORES_ACTUALIZAR',
              'PRODUCTORES_OBSERVAR',
            ],
          },
        ];
      case '/administracion/accesos/permisos':
        return [
          {
            'codigo': 'PRODUCTORES_VER',
            'nombre': 'Consultar productores',
            'grupo': 'Productores',
          },
          {
            'codigo': 'FOTOS_PRODUCTORES_EDITAR',
            'nombre': 'Editar fotografías',
            'grupo': 'Productores',
          },
          {
            'codigo': 'FOTOS_PRODUCTORES_ACTUALIZAR',
            'nombre': 'Subir y actualizar fotografías',
            'grupo': 'Productores',
          },
          {
            'codigo': 'SIE_REVISAR',
            'nombre': 'Revisar SIE',
            'grupo': 'Productores',
          },
          {
            'codigo': 'PRODUCTORES_REGISTRAR',
            'nombre': 'Registrar productores nuevos',
            'grupo': 'Productores',
          },
          {
            'codigo': 'PRODUCTORES_OBSERVAR',
            'nombre': 'Observar productores',
            'grupo': 'Productores',
          },
          {
            'codigo': 'NUMERO_LOTE_EDITAR',
            'nombre': 'Editar número de lote',
            'grupo': 'Productores',
          },
          {
            'codigo': 'INFORMES_DESCARGAR',
            'nombre': 'Descargar informes',
            'grupo': 'Informes',
          },
          {
            'codigo': 'PRODUCTORES_EDITAR',
            'nombre': 'Editar productores',
            'grupo': 'Productores',
          },
          {
            'codigo': 'LOTES_EDITAR',
            'nombre': 'Editar parcelas',
            'grupo': 'Parcelas',
          },
          {
            'codigo': 'IMAGENES_EDITAR',
            'nombre': 'Editar imágenes',
            'grupo': 'Imágenes',
          },
          {
            'codigo': 'PRODUCTORES_ELIMINAR',
            'nombre': 'Eliminar productores',
            'grupo': 'Productores',
          },
          {
            'codigo': 'LOTES_DESASIGNAR',
            'nombre': 'Quitar parcela asignada',
            'grupo': 'Productores',
          },
          {
            'codigo': 'DIRECTORIOS_EDITAR',
            'nombre': 'Editar directorios',
            'grupo': 'Jerarquía',
          },
          {
            'codigo': 'CARNETS_IMPRIMIR',
            'nombre': 'Imprimir carnets',
            'grupo': 'Carnets',
          },
          {
            'codigo': 'IMPORTAR_PADRON',
            'nombre': 'Importar padrón',
            'grupo': 'Importaciones',
          },
        ];
      case '/centrales':
        return [
          {'id': 3, 'nombre': 'CENTRAL PRUEBA'},
        ];
      case '/centrales/3/sindicatos':
        return [
          {'id': 7, 'nombre': 'SINDICATO A'},
          {'id': 8, 'nombre': 'SINDICATO B'},
        ];
      default:
        throw StateError('Ruta inesperada: $ruta');
    }
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) async {
    guardado = Map<String, dynamic>.from(cuerpo as Map);
    return usuario;
  }

  @override
  Future<Object?> crear(String ruta, Object cuerpo) async {
    codigo = ruta.endsWith('/codigo-manual')
        ? (cuerpo as Map)['codigoAcceso'] as String
        : 'AbCdE234FgHi567JkLmN89pq';
    return {'codigoAcceso': codigo};
  }
}
