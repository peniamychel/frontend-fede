import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// Cliente HTTP contra la API del padrón.
///
/// Centraliza tres cosas que si no habría que repetir en cada repositorio:
/// decodificar siempre en UTF-8, traducir los `ErrorResponse` del backend a
/// [ApiException], y aceptar tanto 200 como 201 en las altas — los POST del
/// backend devuelven 201 aunque el spec diga 200.
class ApiClient {
  ApiClient({
    http.Client? cliente,
    this.tiempoLimite = const Duration(seconds: 20),
  }) : _cliente = cliente ?? http.Client();

  final http.Client _cliente;
  final Duration tiempoLimite;
  String? _token;

  static const Map<String, String> _cabeceras = {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
  };

  void cerrar() => _cliente.close();

  void usarToken(String? token) {
    final limpio = token?.trim();
    _token = limpio == null || limpio.isEmpty ? null : limpio;
  }

  bool get tieneToken => _token != null;

  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) =>
      _enviar('GET', ruta, query: query);

  Future<DescargaBinaria> obtenerBytes(
    String ruta, {
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    final peticion = http.Request('GET', ApiConfig.uri(ruta, query));
    // Una descarga puede ser PDF, XLSX, GZIP u otro binario. Pedir solamente
    // application/octet-stream hace que Spring responda 406 cuando el endpoint
    // declara un tipo más específico, como application/gzip.
    peticion.headers['Accept'] = '*/*';
    _autorizar(peticion.headers);

    final http.Response respuesta;
    try {
      final flujo = await _cliente.send(peticion).timeout(tiempoLimite);
      respuesta = await http.Response.fromStream(flujo);
    } on TimeoutException catch (e) {
      throw SinConexionException(ApiConfig.descripcion, e);
    } on http.ClientException catch (e) {
      throw SinConexionException(ApiConfig.descripcion, e);
    }

    if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
      _interpretar(respuesta);
    }
    return DescargaBinaria(
      bytes: respuesta.bodyBytes,
      nombreArchivo: _nombreDescarga(respuesta.headers['content-disposition']),
      tipoMime: respuesta.headers['content-type'] ?? 'application/octet-stream',
    );
  }

  Future<Object?> crear(String ruta, Object cuerpo) =>
      _enviar('POST', ruta, cuerpo: cuerpo);

  /// PUT, con parámetros de consulta opcionales.
  ///
  /// El [query] va aparte y no pegado a [ruta] con un `?`: la URI se arma con
  /// `Uri(path: ...)`, que codifica el signo de pregunta como parte del camino
  /// y convierte `/traslado?loteId=5` en `/traslado%3FloteId=5`. El servidor
  /// responde 404 y el error no dice por qué.
  Future<Object?> reemplazar(
    String ruta,
    Object cuerpo, {
    Map<String, dynamic>? query,
  }) => _enviar('PUT', ruta, cuerpo: cuerpo, query: query);

  Future<Object?> parchear(String ruta, {Object? cuerpo}) =>
      _enviar('PATCH', ruta, cuerpo: cuerpo);

  Future<void> eliminar(String ruta) async {
    await _enviar('DELETE', ruta);
  }

  /// DELETE que sí devuelve cuerpo.
  ///
  /// No todo borrado responde 204: quitar la ubicación de un sindicato lo
  /// devuelve actualizado, porque el sindicato no desaparece.
  Future<Object?> eliminarConRespuesta(
    String ruta, {
    Map<String, dynamic>? query,
  }) => _enviar('DELETE', ruta, query: query);

  /// Sube un archivo como `multipart/form-data`.
  ///
  /// No lleva las cabeceras normales: `MultipartRequest` arma su propio
  /// `Content-Type` con el separador de partes, y fijarlo a mano lo rompería.
  /// El tiempo límite es aparte porque subir y procesar una planilla de miles
  /// de filas no entra en los 20 segundos del resto de las llamadas.
  /// [campos] son los datos que acompañan al archivo —el número del acta, por
  /// ejemplo—. Van como partes del formulario y no en la dirección: lo que se
  /// manda en un POST no tiene por qué quedar escrito en el historial ni en el
  /// registro del servidor. Los nulos se omiten.
  Future<Object?> subirArchivo(
    String ruta, {
    required String campo,
    required List<int> bytes,
    required String nombreArchivo,
    Map<String, String?>? campos,
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    final uri = ApiConfig.uri(ruta, query);
    final peticion = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes(campo, bytes, filename: nombreArchivo),
      );
    _autorizar(peticion.headers);
    campos?.forEach((clave, valor) {
      if (valor != null) peticion.fields[clave] = valor;
    });

    final http.Response respuesta;
    try {
      final flujo = await _cliente.send(peticion).timeout(tiempoLimite);
      respuesta = await http.Response.fromStream(flujo);
    } on TimeoutException catch (e) {
      throw SinConexionException(ApiConfig.descripcion, e);
    } on http.ClientException catch (e) {
      throw SinConexionException(ApiConfig.descripcion, e);
    }

    return _interpretar(respuesta);
  }

  Future<Object?> _enviar(
    String metodo,
    String ruta, {
    Map<String, dynamic>? query,
    Object? cuerpo,
  }) async {
    final uri = ApiConfig.uri(ruta, query);
    final peticion = http.Request(metodo, uri)..headers.addAll(_cabeceras);
    _autorizar(peticion.headers);
    if (cuerpo != null) {
      peticion.body = jsonEncode(cuerpo);
    }

    final http.Response respuesta;
    try {
      final flujo = await _cliente.send(peticion).timeout(tiempoLimite);
      respuesta = await http.Response.fromStream(flujo);
    } on TimeoutException catch (e) {
      throw SinConexionException(ApiConfig.descripcion, e);
    } on http.ClientException catch (e) {
      // Cubre los dos casos sin importar la plataforma: en escritorio y móvil
      // el paquete http envuelve aquí el SocketException del sistema, y en web
      // un fallo de CORS o de red llega igual, porque el navegador no deja
      // distinguirlos. Importar dart:io para atrapar SocketException rompería
      // la compilación del target web.
      throw SinConexionException(ApiConfig.descripcion, e);
    }

    return _interpretar(respuesta);
  }

  Object? _interpretar(http.Response respuesta) {
    final codigo = respuesta.statusCode;

    // 204 No Content: los DELETE del backend no devuelven cuerpo.
    if (codigo == 204 || respuesta.bodyBytes.isEmpty) {
      if (codigo >= 400) {
        throw ApiException.desdeJson(codigo, null);
      }
      return null;
    }

    // `respuesta.body` asume latin-1 si el servidor no declara charset, lo que
    // rompe los acentos. Decodificar los bytes a mano evita el problema.
    final texto = utf8.decode(respuesta.bodyBytes, allowMalformed: true);

    Object? decodificado;
    try {
      decodificado = jsonDecode(texto);
    } on FormatException {
      decodificado = null;
    }

    if (codigo >= 200 && codigo < 300) {
      return decodificado;
    }

    throw ApiException.desdeJson(codigo, decodificado);
  }

  void _autorizar(Map<String, String> cabeceras) {
    final token = _token;
    if (token != null) cabeceras['Authorization'] = 'Bearer $token';
  }

  String _nombreDescarga(String? disposicion) {
    if (disposicion == null) return 'descarga.bin';
    final coincidencia = RegExp(
      r'''filename\*?=(?:UTF-8''|["']?)([^"';]+)''',
      caseSensitive: false,
    ).firstMatch(disposicion);
    return Uri.decodeComponent(
      coincidencia?.group(1)?.trim() ?? 'descarga.bin',
    );
  }
}

class DescargaBinaria {
  const DescargaBinaria({
    required this.bytes,
    required this.nombreArchivo,
    required this.tipoMime,
  });

  final List<int> bytes;
  final String nombreArchivo;
  final String tipoMime;
}

/// Azúcar para los repositorios: castea la respuesta al tipo esperado.
///
/// La extensión va sobre `Object?` y no sobre `dynamic` a propósito: Dart no
/// resuelve métodos de extensión cuando el tipo estático es `dynamic`, así que
/// declararla así la volvería inalcanzable.
extension RespuestaJson on Object? {
  Map<String, dynamic> get comoObjeto {
    final valor = this;
    if (valor is Map<String, dynamic>) return valor;
    throw const ApiException(
      estado: 500,
      mensaje: 'El servidor devolvió algo que no es un objeto JSON.',
    );
  }

  List<Map<String, dynamic>> get comoLista {
    final valor = this;
    if (valor is List) return valor.whereType<Map<String, dynamic>>().toList();
    throw const ApiException(
      estado: 500,
      mensaje: 'El servidor devolvió algo que no es una lista JSON.',
    );
  }

  List<String> get comoListaDeTextos {
    final valor = this;
    if (valor is List) return valor.map((e) => '$e').toList(growable: false);
    throw const ApiException(
      estado: 500,
      mensaje: 'El servidor devolvió algo que no es una lista JSON.',
    );
  }
}
