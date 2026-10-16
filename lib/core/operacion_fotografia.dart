import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/imagen.dart';

/// El destinatario pertenece a la operación, no a la ficha que esté visible.
class OperacionFotografia {
  OperacionFotografia({
    required this.productorId,
    required this.nombre,
    this.ci,
    String? id,
  }) : id = id ?? _nuevoId();

  final int productorId;
  final String nombre;
  final String? ci;
  final String id;
  bool _cancelada = false;
  bool _confirmada = false;

  String get destinatario =>
      ci == null || ci!.isEmpty ? nombre : '$nombre · CI: $ci';
  bool get vigente => !_cancelada;

  void cancelar() => _cancelada = true;

  void verificarParaEnviar() {
    if (_cancelada) {
      throw StateError(
        'La ficha de origen cambió o se cerró. Cerrá este editor y abrí la fotografía desde la ficha correcta.',
      );
    }
    if (_confirmada) {
      throw StateError('Esta fotografía ya fue guardada. Cerrá este editor.');
    }
  }

  void confirmar(ImagenSubida respuesta) {
    if (respuesta.productorId != productorId || respuesta.operacionId != id) {
      throw const FormatException(
        'La confirmación no corresponde a este productor.',
      );
    }
    _confirmada = true;
  }

  static String _nuevoId() {
    final aleatorio = Random.secure();
    return List.generate(
      16,
      (_) => aleatorio.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

/// Guarda la identidad antes de abandonar la aplicación para abrir la cámara.
class FotoCamaraPendiente {
  static const clave = 'fotografia_productor_pendiente_v1';

  static Future<void> guardar(OperacionFotografia operacion) async {
    final preferencias = await SharedPreferences.getInstance();
    final guardada = await preferencias.setString(
      clave,
      jsonEncode({
        'productorId': operacion.productorId,
        'nombre': operacion.nombre,
        'ci': operacion.ci,
        'operacionId': operacion.id,
      }),
    );
    if (!guardada) {
      throw StateError(
        'No se pudo conservar el destinatario de la fotografía.',
      );
    }
  }

  static Future<OperacionFotografia?> leer() async {
    final preferencias = await SharedPreferences.getInstance();
    final texto = preferencias.getString(clave);
    if (texto == null) return null;
    try {
      final datos = jsonDecode(texto) as Map<String, dynamic>;
      final productorId = datos['productorId'];
      final operacionId = datos['operacionId'];
      if (productorId is! int ||
          productorId <= 0 ||
          operacionId is! String ||
          !RegExp(r'^[a-f0-9]{32}$').hasMatch(operacionId) ||
          datos['nombre'] is! String) {
        return null;
      }
      return OperacionFotografia(
        productorId: productorId,
        nombre: datos['nombre'] as String,
        ci: datos['ci'] as String?,
        id: operacionId,
      );
    } catch (_) {
      // Un archivo sin identidad verificable nunca se asigna a la ficha actual.
      return null;
    }
  }

  static Future<void> borrarSiCorresponde(String operacionId) async {
    try {
      final pendiente = await leer();
      if (pendiente?.id != operacionId) return;
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.remove(clave);
    } catch (_) {
      // Un fallo de limpieza no debe descartar el archivo recién recuperado.
    }
  }
}
