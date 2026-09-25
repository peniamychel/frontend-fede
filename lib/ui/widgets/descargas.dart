import 'package:flutter/material.dart';
import '../../core/guardar_archivo.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import 'estados.dart';

/// Descargas de PDF de informes y credenciales.
///
/// El cliente HTTP incluye la sesión y el guardado funciona en web y móvil
/// además de escritorio. Abrir directamente la URL pierde la autorización.

/// Informe consolidado del avance de impresión de una central.
Future<void> descargarInformeImpresionCentral(
  BuildContext context,
  Central central,
) {
  return _abrir(
    context,
    PadronScope.of(context).centrales.urlInformeImpresion(central.id),
    'Generando el informe de impresión de «${central.nombre}»…',
  );
}

/// Informe consolidado del avance de impresión de toda la federación.
Future<void> descargarInformeImpresionFederacion(
  BuildContext context,
  Federacion federacion,
) {
  return _abrir(
    context,
    PadronScope.of(
      context,
    ).centrales.urlInformeImpresionFederacion(federacion.id),
    'Generando el avance general de «${federacion.nombre}»…',
  );
}

/// Planilla para estampar y luego digitalizar sellos, firma y pie de firma.
Future<void> descargarPlanillaRecoleccionDirectorio(
  BuildContext context,
  Central central,
) {
  return _abrir(
    context,
    PadronScope.of(
      context,
    ).centrales.urlPlanillaRecoleccionDirectorio(central.id),
    'Generando la planilla de recolección de «${central.nombre}»…',
  );
}

/// Credencial de un productor: anverso y reverso, tamaño cédula.
Future<void> descargarCredencialProductor(
  BuildContext context,
  int productorId,
  String nombre,
) {
  return _abrir(
    context,
    PadronScope.of(context).productores.urlCredencial(productorId),
    'Generando la credencial de $nombre…',
  );
}

/// Credencial de quien ocupa un cargo: vertical, y con su propia firma atrás.
Future<void> descargarCredencialDirigente(BuildContext context, Cargo cargo) {
  return _abrir(
    context,
    PadronScope.of(context).directorios.urlCredencial(cargo.id),
    'Generando la credencial de ${cargo.productorNombre}…',
  );
}

/// Credenciales de todo el sindicato, en hojas para recortar.
Future<void> descargarCredencialesSindicato(
  BuildContext context,
  Sindicato sindicato,
) {
  return _abrir(
    context,
    PadronScope.of(context).sindicatos.urlCredenciales(sindicato.id),
    'Generando las credenciales de «${sindicato.nombre}»…',
  );
}

Future<void> _abrir(BuildContext context, Uri url, String aviso) async {
  try {
    mostrarExito(context, aviso);
    final archivo = await PadronScope.of(context).api.descargarUrl(url);
    await guardarArchivo(
      archivo.bytes,
      archivo.nombreArchivo,
      archivo.tipoMime,
    );
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
  }
}
