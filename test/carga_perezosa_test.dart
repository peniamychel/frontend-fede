import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fede/core/preferencia_tema.dart';
import 'package:fede/core/sesion_controlador.dart';
import 'package:fede/repositories/padron.dart';
import 'package:fede/ui/inicio.dart';
import 'package:fede/ui/administracion/accesos_pagina.dart';
import 'package:fede/ui/padron_scope.dart';
import 'package:fede/ui/sesion_scope.dart';

/// Cada sección se carga la primera vez que se entra, no al abrir la app.
///
/// El armazón usa un IndexedStack para conservar el scroll y los filtros al ir
/// y volver entre secciones. El precio de eso es que construye todos sus hijos
/// de entrada: al abrir la aplicación salían once consultas a la API para
/// dibujar cinco pantallas de las que se ve una.
///
/// Estas pruebas fijan el arreglo. Sin ellas, agregar una sección nueva volvería
/// a sumar sus consultas al arranque sin que nadie se entere.
void main() {
  /// Cliente que anota cada ruta pedida y no llama a ningún servidor.
  late _ApiEspia espia;

  Widget app({Sesion? datosSesion}) {
    Widget vista = const MaterialApp(home: Inicio());
    if (datosSesion != null) {
      final controlador = SesionControlador(AutenticacionRepository(espia));
      controlador.sesion = datosSesion;
      addTearDown(controlador.dispose);
      vista = SesionScope(controlador: controlador, child: vista);
    }
    return TemaScope(
      preferencia: PreferenciaTema(),
      child: PadronScope(
        padron: Padron(api: espia),
        child: vista,
      ),
    );
  }

  setUp(() => espia = _ApiEspia());

  Sesion sesionMenu({bool administrador = true}) => Sesion(
    token: 'prueba',
    usuario: 'usuario',
    nombreCompleto: 'Usuario de prueba',
    rol: administrador ? 'ADMIN' : 'OPERADOR',
    roles: {administrador ? 'ADMIN' : 'SUPERVISOR'},
    permisos: const {
      'PRODUCTORES_VER',
      'REUNIONES_GESTIONAR',
      'CARNETS_DISENO',
      'CREDENCIALES_OPERADORES_GESTIONAR',
      'USUARIOS_ADMINISTRAR',
      'RESPALDOS_ADMINISTRAR',
    },
    expiraEn: DateTime(2100),
  );

  for (final caso in [
    (tamano: const Size(390, 844), administrador: true, ocultar: true),
    (tamano: const Size(640, 600), administrador: true, ocultar: false),
    (tamano: const Size(1200, 800), administrador: true, ocultar: false),
    (tamano: const Size(390, 844), administrador: false, ocultar: false),
  ]) {
    testWidgets(
      'menú móvil administrador ${caso.administrador} en ${caso.tamano}',
      (tester) async {
        tester.view.physicalSize = caso.tamano;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          app(datosSesion: sesionMenu(administrador: caso.administrador)),
        );
        await tester.pumpAndSettle();
        final menu = caso.tamano.width < 700
            ? find.byType(NavigationBar)
            : find.byType(NavigationRail);
        for (final etiqueta in ['Carnet', 'Personal operador', 'Reuniones']) {
          expect(
            find.descendant(of: menu, matching: find.text(etiqueta)),
            caso.ocultar ? findsNothing : findsOneWidget,
          );
        }
        for (final etiqueta in [
          'Productores',
          'Centrales',
          'Calidad',
          'Respaldos',
          'Accesos',
          'Cuenta',
        ]) {
          expect(
            find.descendant(of: menu, matching: find.text(etiqueta)),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Accesos conserva su página e índice al girar el móvil y Atrás omite menús ocultos',
    (tester) async {
      tester.view.physicalSize = const Size(640, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(datosSesion: sesionMenu()));
      await tester.pumpAndSettle();
      final barra = find.byType(NavigationBar);
      for (final etiqueta in ['Reuniones', 'Accesos']) {
        await tester.tap(
          find.descendant(of: barra, matching: find.text(etiqueta)),
        );
        await tester.pumpAndSettle();
      }
      final accesos = tester.state(find.byType(AccesosPagina));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationBar>(barra).selectedIndex, 4);
      expect(tester.state(find.byType(AccesosPagina)), same(accesos));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<NavigationBar>(barra).selectedIndex, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('girar a vertical desde Reuniones vuelve a Productores', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(datosSesion: sesionMenu()));
    await tester.pumpAndSettle();
    final barra = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: barra, matching: find.text('Reuniones')),
    );
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationBar>(barra).selectedIndex, 0);
    expect(
      find.descendant(of: barra, matching: find.text('Reuniones')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('al abrir solo consulta la sección visible', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    // Productores es la primera sección: lo suyo sí se pide.
    expect(
      espia.rutas.any((r) => r.startsWith('/productores')),
      isTrue,
      reason: 'la sección visible tiene que cargar sus datos',
    );

    // Lo de las otras tres, no.
    for (final ajena in ['/reuniones', '/federaciones']) {
      expect(
        espia.rutas.any((r) => r.startsWith(ajena)),
        isFalse,
        reason: 'no se puede consultar $ajena antes de entrar a esa sección',
      );
    }
  });

  testWidgets('entrar a una sección carga la suya, y solo la suya', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    espia.rutas.clear();

    // La tercera pestaña es Reuniones.
    await tester.tap(find.text('Reuniones'));
    await tester.pump();

    expect(espia.rutas.any((r) => r.startsWith('/reuniones')), isTrue);
    expect(
      espia.rutas.any((r) => r.startsWith('/federaciones')),
      isFalse,
      reason: 'entrar a una sección no puede arrastrar a las demás',
    );
  });

  testWidgets('volver a una sección ya visitada no la reconstruye', (
    tester,
  ) async {
    // Es lo que da el IndexedStack y hay que conservarlo: al volver, el scroll
    // y los filtros siguen donde estaban, sin pedir los datos de nuevo.
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.tap(find.text('Reuniones'));
    await tester.pump();
    final tras = espia.rutas.where((r) => r.startsWith('/reuniones')).length;

    await tester.tap(find.text('Productores'));
    await tester.pump();
    await tester.tap(find.text('Reuniones'));
    await tester.pump();

    expect(
      espia.rutas.where((r) => r.startsWith('/reuniones')).length,
      equals(tras),
      reason: 'volver no puede volver a consultar',
    );
  });

  testWidgets('el nombre del padrón abre el directorio de la federación', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pump();

    expect(
      espia.rutas.where((ruta) => ruta == '/federaciones'),
      isEmpty,
      reason: 'el menú no debe consultar la federación antes de abrirse',
    );

    await tester.tap(find.byKey(const ValueKey('menu-directorio-federacion')));
    await tester.pumpAndSettle();
    expect(find.text('Directorio de la federación'), findsOneWidget);

    await tester.tap(find.text('Directorio de la federación'));
    await tester.pumpAndSettle();

    expect(find.text('Directorio de CARRASCO TROPICAL'), findsOneWidget);
    expect(espia.rutas, contains('/federaciones/10/directorio'));
    expect(espia.rutas, contains('/federaciones/10/directorio/historial'));
  });

  for (final caso in [
    (
      nombre: 'registro y revisión',
      roles: {'REGISTRO_REVISION'},
      administrador: false,
      mostrar: false,
    ),
    (
      nombre: 'registro de productores',
      roles: {'REGISTRO'},
      administrador: false,
      mostrar: true,
    ),
    (
      nombre: 'solo consulta',
      roles: {'CONSULTA'},
      administrador: false,
      mostrar: true,
    ),
    (
      nombre: 'administrador con registro y revisión',
      roles: {'ADMIN', 'REGISTRO_REVISION'},
      administrador: true,
      mostrar: true,
    ),
  ]) {
    testWidgets('menú de directorio federación para ${caso.nombre}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          datosSesion: Sesion(
            token: 'prueba',
            usuario: 'usuario',
            nombreCompleto: 'Usuario de prueba',
            rol: caso.administrador ? 'ADMIN' : 'OPERADOR',
            roles: caso.roles,
            permisos: const {'PRODUCTORES_VER'},
            expiraEn: DateTime(2100),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menu = find.byKey(const ValueKey('menu-directorio-federacion'));
      final marca = find.text('PADRÓN FEDERACIÓN\nCARRASCO TROPICAL');
      expect(marca, findsOneWidget);
      expect(menu, caso.mostrar ? findsOneWidget : findsNothing);
      expect(
        find.byTooltip('Opciones de la federación'),
        caso.mostrar ? findsOneWidget : findsNothing,
      );

      if (caso.mostrar) {
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.text('Directorio de la federación'), findsOneWidget);
        await tester.tap(find.text('Directorio de la federación'));
        await tester.pumpAndSettle();
        expect(find.text('Directorio de CARRASCO TROPICAL'), findsOneWidget);
        expect(espia.rutas, contains('/federaciones/10/directorio'));
      } else {
        final encabezado = find
            .ancestor(of: marca, matching: find.byType(Row))
            .first;
        expect(
          find.descendant(
            of: encabezado,
            matching: find.byIcon(Icons.arrow_drop_down),
          ),
          findsNothing,
        );
        await tester.tap(marca);
        await tester.pumpAndSettle();
        expect(find.text('Directorio de la federación'), findsNothing);
        expect(
          espia.rutas.where((ruta) => ruta.startsWith('/federaciones')),
          isEmpty,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}

/// Un ApiClient que anota las rutas y devuelve listas vacías.
///
/// No hereda de una interfaz porque no hay ninguna: se extiende el cliente real
/// y se interceptan sus cuatro métodos de lectura, que es lo único que las
/// pantallas usan al construirse.
class _ApiEspia extends ApiClient {
  final List<String> rutas = [];

  @override
  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) async {
    rutas.add(ruta);
    if (ruta == '/federaciones') {
      return [
        {'id': 10, 'nombre': 'CARRASCO TROPICAL'},
      ];
    }
    if (ruta == '/federaciones/10/directorio') {
      return {
        'ambito': 'FEDERACION',
        'ambitoId': 10,
        'ambitoNombre': 'CARRASCO TROPICAL',
        'puestos': <dynamic>[],
      };
    }
    if (ruta == '/federaciones/10/directorio/historial') {
      return <dynamic>[];
    }
    // Las pantallas esperan una lista o una página; se devuelve lo mínimo que
    // no rompe el mapeo de ninguna.
    if (ruta.contains('total')) return 0;
    return <dynamic>[];
  }
}
