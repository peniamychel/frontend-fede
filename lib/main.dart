import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'core/preferencia_tema.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Navigator usa rutas imperativas, no Router. Chrome debe enviar popRoute
  // incluso para pantallas sin nombre y cambios internos de Jerarquía.
  if (kIsWeb) await SystemNavigator.selectSingleEntryHistory();
  final tema = PreferenciaTema();
  await tema.cargar();
  runApp(PadronApp(preferenciaTema: tema));
}
