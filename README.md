# fede — Padrón FEDERA

Cliente Flutter del padrón de productores. Consume la API de Spring Boot del
repositorio `backend-fede`.

Jerarquía del dominio: **Federación › Central › Sindicato › Productor**, y cada
productor tiene lotes y observaciones.

Además del padrón, la app cubre:

- **Directorio** en los tres niveles. Un sindicato tiene presidente y
  secretario; una central suma haciendas; la federación suma vocal. Nadie puede
  ocupar dos cargos a la vez.
- **Documentos**: la nómina del sindicato con su acta de entrega, la credencial
  del afiliado (apaisada) y la del dirigente (vertical), las dos del tamaño de
  una cédula y con QR.
- **Reuniones y pase de lista**. Cuatro tipos de convocatoria, cada uno con su
  propia lista, y registro leyendo el QR con la cámara.

## Cómo correrlo

El backend tiene que estar arriba primero, en `http://localhost:8080`.

```bash
flutter run -d web-server --web-port=5173
```

**El puerto 5173 no es opcional.** El `CorsConfig` del backend solo autoriza ese
origen; con cualquier otro, el navegador bloquea todas las llamadas en el
preflight y la app se ve vacía sin decir por qué.

Para Android alcanza con `flutter run`: `ApiConfig` resuelve solo el `10.0.2.2`
que necesita el emulador. Para un teléfono por USB hay que pasarle la IP del
equipo:

```bash
flutter run --dart-define=API_HOST=192.168.1.X
```

## Por qué no hay carpeta `windows/`

Está apartada como `windows_desactivada`.

`file_picker` —el selector de archivos de la pantalla de importación— es el
primer plugin con código nativo del proyecto. Las plataformas de escritorio
registran sus plugins con enlaces simbólicos, y Windows no deja crearlos sin el
modo de desarrollador activado. Como el escritorio igual no compila sin Visual
Studio, se apartó la carpeta en vez de tocar la configuración del sistema.

Para recuperar el target de escritorio: activar el modo de desarrollador
(`start ms-settings:developers`) y devolver la carpeta a su sitio.

```bash
Rename-Item windows_desactivada windows
```

Android y web no necesitan nada de eso.

## Google Maps (ubicación de sindicatos)

La app funciona **sin clave de Google**: la pantalla de ubicación permite cargar
las coordenadas a mano y se guardan igual. El mapa es la forma cómoda de
obtenerlas, no la única. Para activarlo hacen falta tres cosas, y las tres con
la misma clave:

1. **Generar la clave** en Google Cloud, con la *Maps JavaScript API* habilitada
   para web y la *Maps SDK for Android* para Android. Restringila: por referente
   HTTP la de web, por paquete y huella SHA-1 la de Android. Una clave sin
   restringir la usa cualquiera y la factura llega igual.

2. **Web**: descomentar el `<script>` de `web/index.html` y poner la clave ahí.
   Queda comentado a propósito — con una clave de ejemplo, Google devuelve un
   error en la consola en cada carga.

3. **Android**: reemplazar `TU_API_KEY_AQUI` en
   `android/app/src/main/AndroidManifest.xml`.

Y al arrancar, pasarle la clave también a Dart, que es como la app sabe que el
mapa está disponible y decide entre mostrarlo o pedir las coordenadas a mano:

```bash
flutter run -d web-server --web-port=5173 --dart-define=GOOGLE_MAPS_API_KEY=TU_CLAVE
```

Las coordenadas se guardan como `DECIMAL(10,7)`: un `double` redondea, y en
coordenadas ese redondeo son metros de error.

## Pruebas

```bash
flutter test --dart-define=API_HOST=localhost
```

El `--dart-define` hace falta porque `flutter_test` finge ser Android y
`ApiConfig` resolvería `10.0.2.2`, que desde el equipo no lleva a ninguna parte.

Las pruebas con la etiqueta `integracion` golpean el backend real, siempre en
modo simulación: no escriben nada en el padrón.

## Estructura

```
lib/
├── core/            cliente HTTP, errores, paginación, host por plataforma
├── models/          los tipos del dominio
├── repositories/    uno por recurso, más la fachada `Padron`
└── ui/
    ├── productores/ listado, ficha y formulario
    ├── jerarquia/   navegación Federación › Central › Sindicato
    ├── reuniones/    convocatoria y pase de lista con la cámara
    ├── observaciones/
    ├── calidad/      panel de duplicados, sin foto y lotes sin reconocer
    └── importacion/  carga masiva desde Excel
```

## Leer el QR de las credenciales

El pase de lista usa `mobile_scanner`. En Android pide permiso de cámara la
primera vez; en el navegador lo pide el propio navegador, y **solo funciona
sobre HTTPS o en `localhost`** —es una restricción del navegador, no de la app.

Nunca depende de la cámara: debajo del QR, cada credencial trae el código
impreso en letras, y la pantalla siempre ofrece escribirlo a mano. Es el
respaldo que hace falta en el campo, de noche o con una cámara sucia.
