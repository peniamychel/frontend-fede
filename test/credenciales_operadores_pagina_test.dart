import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/operadores/credenciales_operadores_pagina.dart';
import 'package:fede/ui/operadores/operador_credencial_previa_pagina.dart';
import 'package:fede/ui/operadores/operador_formulario_pagina.dart';
import 'package:fede/ui/operadores/operadores_resena_pagina.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/sesion_scope.dart';

const _operador = {
  'id': 7,
  'nombres': 'ANA',
  'apellidos': 'PEREZ',
  'ci': '123456',
  'cargo': 'OPERADORA',
  'telefono': '77712345',
};

class _ApiPrueba extends ApiClient {
  bool fallarGuardado = false;
  int consultas = 0;
  int creados = 0;
  int eliminados = 0;
  Object? cuerpo;
  String? busqueda;

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    consultas++;
    if (ruta.endsWith('/configuracion')) {
      return {'resena': 'Autorizado por Carrasco'};
    }
    if (ruta.endsWith('/previa')) {
      return {
        ..._operador,
        'resena': 'Autorizado por Carrasco',
        'federacion': 'CARRASCO TROPICAL',
        'ejecutivo': null,
      };
    }
    if (ruta == '/configuracion/credencial-operador') {
      return {
        'diseno': {'elementos': []},
        'campos': [],
      };
    }
    busqueda = query?['buscar'] as String?;
    return busqueda?.isNotEmpty == true ? [] : [_operador];
  }

  @override
  Future<Object?> crear(String ruta, Object datos) async {
    creados++;
    cuerpo = datos;
    if (fallarGuardado) {
      throw ApiException(estado: 500, mensaje: 'Error de prueba');
    }
    return {...(datos as Map<String, dynamic>), 'id': 7};
  }

  @override
  Future<Object?> reemplazar(
    String ruta,
    Object datos, {
    Map<String, dynamic>? query,
  }) async {
    cuerpo = datos;
    return datos;
  }

  @override
  Future<void> eliminar(String ruta) async {
    eliminados++;
  }
}

Widget _pantalla(_ApiPrueba api, Widget pagina, {SesionControlador? sesion}) {
  Widget app = PadronScope(
    padron: Padron(api: api),
    child: MaterialApp(home: pagina),
  );
  if (sesion != null) app = SesionScope(controlador: sesion, child: app);
  return app;
}

void main() {
  testWidgets('lista, búsqueda y confirmación antes de eliminar', (
    tester,
  ) async {
    final api = _ApiPrueba();
    await tester.pumpWidget(
      _pantalla(api, const CredencialesOperadoresPagina()),
    );
    await tester.pumpAndSettle();
    expect(find.text('ANA PEREZ'), findsOneWidget);
    await tester.tap(find.byTooltip('Acciones del operador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar operador'));
    await tester.pumpAndSettle();
    expect(api.eliminados, 0);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.eliminados, 0);
    await tester.enterText(find.byType(TextField), 'OTRO');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(api.busqueda, 'OTRO');
    expect(find.text('No se encontraron operadores'), findsOneWidget);
  });

  testWidgets('campos obligatorios y fallo al guardar mantienen los datos', (
    tester,
  ) async {
    final api = _ApiPrueba()..fallarGuardado = true;
    await tester.pumpWidget(_pantalla(api, const OperadorFormularioPagina()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(api.creados, 0);
    expect(find.text('Completá este campo'), findsNWidgets(5));
    final valores = ['ANA', 'PEREZ', '123456', 'OPERADORA', '77712345'];
    for (var i = 0; i < valores.length; i++) {
      final campo = find.byType(TextFormField).at(i);
      await tester.ensureVisible(campo);
      await tester.enterText(campo, valores[i]);
    }
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(api.creados, 1);
    expect(find.text('Nuevo operador'), findsOneWidget);
    expect((api.cuerpo as Map)['telefono'], '77712345');
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      'ANA',
    );
  });

  testWidgets('reseña se carga como configuración común', (tester) async {
    await tester.pumpWidget(
      _pantalla(_ApiPrueba(), const OperadoresResenaPagina()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Autorizado por Carrasco'), findsOneWidget);
    expect(find.text('Reseña común de autorización'), findsOneWidget);
  });

  testWidgets('vista previa sin firma permite revisar pero no emitir PDF', (
    tester,
  ) async {
    await tester.pumpWidget(
      _pantalla(
        _ApiPrueba(),
        const OperadorCredencialPreviaPagina(operadorId: 7),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Anverso'), findsOneWidget);
    expect(find.text('Reverso'), findsOneWidget);
    expect(
      find.text('Falta la firma del ejecutivo de la federación'),
      findsOneWidget,
    );
    final boton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Credencial completa en PDF'),
    );
    expect(boton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'usuario de una central no consulta el módulo aunque tenga permiso',
    (tester) async {
      final api = _ApiPrueba();
      final sesion = SesionControlador(AutenticacionRepository(api))
        ..sesion = Sesion(
          token: 'token',
          usuario: 'central',
          nombreCompleto: 'Central',
          rol: 'OPERADOR',
          roles: const {},
          permisos: const {'CREDENCIALES_OPERADORES_GESTIONAR'},
          expiraEn: DateTime(2030),
          centralId: 5,
        );
      await tester.pumpWidget(
        _pantalla(api, const CredencialesOperadoresPagina(), sesion: sesion),
      );
      await tester.pumpAndSettle();
      expect(api.consultas, 0);
      expect(
        find.text('Sin acceso a las credenciales del personal operador'),
        findsOneWidget,
      );
      sesion.dispose();
    },
  );

  testWidgets('vista previa se adapta al móvil sin desbordar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _pantalla(
        _ApiPrueba(),
        const OperadorCredencialPreviaPagina(operadorId: 7),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Anverso'), findsOneWidget);
    expect(find.text('Reverso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
