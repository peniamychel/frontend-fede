import 'package:flutter/widgets.dart';

import '../repositories/padron.dart';

/// Deja el [Padron] disponible para todo el árbol de widgets.
///
/// Es un [InheritedWidget] a propósito: la app tiene un único cliente HTTP y
/// seis repositorios sin estado, así que no hace falta traer una librería de
/// gestión de estado para esto.
class PadronScope extends InheritedWidget {
  const PadronScope({
    super.key,
    required this.padron,
    required super.child,
  });

  final Padron padron;

  /// Devuelve el [Padron] sin suscribirse a cambios.
  ///
  /// Usa `getInheritedWidgetOfExactType` y no `dependOnInheritedWidgetOfExactType`
  /// a propósito. La segunda registra una dependencia, y Flutter prohíbe
  /// registrarla desde `initState`: casi todas las pantallas lanzan su primera
  /// petición justo ahí, así que depender rompería el arranque de siete
  /// pantallas. Como el [Padron] se construye una sola vez en el arranque de la
  /// app y nunca se reemplaza, no hay nada a lo que suscribirse.
  static Padron of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PadronScope>();
    assert(scope != null, 'No hay un PadronScope por encima de este widget.');
    return scope!.padron;
  }

  @override
  bool updateShouldNotify(PadronScope oldWidget) => padron != oldWidget.padron;
}
