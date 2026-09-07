# frontend-fede — Padrón FEDERA

Cliente Flutter del padrón de productores. Consume la API de Spring Boot del
repositorio `backend-fede`.

Jerarquía del dominio: **Federación › Central › Sindicato › Productor**, y cada
productor tiene lotes.

Cada productor lleva un código del padrón —`2-13J-1`: número de la federación,
sigla de la central, y su número dentro de esa central—. La numeración de cada
central arranca en 1 y **saltea los números que llevan 666**: el 666, el 1666,
el 2666. No es una superstición del sistema, es de la gente; y en centrales de
más de tres mil afiliados el número aparecería varias veces.

Además del padrón, la app cubre:

- **Directorio** en los tres niveles. Un sindicato tiene presidente y
  secretario; una central suma haciendas; la federación suma vocal. Nadie puede
  ocupar dos cargos a la vez.
- **Documentos**: la nómina del sindicato con su acta de entrega, la credencial
  del afiliado (apaisada) y la del dirigente (vertical), las dos del tamaño de
  una cédula y con QR.
- **Reuniones**, en cuadros: quién convoca, llamar lista, el acta y los vetos.
  Cuatro tipos de convocatoria, cada uno con su propia lista. Se llama lista
  varias veces por asamblea —al empezar, más tarde para los que llegaron con
  retraso— y cada vuelta tiene sus presentes; se registra leyendo el QR con la
  cámara. El acta se sube hoja por hoja, que es como se fotografía el cuaderno,
  y con el número que lleva en el libro del sindicato: sin él, meses después
  nadie puede ir al original a cotejar lo que la pantalla dice que se decidió.

  El listado se divide por tipo y tiene buscador. Se busca por el detalle de la
  reunión —título, lugar, notas, número del acta— **y por a quién se vetó en
  ella**: nombre, cédula, cualquiera de sus dos códigos, o el motivo escrito.
  «¿En qué reunión vetaron a Fulano?» es una pregunta que se hace sola.
- **Vetos**, decididos en asamblea. Se ponen y se quitan **desde la reunión que
  los decidió**, no desde la ficha de la persona: buscando a quien sea por
  nombre, cédula o código. Se habilitan por reunión, porque no toda asamblea es
  para sancionar, y hace falta el acta: sin el documento la sanción sería la
  palabra de quien la cargó.

  Mientras el veto rige, la persona queda suspendida de sus derechos: no se le
  emite credencial —ni la de afiliado ni la de dirigente—, no puede ocupar un
  cargo —y deja el que tuviera al quedar observada—, y no se le toma asistencia
  ni cuenta para el quórum. Sigue siendo afiliada: conserva su parcela, su
  código y su historial. Levantarlo se decide en otra reunión, también con su
  acta.

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

## Probar contra el entorno Docker

El entorno de integración se levanta desde el repositorio del backend y
publica web y API juntas en el puerto 80. La base de Docker es independiente de
la MariaDB usada en desarrollo.

Flutter Web no necesita una IP compilada: usa el mismo origen con el que se
abre en el navegador. Entradas habituales:

```text
http://localhost/
http://192.168.1.X/
```

Para ejecutar pruebas de integración contra Docker:

```bash
flutter test --dart-define=API_HOST=localhost --dart-define=API_PUERTO=80
```

Android y Windows nativos pueden apuntar al mismo entorno:

```bash
flutter run -d android --dart-define=API_HOST=192.168.1.X --dart-define=API_PUERTO=80
flutter run -d windows --dart-define=API_HOST=localhost --dart-define=API_PUERTO=80
```

El build web de Docker incluye CanvasKit y el modelo de segmentación localmente,
por lo que sigue cargando si la intranet pierde la salida a Internet. Por ahora
se sirve por HTTP: el lector QR del navegador no está disponible desde otra
máquina, pero la carga manual y el resto de la aplicación sí funcionan.

## Aplicación para Windows

El target `windows/` está activo. Para compilarlo hacen falta Visual Studio
Community 2022 con la carga **Desarrollo para el escritorio con C++** y el modo
de desarrollador de Windows, que permite registrar los plugins mediante enlaces
simbólicos.

```powershell
start ms-settings:developers
flutter doctor -v
flutter run -d windows
```

La aplicación de Windows usa `http://localhost:8080` por defecto, por lo que el
backend debe estar ejecutándose en la misma computadora. Se puede apuntar a otra
máquina con `--dart-define=API_HOST=192.168.1.X`.

Android y web no necesitan Visual Studio.

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

## Productores pendientes de lote

La importación del padrón usa automáticamente CARRASCO TROPICAL, sin selector
de federación. Comparte la resolución del destino con Jerarquía y usa el ID
devuelto por la API, no un ID fijo. Si falta esa federación o hay más de una con
el mismo nombre, se bloquea la pantalla hasta corregirlo; no se elige otra.

La lista general y la del sindicato muestran la clasificación y «Falta número
de lote» cuando `revisionLotePendiente` llega activo desde el backend. En la ficha,
«Completar número de lote» asigna una parcela o corrige la existente. La
clasificación importada queda preseleccionada al asignar una parcela nueva.

La revisión se cierra al guardar el número y recargar la ficha, sin un botón de
aprobación que pueda saltarse el requisito. Esto aplica a Android, web y Windows.
La ausencia de foto u otros datos puede seguir impidiendo imprimir después.
El informe de importación también indica cuántos productores quedan sin lote.

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
    ├── reuniones/    la reunión en cuadros, y el pase de lista con la cámara
    ├── vetos/        buscar a quién se observó, y por qué
    ├── credenciales/ vista previa antes de imprimir
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
