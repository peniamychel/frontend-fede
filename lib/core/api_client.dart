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
  ApiClient({http.Client? cliente, this.tiempoLimite = const Duration(seconds: 20)})
      : _cliente = cliente ?? http.Client();

  final http.Client _cliente;
  final Duration tiempoLimite;

  static const Map<String, String> _cabeceras = {
    'Accept': 'application/json',
    'Content-Type': 'application/json; charset=utf-8',
  };

  void cerrar() => _cliente.close();

  Future<Object?> obtener(String ruta, {Map<String, dynamic>? query}) =>
      _enviar('GET', ruta, query: query);

  Future<Object?> crear(String ruta, Object cuerpo) =>
      _enviar('POST', ruta, cuerpo: cuerpo);

  Future<Object?> reemplazar(String ruta, Object cuerpo) =>
      _enviar('PUT', ruta, cuerpo: cuerpo);

  Future<Object?> parchear(String ruta, {Object? cuerpo}) =>
      _enviar('PATCH', ruta, cuerpo: cuerpo);

  Future<void> eliminar(String ruta) async {
    await _enviar('DELETE', ruta);
  }

  /// DELETE que sí devuelve cuerpo.
  ///
  /// No todo borrado responde 204: quitar la ubicación de un sindicato lo
  /// devuelve actualizado, porque el sindicato no desaparece.
  Future<Object?> eliminarConRespuesta(String ruta) => _enviar('DELETE', ruta);

  /// Sube un archivo como `multipart/form-data`.
  ///
  /// No lleva las cabeceras normales: `MultipartRequest` arma su propio
  /// `Content-Type` con el separador de partes, y fijarlo a mano lo rompería.
  /// El tiempo límite es aparte porque subir y procesar una planilla de miles
  /// de filas no entra en los 20 segundos del resto de las llamadas.
  Future<Object?> subirArchivo(
    String ruta, {
    required String campo,
    required List<int> bytes,
    required String nombreArchivo,
    Map<String, dynamic>? query,
    Duration tiempoLimite = const Duration(minutes: 5),
  }) async {
    final uri = ApiConfig.uri(ruta, query);
    final peticion = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..files.add(http.MultipartFile.fromBytes(
        campo,
        bytes,
        filename: nombreArchivo,
      ));

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
