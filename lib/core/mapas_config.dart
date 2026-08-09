/// Configuración de Google Maps.
///
/// La clave de API no vive acá: cada plataforma la necesita en su propio lugar
/// —`web/index.html` para la web y `AndroidManifest.xml` para Android—, porque
/// quien la consume es el SDK nativo, no el código Dart.
///
/// Lo que sí hace falta en Dart es *saber* si hay clave configurada, para
/// decidir entre mostrar el mapa o el modo de coordenadas manuales. Eso llega
/// por `--dart-define`:
///
/// ```
/// flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...
/// ```
///
/// Sin clave la aplicación sigue siendo usable: se pueden cargar y editar
/// coordenadas a mano. El mapa es la forma cómoda de obtenerlas, no la única.
class MapasConfig {
  const MapasConfig._();

  static const String clave = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  /// Si se puede intentar dibujar el mapa.
  ///
  /// Se comprueba antes de construir el widget en vez de dejar que falle: un
  /// mapa que no carga deja un rectángulo gris sin explicación, y es peor que
  /// decir directamente que falta la clave.
  static bool get hayClave => clave.trim().isNotEmpty;

  /// Centro por defecto cuando el sindicato todavía no tiene sede marcada:
  /// el trópico de Cochabamba, que es donde está el padrón.
  static const double latitudPorDefecto = -16.8574;
  static const double longitudPorDefecto = -64.7891;

  /// Enlace para abrir un punto en Google Maps fuera de la aplicación. No
  /// necesita clave: es una URL pública.
  static Uri enlaceExterno(double latitud, double longitud) => Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud');
}
