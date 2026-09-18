const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

test('motor bajo demanda: carga compartida, reutilización y reintento', async () => {
  let intentos = 0;
  let motores = 0;
  const contexto = {
    URL, window: {},
    document: {
      baseURI: 'http://servidor/',
      createElement: () => ({remove() {}}),
      head: {appendChild(script) {
        intentos++;
        queueMicrotask(() => {
          if (intentos === 1) return script.onerror();
          contexto.SelfieSegmentation = class {
            constructor() { motores++; }
            setOptions() {}
          };
          script.onload();
        });
      }},
    },
  };
  const codigo = fs.readFileSync('web/fondo_ia.js', 'utf8')
    .replace('window.FondoIA = {procesar, procesarDocumento};',
      'window.FondoIA = {obtenerSegmentador};');
  vm.runInNewContext(codigo, contexto);
  assert.equal(intentos, 0);
  const cargar = contexto.window.FondoIA.obtenerSegmentador;
  await assert.rejects(cargar());
  const [a, b] = await Promise.all([cargar(), cargar()]);
  assert.equal(a, b);
  assert.equal(await cargar(), a);
  assert.equal(intentos, 2);
  assert.equal(motores, 1);
});
