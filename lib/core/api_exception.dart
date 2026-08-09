/// Error devuelto por la API, mapeado desde el `ErrorResponse` del backend.
///
/// El backend responde con la misma forma en todos los fallos:
/// `{estado, mensaje, errores, momento}`, donde `errores` trae el detalle por
/// campo cuando la validación de Jakarta rechaza una petición.
class ApiException implements Exception {
  const ApiException({
    required this.estado,
    required this.mensaje,
    this.errores = const {},
    this.momento,
  });

  final int estado;
  final String mensaje;

  /// Mensajes de validación por campo, por ejemplo
  /// `{'nombres': 'los nombres son obligatorios'}`. Va directo a los
  /// `errorText` del formulario.
  final Map<String, String> errores;

  final DateTime? momento;

  bool get esValidacion => estado == 400;
  bool get esNoEncontrado => estado == 404;
  bool get esConflicto => estado == 409;
  bool get esDelServidor => estado >= 500;

  /// Construye la excepción a partir del cuerpo ya decodificado. Si la
  /// respuesta no tenía la forma esperada, conserva al menos el código HTTP.
  factory ApiException.desdeJson(int estado, Object? cuerpo) {
    if (cuerpo is! Map) {
      return ApiException(estado: estado, mensaje: _mensajePorDefecto(estado));
    }

    final errores = <String, String>{};
    final crudos = cuerpo['errores'];
    if (crudos is Map) {
      for (final entrada in crudos.entries) {
        errores['${entrada.key}'] = '${entrada.value}';
      }
    }

    return ApiException(
      estado: (cuerpo['estado'] as num?)?.toInt() ?? estado,
      mensaje: cuerpo['mensaje'] as String? ?? _mensajePorDefecto(estado),
      errores: errores,
      momento: DateTime.tryParse('${cuerpo['momento']}'),
    );
  }

  static String _mensajePorDefecto(int estado) => switch (estado) {
        400 => 'La petición tiene datos inválidos.',
        404 => 'No se encontró el recurso solicitado.',
        409 => 'El registro entra en conflicto con uno existente.',
        _ when estado >= 500 => 'El servidor falló al procesar la petición.',
        _ => 'La petición falló con código $estado.',
      };

  /// Texto listo para mostrar, con el detalle de validación si lo hay.
  String get descripcion {
    if (errores.isEmpty) return mensaje;
    final detalle = errores.entries.map((e) => '• ${e.value}').join('\n');
    return '$mensaje\n$detalle';
  }

  @override
  String toString() => 'ApiException($estado): $mensaje';
}

/// No hubo respuesta: el backend está apagado, el host no es alcanzable, o la
/// petición excedió el tiempo de espera.
class SinConexionException implements Exception {
  const SinConexionException(this.destino, [this.causa]);

  /// A dónde se intentó llegar, para poder decirlo en pantalla.
  final String destino;
  final Object? causa;

  String get descripcion =>
      'No se pudo conectar con $destino.\n'
      'Verificá que el backend esté corriendo y que la dirección sea la correcta.';

  @override
  String toString() => 'SinConexionException($destino): $causa';
}
