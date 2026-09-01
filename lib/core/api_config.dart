import 'package:flutter/foundation.dart';

/// Resuelve dónde vive la API del padrón según dónde corra esta app.
///
/// El host no puede ser una constante: el emulador de Android es una máquina
/// virtual, así que dentro de él `localhost` apunta a sí mismo y nunca al
/// equipo que ejecuta Spring Boot. Para un teléfono físico hace falta la IP de
/// la red local, que solo se conoce al compilar:
///
/// ```
/// flutter run --dart-define=API_HOST=192.168.1.20
/// ```
class ApiConfig {
  const ApiConfig._();

  static const String _hostForzado = String.fromEnvironment('API_HOST');
  static const int _puerto = int.fromEnvironment(
    'API_PUERTO',
    defaultValue: 8080,
  );

  /// Prefijo común de los recursos versionados del backend.
  static const String prefijo = '/api/v1';

  static String get host {
    if (_hostForzado.isNotEmpty) return _hostForzado;
    // En web, el host debe acompañar al navegador. Así, si otro dispositivo
    // abre la aplicación mediante 192.168.x.x, también consulta la API en esa
    // máquina en vez de intentar usar el localhost del propio dispositivo.
    if (kIsWeb) return Uri.base.host;
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return 'localhost';
  }

  /// En web la API se publica detrás del mismo servidor que entrega Flutter.
  /// Reutilizar esquema y puerto permite que Nginx haga el proxy en Docker sin
  /// dejar una IP ni un puerto de producción escritos dentro del build.
  static String get esquema {
    if (kIsWeb && _hostForzado.isEmpty) return Uri.base.scheme;
    return 'http';
  }

  static int get puerto {
    if (kIsWeb && _hostForzado.isEmpty) return Uri.base.port;
    return _puerto;
  }

  /// Cómo se está apuntando al backend. Útil para mostrarlo en una pantalla de
  /// diagnóstico cuando algo no conecta.
  static String get descripcion => '$esquema://$host:$puerto$prefijo';

  /// Convierte una ruta relativa devuelta por la API —como la URL de una
  /// imagen— en una dirección completa.
  ///
  /// La API las devuelve relativas a propósito: guardar la URL absoluta en la
  /// base ataría los datos al host y rompería todo al cambiar de dominio o de
  /// puerto. El cliente, que sí sabe a qué servidor le habla, la completa.
  static String urlAbsoluta(String rutaRelativa) {
    if (rutaRelativa.startsWith('http://') ||
        rutaRelativa.startsWith('https://')) {
      return rutaRelativa;
    }
    final camino = rutaRelativa.startsWith('/')
        ? rutaRelativa
        : '/$rutaRelativa';
    return '$esquema://$host:$puerto$camino';
  }

  /// Construye la URI de un recurso. Las claves de [query] con valor nulo se
  /// descartan, para poder pasar filtros opcionales sin condicionales.
  static Uri uri(String ruta, [Map<String, dynamic>? query]) {
    return Uri(
      scheme: esquema,
      host: host,
      port: puerto,
      path: '$prefijo$ruta',
      queryParameters: query == null ? null : _limpiar(query),
    );
  }

  static Map<String, dynamic>? _limpiar(Map<String, dynamic> query) {
    final limpio = <String, dynamic>{};
    for (final entrada in query.entries) {
      final valor = entrada.value;
      if (valor == null) continue;
      if (valor is Iterable) {
        final lista = valor.map((e) => '$e').toList(growable: false);
        if (lista.isNotEmpty) limpio[entrada.key] = lista;
      } else {
        final texto = '$valor';
        if (texto.isNotEmpty) limpio[entrada.key] = texto;
      }
    }
    return limpio.isEmpty ? null : limpio;
  }
}
