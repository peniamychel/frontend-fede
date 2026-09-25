import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/preferencia_tema.dart';
import '../core/sesion_controlador.dart';
import '../repositories/padron.dart';
import 'inicio.dart';
import 'acceso/acceso_pagina.dart';
import 'padron_scope.dart';
import 'sesion_scope.dart';

class PadronApp extends StatefulWidget {
  const PadronApp({super.key, this.preferenciaTema, this.padron});

  /// `main` la entrega ya cargada para que MaterialApp no cambie de tema
  /// mientras Flutter calcula el primer layout de la versión web.
  final PreferenciaTema? preferenciaTema;

  /// Se puede inyectar en pruebas para recorrer el acceso completo sin abrir
  /// conexiones reales. En la aplicación normal se crea el repositorio aquí.
  final Padron? padron;

  @override
  State<PadronApp> createState() => _PadronAppState();
}

class _PadronAppState extends State<PadronApp> {
  late final Padron _padron;
  late final bool _esPropietariaDelPadron;
  late final PreferenciaTema _tema;
  late final SesionControlador _sesion;
  final GlobalKey<NavigatorState> _navegador = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _esPropietariaDelPadron = widget.padron == null;
    _padron = widget.padron ?? Padron();
    _tema = widget.preferenciaTema ?? PreferenciaTema();
    _sesion = SesionControlador(_padron.autenticacion)..restaurar();
  }

  @override
  void dispose() {
    if (_esPropietariaDelPadron) _padron.cerrar();
    _tema.dispose();
    _sesion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PadronScope(
      padron: _padron,
      child: SesionScope(
        controlador: _sesion,
        child: TemaScope(
          preferencia: _tema,
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: _tema,
            builder: (context, modo, _) => ListenableBuilder(
              listenable: _sesion,
              builder: (context, _) => MaterialApp(
                navigatorKey: _navegador,
                title: 'PADRÓN FEDERACIÓN CARRASCO TROPICAL',
                debugShowCheckedModeBanner: false,
                theme: _construirTema(Brightness.light),
                darkTheme: _construirTema(Brightness.dark),
                themeMode: modo,
                home: _sesion.restaurando
                    ? const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      )
                    : _sesion.autenticado
                    ? const Inicio()
                    : const AccesoPagina(),
                builder: (context, child) {
                  final contenido = child ?? const SizedBox.shrink();
                  // El navegador ya administra su propia tecla Escape. Crear un
                  // foco global durante el arranque de Flutter Web provoca que el
                  // motor intente medir controles antes del primer layout.
                  if (kIsWeb) return contenido;
                  return RetrocesoConEscape(
                    navegador: _navegador,
                    child: contenido,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  ThemeData _construirTema(Brightness brillo) {
    final esquema = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E6B4F),
      brightness: brillo,
    );
    final esOscuro = brillo == Brightness.dark;

    return ThemeData(
      colorScheme: esquema,
      useMaterial3: true,
      // La app es de escritorio tanto como de móvil: densidad compacta para
      // que quepan más filas del padrón en pantalla.
      visualDensity: VisualDensity.adaptivePlatformDensity,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: esquema.outlineVariant),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      // En oscuro, una barra del mismo color que el fondo hace desaparecer el
      // borde entre encabezado y contenido; un tono apenas distinto lo separa
      // sin agregar una línea.
      appBarTheme: AppBarTheme(
        backgroundColor: esOscuro ? esquema.surfaceContainer : esquema.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: esOscuro ? 0 : 2,
      ),
      dividerTheme: DividerThemeData(color: esquema.outlineVariant),
    );
  }
}

/// Hace que Escape cierre primero el diálogo o la pantalla superior.
///
/// Vive alrededor del Navigator completo, por lo que funciona incluso cuando
/// el foco está dentro de un campo de texto. En la pantalla inicial no hace
/// nada y deja que el navegador conserve la aplicación abierta.
class RetrocesoConEscape extends StatelessWidget {
  const RetrocesoConEscape({
    super.key,
    required this.navegador,
    required this.child,
  });

  final GlobalKey<NavigatorState> navegador;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          navegador.currentState?.maybePop();
        },
      },
      // Navigator y los controles de cada ruta administran el foco. Pedirlo
      // aquí con autofocus durante el primer frame hacía que Flutter Web
      // intentara recorrer un RenderBox todavía sin tamaño.
      child: Focus(child: child),
    );
  }
}
