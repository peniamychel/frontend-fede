import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../repositories/padron.dart';

/// Proporciones ofrecidas para el recorte.
enum Proporcion {
  libre('Libre', null),
  carne('3:4', 3 / 4),
  cuadrada('1:1', 1),
  apaisada('4:3', 4 / 3);

  const Proporcion(this.etiqueta, this.relacion);

  final String etiqueta;

  /// Ancho dividido alto. Null cuando no se fuerza ninguna.
  final double? relacion;
}

/// Selector de la región de una imagen que se quiere conservar.
///
/// Está escrito a mano en vez de usar un paquete porque los recortadores
/// habituales de Flutter envuelven bibliotecas nativas de Android e iOS y no
/// funcionan en web, que es donde corre esta app.
///
/// Trabaja en dos sistemas de coordenadas: el del widget, para dibujar y
/// arrastrar, y el de los píxeles de la imagen, que es lo único que entiende el
/// servidor. La conversión entre ambos vive en [_aCoordenadasDeImagen].
class RecortadorImagen extends StatefulWidget {
  const RecortadorImagen({
    super.key,
    required this.bytes,
    required this.alCambiar,
    this.alCargarImagen,
    this.proporcionFija,
    this.alCambiarInteraccion,
  });

  final Uint8List bytes;

  /// Avisa el recorte elegido en píxeles de la imagen, o null mientras todavía
  /// no se conocen sus dimensiones.
  final ValueChanged<Recorte?> alCambiar;

  /// Avisa el tamaño real de la imagen una vez decodificada. Lo necesita quien
  /// tenga que comparar el recorte contra la imagen entera.
  final void Function(int ancho, int alto)? alCargarImagen;

  /// Cuando se define, la persona no puede cambiar la relación del marco.
  /// Las fotos para la credencial usan un único encuadre cuadrado.
  final Proporcion? proporcionFija;

  /// Permite que un contenedor desplazable se detenga mientras se manipula el
  /// marco. En Android, si ambos reconocen el mismo arrastre vertical, el
  /// diálogo puede desplazarse en vez de mover la esquina bajo el dedo.
  final ValueChanged<bool>? alCambiarInteraccion;

  @override
  State<RecortadorImagen> createState() => _RecortadorImagenState();
}

class _RecortadorImagenState extends State<RecortadorImagen> {
  /// Lado mínimo del rectángulo, en píxeles de pantalla. Evita que un toque
  /// torpe lo reduzca a nada.
  static const double _minimo = 48;

  /// Zona sensible de las esquinas. En una pantalla táctil el centro puede
  /// quedar debajo del dedo y, cuando está en el borde, parte del área queda
  /// fuera del lienzo; por eso es bastante mayor que el indicador visible.
  double _tamanoAsa() => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => 88,
    _ => 56,
  };

  ui.Image? _imagen;
  Object? _error;

  late Proporcion _proporcion;

  /// Recorte en coordenadas del área de dibujo, no de la imagen.
  Rect? _recorte;

  /// Dónde quedó dibujada la imagen dentro del área disponible.
  Rect _areaImagen = Rect.zero;

  @override
  void initState() {
    super.initState();
    _proporcion = widget.proporcionFija ?? Proporcion.libre;
    _decodificar();
  }

  @override
  void dispose() {
    _imagen?.dispose();
    super.dispose();
  }

  Future<void> _decodificar() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final cuadro = await codec.getNextFrame();
      if (!mounted) {
        cuadro.image.dispose();
        return;
      }
      setState(() => _imagen = cuadro.image);
      widget.alCargarImagen?.call(cuadro.image.width, cuadro.image.height);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imagen = _imagen;

    if (_error != null) {
      return _mensaje(
        context,
        'El archivo no se puede mostrar como imagen. '
        'El servidor también lo va a rechazar.',
        esError: true,
      );
    }
    if (imagen == null) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 320,
          child: LayoutBuilder(
            builder: (context, restricciones) {
              _recalcularArea(restricciones.biggest, imagen);
              return _lienzo(context, imagen);
            },
          ),
        ),
        const SizedBox(height: 12),
        _controles(context),
      ],
    );
  }

  /// Calcula dónde entra la imagen en el área disponible, respetando su
  /// proporción, y coloca el recorte inicial la primera vez.
  void _recalcularArea(Size disponible, ui.Image imagen) {
    final escala = math.min(
      disponible.width / imagen.width,
      disponible.height / imagen.height,
    );
    final ancho = imagen.width * escala;
    final alto = imagen.height * escala;
    _areaImagen = Rect.fromLTWH(
      (disponible.width - ancho) / 2,
      (disponible.height - alto) / 2,
      ancho,
      alto,
    );

    if (_recorte == null) {
      _recorte = _rectanguloInicial();
      // Después del primer cuadro, para no notificar durante el build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _notificar());
    }
  }

  Widget _lienzo(BuildContext context, ui.Image imagen) {
    final recorte = _recorte!;
    final tema = Theme.of(context);

    return Stack(
      children: [
        Positioned.fromRect(
          rect: _areaImagen,
          child: RawImage(image: imagen, fit: BoxFit.fill),
        ),
        // Oscurece lo que quedaría afuera: es la forma más directa de mostrar
        // qué se conserva y qué se descarta.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PintorRecorte(
                recorte: recorte,
                color: tema.colorScheme.primary,
              ),
            ),
          ),
        ),
        // Mover el rectángulo entero.
        Positioned.fromRect(
          rect: recorte,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => widget.alCambiarInteraccion?.call(true),
            onPanUpdate: (d) => _mover(d.delta),
            onPanEnd: (_) => widget.alCambiarInteraccion?.call(false),
            onPanCancel: () => widget.alCambiarInteraccion?.call(false),
            child: const MouseRegion(cursor: SystemMouseCursors.move),
          ),
        ),
        for (final esquina in _Esquina.values) _asaDe(esquina, recorte, tema),
      ],
    );
  }

  Widget _asaDe(_Esquina esquina, Rect recorte, ThemeData tema) {
    final asa = _tamanoAsa();
    final indicador = asa > 56 ? 20.0 : 12.0;
    final punto = switch (esquina) {
      _Esquina.superiorIzquierda => recorte.topLeft,
      _Esquina.superiorDerecha => recorte.topRight,
      _Esquina.inferiorIzquierda => recorte.bottomLeft,
      _Esquina.inferiorDerecha => recorte.bottomRight,
    };

    return Positioned(
      left: punto.dx - asa / 2,
      top: punto.dy - asa / 2,
      width: asa,
      height: asa,
      child: GestureDetector(
        key: ValueKey('recorte-${esquina.name}'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => widget.alCambiarInteraccion?.call(true),
        onPanUpdate: (d) => _redimensionar(esquina, d.delta),
        onPanEnd: (_) => widget.alCambiarInteraccion?.call(false),
        onPanCancel: () => widget.alCambiarInteraccion?.call(false),
        child: MouseRegion(
          cursor:
              esquina == _Esquina.superiorIzquierda ||
                  esquina == _Esquina.inferiorDerecha
              ? SystemMouseCursors.resizeUpLeftDownRight
              : SystemMouseCursors.resizeUpRightDownLeft,
          child: Center(
            child: Container(
              // El círculo muestra dónde apoyar el dedo, mientras toda el
              // área transparente que lo rodea también acepta el arrastre.
              width: indicador,
              height: indicador,
              decoration: BoxDecoration(
                color: tema.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.25),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controles(BuildContext context) {
    final tema = Theme.of(context);
    final imagen = _imagen!;
    final actual = _aCoordenadasDeImagen();

    return Column(
      children: [
        if (widget.proporcionFija == null)
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final p in Proporcion.values)
                ChoiceChip(
                  label: Text(p.etiqueta),
                  selected: _proporcion == p,
                  onSelected: (_) => _aplicarProporcion(p),
                  visualDensity: VisualDensity.compact,
                ),
              ActionChip(
                avatar: const Icon(Icons.crop_free, size: 16),
                label: const Text('Todo'),
                onPressed: () {
                  setState(() {
                    _proporcion = Proporcion.libre;
                    _recorte = _areaImagen;
                  });
                  _notificar();
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          )
        else
          const Text('Formato de fotografía: cuadrado (1:1)'),
        const SizedBox(height: 8),
        Text(
          actual == null
              ? '${imagen.width} × ${imagen.height}'
              : 'Se guardará ${actual.ancho} × ${actual.alto} '
                    'de ${imagen.width} × ${imagen.height}',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _mensaje(BuildContext context, String texto, {bool esError = false}) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: esError ? Theme.of(context).colorScheme.error : null,
        ),
      ),
    );
  }

  // ---------- Manipulación ----------

  void _mover(Offset delta) {
    final recorte = _recorte!;
    var movido = recorte.shift(delta);

    // Se frena contra los bordes en vez de dejar salir el rectángulo: un
    // recorte fuera de la imagen no existe, y el servidor lo rechazaría.
    final dx = movido.left < _areaImagen.left
        ? _areaImagen.left - movido.left
        : movido.right > _areaImagen.right
        ? _areaImagen.right - movido.right
        : 0.0;
    final dy = movido.top < _areaImagen.top
        ? _areaImagen.top - movido.top
        : movido.bottom > _areaImagen.bottom
        ? _areaImagen.bottom - movido.bottom
        : 0.0;
    movido = movido.shift(Offset(dx, dy));

    setState(() => _recorte = movido);
    _notificar();
  }

  void _redimensionar(_Esquina esquina, Offset delta) {
    final relacion = _proporcion.relacion;
    if (relacion != null) {
      final nuevo = _redimensionarProporcional(esquina, delta, relacion);
      setState(() => _recorte = nuevo);
      _notificar();
      return;
    }

    final recorte = _recorte!;
    double izq = recorte.left;
    double arr = recorte.top;
    double der = recorte.right;
    double aba = recorte.bottom;

    switch (esquina) {
      case _Esquina.superiorIzquierda:
        izq += delta.dx;
        arr += delta.dy;
      case _Esquina.superiorDerecha:
        der += delta.dx;
        arr += delta.dy;
      case _Esquina.inferiorIzquierda:
        izq += delta.dx;
        aba += delta.dy;
      case _Esquina.inferiorDerecha:
        der += delta.dx;
        aba += delta.dy;
    }

    izq = izq.clamp(_areaImagen.left, der - _minimo);
    arr = arr.clamp(_areaImagen.top, aba - _minimo);
    der = der.clamp(izq + _minimo, _areaImagen.right);
    aba = aba.clamp(arr + _minimo, _areaImagen.bottom);

    setState(() => _recorte = Rect.fromLTRB(izq, arr, der, aba));
    _notificar();
  }

  /// Redimensiona conservando la proporción y dejando quieta la esquina
  /// opuesta. El eje que más se movió gobierna el tamaño: así un dedo no tiene
  /// que recorrer una diagonal perfecta para que el asa lo siga en Android.
  Rect _redimensionarProporcional(
    _Esquina esquina,
    Offset delta,
    double relacion,
  ) {
    final recorte = _recorte!;
    final esIzquierda =
        esquina == _Esquina.superiorIzquierda ||
        esquina == _Esquina.inferiorIzquierda;
    final esSuperior =
        esquina == _Esquina.superiorIzquierda ||
        esquina == _Esquina.superiorDerecha;
    final fijo = switch (esquina) {
      _Esquina.superiorIzquierda => recorte.bottomRight,
      _Esquina.superiorDerecha => recorte.bottomLeft,
      _Esquina.inferiorIzquierda => recorte.topRight,
      _Esquina.inferiorDerecha => recorte.topLeft,
    };

    final cambioHorizontal = esIzquierda ? -delta.dx : delta.dx;
    final cambioVerticalComoAncho =
        (esSuperior ? -delta.dy : delta.dy) * relacion;
    final cambio = cambioHorizontal.abs() >= cambioVerticalComoAncho.abs()
        ? cambioHorizontal
        : cambioVerticalComoAncho;

    final maximoHorizontal = esIzquierda
        ? fijo.dx - _areaImagen.left
        : _areaImagen.right - fijo.dx;
    final maximoVertical =
        (esSuperior
            ? fijo.dy - _areaImagen.top
            : _areaImagen.bottom - fijo.dy) *
        relacion;
    final maximoAncho = math.min(maximoHorizontal, maximoVertical);
    final minimoAncho = math.min(
      maximoAncho,
      math.max(_minimo, _minimo * relacion),
    );
    final ancho = (recorte.width + cambio).clamp(minimoAncho, maximoAncho);
    final alto = ancho / relacion;

    return switch (esquina) {
      _Esquina.superiorIzquierda => Rect.fromLTWH(
        fijo.dx - ancho,
        fijo.dy - alto,
        ancho,
        alto,
      ),
      _Esquina.superiorDerecha => Rect.fromLTWH(
        fijo.dx,
        fijo.dy - alto,
        ancho,
        alto,
      ),
      _Esquina.inferiorIzquierda => Rect.fromLTWH(
        fijo.dx - ancho,
        fijo.dy,
        ancho,
        alto,
      ),
      _Esquina.inferiorDerecha => Rect.fromLTWH(fijo.dx, fijo.dy, ancho, alto),
    };
  }

  Rect _dentroDelArea(Rect rect) {
    final izq = rect.left.clamp(_areaImagen.left, _areaImagen.right - _minimo);
    final arr = rect.top.clamp(_areaImagen.top, _areaImagen.bottom - _minimo);
    final der = rect.right.clamp(izq + _minimo, _areaImagen.right);
    final aba = rect.bottom.clamp(arr + _minimo, _areaImagen.bottom);
    return Rect.fromLTRB(izq, arr, der, aba);
  }

  void _aplicarProporcion(Proporcion p) {
    setState(() {
      _proporcion = p;
      final relacion = p.relacion;
      if (relacion == null) return;

      // Se arma el rectángulo más grande con esa proporción que entre en la
      // imagen, centrado: es el punto de partida más útil.
      final recorte = _recorte!;
      double ancho = recorte.width;
      double alto = ancho / relacion;
      if (alto > _areaImagen.height) {
        alto = _areaImagen.height;
        ancho = alto * relacion;
      }
      if (ancho > _areaImagen.width) {
        ancho = _areaImagen.width;
        alto = ancho / relacion;
      }
      _recorte = _dentroDelArea(
        Rect.fromCenter(center: recorte.center, width: ancho, height: alto),
      );
    });
    _notificar();
  }

  Rect _rectanguloInicial() {
    final relacion = _proporcion.relacion;
    if (relacion == null) return _areaImagen;

    double ancho = _areaImagen.width;
    double alto = ancho / relacion;
    if (alto > _areaImagen.height) {
      alto = _areaImagen.height;
      ancho = alto * relacion;
    }
    return Rect.fromCenter(
      center: _areaImagen.center,
      width: ancho,
      height: alto,
    );
  }

  // ---------- Conversión ----------

  /// Pasa el rectángulo de coordenadas de pantalla a píxeles de la imagen.
  Recorte? _aCoordenadasDeImagen() {
    final imagen = _imagen;
    final recorte = _recorte;
    if (imagen == null || recorte == null || _areaImagen.width == 0) {
      return null;
    }

    final escala = imagen.width / _areaImagen.width;

    final x = ((recorte.left - _areaImagen.left) * escala).round();
    final y = ((recorte.top - _areaImagen.top) * escala).round();
    final ancho = (recorte.width * escala).round();
    final alto = (recorte.height * escala).round();

    // El redondeo puede empujar el borde un píxel afuera; se acota para que el
    // servidor no rechace un recorte que en pantalla se veía bien.
    final xSeguro = x.clamp(0, imagen.width - 1);
    final ySeguro = y.clamp(0, imagen.height - 1);
    return Recorte(
      x: xSeguro,
      y: ySeguro,
      ancho: ancho.clamp(1, imagen.width - xSeguro),
      alto: alto.clamp(1, imagen.height - ySeguro),
    );
  }

  void _notificar() => widget.alCambiar(_aCoordenadasDeImagen());
}

enum _Esquina {
  superiorIzquierda,
  superiorDerecha,
  inferiorIzquierda,
  inferiorDerecha,
}

/// Oscurece lo que queda fuera del recorte y dibuja la guía de tercios.
class _PintorRecorte extends CustomPainter {
  _PintorRecorte({required this.recorte, required this.color});

  final Rect recorte;
  final Color color;

  @override
  void paint(Canvas lienzo, Size tamano) {
    final sombra = Paint()..color = Colors.black.withValues(alpha: 0.55);

    // Se pinta todo y se descuenta el recorte con evenOdd: más simple y exacto
    // que calcular las cuatro franjas de alrededor a mano.
    final camino = Path()
      ..addRect(Offset.zero & tamano)
      ..addRect(recorte)
      ..fillType = PathFillType.evenOdd;
    lienzo.drawPath(camino, sombra);

    final borde = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    lienzo.drawRect(recorte, borde);

    // Regla de los tercios: ayuda a centrar la cara sin adivinar.
    final guia = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = recorte.left + recorte.width * i / 3;
      final dy = recorte.top + recorte.height * i / 3;
      lienzo.drawLine(
        Offset(dx, recorte.top),
        Offset(dx, recorte.bottom),
        guia,
      );
      lienzo.drawLine(
        Offset(recorte.left, dy),
        Offset(recorte.right, dy),
        guia,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorRecorte anterior) =>
      anterior.recorte != recorte || anterior.color != color;
}
