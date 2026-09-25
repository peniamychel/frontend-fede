import 'package:flutter/widgets.dart';
import 'sesion_scope.dart';

/// Consulta permisos sin acoplar cada pantalla al modelo de sesión.
///
/// Cuando una pantalla se prueba aislada, sin [SesionScope], se conserva el
/// comportamiento completo histórico. En la aplicación real el scope siempre
/// está presente y decide según el backend.
extension PermisosUi on BuildContext {
  bool get accesoCentral =>
      getInheritedWidgetOfExactType<SesionScope>()
          ?.notifier
          ?.sesion
          ?.centralId !=
      null;
  bool puede(String permiso) =>
      SesionScope.maybeOf(this)?.puede(permiso) ?? true;
}
