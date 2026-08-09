# Prompt para el agente de Spring Boot — endpoint de importación desde Excel

> Copiá todo lo que sigue y pasáselo al agente que trabaja en `federa/backend`.

---

Necesito un endpoint de importación masiva del padrón desde un archivo Excel (`.xlsx`).

## Contexto del proyecto (ya existente, respetalo)

- Spring Boot **3.5.16**, Java **17**, MariaDB, springdoc-openapi **2.9.0**, Lombok.
- Paquete raíz `com.federa.backend`, con capas `controller` / `service` / `repository` / `dto` / `model` / `util` / `exception` / `config`.
- Las rutas se arman con la constante `ApiRutas.V1` (`/api/v1`), nunca con literales.
- Los DTO son **`record`** con `@Schema` en cada componente y ejemplos reales. Los de respuesta llevan un factory estático `desde(...)`.
- Los servicios van `@Transactional(readOnly = true)` a nivel de clase y `@Transactional` en los métodos de escritura.
- Los errores se manejan en `ManejadorGlobalErrores`, que responde siempre con `ErrorResponse`. Lanzá `RecursoNoEncontradoException` (→404) y `ReglaNegocioException` (→409); no inventes handlers nuevos.
- Los `POST` devuelven **201** con `ResponseEntity.created(...)`.
- Javadoc, mensajes de error y descripciones OpenAPI **en español**, con el mismo tono conciso del resto del proyecto: explicá el porqué, no lo obvio.
- `CorsConfig` ya permite `http://localhost:5173` con `allowedHeaders("*")` y todos los métodos. **No lo toques**: el multipart ya está cubierto.

## Utilidades que TENÉS que reutilizar, no reimplementar

En `com.federa.backend.util.Textos`:

- `Textos.normalizar(String)` → MAYÚSCULAS, sin tildes, espacios colapsados, `null` si queda vacío. Usalo para nombres, apellidos y para los nombres de central y sindicato.
- `Textos.limpiar(String)` → recorta espacios y **convierte el guion `"-"` en `null`**, porque así viene el dato ausente en las columnas C.I y N° LOTE de la planilla MATRIX. Usalo para cédula y número de lote.

La normalización de los productores ya vive en `ProductorService.aplicar(...)`. Si podés, reusá esa ruta en lugar de duplicar reglas.

## Dependencia nueva

Agregá Apache POI al `pom.xml` (la última 5.x estable; **no** la gestiona el parent de Spring Boot):

```xml
<dependency>
  <groupId>org.apache.poi</groupId>
  <artifactId>poi-ooxml</artifactId>
  <version>5.4.1</version>
</dependency>
```

Y subí el límite de subida en `application.properties`, porque el de fábrica es 1 MB:

```properties
spring.servlet.multipart.max-file-size=10MB
spring.servlet.multipart.max-request-size=10MB
```

## El endpoint

```
POST /api/v1/importaciones/productores
Content-Type: multipart/form-data
```

**Parte del cuerpo**

| Nombre | Tipo | Descripción |
|---|---|---|
| `archivo` | binario | El `.xlsx`. Rechazá cualquier otra extensión con 400 |

**Parámetros de consulta**

| Nombre | Tipo | Por defecto | Descripción |
|---|---|---|---|
| `federacionId` | `Long` | — **obligatorio** | La planilla no trae federación, solo central. 404 si no existe |
| `simular` | `boolean` | `true` | En `true` no escribe **nada**. Es el valor por defecto a propósito: una llamada sin parámetros nunca debe modificar la base |
| `crearJerarquia` | `boolean` | `false` | Si es `true`, da de alta las centrales y sindicatos que falten. Si es `false`, las filas cuya jerarquía no exista se rechazan |
| `ignorarFilasConError` | `boolean` | `false` | Si es `false` y hay al menos una fila inválida, no se escribe nada y se devuelve el informe. Si es `true`, importa las válidas y reporta el resto |

### Requisito central: la simulación no puede mentir

`simular=true` y `simular=false` deben recorrer **exactamente el mismo código**, incluidas la resolución de jerarquía y todas las validaciones. Lo único que cambia es que la simulación no persiste. Si son dos caminos distintos, la vista previa deja de ser confiable y el endpoint pierde el sentido.

Sugerencia de implementación: hacé todo el trabajo dentro de un método `@Transactional` y, cuando `simular` sea `true`, marcá la transacción para rollback al final (`TransactionAspectSupport.currentTransactionStatus().setRollbackOnly()`). Así hasta las restricciones de la base se validan de verdad en la simulación.

## Columnas de la planilla

Encabezados en la **primera fila**. Reconocelos de forma tolerante: aplicá `Textos.normalizar` al encabezado y aceptá sinónimos.

| Campo | Encabezados aceptados | Obligatorio | Destino |
|---|---|---|---|
| Central | `CENTRAL` | Sí | `Central.nombre` |
| Sindicato | `SINDICATO` | Sí | `Sindicato.nombre` |
| Nombres | `NOMBRES`, `NOMBRE` | Sí | `Productor.nombres` |
| Apellidos | `APELLIDOS`, `APELLIDO` | No | `Productor.apellidos` |
| Cédula | `CEDULA`, `CI`, `C.I`, `C.I.` | No | `Productor.ci` |
| Número de lote | `NUMERO LOTE`, `N LOTE`, `N° LOTE`, `LOTE` | No | `Lote.numero` |
| Observaciones | `OBSERVACIONES`, `OBSERVACION` | No | `Observacion.mensaje` |

Si falta alguna columna obligatoria, respondé **400** diciendo cuál falta y listando los encabezados que sí encontraste. No adivines por posición.

### La trampa de las celdas numéricas

**Este es el error más común en importaciones de Excel y quiero que lo evites explícitamente.** Cédulas y números de lote suelen venir como celdas numéricas: `getNumericCellValue()` devuelve `1226.0` y terminás guardando `"1226.0"` en lugar de `"1226"`.

Leé **todas** las celdas como texto con `DataFormatter`:

```java
private static final DataFormatter FORMATO = new DataFormatter();
String valor = FORMATO.formatCellValue(celda);
```

Y probalo: la prueba tiene que incluir una cédula cargada como número.

## Reglas de proceso, fila por fila

1. **Filas vacías**: salteálas en silencio. Los `.xlsx` suelen traer cientos de filas en blanco al final; no son errores.
2. **Central y sindicato**: buscá por nombre normalizado. La central se busca dentro de la `federacionId` recibida; el sindicato, dentro de esa central. Un sindicato con el mismo nombre en otra central es otro sindicato.
3. **Jerarquía faltante**: con `crearJerarquia=false`, rechazá la fila con un mensaje que diga exactamente qué falta. Con `true`, creala. En **ambos casos** el informe debe listar las centrales y sindicatos que se crearían o crearon.
4. **Cédulas y carnés repetidos son válidos.** El padrón real tiene 27 cédulas y 208 carnés compartidos. **No** apliques unicidad ni descartes filas por eso.
5. **Lote**: si la columna trae valor, creá un `Lote` asociado al productor con ese `numero`. Dejá `estado` y `mercado` nulos — la planilla no los trae y el backend ya los normaliza a `DESCONOCIDO` cuando corresponde.
6. **Observación**: si la columna trae texto, creá una `Observacion` con ese mensaje, asociada al productor y **sin resolver**.
7. **Posibles duplicados**: contá cuántas filas coinciden en nombres + apellidos + sindicato con un productor que ya está en la base. Reportalo como **advertencia, no como error**, e importá igual. Es un dato para que el usuario decida, no una regla.

## Respuesta

Devolvé **200** (no 201: puede no haber creado nada) con un `ImportacionResponse`:

```json
{
  "simulacion": true,
  "federacionId": 3,
  "federacionNombre": "CARRASCO",
  "filasLeidas": 4051,
  "filasValidas": 4038,
  "filasRechazadas": 13,
  "productores": 4038,
  "lotes": 3800,
  "observaciones": 210,
  "centralesNuevas": ["IVIRGARZAMA", "1RO MAYO"],
  "sindicatosNuevos": [
    { "central": "IVIRGARZAMA", "sindicato": "LIBERTAD" }
  ],
  "posiblesDuplicados": 4,
  "errores": [
    {
      "fila": 42,
      "columna": "nombres",
      "valor": "",
      "mensaje": "los nombres son obligatorios"
    }
  ],
  "duracionMs": 1840
}
```

- `fila` es el **número de fila tal como se ve en Excel** (con encabezado en la 1, el primer dato es la 2). Si devolvés el índice base cero, el usuario no encuentra la fila.
- Los contadores significan «lo que se creó» en la ejecución real y «lo que se crearía» en la simulación. El campo `simulacion` desambigua.
- Limitá `errores` a las primeras 200 entradas y agregá `erroresOmitidos` con el resto, para que una planilla rota no devuelva un JSON de 30 MB.

## Rendimiento

Son ~4.051 productores más sus lotes y observaciones. Insertar de a uno con `save()` genera un `INSERT` por fila y tarda muchísimo. Usá `saveAll` por lotes y activá el batching de Hibernate:

```properties
spring.jpa.properties.hibernate.jdbc.batch_size=100
spring.jpa.properties.hibernate.order_inserts=true
```

## Documentación OpenAPI

Anotá con `@Tag(name = "Importaciones", ...)` y `@Operation` como el resto de los controladores. Para que springdoc muestre el selector de archivo, la parte del cuerpo necesita:

```java
@RequestPart("archivo")
@Parameter(description = "Planilla .xlsx del padrón",
           content = @Content(mediaType = MediaType.MULTIPART_FORM_DATA_VALUE))
MultipartFile archivo
```

Verificá que `/v3/api-docs` quede válido después de tu cambio: hay un cliente Flutter que se genera a mano contra ese contrato.

## Pruebas que quiero ver

1. **Celda numérica**: una cédula cargada como número llega a la base como `"1226"`, no `"1226.0"`.
2. **La simulación no escribe**: con `simular=true` sobre una base vacía, el conteo de productores sigue en cero después de la llamada.
3. **Simulación y ejecución coinciden**: correr `simular=true` y después `simular=false` sobre la misma planilla da los mismos contadores.
4. **Jerarquía faltante**: con `crearJerarquia=false` las filas se rechazan y el informe nombra la central o el sindicato que falta.
5. **Guion como ausente**: una cédula `"-"` se guarda como `null`, no como el texto `"-"`.
6. **Todo o nada**: con `ignorarFilasConError=false` y una fila inválida, la base queda intacta.
7. **Cédula repetida**: dos filas con la misma cédula se importan las dos, sin error.

## Lo que NO quiero

- Que toques `CorsConfig`, `ManejadorGlobalErrores` ni `ErrorResponse`. Ya funcionan.
- Que reimplementes la normalización de texto teniendo `Textos`.
- Que la simulación tenga un camino de código distinto al de la ejecución.
- Un endpoint que escriba parcialmente sin que el cliente lo haya pedido con `ignorarFilasConError=true`.
