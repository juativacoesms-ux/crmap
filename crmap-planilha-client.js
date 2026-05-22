/**
 * Envio confiável para a planilha (Google Apps Script).
 * Usa sendBeacon + fetch com corpo urlencoded (Content-Length explícito).
 */
(function (global) {
  const GOOGLE_SCRIPT_URL =
    'https://script.google.com/macros/s/AKfycbxta2QnUbWxVA9DRuy5NdKwSjDv_RjfIht0Qgt5C6CRnUlzZ_QnVB7G1V2DxamDMMLW/exec';

  function dataHojeBr() {
    const d = new Date();
    const dd = String(d.getDate()).padStart(2, '0');
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const yyyy = d.getFullYear();
    return `${dd}/${mm}/${yyyy}`;
  }

  function enviarParaPlanilha(payload) {
    if (!GOOGLE_SCRIPT_URL || GOOGLE_SCRIPT_URL === 'COLOQUE_SUA_URL_AQUI') return;

    const body = new URLSearchParams();
    Object.keys(payload || {}).forEach((k) => {
      const v = payload[k];
      if (v !== undefined && v !== null) body.set(k, String(v));
    });
    if (!body.get('data')) body.set('data', dataHojeBr());

    const encoded = body.toString();

    if (navigator.sendBeacon) {
      try {
        navigator.sendBeacon(
          GOOGLE_SCRIPT_URL,
          new Blob([encoded], { type: 'application/x-www-form-urlencoded;charset=UTF-8' })
        );
      } catch (e) {
        console.warn('sendBeacon planilha:', e);
      }
    }

    fetch(GOOGLE_SCRIPT_URL, {
      method: 'POST',
      mode: 'no-cors',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
      body: encoded,
      keepalive: true
    }).catch((err) => console.error('Erro ao salvar na planilha', err));
  }

  global.CRMAP_PLANILHA = {
    GOOGLE_SCRIPT_URL,
    dataHojeBr,
    enviar: enviarParaPlanilha
  };
})(typeof window !== 'undefined' ? window : globalThis);
