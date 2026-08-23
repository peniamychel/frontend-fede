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
