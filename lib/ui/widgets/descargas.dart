import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../repositories/padron.dart';
import '../padron_scope.dart';
import 'estados.dart';

/// Descargas de PDF: la nómina del sindicato y las credenciales.
///
/// Todas abren la URL en vez de traer los bytes con el cliente HTTP. El backend
/// manda los archivos como adjunto, así que el navegador o el sistema los
/// guardan solos, sin tener que resolver a mano dónde escribirlos en cada
/// plataforma. Es el mismo camino que usa la plantilla de importación.

/// Nómina del sindicato, para imprimir y entregar.
Future<void> descargarInformeSindicato(
  BuildContext context,
  Sindicato sindicato,
) {
  return _abrir(
    context,
    PadronScope.of(context).sindicatos.urlInforme(sindicato.id),
    'Generando la nómina de «${sindicato.nombre}»…',
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
Future<void> descargarCredencialDirigente(
  BuildContext context,
  Cargo cargo,
) {
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
    final abierta = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (abierta) {
      mostrarExito(context, aviso);
    } else {
      mostrarAviso(context, 'No se pudo abrir la descarga: $url');
    }
  } catch (e) {
    if (context.mounted) mostrarError(context, e);
  }
}
