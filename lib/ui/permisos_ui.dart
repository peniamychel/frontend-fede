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

  /// Registrar no concede permiso para editar identidades ya existentes.
  bool get puedeRegistrarProductores =>
      puede('PRODUCTORES_EDITAR') || puede('PRODUCTORES_REGISTRAR');

  /// La consulta de este perfil sirve únicamente para trabajar con las fotos,
  /// las observaciones y la ficha de datos de cada productor.
  bool get soloFotosObservaciones {
    final sesion =
        getInheritedWidgetOfExactType<SesionScope>()?.notifier?.sesion;
    return sesion != null &&
        !sesion.esAdministrador &&
        sesion.roles.contains('FOTOS_OBSERVACIONES');
  }

  /// Este rol trabaja desde la ficha individual, sin el acceso al editor masivo.
  /// No retira PRODUCTORES_EDITAR ni limita a los administradores.
  bool get mostrarEdicionRapidaProductores {
    final sesion = SesionScope.maybeOf(this)?.sesion;
    return sesion == null ||
        sesion.esAdministrador ||
        (!sesion.roles.contains('REGISTRO_REVISION') &&
            !soloFotosObservaciones);
  }

  /// Oculta los directorios para los perfiles de gestión de productores/fotos,
  /// sin retirar
  /// la consulta a los demás roles ni alterar sus permisos de edición.
  bool get mostrarDirectorios {
    final sesion = SesionScope.maybeOf(this)?.sesion;
    return sesion == null ||
        sesion.esAdministrador ||
        (!sesion.roles.contains('REGISTRO_REVISION') &&
            !soloFotosObservaciones);
  }
}
