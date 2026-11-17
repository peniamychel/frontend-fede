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

Para compilar Android o Windows con HTTPS mediante Tailscale, usar el dominio
real del servidor de producción en `API_HOST` (sin `https://`, puerto ni ruta),
`API_ESQUEMA=https` y `API_PUERTO=443`. Ejemplo; reemplazar el dominio:

```powershell
flutter build apk --release --split-per-abi --dart-define=API_HOST=servidor.su-tailnet.ts.net --dart-define=API_ESQUEMA=https --dart-define=API_PUERTO=443
flutter build windows --release --dart-define=API_HOST=servidor.su-tailnet.ts.net --dart-define=API_ESQUEMA=https --dart-define=API_PUERTO=443
```

Tailscale debe estar conectado y autorizado tanto en el servidor como en el
dispositivo cliente. Usar el nombre del servidor cubierto por su certificado
HTTPS. El destino se configura al compilar: al cambiarlo hay que generar e
instalar una nueva versión del cliente. Sin `API_ESQUEMA`, desarrollo conserva
HTTP y el puerto predeterminado 8080; con HTTPS el puerto predeterminado es 443.
Flutter Web sin `API_HOST` sigue utilizando el origen del navegador.

El build web de Docker incluye CanvasKit y el modelo de segmentación localmente,
por lo que sigue cargando si la intranet pierde la salida a Internet. Nginx usa
HTTP dentro de Docker; el acceso externo usa HTTPS cuando Tailscale Serve está
configurado delante de ese puerto.

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


## Versión de la aplicación

«Cuenta» muestra la versión del programa compilado en formato `AAAA.MM.DD-N`,
igual que los paquetes de actualización. La referencia actual es `2026.11.03-1`.
Al preparar cada nueva actualización, usar la misma versión del paquete en la
compilación de web, Android y Windows:

```powershell
flutter build apk --release --split-per-abi --dart-define=FEDERA_VERSION=2026.11.03-1
flutter build windows --release --dart-define=FEDERA_VERSION=2026.11.03-1
flutter build web --release --dart-define=FEDERA_VERSION=2026.11.03-1
```

Estos parámetros se añaden a los de conexión de API que utilice cada instalación.
En Docker, pasar `--build-arg FEDERA_VERSION=AAAA.MM.DD-N` o definir
`FEDERA_VERSION` al compilar con Compose. Cambiar solo la etiqueta de una imagen
ya compilada no actualiza el número que lleva dentro. Una APK conserva su
versión aunque se actualice el servidor. No se usa la fecha del dispositivo.

## Detalles de la fotografía

Al abrir la fotografía del productor, el visor muestra el nombre original del
archivo, la fecha de creación de su registro (primera carga) y la última edición.
Estas fechas pertenecen a la fotografía, no a la ficha ni a los datos EXIF de
la cámara. Si no están disponibles se muestra «Sin registro». El modal y el
fondo de transparencia usan el tema claro u oscuro. En móvil horizontal, los
detalles se sitúan junto a la imagen; en vertical, debajo.

## Orden de los informes

Antes de generar pre-impresión, revisión del padrón, lista de productores en
Excel, nómina PDF o informe de fase, se pregunta el orden de la lista:
«Apellidos» (opción inicial) o «Número de lote». Cancelar o volver atrás no
genera ni descarga archivos. La elección se solicita en cada descarga, tanto
en los informes de centrales como de sindicatos.

Por lote se usa orden numérico ascendente (2 antes que 10), luego sus letras;
si hay varios lotes se toma el menor y quienes no tienen lote quedan al final.
Los empates se resuelven por apellidos y nombres. El orden se aplica dentro de
cada sindicato y se conserva el diseño de los archivos. Requiere el backend
que admite el parámetro `orden=APELLIDOS|NUMERO_LOTE`.

## Listas de productores en Excel

Los paneles de informes de centrales y sindicatos ofrecen «Lista de productores
en Excel». Descarga un `.xlsx` con el diseño de «Nómina en PDF»: encabezados
centrados, tabla de seis columnas con bordes y cabecera gris, observaciones
en blanco y dos espacios de sello, firma y pie de firma manual para los
secretarios generales de Central y Sindicato, como en revisión del padrón.
La central descarga una hoja por sindicato autorizado. Incluye encabezados
fijos y bloques paginados para impresión en carta vertical; las cédulas y lotes se
conservan como texto. Usa la sesión vigente y exige
`INFORMES_DESCARGAR`. El archivo se guarda mediante el diálogo habitual o la
descarga del navegador.

## Listas de afiliados en blanco

En «Informes y reportes del sindicato», «Lista en blanco» pide la cantidad de
afiliados antes de descargar el PDF. Propone el total registrado y permite
indicar otro número entre 1 y 5000. Genera exactamente esa cantidad de filas
numeradas para completar a mano, con «Detalles» como última columna y sin datos
personales ni notas de revisión. Requiere el permiso de descarga de informes.

## Pendientes de impresión y reimpresión

«Impresiones faltantes» reúne las primeras impresiones y las reimpresiones
marcadas que siguen pendientes en la fase activa y cumplen los requisitos.
Los carnets ya impresos sin esa marca se conservan en la impresión selectiva.
Al abrir una fase también se incorporan los productores que nunca se imprimieron,
incluidos los registros importados sin una marca de fase anterior.

En los listados, el naranja oscuro indica una reserva pendiente para la fase
actual o la próxima; el ámbar claro indica datos completos sin esa reserva.
El verde indica un carnet impreso sin reimpresión pendiente. Reservar o abrir una
fase no incrementa las impresiones ni modifica el historial de fases cerradas.

Mientras una fase está abierta, las altas manuales y las importadas se incorporan
automáticamente como primeras impresiones pendientes. Al actualizar el backend
se recuperan las altas omitidas en fases todavía abiertas; no se duplican
participaciones ni se modifican carnets ya impresos o fases cerradas.

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

La letra del lote permite elegir de A a Z o dejar la asignación automática.
Se admiten hasta 26 productores por número dentro del mismo sindicato,
respetando las letras reservadas. Este rango requiere el backend actualizado.

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

## Subir fotografías sin procesar

El editor presenta «Procesar imagen», «Cancelar» y «Subir sin procesar», en ese
orden. Al editar una foto ya procesada, se oculta «Subir sin procesar».
La carga rápida recorta en cuadrado (1:1), aplica los ajustes elegidos y
comprime en JPEG hasta 400 KB, conservando hasta 1600 × 1600 px para editar
después. No ejecuta la eliminación de fondo ni amplía las fotos pequeñas.

La fotografía queda visible como pendiente de edición y bloquea la impresión
del carnet en el servidor. Para habilitarla, abrir la foto → Editar → Procesar
imagen con «Quitar fondo» activado. Los demás requisitos de impresión siguen
vigentes. Al editar una foto pendiente, «Quitar fondo» se activa inicialmente;
volver a subirla sin procesar conserva el bloqueo.

La carga rápida requiere el backend actualizado. Antes de enviar los bytes,
el cliente comprueba que el servidor admita fotografías pendientes de edición.

## Leer el QR de las credenciales

El pase de lista usa `mobile_scanner`. En Android pide permiso de cámara la
primera vez; en el navegador lo pide el propio navegador, y **solo funciona
sobre HTTPS o en `localhost`** —es una restricción del navegador, no de la app.

Nunca depende de la cámara: debajo del QR, cada credencial trae el código
impreso en letras, y la pantalla siempre ofrece escribirlo a mano. Es el
respaldo que hace falta en el campo, de noche o con una cámara sucia.
