import 'package:flutter/widgets.dart';
import '../core/sesion_controlador.dart';

class SesionScope extends InheritedNotifier<SesionControlador> {
  const SesionScope({super.key, required SesionControlador controlador, required super.child})
      : super(notifier: controlador);

  static SesionControlador of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SesionScope>();
    assert(scope != null, 'No hay SesionScope en el árbol.');
    return scope!.notifier!;
  }

  static SesionControlador? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SesionScope>()?.notifier;
}
