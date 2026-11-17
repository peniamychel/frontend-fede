// La versión identifica el paquete compilado; no cambia con la fecha del equipo
// ni con las actualizaciones del servidor al que se conecta una APK existente.
const _versionCompilada = String.fromEnvironment('FEDERA_VERSION');

// Último paquete publicado. Al compilar una actualización se indica su versión
// con --dart-define=FEDERA_VERSION=AAAA.MM.DD-N.
const versionAplicacion = _versionCompilada == ''
    ? '2026.11.03-1'
    : _versionCompilada;
