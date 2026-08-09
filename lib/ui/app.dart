import 'package:flutter/material.dart';

import '../core/preferencia_tema.dart';
import '../repositories/padron.dart';
import 'inicio.dart';
import 'padron_scope.dart';

class PadronApp extends StatefulWidget {
  const PadronApp({super.key});

  @override
  State<PadronApp> createState() => _PadronAppState();
}

class _PadronAppState extends State<PadronApp> {
  final Padron _padron = Padron();
  final PreferenciaTema _tema = PreferenciaTema();

  @override
  void initState() {
    super.initState();
    // Se lee sin bloquear el arranque: la app se dibuja en automático y salta
    // al tema guardado en cuanto se conoce. Esperar la lectura para mostrar
    // algo agregaría una pantalla en blanco por una preferencia.
    _tema.cargar();
  }

  @override
  void dispose() {
    _padron.cerrar();
    _tema.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PadronScope(
      padron: _padron,
      child: TemaScope(
        preferencia: _tema,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: _tema,
          builder: (context, modo, _) => MaterialApp(
            title: 'Padrón FEDERA',
            debugShowCheckedModeBanner: false,
            theme: _construirTema(Brightness.light),
            darkTheme: _construirTema(Brightness.dark),
            themeMode: modo,
            home: const Inicio(),
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
        backgroundColor:
            esOscuro ? esquema.surfaceContainer : esquema.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: esOscuro ? 0 : 2,
      ),
      dividerTheme: DividerThemeData(color: esquema.outlineVariant),
    );
  }
}
