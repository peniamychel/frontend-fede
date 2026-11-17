enum OrdenInformes {
  apellidos('APELLIDOS', 'Apellidos'),
  numeroLote('NUMERO_LOTE', 'Número de lote');

  const OrdenInformes(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;
}
