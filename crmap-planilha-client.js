/**
 * Envio confiável para a planilha (Google Apps Script).
 * Usa sendBeacon + fetch com corpo urlencoded (Content-Length explícito).
 */
(function (global) {
  const GOOGLE_SCRIPT_URL =
    'https://script.google.com/macros/s/AKfycbzRPMVu--BYlX51qU0Mj6P1SBTikDE7RKJhym0c_RMCJ-CoRM_4T4mNHjRudcvx6EK1/exec';
  const SUPABASE_URL = 'https://qzjvzbvoxwhggvadaroq.supabase.co';
  const SUPABASE_ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6anZ6YnZveHdoZ2d2YWRhcm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzOTA4NDEsImV4cCI6MjA4OTk2Njg0MX0.bTss42oILYSmAGP3vAP-9OQ1-qnKnZXbVxz2SDxWmW0';

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

    // Backup server-side (CORS ok, confirma gravação quando o GAS estiver publicado)
    fetch(SUPABASE_URL + '/functions/v1/registrar-planilha', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer ' + SUPABASE_ANON_KEY
      },
      body: JSON.stringify(payload || {}),
      keepalive: true
    }).catch((err) => console.warn('Backup planilha (edge):', err));
  }

  global.CRMAP_PLANILHA = {
    GOOGLE_SCRIPT_URL,
    dataHojeBr,
    enviar: enviarParaPlanilha
  };
})(typeof window !== 'undefined' ? window : globalThis);
