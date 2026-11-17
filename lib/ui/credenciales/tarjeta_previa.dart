import '../imagen_autenticada.dart';
import 'package:flutter/material.dart';
import 'fuentes_bajo_demanda.dart';
import 'imagen_plantilla_autenticada.dart';

import '../../core/api_config.dart';
import '../../models/credencial_previa.dart';
import '../../models/diseno_credencial.dart';

/// Vista previa alimentada por la misma configuración que usa el PDF.
class TarjetaPrevia extends StatelessWidget {
  const TarjetaPrevia({
    super.key,
    required this.previa,
    required this.reverso,
    this.ancho = 420,
    this.diseno,
    this.plantillaUrl,
    this.valores = const {},
    this.plantillaPorDefecto = true,
  });

  final CredencialPrevia previa;
  final bool reverso;
  final double ancho;
  final DisenoCredencial? diseno;
  final String? plantillaUrl;

  /// Campos de otros tipos de credencial, sin alterar los datos del productor.
  final Map<String, String> valores;

  /// Los operadores tienen un diseño independiente y no usan el carnet agrícola.
  final bool plantillaPorDefecto;

  static const double anchoPt = 242.65;
  static const double altoPt = 153.01;
  static const double margenPt = 8;
  static const double bandaSuperiorPt = 26;
  static const double bandaInferiorPt = 22;
  static const double bandaReversoPt = 20;
  static const double pieReversoPt = 24;
  static const double tituloPt = 7.5;
  static const double subtituloPt = 5.5;
  static const double rotuloPt = 5.5;
  static const double valorPt = 8;
  static const double pieFuertePt = 6.5;
  static const double pieSuavePt = 6;
  static const double cargoPt = 6.5;
  static const double nombreFirmantePt = 5.5;
  static const double notaPt = 5;
  static const double numeroPlantillaPt = 10;
  static const double firmaNombrePt = 4.2;
  static const double firmaCargoPt = 4;
  static const double firmaOrganizacionPt = 3.8;
  static const Color grisLinea = Color(0xFFAAAAAA);

  double get _escala => ancho / (diseno?.ancho ?? anchoPt);
  double _p(double puntos) => puntos * _escala;

  @override
  Widget build(BuildContext context) {
    final actual =
        diseno ??
        (plantillaPorDefecto
            ? DisenoCredencial.predeterminado()
            : const DisenoCredencial(
                ancho: anchoPt,
                alto: altoPt,
                elementos: [],
              ));
    final cara = reverso ? CaraCredencial.reverso : CaraCredencial.cara;
    final elementos = actual.elementos.where((e) => e.cara == cara);

    // Dibujar primero en el lienzo completo y reducirlo como una sola pieza.
    // Reducir solo el Container deformaba la plantilla y recortaba los objetos,
    // que seguían posicionados según `ancho` (420 por defecto).
    return FuentesBajoDemanda(
      fuentes: elementos
          .where(
            (e) =>
                e.tipo == TipoElementoCredencial.texto ||
                e.tipo == TipoElementoCredencial.pieFirma,
          )
          .map((e) => e.fuente)
          .toSet(),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: MediaQuery.withNoTextScaling(
          // El tamaño de letra pertenece al diseño impreso, no al ajuste del móvil.
          child: Container(
            width: ancho,
            height: _p(actual.alto),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: grisLinea),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                if (!elementos.any(
                  (e) => e.tipo == TipoElementoCredencial.plantilla,
                ))
                  _plantilla(),
                for (final elemento in elementos) ..._dibujar(elemento),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _dibujar(ElementoDisenoCredencial e) => switch (e.tipo) {
    TipoElementoCredencial.texto => [_texto(e)],
    TipoElementoCredencial.imagen => [_imagen(e)],
    TipoElementoCredencial.pieFirma => _pie(e),
    TipoElementoCredencial.plantilla => [_plantilla()],
  };

  Widget _plantilla() => Positioned.fill(
    child: plantillaUrl == null
        ? _plantillaPredeterminada()
        : !plantillaPorDefecto
        ? ImagenPlantillaAutenticada(url: plantillaUrl!)
        : ImagenAutenticada(
            ApiConfig.urlAbsoluta(plantillaUrl!),
            fit: BoxFit.fill,
            errorBuilder: (_, _, _) => _plantillaPredeterminada(),
          ),
  );

  Widget _plantillaPredeterminada() => plantillaPorDefecto
      ? Image.asset(
          reverso
              ? 'assets/credencial/reverso.jpg'
              : 'assets/credencial/cara.png',
          fit: BoxFit.fill,
        )
      : const ColoredBox(color: Colors.white);

  Widget _texto(ElementoDisenoCredencial e) {
    if (e.campo == 'RESENA') return _resena(e);
    final valor = _valor(e);
    final falta = valor.isEmpty;
    final texto = falta ? 'FALTA' : valor;
    final px = _p(e.tamanoFuente);
    final alignment = switch (e.alineacion) {
      AlineacionCredencial.izquierda => Alignment.bottomLeft,
      AlineacionCredencial.centro => Alignment.bottomCenter,
      AlineacionCredencial.derecha => Alignment.bottomRight,
    };
    return Positioned(
      left: _p(e.x),
      width: _p(e.ancho),
      bottom: _p(e.y) - px * .22,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          texto,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: e.fuente.familiaFlutter,
            fontSize: px,
            height: 1,
            fontWeight: e.negrita ? FontWeight.bold : FontWeight.normal,
            color: falta ? Colors.red.shade700 : _color(e.color),
          ),
        ),
      ),
    );
  }

  /// La autorización común es un párrafo, no un dato de una sola línea.
  Widget _resena(ElementoDisenoCredencial e) {
    final valor = _valor(e);
    final texto = valor.isEmpty ? 'FALTA' : valor;
    final alineacion = switch (e.alineacion) {
      AlineacionCredencial.izquierda => TextAlign.left,
      AlineacionCredencial.centro => TextAlign.center,
      AlineacionCredencial.derecha => TextAlign.right,
    };
    return Positioned(
      left: _p(e.x),
      bottom: _p(e.y),
      width: _p(e.ancho),
      height: _p(e.alto),
      child: LayoutBuilder(
        builder: (context, limites) {
          final base = TextStyle(
            fontFamily: e.fuente.familiaFlutter,
            fontSize: _p(e.tamanoFuente),
            height: 1.2,
            fontWeight: e.negrita ? FontWeight.bold : FontWeight.normal,
            color: valor.isEmpty ? Colors.red.shade700 : _color(e.color),
          );
          var inferior = .1;
          var superior = _p(e.tamanoFuente);
          var cuerpo = superior;
          for (var intento = 0; intento < 16; intento++) {
            final medida = TextPainter(
              text: TextSpan(
                text: texto,
                style: base.copyWith(fontSize: cuerpo),
              ),
              textAlign: alineacion,
              textDirection: Directionality.of(context),
            )..layout(maxWidth: limites.maxWidth);
            final cabe = medida.height <= limites.maxHeight;
            medida.dispose();
            if (cabe) {
              inferior = cuerpo;
              if (cuerpo == superior) break;
            } else {
              superior = cuerpo;
            }
            cuerpo = (inferior + superior) / 2;
          }
          return Text(
            texto,
            softWrap: true,
            textAlign: alineacion,
            style: base.copyWith(fontSize: inferior),
          );
        },
      ),
    );
  }

  Widget _imagen(ElementoDisenoCredencial e) {
    final url = _url(e);
    final esta = _imagenPresente(e);
    final esFoto = e.campo == 'FOTO';
    final opcional = _imagenOpcional(e.campo);
    final contenido = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: !esta && !opcional
            ? Border.all(color: Colors.red.shade400)
            : null,
      ),
      child: url != null
          ? ImagenAutenticada(
              ApiConfig.urlAbsoluta(url),
              fit: esFoto && e.circular ? BoxFit.cover : BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            )
          : e.campo == 'QR'
          ? Icon(Icons.qr_code_2, size: _p(e.alto) * .8)
          : Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  esFoto
                      ? 'SIN FOTO'
                      : opcional
                      ? 'FIRMA OPCIONAL'
                      : esta
                      ? e.etiqueta
                      : 'SIN ${e.etiqueta.toUpperCase()}',
                  style: TextStyle(
                    fontSize: _p(rotuloPt),
                    color: opcional
                        ? Colors.grey.shade600
                        : esta
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ),
    );
    return Positioned(
      left: _p(e.x),
      bottom: _p(e.y),
      width: _p(e.ancho),
      height: _p(e.alto),
      child: esFoto && e.circular ? ClipOval(child: contenido) : contenido,
    );
  }

  List<Widget> _pie(ElementoDisenoCredencial e) {
    final quien = _firmantePie(e.campo);
    final pieImagenUrl = quien?.pieFirmaUrl;
    final factor = e.alto / 21;
    Widget linea(String texto, double y, double fuente, FontWeight peso) {
      final px = _p(fuente);
      return Positioned(
        left: _p(e.x),
        width: _p(e.ancho),
        bottom: _p(e.y + y * factor) - px * .22,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomCenter,
          child: Text(
            texto,
            maxLines: 1,
            style: TextStyle(
              fontFamily: e.fuente.familiaFlutter,
              fontSize: px,
              height: 1,
              fontWeight: peso,
            ),
          ),
        ),
      );
    }

    return [
      if (pieImagenUrl != null)
        Positioned(
          left: _p(e.x),
          bottom: _p(e.y),
          width: _p(e.ancho),
          height: _p(e.alto),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: ImagenAutenticada(
              ApiConfig.urlAbsoluta(pieImagenUrl),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          ),
        )
      else if (quien == null && !_pieOpcional(e.campo))
        linea('SIN FIRMANTE', 10, e.tamanoFuente, FontWeight.bold)
      else if (quien != null) ...[
        linea(quien.nombre, 15, e.tamanoFuente, FontWeight.bold),
        linea(
          quien.cargo,
          10,
          ((e.tamanoFuente * 10 - 2).round() / 10).clamp(3, 40),
          FontWeight.bold,
        ),
        linea(
          quien.organizacion,
          5,
          ((e.tamanoFuente * 10 - 4).round() / 10).clamp(3, 40),
          FontWeight.normal,
        ),
      ],
    ];
  }

  String _valor(ElementoDisenoCredencial e) =>
      valores[e.campo] ??
      switch (e.campo) {
        'CODIGO_PADRON' => previa.codigoPadron ?? '',
        'NOMBRE_COMPLETO' => '${previa.nombres} ${previa.apellidos}'.trim(),
        'NOMBRES' => previa.nombres,
        'APELLIDOS' => previa.apellidos,
        'CI' => previa.ci,
        'SINDICATO' => previa.sindicato,
        'CENTRAL' => previa.central,
        'FEDERACION' => previa.federacion.replaceFirst(
          RegExp(r'^FEDERACI[ÓO]N\s+', caseSensitive: false),
          '',
        ),
        'LOTES' => previa.lotes.isEmpty ? '—' : previa.lotes,
        'FECHA_EMISION' => DateTime.now().toString().substring(0, 10),
        'CODIGO_CREDENCIAL' => previa.codigoQr,
        'TEXTO_FIJO' => e.texto,
        _ => '',
      };

  String? _url(ElementoDisenoCredencial e) {
    if (e.campo == 'IMAGEN_PERSONALIZADA' && e.recurso != null) {
      return '/api/v1/archivos/${e.recurso}';
    }
    return switch (e.campo) {
      'FOTO' => previa.fotoUrl,
      'SELLO_FEDERACION' => previa.selloFederacionUrl,
      'SELLO_CENTRAL' => previa.selloCentralUrl,
      'SELLO_SINDICATO' => previa.selloSindicatoUrl,
      'FIRMA_FEDERACION' => previa.ejecutivoFederacion?.firmaUrl,
      'FIRMA_CENTRAL' => previa.secretarioGeneralCentral?.firmaUrl,
      'FIRMA_SINDICATO' => previa.secretarioGeneralSindicato?.firmaUrl,
      _ => null,
    };
  }

  bool _imagenPresente(ElementoDisenoCredencial e) => switch (e.campo) {
    'IMAGEN_PERSONALIZADA' => e.recurso?.isNotEmpty ?? false,
    'FOTO' => previa.fotoUrl != null,
    'QR' => true,
    'SELLO_FEDERACION' => previa.selloFederacionUrl != null,
    'SELLO_CENTRAL' => previa.selloCentralUrl != null,
    'SELLO_SINDICATO' => previa.selloSindicatoUrl != null,
    'FIRMA_FEDERACION' => previa.ejecutivoFederacion?.tieneFirma ?? false,
    'FIRMA_CENTRAL' => previa.secretarioGeneralCentral?.tieneFirma ?? false,
    'FIRMA_SINDICATO' => previa.secretarioGeneralSindicato?.tieneFirma ?? false,
    _ => false,
  };

  bool _imagenOpcional(String campo) =>
      campo == 'FIRMA_SINDICATO' && !previa.firmaSindicatoObligatoria;

  bool _pieOpcional(String campo) =>
      campo == 'PIE_SINDICATO' && !previa.firmaSindicatoObligatoria;

  FirmantePrevio? _firmantePie(String campo) => switch (campo) {
    'PIE_FEDERACION' => previa.ejecutivoFederacion,
    'PIE_CENTRAL' => previa.secretarioGeneralCentral,
    'PIE_SINDICATO' => previa.secretarioGeneralSindicato,
    _ => null,
  };

  Color _color(String texto) {
    final limpio = texto.replaceFirst('#', '');
    final valor = int.tryParse(limpio, radix: 16);
    return valor == null ? Colors.black : Color(0xFF000000 | valor);
  }
}
