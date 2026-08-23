/*
 * Eliminación de fondo para fotografías de credencial.
 *
 * Se ejecuta enteramente en el navegador: la foto no se envía a ningún
 * servicio externo para detectar a la persona. MediaPipe se carga desde
 * web/mediapipe, de modo que funciona también sin conexión a Internet una vez
 * que la aplicación está servida localmente.
 */
(function () {
  'use strict';

  const LADO_MAXIMO = 600;
  const PESO_MAXIMO = 300 * 1024;
  const TAMANOS = [600, 512, 448, 384, 320, 256];

  let segmentador;
  let cargando;
  let cola = Promise.resolve();

  function rutaMediaPipe(archivo) {
    return new URL('mediapipe/' + archivo, document.baseURI).toString();
  }

  async function obtenerSegmentador() {
    if (segmentador) return segmentador;
    if (cargando) return cargando;
    if (typeof SelfieSegmentation === 'undefined') {
      throw new Error('No se pudo cargar el motor local de eliminación de fondo.');
    }

    cargando = Promise.resolve().then(() => {
      const nuevo = new SelfieSegmentation({
        locateFile: rutaMediaPipe,
      });
      // El modelo general conserva mejor el contorno de cabeza y hombros.
      nuevo.setOptions({modelSelection: 0});
      segmentador = nuevo;
      return nuevo;
    });
    return cargando;
  }

  function cargarImagen(origen) {
    return new Promise((resolve, reject) => {
      const imagen = new Image();
      imagen.onload = () => resolve(imagen);
      imagen.onerror = () => reject(new Error('No se pudo abrir la fotografía.'));
      imagen.src = origen;
    });
  }

  function lienzo(lado, alto = lado) {
    const canvas = document.createElement('canvas');
    canvas.width = lado;
    canvas.height = alto;
    return canvas;
  }

  function validarRecorte(recorte, imagen) {
    const x = Number(recorte.x);
    const y = Number(recorte.y);
    const ancho = Number(recorte.ancho);
    const alto = Number(recorte.alto);
    if (![x, y, ancho, alto].every(Number.isFinite) || ancho <= 0 || alto <= 0 ||
        x < 0 || y < 0 || x + ancho > imagen.naturalWidth ||
        y + alto > imagen.naturalHeight) {
      throw new Error('El recorte de la fotografía no es válido.');
    }

    // La foto de la credencial siempre es cuadrada. Si por una versión vieja
    // del cliente llegara un rectángulo, conserva el mayor cuadrado centrado.
    const lado = Math.min(ancho, alto);
    return {
      x: x + (ancho - lado) / 2,
      y: y + (alto - lado) / 2,
      lado,
    };
  }

  function dibujarRecorte(imagen, recorte) {
    const origen = lienzo(LADO_MAXIMO);
    const contexto = origen.getContext('2d', {alpha: true});
    contexto.imageSmoothingEnabled = true;
    contexto.imageSmoothingQuality = 'high';
    contexto.drawImage(
      imagen,
      recorte.x,
      recorte.y,
      recorte.lado,
      recorte.lado,
      0,
      0,
      LADO_MAXIMO,
      LADO_MAXIMO,
    );
    return origen;
  }

  function segmentar(origen) {
    return obtenerSegmentador().then((motor) => new Promise((resolve, reject) => {
      motor.onResults((resultado) => resolve(resultado));
      Promise.resolve(motor.send({image: origen})).catch(reject);
    }));
  }

  function componer(origen, mascara, lado, quitarFondo) {
    const salida = lienzo(lado);
    const contexto = salida.getContext('2d', {alpha: true});
    contexto.imageSmoothingEnabled = true;
    contexto.imageSmoothingQuality = 'high';

    if (!quitarFondo) {
      contexto.drawImage(origen, 0, 0, lado, lado);
      return salida;
    }

    // La máscara de MediaPipe usa la opacidad para representar la confianza de
    // «persona». Al usarla como source-in, el fondo queda completamente alfa.
    contexto.drawImage(mascara, 0, 0, lado, lado);
    contexto.globalCompositeOperation = 'source-in';
    contexto.drawImage(origen, 0, 0, lado, lado);
    contexto.globalCompositeOperation = 'source-over';
    return salida;
  }

  function pesoDataUrl(dataUrl) {
    const coma = dataUrl.indexOf(',');
    const base64 = coma < 0 ? dataUrl : dataUrl.substring(coma + 1);
    return Math.floor(base64.length * 3 / 4);
  }

  async function procesar(origenDataUrl, recorteJson, quitarFondo) {
    // MediaPipe mantiene un callback por instancia. Serializar evita que dos
    // diálogos abiertos a la vez mezclen sus máscaras.
    const trabajo = async () => {
      const imagen = await cargarImagen(origenDataUrl);
      const recorte = validarRecorte(JSON.parse(recorteJson), imagen);
      const origen = dibujarRecorte(imagen, recorte);
      const resultado = quitarFondo ? await segmentar(origen) : null;

      let ultimo;
      for (const lado of TAMANOS) {
        const salida = componer(
          origen,
          resultado && resultado.segmentationMask,
          lado,
          quitarFondo,
        );
        const dataUrl = salida.toDataURL('image/png');
        ultimo = dataUrl;
        if (pesoDataUrl(dataUrl) <= PESO_MAXIMO) return dataUrl;
      }
      // 256 px es suficiente para una credencial pequeña. Si una imagen muy
      // ruidosa todavía supera el límite, se informa en vez de guardar más de
      // 300 KB sin que la persona que carga se entere.
      if (pesoDataUrl(ultimo) > PESO_MAXIMO) {
        throw new Error('No se pudo reducir la fotografía a 300 KB. Probá con una imagen más nítida y uniforme.');
      }
      return ultimo;
    };

    const siguiente = cola.then(trabajo, trabajo);
    cola = siguiente.catch(() => undefined);
    return siguiente;
  }

  function validarRecorteLibre(recorte, imagen) {
    const x = Number(recorte.x);
    const y = Number(recorte.y);
    const ancho = Number(recorte.ancho);
    const alto = Number(recorte.alto);
    if (![x, y, ancho, alto].every(Number.isFinite) || ancho <= 0 || alto <= 0 ||
        x < 0 || y < 0 || x + ancho > imagen.naturalWidth ||
        y + alto > imagen.naturalHeight) {
      throw new Error('El recorte de la imagen no es válido.');
    }
    return {x, y, ancho, alto};
  }

  function mediana(valores) {
    valores.sort((a, b) => a - b);
    return valores[Math.floor(valores.length / 2)];
  }

  // Toma muestras de las cuatro esquinas. En una firma o sello fotografiado,
  // esas zonas suelen ser papel y permiten estimar su color aun si no es
  // blanco puro.
  function colorDelFondo(datos, ancho, alto) {
    const radio = Math.max(1, Math.min(
      12,
      ancho,
      alto,
      Math.floor(Math.min(ancho, alto) / 12) || 1,
    ));
    const rojos = [];
    const verdes = [];
    const azules = [];
    const esquinas = [
      [0, 0], [Math.max(0, ancho - radio), 0],
      [0, Math.max(0, alto - radio)],
      [Math.max(0, ancho - radio), Math.max(0, alto - radio)],
    ];
    for (const [inicioX, inicioY] of esquinas) {
      for (let y = inicioY; y < inicioY + radio; y++) {
        for (let x = inicioX; x < inicioX + radio; x++) {
          const i = (y * ancho + x) * 4;
          if (datos[i + 3] === 0) continue;
          rojos.push(datos[i]);
          verdes.push(datos[i + 1]);
          azules.push(datos[i + 2]);
        }
      }
    }
    if (rojos.length === 0) return [255, 255, 255];
    return [mediana(rojos), mediana(verdes), mediana(azules)];
  }

  function quitarFondoUniforme(canvas, intensidad) {
    const contexto = canvas.getContext('2d', {alpha: true, willReadFrequently: true});
    const imagen = contexto.getImageData(0, 0, canvas.width, canvas.height);
    const datos = imagen.data;
    const fondo = colorDelFondo(datos, canvas.width, canvas.height);
    // La franja suave conserva bordes antialiasados y trazos de tinta tenue.
    const tolerancia = 45 + Math.max(0, Math.min(1, intensidad)) * 105;
    const inicio = tolerancia * 0.38;

    for (let i = 0; i < datos.length; i += 4) {
      const original = datos[i + 3];
      if (original === 0) continue;
      const dr = datos[i] - fondo[0];
      const dg = datos[i + 1] - fondo[1];
      const db = datos[i + 2] - fondo[2];
      const distancia = Math.sqrt(dr * dr + dg * dg + db * db);
      const opacidad = distancia <= inicio
        ? 0
        : distancia >= tolerancia
          ? 1
          : (distancia - inicio) / (tolerancia - inicio);
      datos[i + 3] = Math.round(original * opacidad);
    }
    contexto.putImageData(imagen, 0, 0);
  }

  async function procesarDocumento(origenDataUrl, parametrosJson) {
    const parametros = JSON.parse(parametrosJson);
    const imagen = await cargarImagen(origenDataUrl);
    const recorte = validarRecorteLibre(parametros.recorte, imagen);
    const ladoMaximo = Math.max(128, Number(parametros.ladoMaximo) || 600);
    const pesoMaximo = Math.max(20 * 1024, Number(parametros.pesoMaximo) || 500 * 1024);
    const escala = Math.min(1, ladoMaximo / Math.max(recorte.ancho, recorte.alto));
    let ancho = Math.max(1, Math.round(recorte.ancho * escala));
    let alto = Math.max(1, Math.round(recorte.alto * escala));

    let ultimo;
    while (true) {
      const salida = lienzo(ancho, alto);
      const contexto = salida.getContext('2d', {alpha: true});
      contexto.imageSmoothingEnabled = true;
      contexto.imageSmoothingQuality = 'high';
      contexto.drawImage(
        imagen,
        recorte.x, recorte.y, recorte.ancho, recorte.alto,
        0, 0, ancho, alto,
      );
      if (parametros.quitarFondo) {
        const intensidad = Number(parametros.intensidad);
        quitarFondoUniforme(salida, Number.isFinite(intensidad) ? intensidad : 0.55);
      }
      ultimo = salida.toDataURL('image/png');
      if (pesoDataUrl(ultimo) <= pesoMaximo || Math.max(ancho, alto) <= 128) {
        return ultimo;
      }
      ancho = Math.max(1, Math.round(ancho * 0.82));
      alto = Math.max(1, Math.round(alto * 0.82));
    }
  }

  window.FondoIA = {procesar, procesarDocumento};
})();
