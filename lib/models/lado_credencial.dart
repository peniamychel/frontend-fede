/// Lado físico de una credencial para impresoras de una sola cara.
enum LadoCredencial {
  anverso('ANVERSO', 'anverso'),
  reverso('REVERSO', 'reverso');

  const LadoCredencial(this.parametroApi, this.etiqueta);

  final String parametroApi;
  final String etiqueta;
}
