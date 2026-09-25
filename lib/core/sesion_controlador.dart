import 'package:flutter/foundation.dart';

import '../models/sesion.dart';
import '../repositories/autenticacion_repository.dart';

class SesionControlador extends ChangeNotifier {
  SesionControlador(this._repositorio) {
    _repositorio.api.alPerderAutorizacion = _sesionInvalida;
  }
  final AutenticacionRepository _repositorio;

  Sesion? sesion;
  bool restaurando = true;

  bool get autenticado => sesion != null;
  bool puede(String permiso) => sesion?.puede(permiso) ?? false;

  Future<void> restaurar() async {
    restaurando = true;
    notifyListeners();
    sesion = await _repositorio.restaurar();
    restaurando = false;
    notifyListeners();
  }

  Future<void> acceder(String codigo) async {
    sesion = await _repositorio.acceder(codigo);
    notifyListeners();
  }

  Future<void> cerrar() async {
    await _repositorio.cerrarSesion();
    sesion = null;
    notifyListeners();
  }

  void _sesionInvalida() {
    if (sesion == null && !restaurando) return;
    sesion = null;
    restaurando = false;
    _repositorio.descartarSesionLocal();
    notifyListeners();
  }

  @override
  void dispose() {
    _repositorio.api.alPerderAutorizacion = null;
    super.dispose();
  }
}
