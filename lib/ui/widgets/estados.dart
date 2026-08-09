import 'package:flutter/material.dart';

import '../../repositories/padron.dart';

/// Rueda de carga centrada, con un margen que evita que salte al aparecer.
class Cargando extends StatelessWidget {
  const Cargando({super.key, this.mensaje});

  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (mensaje != null) ...[
            const SizedBox(height: 16),
            Text(mensaje!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Estado vacío: la petición fue bien pero no hay nada que mostrar.
class SinResultados extends StatelessWidget {
  const SinResultados({
    super.key,
    required this.mensaje,
    this.detalle,
    this.icono = Icons.inbox_outlined,
    this.accion,
  });

  final String mensaje;
  final String? detalle;
  final IconData icono;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: tema.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              mensaje,
              style: tema.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (detalle != null) ...[
              const SizedBox(height: 8),
              Text(
                detalle!,
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: tema.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
            if (accion != null) ...[const SizedBox(height: 20), accion!],
          ],
        ),
      ),
    );
  }
}

/// Estado de error, con reintento.
///
/// Distingue el fallo de conexión del error de la API porque la solución es
/// distinta: uno se arregla levantando el backend o cambiando el host, el otro
/// es una respuesta legítima que hay que leer.
class FalloCarga extends StatelessWidget {
  const FalloCarga({super.key, required this.error, this.alReintentar});

  final Object error;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final (icono, titulo, detalle) = switch (error) {
      SinConexionException e => (
          Icons.cloud_off_outlined,
          'Sin conexión con el backend',
          e.descripcion,
        ),
      ApiException e when e.esNoEncontrado => (
          Icons.search_off_outlined,
          'No encontrado',
          e.descripcion,
        ),
      ApiException e when e.esConflicto => (
          Icons.report_problem_outlined,
          'Conflicto con un registro existente',
          e.descripcion,
        ),
      ApiException e when e.esValidacion => (
          Icons.rule_outlined,
          'Datos inválidos',
          e.descripcion,
        ),
      ApiException e => (
          Icons.error_outline,
          'Error ${e.estado}',
          e.descripcion,
        ),
      _ => (Icons.error_outline, 'Algo salió mal', '$error'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 48, color: tema.colorScheme.error),
            const SizedBox(height: 16),
            Text(titulo, style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              detalle,
              style: tema.textTheme.bodyMedium
                  ?.copyWith(color: tema.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
            if (error is SinConexionException) ...[
              const SizedBox(height: 12),
              SelectableText(
                ApiConfig.descripcion,
                style: tema.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: tema.colorScheme.outline,
                ),
              ),
            ],
            if (alReintentar != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: alReintentar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Envuelve un [Future] resolviendo los tres estados de una vez.
class CargaAsync<T> extends StatelessWidget {
  const CargaAsync({
    super.key,
    required this.futuro,
    required this.constructor,
    this.alReintentar,
    this.mensajeCarga,
  });

  final Future<T> futuro;
  final Widget Function(BuildContext, T) constructor;
  final VoidCallback? alReintentar;
  final String? mensajeCarga;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: futuro,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Cargando(mensaje: mensajeCarga);
        }
        if (snapshot.hasError) {
          return FalloCarga(
            error: snapshot.error!,
            alReintentar: alReintentar,
          );
        }
        return constructor(context, snapshot.data as T);
      },
    );
  }
}

/// Qué clase de aviso es. Define color, icono y cuánto queda en pantalla.
enum _Tono { exito, aviso, error }

/// Confirma que algo salió bien.
void mostrarExito(BuildContext context, String mensaje, {String? detalle}) {
  _mostrar(context, mensaje, detalle: detalle, tono: _Tono.exito);
}

/// Avisa de algo que el usuario tiene que corregir, sin que haya fallado nada.
void mostrarAviso(BuildContext context, String mensaje, {String? detalle}) {
  _mostrar(context, mensaje, detalle: detalle, tono: _Tono.aviso);
}

/// Muestra un error, con el detalle de validación si el backend lo mandó.
///
/// Separa el motivo del detalle: el título dice qué pasó de un vistazo y el
/// cuerpo da la explicación larga, que en los errores de validación puede ser
/// una lista de campos.
void mostrarError(BuildContext context, Object error) {
  final (titulo, detalle) = switch (error) {
    SinConexionException e => ('Sin conexión con el servidor', e.descripcion),
    ApiException e when e.esNoEncontrado => ('No encontrado', e.descripcion),
    ApiException e when e.esConflicto => ('No se pudo guardar', e.descripcion),
    ApiException e when e.esValidacion => ('Revisá los datos', e.descripcion),
    ApiException e when e.esDelServidor =>
      ('Falló el servidor', e.descripcion),
    ApiException e => ('Error ${e.estado}', e.descripcion),
    _ => ('Algo salió mal', '$error'),
  };

  _mostrar(context, titulo,
      detalle: detalle == titulo ? null : detalle, tono: _Tono.error);
}

void _mostrar(BuildContext context, String mensaje,
    {String? detalle, required _Tono tono}) {
  final tema = Theme.of(context);
  final esquema = tema.colorScheme;

  final (fondo, frente, icono) = switch (tono) {
    _Tono.exito => (
        esquema.primaryContainer,
        esquema.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
    _Tono.aviso => (
        esquema.secondaryContainer,
        esquema.onSecondaryContainer,
        Icons.info_outline,
      ),
    _Tono.error => (
        esquema.errorContainer,
        esquema.onErrorContainer,
        Icons.error_outline,
      ),
  };

  // Un error hay que poder leerlo con calma; una confirmación estorba si se
  // queda. Y el detalle largo necesita más tiempo que un título suelto.
  final duracion = switch (tono) {
    _Tono.exito => const Duration(seconds: 3),
    _Tono.aviso => const Duration(seconds: 5),
    _Tono.error => const Duration(seconds: 8),
  };

  // En pantallas anchas se acota: una barra de 1600 px con seis palabras deja
  // el texto perdido en una esquina y obliga a cruzar la pantalla con la vista.
  final ancho = MediaQuery.sizeOf(context).width;
  final acotada = ancho >= 700;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: frente, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mensaje,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: frente,
                      fontWeight:
                          detalle == null ? FontWeight.w500 : FontWeight.w600,
                    ),
                  ),
                  if (detalle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      style: tema.textTheme.bodySmall
                          ?.copyWith(color: frente.withValues(alpha: 0.85)),
                      // Un error de validación puede listar varios campos, pero
                      // un muro de texto en una barra flotante no lo lee nadie.
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: fondo,
        duration: duracion,
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // width y margin se excluyen entre sí en Flutter: hay que elegir uno.
        width: acotada ? 520 : null,
        margin: acotada ? null : const EdgeInsets.all(12),
        showCloseIcon: tono == _Tono.error,
        closeIconColor: frente,
      ),
    );
}
