import 'auditoria.dart';
import 'imagen.dart';
import 'lote.dart';

/// Una fila del padrón.
///
/// Casi todo puede faltar: el padrón real tiene 124 productores sin cédula,
/// 1.837 sin carné y 5 sin apellido. Por eso solo [nombres] y [sindicatoId]
/// son obligatorios en el alta, y aquí casi todos los campos son nulables.
///
/// La jerarquía llega hasta la central. El backend todavía no expone
/// `federacionId` ni `federacionNombre` en esta respuesta, así que para
/// mostrar la ruta completa hay que resolver la federación desde la central.
class Productor {
  const Productor({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.nombreCompleto,
    required this.ci,
    required this.nombresCorregidos,
    required this.apellidosCorregidos,
    required this.fotoDescripcion,
    required this.tieneFoto,
    required this.marcado,
    required this.sindicatoId,
    required this.sindicatoNombre,
    required this.centralId,
    required this.centralNombre,
    this.miniaturaUrl,
    this.fotoUrl,
    this.codigo,
    this.codigoPadron,
    this.auditoria = Auditoria.habilitado,
  });

  /// Código de su credencial: lo que dice el QR, y lo que se escribe a mano
  /// cuando la cámara no lee.
  final String? codigo;

  /// Código en el padrón: número de la federación, sigla de la central y número
  /// del productor dentro de esa central, como `2-IVI-1`.
  ///
  /// Null mientras la federación no tenga número o la central no tenga sigla.
  /// El backend prefiere no devolver nada antes que un código a medias, porque
  /// esto se imprime en la credencial.
  final String? codigoPadron;

  final Auditoria auditoria;

  bool get habilitado => auditoria.estado;

  final int id;
  final String nombres;
  final String? apellidos;

  /// Nombre y apellido ya armados por el backend, tomando la corrección si la
  /// hay. Es el que se muestra en listas.
  final String nombreCompleto;

  /// Es texto, no número: admite complemento como `8005906-1V`. No es único —
  /// el padrón tiene 27 cédulas repetidas.
  final String? ci;

  final String? nombresCorregidos;
  final String? apellidosCorregidos;

  /// Rótulo con el que se archivó la fotografía. Que venga vacío es
  /// precisamente lo que cuenta como «sin foto».
  final String? fotoDescripcion;

  final bool tieneFoto;

  /// Marca manual puesta durante la revisión.
  final bool marcado;

  final int sindicatoId;
  final String sindicatoNombre;
  final int centralId;
  final String centralNombre;

  /// Dirección de la miniatura, o null si el productor no tiene foto.
  ///
  /// Ojo con no confundirlo con [tieneFoto], que dice si la planilla trae el
  /// rótulo de la fotografía archivada en papel. Son cosas distintas: un
  /// productor puede tener rótulo y no tener imagen subida, y al revés.
  ///
  /// La dirección incluye un identificador que cambia al reemplazar la foto,
  /// así que no hace falta ningún parámetro extra para evitar que la caché
  /// devuelva la anterior.
  final String? miniaturaUrl;

  /// Dirección de la fotografía completa, o null.
  final String? fotoUrl;

  bool get tieneMiniatura => miniaturaUrl != null;
  bool get tieneOriginal => fotoUrl != null;

  /// Hay una corrección de nombre propuesta y sin confirmar.
  bool get tieneCorreccionPendiente =>
      (nombresCorregidos?.isNotEmpty ?? false) ||
      (apellidosCorregidos?.isNotEmpty ?? false);

  /// Ruta jerárquica que se puede armar con lo que devuelve el backend hoy.
  String get ruta => '$centralNombre › $sindicatoNombre';

  factory Productor.desdeJson(Map<String, dynamic> json) => Productor(
    id: (json['id'] as num?)?.toInt() ?? 0,
    nombres: json['nombres'] as String? ?? '',
    apellidos: json['apellidos'] as String?,
    nombreCompleto: json['nombreCompleto'] as String? ?? '',
    ci: json['ci'] as String?,
    nombresCorregidos: json['nombresCorregidos'] as String?,
    apellidosCorregidos: json['apellidosCorregidos'] as String?,
    fotoDescripcion: json['fotoDescripcion'] as String?,
    tieneFoto: json['tieneFoto'] as bool? ?? false,
    marcado: json['marcado'] as bool? ?? false,
    sindicatoId: (json['sindicatoId'] as num?)?.toInt() ?? 0,
    sindicatoNombre: json['sindicatoNombre'] as String? ?? '',
    centralId: (json['centralId'] as num?)?.toInt() ?? 0,
    centralNombre: json['centralNombre'] as String? ?? '',
    miniaturaUrl: json['miniaturaUrl'] as String?,
    fotoUrl: json['fotoUrl'] as String?,
    codigo: json['codigo'] as String?,
    codigoPadron: json['codigoPadron'] as String?,
    auditoria: Auditoria.desdeJson(json['auditoria'] as Map<String, dynamic>?),
  );

  @override
  bool operator ==(Object other) => other is Productor && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Ficha completa: el productor con sus lotes y sus imágenes.
class ProductorDetalle {
  const ProductorDetalle({
    required this.productor,
    required this.lotes,
    required this.imagenes,
  });

  final Productor productor;
  final List<Lote> lotes;
  final List<Imagen> imagenes;

  Iterable<Lote> get lotesPorRevisar => lotes.where((l) => l.necesitaRevision);

  /// La imagen de ese tipo, o null si el productor no la tiene cargada.
  Imagen? imagen(TipoImagen tipo) {
    for (final i in imagenes) {
      if (i.tipo == tipo) return i;
    }
    return null;
  }

  factory ProductorDetalle.desdeJson(Map<String, dynamic> json) {
    List<T> lista<T>(Object? crudo, T Function(Map<String, dynamic>) mapear) =>
        crudo is List
        ? crudo.whereType<Map<String, dynamic>>().map(mapear).toList()
        : const [];

    return ProductorDetalle(
      productor: Productor.desdeJson(
        (json['productor'] as Map<String, dynamic>?) ?? const {},
      ),
      lotes: lista(json['lotes'], Lote.desdeJson),
      imagenes: lista(json['imagenes'], Imagen.desdeJson),
    );
  }
}

/// Alta y edición de productores.
///
/// Los límites de longitud son los mismos que valida Jakarta en el backend;
/// repetirlos aquí permite avisar en el formulario antes de gastar una
/// petición.
class ProductorRequest {
  const ProductorRequest({
    required this.nombres,
    required this.sindicatoId,
    this.apellidos,
    this.ci,
    this.nombresCorregidos,
    this.apellidosCorregidos,
    this.fotoDescripcion,
    this.marcado = false,
  });

  static const int maxNombres = 60;
  static const int maxApellidos = 60;
  static const int maxCi = 20;
  static const int maxFotoDescripcion = 120;

  final String nombres;
  final int sindicatoId;
  final String? apellidos;
  final String? ci;
  final String? nombresCorregidos;
  final String? apellidosCorregidos;
  final String? fotoDescripcion;
  final bool marcado;

  /// Copia los datos de un productor existente, para precargar el formulario
  /// de edición.
  factory ProductorRequest.desde(Productor p) => ProductorRequest(
    nombres: p.nombres,
    sindicatoId: p.sindicatoId,
    apellidos: p.apellidos,
    ci: p.ci,
    nombresCorregidos: p.nombresCorregidos,
    apellidosCorregidos: p.apellidosCorregidos,
    fotoDescripcion: p.fotoDescripcion,
    marcado: p.marcado,
  );

  Map<String, dynamic> aJson() => {
    'nombres': nombres,
    'sindicatoId': sindicatoId,
    if (apellidos != null) 'apellidos': apellidos,
    if (ci != null) 'ci': ci,
    if (nombresCorregidos != null) 'nombresCorregidos': nombresCorregidos,
    if (apellidosCorregidos != null) 'apellidosCorregidos': apellidosCorregidos,
    if (fotoDescripcion != null) 'fotoDescripcion': fotoDescripcion,
    'marcado': marcado,
  };
}

enum EstadoConsultaPersona { encontrada, noEncontrada, noDisponible }

class ConsultaPersona {
  const ConsultaPersona({
    required this.estado,
    this.nombres,
    this.apellidos,
    this.mensaje,
  });

  final EstadoConsultaPersona estado;
  final String? nombres;
  final String? apellidos;
  final String? mensaje;

  bool get encontrada => estado == EstadoConsultaPersona.encontrada;

  factory ConsultaPersona.desdeJson(Map<String, dynamic> json) =>
      ConsultaPersona(
        estado: switch (json['estado']) {
          'ENCONTRADA' => EstadoConsultaPersona.encontrada,
          'NO_ENCONTRADA' => EstadoConsultaPersona.noEncontrada,
          _ => EstadoConsultaPersona.noDisponible,
        },
        nombres: json['nombres'] as String?,
        apellidos: json['apellidos'] as String?,
        mensaje: json['mensaje'] as String?,
      );
}
