import 'package:flutter/material.dart';

import 'core/preferencia_tema.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final tema = PreferenciaTema();
  await tema.cargar();
  runApp(PadronApp(preferenciaTema: tema));
}
