/// Convierte texto visible en una clave tolerante para búsquedas locales.
///
/// Los datos se siguen mostrando y guardando con Ñ y tildes; esta clave solo
/// permite que escribir `NUNEZ` encuentre `NUÑEZ`, o `JOSE` encuentre `JOSÉ`.
String textoParaBusqueda(String valor) => valor
    .trim()
    .toUpperCase()
    .replaceAll('Á', 'A')
    .replaceAll('É', 'E')
    .replaceAll('Í', 'I')
    .replaceAll('Ó', 'O')
    .replaceAll('Ú', 'U')
    .replaceAll('Ü', 'U')
    .replaceAll('Ñ', 'N')
    // También tolera texto pegado en forma descompuesta: letra + acento.
    .replaceAll(RegExp(r'[\u0300-\u036f]'), '');
