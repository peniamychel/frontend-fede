import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/sesion.dart';

class AutenticacionRepository {
  AutenticacionRepository(this.api);

  static const _claveSesion = 'federa.sesion';
  final ApiClient api;
  Sesion? _sesion;

  Future<Sesion> acceder(String codigo) async {
    final respuesta = await api.crear('/auth/acceso', {
      'codigo': codigo.trim(),
    });
    final sesion = Sesion.desdeLogin(respuesta.comoObjeto);
    api.usarToken(sesion.token);
    _sesion = sesion;
    await _borrarSesionPersistida();
    return sesion;
  }

  Future<Sesion?> restaurar() async {
    // Retirar los tokens guardados por versiones anteriores. La sesión nueva
    // vive en memoria: cerrar la aplicación o recargar exige iniciar sesión.
    await _borrarSesionPersistida();
    final sesion = _sesion;
    if (sesion == null) {
      api.usarToken(null);
      return null;
    }

    try {
      if (sesion.expirada) {
        await cerrarSesion();
        return null;
      }
      api.usarToken(sesion.token);
      final respuesta = await api.obtener('/auth/yo');
      final actual = respuesta.comoObjeto;
      if (actual['autenticado'] != true) {
        await cerrarSesion();
        return null;
      }
      final renovada = sesion.conAutorizaciones(actual);
      _sesion = renovada;
      return renovada;
    } on ApiException {
      await cerrarSesion();
      return null;
    } on FormatException {
      await cerrarSesion();
      return null;
    }
  }

  Future<void> cerrarSesion() async {
    if (api.tieneToken) {
      try {
        await api.crear('/auth/logout', const {});
      } on ApiException {
        // El cierre local debe funcionar aunque la sesión ya haya vencido.
      }
    }
    await descartarSesionLocal();
  }

  Future<void> descartarSesionLocal() async {
    api.usarToken(null);
    _sesion = null;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await _borrarSesionPersistida();
  }

  Future<void> _borrarSesionPersistida() async {
    final preferencias = await SharedPreferences.getInstance();
    await preferencias.remove(_claveSesion);
  }
}
