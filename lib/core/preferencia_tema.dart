import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Recuerda si el usuario prefiere claro, oscuro, o lo que diga el sistema.
///
/// Es un [ValueNotifier] y no una solución más grande porque el estado es
/// literalmente un enum: montar algo más sería desproporcionado.
///
/// La preferencia se guarda en el dispositivo —`localStorage` en web—, así que
/// sobrevive a recargar la página. Sin eso, elegir el tema en cada visita
/// convierte una preferencia en una tarea.
class PreferenciaTema extends ValueNotifier<ThemeMode> {
  PreferenciaTema() : super(ThemeMode.system);

  static const String _clave = 'tema';

  /// Lee lo guardado. Si falla, se queda en automático: no poder leer una
  /// preferencia no es motivo para impedir que la app arranque.
  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = _desdeTexto(prefs.getString(_clave));
    } catch (_) {
      value = ThemeMode.system;
    }
  }

  Future<void> cambiar(ThemeMode modo) async {
    if (value == modo) return;
    value = modo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, _aTexto(modo));
    } catch (_) {
      // El tema ya cambió en pantalla; que no se haya podido guardar solo
      // significa que la próxima vez arranca en automático.
    }
  }

  /// Alterna entre claro y oscuro. En automático, salta a lo contrario de lo
  /// que se está viendo, que es lo que espera quien toca el botón.
  Future<void> alternar(Brightness brilloActual) {
    return cambiar(switch (value) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.system =>
        brilloActual == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
    });
  }

  static String _aTexto(ThemeMode modo) => switch (modo) {
        ThemeMode.light => 'claro',
        ThemeMode.dark => 'oscuro',
        ThemeMode.system => 'sistema',
      };

  static ThemeMode _desdeTexto(String? texto) => switch (texto) {
        'claro' => ThemeMode.light,
        'oscuro' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

/// Deja la preferencia disponible para todo el árbol.
class TemaScope extends InheritedNotifier<PreferenciaTema> {
  const TemaScope({
    super.key,
    required PreferenciaTema preferencia,
    required super.child,
  }) : super(notifier: preferencia);

  static PreferenciaTema of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TemaScope>();
    assert(scope != null, 'No hay un TemaScope por encima de este widget.');
    return scope!.notifier!;
  }
}
