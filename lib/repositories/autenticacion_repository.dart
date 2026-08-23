import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/sesion.dart';

class AutenticacionRepository {
  AutenticacionRepository(this.api);

  static const _claveSesion = 'federa.sesion';
  final ApiClient api;

  Future<Sesion> iniciarSesion(String usuario, String contrasena) async {
    final respuesta = await api.crear('/auth/login', {
      'usuario': usuario.trim(),
      'contrasena': contrasena,
    });
    final sesion = Sesion.desdeLogin(respuesta.comoObjeto);
    api.usarToken(sesion.token);
    await _guardar(sesion);
    return sesion;
  }

  Future<Sesion?> restaurar() async {
    final preferencias = await SharedPreferences.getInstance();
    final guardada = preferencias.getString(_claveSesion);
    if (guardada == null) return null;

    try {
      final sesion = Sesion.desdeJson(
        jsonDecode(guardada) as Map<String, dynamic>,
      );
      if (sesion.expirada) {
        await cerrarSesion();
        return null;
      }
      api.usarToken(sesion.token);
      final respuesta = await api.obtener('/auth/yo');
      if (respuesta.comoObjeto['autenticado'] != true) {
        await cerrarSesion();
        return null;
      }
      return sesion;
    } on ApiException {
      await cerrarSesion();
      return null;
    } on FormatException {
      await cerrarSesion();
      return null;
    }
  }

  Future<void> cerrarSesion() async {
    api.usarToken(null);
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_claveSesion);
  }

  Future<void> _guardar(Sesion sesion) async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.setString(_claveSesion, jsonEncode(sesion.toJson()));
  }
}
