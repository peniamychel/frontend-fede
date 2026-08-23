enum CaraCredencial { cara, reverso }

enum TipoElementoCredencial { texto, imagen, pieFirma }

enum AlineacionCredencial { izquierda, centro, derecha }

class ElementoDisenoCredencial {
  const ElementoDisenoCredencial({
    required this.id,
    required this.cara,
    required this.tipo,
    required this.campo,
    required this.etiqueta,
    required this.x,
    required this.y,
    required this.ancho,
    required this.alto,
    required this.tamanoFuente,
    required this.negrita,
    required this.alineacion,
    required this.color,
    required this.texto,
  });

  final String id;
  final CaraCredencial cara;
  final TipoElementoCredencial tipo;
  final String campo;
  final String etiqueta;
  final double x;
  final double y;
  final double ancho;
  final double alto;
  final double tamanoFuente;
  final bool negrita;
  final AlineacionCredencial alineacion;
  final String color;
  final String texto;

  factory ElementoDisenoCredencial.desdeJson(Map<String, dynamic> json) =>
      ElementoDisenoCredencial(
        id: json['id'] as String? ?? '',
        cara: (json['cara'] == 'REVERSO')
            ? CaraCredencial.reverso
            : CaraCredencial.cara,
        tipo: switch (json['tipo']) {
          'IMAGEN' => TipoElementoCredencial.imagen,
          'PIE_FIRMA' => TipoElementoCredencial.pieFirma,
          _ => TipoElementoCredencial.texto,
        },
        campo: json['campo'] as String? ?? '',
        etiqueta: json['etiqueta'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        ancho: (json['ancho'] as num?)?.toDouble() ?? 30,
        alto: (json['alto'] as num?)?.toDouble() ?? 10,
        tamanoFuente: (json['tamanoFuente'] as num?)?.toDouble() ?? 8,
        negrita: json['negrita'] as bool? ?? false,
        alineacion: switch (json['alineacion']) {
          'CENTRO' => AlineacionCredencial.centro,
          'DERECHA' => AlineacionCredencial.derecha,
          _ => AlineacionCredencial.izquierda,
        },
        color: json['color'] as String? ?? '#000000',
        texto: json['texto'] as String? ?? '',
      );

  Map<String, dynamic> aJson() => {
    'id': id,
    'cara': cara == CaraCredencial.cara ? 'CARA' : 'REVERSO',
    'tipo': switch (tipo) {
      TipoElementoCredencial.texto => 'TEXTO',
      TipoElementoCredencial.imagen => 'IMAGEN',
      TipoElementoCredencial.pieFirma => 'PIE_FIRMA',
    },
    'campo': campo,
    'etiqueta': etiqueta,
    'x': x,
    'y': y,
    'ancho': ancho,
    'alto': alto,
    'tamanoFuente': tamanoFuente,
    'negrita': negrita,
    'alineacion': switch (alineacion) {
      AlineacionCredencial.izquierda => 'IZQUIERDA',
      AlineacionCredencial.centro => 'CENTRO',
      AlineacionCredencial.derecha => 'DERECHA',
    },
    'color': color,
    'texto': texto,
  };

  ElementoDisenoCredencial copiar({
    CaraCredencial? cara,
    double? x,
    double? y,
    double? ancho,
    double? alto,
    double? tamanoFuente,
    bool? negrita,
    AlineacionCredencial? alineacion,
    String? texto,
  }) => ElementoDisenoCredencial(
    id: id,
    cara: cara ?? this.cara,
    tipo: tipo,
    campo: campo,
    etiqueta: etiqueta,
    x: x ?? this.x,
    y: y ?? this.y,
    ancho: ancho ?? this.ancho,
    alto: alto ?? this.alto,
    tamanoFuente: tamanoFuente ?? this.tamanoFuente,
    negrita: negrita ?? this.negrita,
    alineacion: alineacion ?? this.alineacion,
    color: color,
    texto: texto ?? this.texto,
  );
}

class DisenoCredencial {
  const DisenoCredencial({
    required this.ancho,
    required this.alto,
    required this.elementos,
  });

  final double ancho;
  final double alto;
  final List<ElementoDisenoCredencial> elementos;

  factory DisenoCredencial.desdeJson(Map<String, dynamic> json) =>
      DisenoCredencial(
        ancho: (json['ancho'] as num?)?.toDouble() ?? 242.65,
        alto: (json['alto'] as num?)?.toDouble() ?? 153.01,
        elementos: ((json['elementos'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ElementoDisenoCredencial.desdeJson)
            .toList(),
      );

  Map<String, dynamic> aJson() => {
    'ancho': ancho,
    'alto': alto,
    'elementos': elementos.map((e) => e.aJson()).toList(),
  };

  DisenoCredencial conElementos(List<ElementoDisenoCredencial> nuevos) =>
      DisenoCredencial(ancho: ancho, alto: alto, elementos: nuevos);

  static DisenoCredencial predeterminado() =>
      DisenoCredencial.desdeJson(_predeterminado);
}

class CampoCredencial {
  const CampoCredencial({
    required this.campo,
    required this.etiqueta,
    required this.tipo,
  });

  final String campo;
  final String etiqueta;
  final TipoElementoCredencial tipo;

  factory CampoCredencial.desdeJson(Map<String, dynamic> json) =>
      CampoCredencial(
        campo: json['campo'] as String? ?? '',
        etiqueta: json['etiqueta'] as String? ?? '',
        tipo: switch (json['tipo']) {
          'IMAGEN' => TipoElementoCredencial.imagen,
          'PIE_FIRMA' => TipoElementoCredencial.pieFirma,
          _ => TipoElementoCredencial.texto,
        },
      );
}

class EditorDisenoCredencial {
  const EditorDisenoCredencial({required this.diseno, required this.campos});

  final DisenoCredencial diseno;
  final List<CampoCredencial> campos;

  factory EditorDisenoCredencial.desdeJson(Map<String, dynamic> json) =>
      EditorDisenoCredencial(
        diseno: DisenoCredencial.desdeJson(
          json['diseno'] as Map<String, dynamic>? ?? const {},
        ),
        campos: ((json['camposDisponibles'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CampoCredencial.desdeJson)
            .toList(),
      );
}

const Map<String, dynamic> _predeterminado = {
  'ancho': 242.65,
  'alto': 153.01,
  'elementos': [
    {
      'id': 'numero-padron',
      'cara': 'CARA',
      'tipo': 'TEXTO',
      'campo': 'CODIGO_PADRON',
      'etiqueta': 'N° de padrón',
      'x': 31,
      'y': 89.5,
      'ancho': 45,
      'alto': 10,
      'tamanoFuente': 10,
      'negrita': true,
      'alineacion': 'IZQUIERDA',
      'color': '#5A0F0A',
      'texto': '',
    },
    {
      'id': 'nombre-completo',
      'cara': 'CARA',
      'tipo': 'TEXTO',
      'campo': 'NOMBRE_COMPLETO',
      'etiqueta': 'Nombre completo',
      'x': 65,
      'y': 75.7,
      'ancho': 102,
      'alto': 8,
      'tamanoFuente': 8,
      'negrita': true,
      'alineacion': 'IZQUIERDA',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'sindicato',
      'cara': 'CARA',
      'tipo': 'TEXTO',
      'campo': 'SINDICATO',
      'etiqueta': 'Sindicato',
      'x': 65,
      'y': 63.8,
      'ancho': 102,
      'alto': 8,
      'tamanoFuente': 8,
      'negrita': true,
      'alineacion': 'IZQUIERDA',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'central',
      'cara': 'CARA',
      'tipo': 'TEXTO',
      'campo': 'CENTRAL',
      'etiqueta': 'Central',
      'x': 65,
      'y': 52.2,
      'ancho': 102,
      'alto': 8,
      'tamanoFuente': 8,
      'negrita': true,
      'alineacion': 'IZQUIERDA',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'federacion',
      'cara': 'CARA',
      'tipo': 'TEXTO',
      'campo': 'FEDERACION',
      'etiqueta': 'Federación',
      'x': 65,
      'y': 40.2,
      'ancho': 102,
      'alto': 8,
      'tamanoFuente': 8,
      'negrita': true,
      'alineacion': 'IZQUIERDA',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'lotes',
      'cara': 'CARA',
      'tipo': 'TEXTO',
      'campo': 'LOTES',
      'etiqueta': 'N° de lote',
      'x': 65,
      'y': 28.1,
      'ancho': 102,
      'alto': 8,
      'tamanoFuente': 8,
      'negrita': true,
      'alineacion': 'IZQUIERDA',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'foto',
      'cara': 'CARA',
      'tipo': 'IMAGEN',
      'campo': 'FOTO',
      'etiqueta': 'Fotografía',
      'x': 172,
      'y': 18.1,
      'ancho': 57.6,
      'alto': 57,
      'tamanoFuente': 5.5,
      'negrita': false,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'sello-federacion',
      'cara': 'REVERSO',
      'tipo': 'IMAGEN',
      'campo': 'SELLO_FEDERACION',
      'etiqueta': 'Sello federación',
      'x': 15,
      'y': 35,
      'ancho': 56.88,
      'alto': 27,
      'tamanoFuente': 5.5,
      'negrita': false,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'firma-federacion',
      'cara': 'REVERSO',
      'tipo': 'IMAGEN',
      'campo': 'FIRMA_FEDERACION',
      'etiqueta': 'Firma ejecutivo',
      'x': 11,
      'y': 22,
      'ancho': 64.88,
      'alto': 18,
      'tamanoFuente': 5.5,
      'negrita': false,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'pie-federacion',
      'cara': 'REVERSO',
      'tipo': 'PIE_FIRMA',
      'campo': 'PIE_FEDERACION',
      'etiqueta': 'Pie federación',
      'x': 8,
      'y': 0,
      'ancho': 70.88,
      'alto': 21,
      'tamanoFuente': 4.2,
      'negrita': true,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'sello-central',
      'cara': 'REVERSO',
      'tipo': 'IMAGEN',
      'campo': 'SELLO_CENTRAL',
      'etiqueta': 'Sello central',
      'x': 93.88,
      'y': 35,
      'ancho': 56.88,
      'alto': 27,
      'tamanoFuente': 5.5,
      'negrita': false,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'firma-central',
      'cara': 'REVERSO',
      'tipo': 'IMAGEN',
      'campo': 'FIRMA_CENTRAL',
      'etiqueta': 'Firma secretario central',
      'x': 89.88,
      'y': 22,
      'ancho': 64.88,
      'alto': 18,
      'tamanoFuente': 5.5,
      'negrita': false,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'pie-central',
      'cara': 'REVERSO',
      'tipo': 'PIE_FIRMA',
      'campo': 'PIE_CENTRAL',
      'etiqueta': 'Pie central',
      'x': 86.88,
      'y': 0,
      'ancho': 70.88,
      'alto': 21,
      'tamanoFuente': 4.2,
      'negrita': true,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'sello-sindicato',
      'cara': 'REVERSO',
      'tipo': 'IMAGEN',
      'campo': 'SELLO_SINDICATO',
      'etiqueta': 'Sello sindicato',
      'x': 172.76,
      'y': 35,
      'ancho': 56.88,
      'alto': 27,
      'tamanoFuente': 5.5,
      'negrita': false,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'firma-sindicato',
      'cara': 'REVERSO',
      'tipo': 'IMAGEN',
      'campo': 'FIRMA_SINDICATO',
      'etiqueta': 'Firma secretario sindicato',
      'x': 168.76,
      'y': 22,
      'ancho': 64.88,
      'alto': 18,
      'tamanoFuente': 5.5,
      'negrita': false,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
    {
      'id': 'pie-sindicato',
      'cara': 'REVERSO',
      'tipo': 'PIE_FIRMA',
      'campo': 'PIE_SINDICATO',
      'etiqueta': 'Pie sindicato',
      'x': 165.76,
      'y': 0,
      'ancho': 70.88,
      'alto': 21,
      'tamanoFuente': 4.2,
      'negrita': true,
      'alineacion': 'CENTRO',
      'color': '#000000',
      'texto': '',
    },
  ],
};
