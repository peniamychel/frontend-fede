import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Lector de QR con la cámara.
///
/// Devuelve el código leído por [alLeer]. No cierra nada por su cuenta: pasar
/// lista es leer un carnet tras otro, y cerrar la cámara en cada uno obligaría
/// a volver a abrirla para el siguiente.
///
/// Se protege de la lectura repetida: la cámara entrega el mismo código muchas
/// veces por segundo mientras el carnet siga delante, y sin esto se dispararía
/// una petición por cuadro.
class EscanerQr extends StatefulWidget {
  const EscanerQr({super.key, required this.alLeer, this.pausado = false});

  final ValueChanged<String> alLeer;

  /// Mientras se procesa una lectura conviene no seguir leyendo.
  final bool pausado;

  @override
  State<EscanerQr> createState() => _EscanerQrState();
}

class _EscanerQrState extends State<EscanerQr> {
  final MobileScannerController _controlador = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  String? _ultimo;
  DateTime _ultimoMomento = DateTime.fromMillisecondsSinceEpoch(0);

  /// Cuánto hay que esperar para volver a aceptar el mismo código.
  ///
  /// Dos segundos: suficiente para no repetir la misma lectura mientras el
  /// carnet sigue delante, y poco como para que quien se equivocó pueda
  /// reintentar enseguida.
  static const Duration _espera = Duration(seconds: 2);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (widget.pausado) return;

    for (final codigo in captura.barcodes) {
      final valor = codigo.rawValue?.trim();
      if (valor == null || valor.isEmpty) continue;

      final ahora = DateTime.now();
      if (valor == _ultimo && ahora.difference(_ultimoMomento) < _espera) {
        continue;
      }
      _ultimo = valor;
      _ultimoMomento = ahora;
      widget.alLeer(valor);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controlador,
              onDetect: _alDetectar,
              errorBuilder: (context, error) => _Aviso(error: error),
            ),
            // Marco guía: sin él la gente no sabe dónde poner el carnet.
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (widget.pausado)
              Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Qué mostrar cuando la cámara no arranca.
///
/// Pasa seguido en el campo: permiso denegado, otra app usándola, o un equipo
/// sin cámara. Se dice qué hacer en vez de mostrar el error crudo, porque
/// siempre queda el camino de escribir el código.
class _Aviso extends StatelessWidget {
  const _Aviso({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final mensaje = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'No diste permiso para usar la cámara.',
      MobileScannerErrorCode.unsupported =>
        'Este equipo no puede leer códigos con la cámara.',
      _ => 'No se pudo abrir la cámara.',
    };

    return ColoredBox(
      color: tema.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_photography_outlined,
                size: 32, color: tema.colorScheme.outline),
            const SizedBox(height: 12),
            Text(mensaje,
                textAlign: TextAlign.center, style: tema.textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(
              'Escribí el código de la credencial acá abajo: está impreso '
              'debajo del QR.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall
                  ?.copyWith(color: tema.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
