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
    expect(find.text('Seleccionados: 1'), findsOneWidget);
    final elegido = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'SINDICATO A'),
    );
    expect(elegido.value, isTrue);
    expect(find.text('CENTRAL PRUEBA'), findsOneWidget);
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
    expect(api.guardado?['permisos'], ['PRODUCTORES_VER']);
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
      'aBcDe',
    );
    await tester.tap(find.text('Guardar código'));
    await tester.pumpAndSettle();
    expect(api.codigo, 'aBcDe');
    expect(find.text('Código de acceso guardado'), findsOneWidget);
    expect(find.text('aBcDe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel usable en móvil sin desbordar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await abrir(tester, _ApiUsuarios());
    await pulsar(tester, 'Personalizar permisos de este usuario');
    await pulsar(tester, 'Generar código de 5 letras');
    await tester.tap(find.text('Generar'));
    await tester.pumpAndSettle();
    expect(find.text('AbCdE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ApiUsuarios extends ApiClient {
  bool eliminado = false;
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
            'nombre': 'Fotos y lotes',
            'activo': true,
            'permisos': ['PRODUCTORES_VER', 'FOTOS_PRODUCTORES_EDITAR'],
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
            'codigo': 'SIE_REVISAR',
            'nombre': 'Revisar SIE',
            'grupo': 'Productores',
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
        : 'AbCdE';
    return {'codigoAcceso': codigo};
  }
}
