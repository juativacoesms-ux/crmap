/**
 * Textos que a diretora edita pelo painel (Painel → Textos do Site).
 *
 * COMO FUNCIONA, e por que assim:
 *   O texto original continua escrito dentro de cada página HTML e é o que
 *   aparece. Este arquivo só troca o que a diretora tiver alterado no painel,
 *   e a troca acontece DEPOIS que a página já apareceu.
 *
 *   Se este arquivo não carregar (internet ruim, celular antigo, bloqueador),
 *   a página fica completa com o texto original em vez de ficar vazia. É a
 *   mesma regra da página de doação, decidida em 31/07/2026.
 *
 * PARA ACRESCENTAR UM PEDAÇO EDITÁVEL:
 *   1. no HTML, marque o elemento com data-site="alguma.chave"
 *   2. no banco, insira a linha em conteudo_site com o texto atual, o rótulo
 *      que a diretora vai ler e o grupo
 *   Faltando um dos dois, o pedaço não aparece no painel ou não muda no site.
 *
 * IMPORTANTE: só marque elementos cujo conteúdo é TEXTO PURO. Um parágrafo com
 * link ou negrito dentro perderia o link, porque a troca usa textContent.
 */
(function () {
  var SUPABASE_URL = 'https://qzjvzbvoxwhggvadaroq.supabase.co';
  var SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6anZ6YnZveHdoZ2d2YWRhcm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzOTA4NDEsImV4cCI6MjA4OTk2Njg0MX0.bTss42oILYSmAGP3vAP-9OQ1-qnKnZXbVxz2SDxWmW0';

  var alvos = document.querySelectorAll('[data-site]');
  if (!alvos.length) return;

  fetch(SUPABASE_URL + '/rest/v1/rpc/conteudo_site_publico', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_KEY,
      Authorization: 'Bearer ' + SUPABASE_KEY
    },
    body: '{}'
  })
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (textos) {
      if (!textos || typeof textos !== 'object') return;
      Array.prototype.forEach.call(alvos, function (el) {
        var novo = textos[el.getAttribute('data-site')];
        // textContent, nunca innerHTML: o que vem do painel entra como TEXTO.
        // Assim nem um erro de digitação com < > quebra a página.
        if (typeof novo === 'string' && novo.trim() && novo !== el.textContent) {
          el.textContent = novo;
        }
      });
    })
    .catch(function () {
      // De propósito sem alarde: a página já está correta com o texto original.
    });
})();
