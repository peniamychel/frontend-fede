import 'package:flutter/material.dart';

import '../../core/preferencia_tema.dart';

/// Cambia entre claro y oscuro.
///
/// Un toque alterna, que es lo que la mayoría quiere; una pulsación larga —o el
/// clic derecho— abre las tres opciones, incluida la de seguir al sistema. Así
/// lo frecuente queda a un toque sin esconder lo demás.
class BotonTema extends StatelessWidget {
  const BotonTema({super.key});

  @override
  Widget build(BuildContext context) {
    final preferencia = TemaScope.of(context);
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<ThemeMode>(
      tooltip: switch (preferencia.value) {
        ThemeMode.light => 'Tema claro · mantené para más opciones',
        ThemeMode.dark => 'Tema oscuro · mantené para más opciones',
        ThemeMode.system => 'Tema automático · mantené para más opciones',
      },
      icon: Icon(_icono(preferencia.value, esOscuro)),
      // Sin esto el menú se abre con un toque simple y no se podría alternar
      // rápido, que es el caso frecuente.
      onOpened: () {},
      itemBuilder: (context) => [
        for (final modo in ThemeMode.values)
          CheckedPopupMenuItem(
            value: modo,
            checked: preferencia.value == modo,
            child: Text(_etiqueta(modo)),
          ),
      ],
      onSelected: preferencia.cambiar,
    );
  }

  static IconData _icono(ThemeMode modo, bool esOscuro) => switch (modo) {
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
        // En automático se muestra lo que se está viendo, con el matiz de que
        // no lo eligió el usuario.
        ThemeMode.system =>
          esOscuro ? Icons.brightness_auto : Icons.brightness_auto_outlined,
      };

  static String _etiqueta(ThemeMode modo) => switch (modo) {
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
        ThemeMode.system => 'Igual que el sistema',
      };
}

/// Versión de un solo toque, para barras donde no molesta abrir un menú.
class BotonTemaRapido extends StatelessWidget {
  const BotonTemaRapido({super.key});

  @override
  Widget build(BuildContext context) {
    final preferencia = TemaScope.of(context);
    final brillo = Theme.of(context).brightness;
    final esOscuro = brillo == Brightness.dark;

    return IconButton(
      tooltip: esOscuro ? 'Pasar a tema claro' : 'Pasar a tema oscuro',
      onPressed: () => preferencia.alternar(brillo),
      icon: Icon(esOscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
    );
  }
}
