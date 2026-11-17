import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/api_client.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/models/sesion.dart';
import 'package:fede/repositories/autenticacion_repository.dart';
import 'package:fede/ui/permisos_ui.dart';
import 'package:fede/ui/sesion_scope.dart';

void main() {
  Future<void> abrir(
    WidgetTester tester, {
    Set<String>? roles,
    bool administrador = false,
  }) async {
    Widget vista = MaterialApp(
      home: Builder(
        builder: (context) => Column(
          children: [
            Text('edición rápida: ${context.mostrarEdicionRapidaProductores}'),
            Text('directorios: ${context.mostrarDirectorios}'),
            Text('editar ficha: ${context.puede('PRODUCTORES_EDITAR')}'),
          ],
        ),
      ),
    );
    if (roles != null) {
      final api = ApiClient();
      addTearDown(api.cerrar);
      final controlador = SesionControlador(AutenticacionRepository(api));
      addTearDown(controlador.dispose);
      controlador.sesion = Sesion(
        token: 'prueba',
        usuario: 'registro',
        nombreCompleto: 'Usuario de prueba',
        rol: administrador ? 'ADMIN' : 'OPERADOR',
        roles: roles,
        permisos: const {'PRODUCTORES_VER', 'PRODUCTORES_EDITAR'},
        expiraEn: DateTime(2100),
      );
      vista = SesionScope(controlador: controlador, child: vista);
    }
    await tester.pumpWidget(vista);
  }

  testWidgets('registro y revisión oculta edición rápida pero conserva ficha', (
    tester,
  ) async {
    await abrir(tester, roles: {'REGISTRO_REVISION'});

    expect(find.text('edición rápida: false'), findsOneWidget);
    expect(find.text('directorios: false'), findsOneWidget);
    expect(find.text('editar ficha: true'), findsOneWidget);
  });

  testWidgets(
    'fotos y observaciones no muestra directorios ni edición rápida',
    (tester) async {
      await abrir(tester, roles: {'FOTOS_OBSERVACIONES'});

      expect(find.text('edición rápida: false'), findsOneWidget);
      expect(find.text('directorios: false'), findsOneWidget);
    },
  );

  for (final rol in ['REGISTRO', 'REGISTRO_CENTRAL', 'SUPERVISOR']) {
    testWidgets('el rol $rol conserva el acceso a edición rápida', (
      tester,
    ) async {
      await abrir(tester, roles: {rol});

      expect(find.text('edición rápida: true'), findsOneWidget);
      expect(find.text('directorios: true'), findsOneWidget);
      expect(find.text('editar ficha: true'), findsOneWidget);
    });
  }

  testWidgets(
    'administrador conserva edición rápida aunque tenga el nuevo rol',
    (tester) async {
      await abrir(
        tester,
        roles: {'ADMIN', 'REGISTRO_REVISION', 'FOTOS_OBSERVACIONES'},
        administrador: true,
      );

      expect(find.text('edición rápida: true'), findsOneWidget);
      expect(find.text('directorios: true'), findsOneWidget);
    },
  );

  testWidgets('sin sesión conserva el comportamiento histórico de las vistas', (
    tester,
  ) async {
    await abrir(tester);

    expect(find.text('edición rápida: true'), findsOneWidget);
    expect(find.text('directorios: true'), findsOneWidget);
    expect(find.text('editar ficha: true'), findsOneWidget);
  });
}
