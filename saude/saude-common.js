/* CRMAP — lógica compartilhada da agenda (profissional + controle) */
const SUPABASE_URL = 'https://qzjvzbvoxwhggvadaroq.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6anZ6YnZveHdoZ2d2YWRhcm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzOTA4NDEsImV4cCI6MjA4OTk2Njg0MX0.bTss42oILYSmAGP3vAP-9OQ1-qnKnZXbVxz2SDxWmW0';
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

const state = {
  modo: null,
  senha: '',
  profissionalId: null,
  profissionalNome: '',
  limiteGratis: 8,
  pixCrmap: '',
  pctRepasse: 10,
  resumoPaciente: null,
  consultaModalId: null
};

function loader(on) { document.getElementById('loader').classList.toggle('show', on); }

/* Datas SEMPRE no horário de Brasília (UTC−3), nunca em UTC nem no relógio do
   aparelho. Antes daqui era `new Date().toISOString()`, que é UTC: das 21h à
   meia-noite de Brasília o sistema já achava que era o dia seguinte. Efeito
   real para quem atende à noite: o campo Data nascia com AMANHÃ, e o filtro
   "De" começava amanhã — as consultas de hoje sumiam da lista.
   O Brasil não tem mais horário de verão desde 2019, então −3 vale o ano todo. */
function dataBrasilia(somarDias) {
  const d = new Date(Date.now() - 3 * 60 * 60 * 1000);
  d.setUTCDate(d.getUTCDate() + (somarDias || 0));
  return d.toISOString().slice(0, 10);
}
function hoje() { return dataBrasilia(0); }
function dias(n) { return dataBrasilia(n); }

/* Hora atual de Brasília, arredondada para a próxima meia hora. Serve de
   sugestão no campo Horário, que antes nascia vazio. */
function proximaMeiaHora() {
  const d = new Date(Date.now() - 3 * 60 * 60 * 1000);
  d.setUTCMinutes(d.getUTCMinutes() > 30 ? 60 : 30, 0, 0);
  return d.toISOString().slice(11, 16);
}
function esc(s) { return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;'); }

/** Nomes corrompidos no seed (F?tima) — exibição até o banco ser corrigido */
const PROFISSIONAIS_NOMES_FIX = {
  1: { nome: 'Fátima Maria de Jesus Chaves Soares', cargo: 'Dra. em Psicanálise — Coord. Saúde Mental' },
  2: { nome: 'Jórsia Chaves Horta Nascimento', cargo: 'Psicanalista — Vice / Diretora Saúde Mental' },
  3: { nome: 'Rosilaine Ribeiro de Moura Rocha', cargo: 'Psicóloga' },
  4: { nome: 'Márcia Rodrigues Daian', cargo: 'Psicóloga' },
  5: { nome: 'Érika Danúbia da Silva', cargo: 'Assistente de Saúde' }
};

function nomeCorrompido(s) {
  return /[\uFFFD?]/.test(String(s || '')) && /[a-zA-Z]\?[a-zA-Z]/.test(String(s || ''));
}

function normalizarProfissional(p) {
  if (!p) return p;
  const fix = PROFISSIONAIS_NOMES_FIX[p.id];
  if (fix && (nomeCorrompido(p.nome) || nomeCorrompido(p.cargo))) {
    return { ...p, nome: fix.nome, cargo: fix.cargo || p.cargo };
  }
  return p;
}

function nomeProfissionalExibicao(nome, id) {
  const fix = id && PROFISSIONAIS_NOMES_FIX[id];
  if (fix && nomeCorrompido(nome)) return fix.nome;
  return nome || '';
}

async function corrigirNomesProfissionaisNoBanco() {
  if (!isCoord() || !state.senha) return;
  try {
    const res = await fetch(SUPABASE_URL + '/functions/v1/corrigir-nomes-saude', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + SUPABASE_KEY },
      body: JSON.stringify({ senha: state.senha })
    });
    const data = await res.json().catch(() => ({}));
    if (data?.success && data.updated > 0) {
      await carregarProfissionaisSelects();
      if (typeof carregarListaProfissionaisAdmin === 'function') await carregarListaProfissionaisAdmin();
    }
  } catch (e) { /* função pode ainda não estar deployada */ }
}
function fmtData(iso) { if (!iso) return '—'; const [y, m, d] = iso.split('-'); return `${d}/${m}/${y}`; }
function fmtHora(t) { return String(t || '').slice(0, 5); }
function fmtMoeda(v) { return 'R$ ' + Number(v || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2 }); }

/* O banco guarda o telefone como um monte de números colados
   ("31988887777"). Na tela isso é difícil de conferir de bater o olho, e
   conferir o WhatsApp é justamente o que evita ficha duplicada. */
function fmtTelefone(t) {
  const n = String(t || '').replace(/\D/g, '');
  if (n.length === 11) return `(${n.slice(0, 2)}) ${n.slice(2, 7)}-${n.slice(7)}`;
  if (n.length === 10) return `(${n.slice(0, 2)}) ${n.slice(2, 6)}-${n.slice(6)}`;
  return t || '—';
}

/* A situação aparecia como o texto cru do banco, em minúsculas e sem cor:
   "agendada", "falta". Quem lê rápido não distingue. Aqui vira palavra do
   dia a dia, com cor. */
const SITUACOES = {
  agendada:  { texto: 'Marcada',   classe: 'sit-marcada'   },
  realizada: { texto: 'Aconteceu', classe: 'sit-aconteceu' },
  falta:     { texto: 'Não veio',  classe: 'sit-naoveio'   },
  cancelada: { texto: 'Cancelada', classe: 'sit-cancelada' }
};
function tagStatus(s) {
  const v = SITUACOES[String(s || '').toLowerCase()];
  return v ? `<span class="tag ${v.classe}">${v.texto}</span>` : esc(s);
}

function isCoord() { return state.modo === 'coordenacao'; }

function iniciarAppUI() {
  document.getElementById('loginOverlay').style.display = 'none';
  document.getElementById('app').classList.add('visible');
  // Estas duas telas compartilham este arquivo, mas não têm os mesmos campos.
  // Antes daqui o código assumia que todos existiam: em /saude/ o
  // 'txtPixInline' não existe, a linha quebrava e NADA depois dela rodava —
  // nem o nome da profissional no topo, nem o carregamento da agenda. A
  // terapeuta entrava e via "Minhas consultas" vazia para sempre.
  const preencher = (id, prop, valor) => {
    const el = document.getElementById(id);
    if (el) el[prop] = valor;
  };
  // O período começa 7 dias ATRÁS, não em hoje. Com o início em hoje, a
  // consulta de ontem sumia da lista — e era exatamente ela que faltava marcar
  // como "Aconteceu". Quem esquecesse de anotar no mesmo dia não tinha mais
  // como achar a consulta.
  preencher('filtroInicio', 'value', dias(-7));
  preencher('filtroFim', 'value', dias(30));
  preencher('dataConsulta', 'value', hoje());
  preencher('horaConsulta', 'value', proximaMeiaHora());
  preencher('txtLimiteGratis', 'textContent', state.limiteGratis);
  preencher('txtPixInline', 'textContent', state.pixCrmap || '(configure no controle)');
  if (isCoord()) {
    preencher('heroMeta', 'textContent', 'Todas as profissionais · repasses · secretaria');
    preencher('inputPixCrmap', 'value', state.pixCrmap || '');
    corrigirNomesProfissionaisNoBanco().then(() =>
      carregarProfissionaisSelects().then(() => { carregarAgenda(); carregarResumoAdmin(); carregarPacientes(); })
    );
  } else {
    preencher('heroMeta', 'textContent', state.profissionalNome + (state.profissionalCargo ? ' · ' + state.profissionalCargo : ''));
    carregarAgenda();
    carregarPacientes();
  }
}

async function carregarProfissionaisSelects() {
  const { data } = await sb.from('profissionais_saude').select('id,nome,cargo').eq('ativo', true).order('ordem');
  const lista = (data || []).map(normalizarProfissional);
  const opts = lista.map(p => `<option value="${p.id}">${esc(p.nome)}</option>`).join('');
  document.getElementById('profissionalId').innerHTML = opts;
  document.getElementById('filtroProf').innerHTML = '<option value="">Todos</option>' + opts;
  const chips = document.getElementById('profChips');
  if (chips) {
    chips.innerHTML = '<button type="button" class="active" data-id="" onclick="filtrarChip(this)">Todos</button>' +
      lista.map(p => `<button type="button" data-id="${p.id}" onclick="filtrarChip(this)">${esc(p.nome.split(' ')[0])}</button>`).join('');
  }
}

function filtrarChip(btn) {
  document.querySelectorAll('#profChips button').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  document.getElementById('filtroProf').value = btn.dataset.id || '';
  carregarAgenda();
}

async function carregarResumoAdmin() {
  const { data } = await sb.rpc('painel_resumo_saude', { p_senha: state.senha });
  if (!data?.success) return;
  state.pixCrmap = data.pix_crmap || state.pixCrmap;
  document.getElementById('txtPixInline').textContent = state.pixCrmap;
  document.getElementById('inputPixCrmap').value = state.pixCrmap;
  const pendentes = (data.repasses_pendentes || []).length;
  const acima = (data.pacientes_acima_limite || []).length;
  document.getElementById('statsRow').innerHTML = `
    <div class="stat-card"><span>Repasses pendentes</span><b>${pendentes}</b></div>
    <div class="stat-card warn"><span>Pacientes ≥ ${data.sessoes_gratuitas} sessões</span><b>${acima}</b></div>
    <div class="stat-card"><span>Repasse CRMAP</span><b>${data.percentual_repasse}%</b></div>`;
}

async function salvarPix() {
  const { data } = await sb.rpc('atualizar_config_saude', { p_senha: state.senha, p_pix_crmap: document.getElementById('inputPixCrmap').value });
  if (data?.success) {
    state.pixCrmap = data.pix_crmap;
    document.getElementById('txtPixInline').textContent = state.pixCrmap;
    alert('PIX atualizado.');
  }
}

async function buscarPaciente() {
  const tel = document.getElementById('telefonePaciente').value;
  const box = document.getElementById('pacientePreview');
  if (!tel || tel.replace(/\D/g, '').length < 10) { box.classList.remove('show'); return; }
  const params = isCoord()
    ? { p_telefone: tel, p_senha_coord: state.senha }
    : { p_telefone: tel, p_profissional_id: state.profissionalId, p_senha_prof: state.senha };
  const { data } = await sb.rpc('resumo_paciente_saude', params);
  if (!data?.success) {
    box.className = 'paciente-preview show pago';
    box.innerHTML = `<strong>${esc(data?.message)}</strong>`;
    return;
  }
  state.limiteGratis = data.limite_gratuitas || 8;
  document.getElementById('txtLimiteGratis').textContent = state.limiteGratis;
  if (data.nome && !document.getElementById('nomePaciente').value) document.getElementById('nomePaciente').value = data.nome;
  box.className = 'paciente-preview show' + (data.exige_pagamento ? ' pago' : '');
  box.innerHTML = `<strong>Sessão ${data.proxima_sessao}</strong> — ${esc(data.mensagem)}`;
  document.getElementById('wrapComunicou').style.display = data.exige_pagamento ? 'flex' : 'none';
}

// Guardadas para as confirmações poderem dizer o nome da paciente e o horário,
// em vez de perguntar só "Confirmar?".
let consultasCarregadas = [];

async function carregarAgenda() {
  loader(true);
  const tbody = document.getElementById('listaConsultas');
  const profFiltro = isCoord() ? (document.getElementById('filtroProf').value || null) : state.profissionalId;
  // Colunas da tabela, para o colspan da linha "nenhuma consulta". A coluna
  // "Sessão" saiu: mostrava "3ª" ao lado de uma Cobrança que já dizia
  // "Grátis · 3ª sessão". Era a mesma informação duas vezes, ocupando a
  // largura que faltava para o nome e para os botões.
  const cols = isCoord() ? 8 : 7;
  try {
    const { data, error } = await sb.rpc('listar_consultas_saude_v2', {
      p_modo: state.modo,
      p_senha: state.senha,
      p_profissional_id: state.profissionalId,
      p_data_inicio: document.getElementById('filtroInicio').value,
      p_data_fim: document.getElementById('filtroFim').value,
      p_filtro_prof_id: profFiltro ? Number(profFiltro) : null
    });
    if (error) throw error;
    consultasCarregadas = data || [];
    if (!data?.length) {
      // Dizer o período por extenso evita a dúvida mais comum: "eu agendei e
      // sumiu". Quase sempre a consulta existe, mas está fora das datas De/Até.
      const de = fmtData(document.getElementById('filtroInicio').value);
      const ate = fmtData(document.getElementById('filtroFim').value);
      tbody.innerHTML = `<tr><td colspan="${cols}" class="vazio">
        Nenhuma consulta entre <strong>${de}</strong> e <strong>${ate}</strong>.<br>
        Marcou para outra data? Mude o <strong>De</strong> e o <strong>Até</strong> ali em cima e toque em Atualizar.
      </td></tr>`;
      return;
    }
    // data-rotulo alimenta a etiqueta de cada linha quando isto vira cartão no
    // celular (ver o @media do saude-common.css). Sem ele o cartão mostraria os
    // valores soltos, sem dizer o que cada um é.
    tbody.innerHTML = data.map(c => {
      const cob = c.tipo_cobranca === 'paga'
        ? `<span class="tag tag-paga">Paga · ${c.numero_sessao}ª sessão</span>`
        : `<span class="tag tag-gratuita">Grátis · ${c.numero_sessao}ª sessão</span>`;
      const profCell = isCoord()
        ? `<td data-rotulo="Profissional">${esc(nomeProfissionalExibicao(c.profissional_nome, c.profissional_id).split(' ')[0])}</td>`
        : '';
      const acoes = c.status === 'agendada'
        ? `<button class="btn btn-sm" onclick="mudarStatus(${c.id},'realizada',${c.numero_sessao || 0},'${c.tipo_cobranca || 'gratuita'}')">Aconteceu</button>
           <button class="btn btn-sm btn-outline" onclick="mudarStatus(${c.id},'falta')">Não veio</button>
           <button class="btn btn-sm btn-danger" onclick="mudarStatus(${c.id},'cancelada')">Cancelar</button>`
        : `<button class="btn btn-sm btn-outline" onclick="mudarStatus(${c.id},'agendada')">Reabrir</button>`;
      const tel = String(c.telefone || '').replace(/\D/g, '');
      return `<tr>
        <td data-rotulo="Data">${fmtData(c.data_consulta)}</td>
        <td data-rotulo="Hora">${fmtHora(c.hora_inicio)}</td>
        <td data-rotulo="Paciente"><strong>${esc(c.nome_paciente)}</strong></td>
        <td data-rotulo="WhatsApp"><a class="link-whats" href="https://wa.me/55${tel}" target="_blank" rel="noopener">${fmtTelefone(c.telefone)}</a></td>
        ${profCell}
        <td data-rotulo="Cobrança">${cob}</td>
        <td data-rotulo="Situação">${tagStatus(c.status)}</td>
        <td class="actions" data-rotulo="O que fazer">${acoes}</td></tr>`;
    }).join('');
  } catch (e) {
    tbody.innerHTML = `<tr><td colspan="${cols}">Erro ao carregar.</td></tr>`;
    console.error(e);
  } finally { loader(false); }
}

async function agendarConsulta(e) {
  e.preventDefault();
  const profId = isCoord() ? Number(document.getElementById('profissionalId').value) : state.profissionalId;
  loader(true);
  try {
    const { data, error } = await sb.rpc('criar_consulta_saude_v2', {
      p_modo: state.modo,
      p_profissional_id: profId,
      p_senha: state.senha,
      p_nome_paciente: document.getElementById('nomePaciente').value,
      p_telefone: document.getElementById('telefonePaciente').value,
      p_data_consulta: document.getElementById('dataConsulta').value,
      p_hora_inicio: document.getElementById('horaConsulta').value,
      p_duracao_min: Number(document.getElementById('duracaoConsulta').value),
      p_tipo_atendimento: document.getElementById('tipoAtendimento').value,
      p_observacoes: document.getElementById('obsConsulta').value,
      p_criado_por: state.profissionalNome || 'Coordenação',
      p_comunicou_pagamento: document.getElementById('comunicouPagamento').checked
    });
    if (error) throw error;
    if (!data?.success) { alert(data?.message || 'Erro'); return; }

    // Se a consulta foi marcada para fora do período que está na tela, ela não
    // apareceria na lista e pareceria que não salvou. Aqui o período se abre
    // sozinho para incluir o dia marcado — a queixa "agendei e sumiu".
    const dia = document.getElementById('dataConsulta').value;
    const ini = document.getElementById('filtroInicio');
    const fim = document.getElementById('filtroFim');
    let ampliou = false;
    if (dia && ini.value && dia < ini.value) { ini.value = dia; ampliou = true; }
    if (dia && fim.value && dia > fim.value) { fim.value = dia; ampliou = true; }

    const nome = document.getElementById('nomePaciente').value.trim();
    alert(
      `Pronto! Consulta marcada para ${fmtData(dia)} às ${fmtHora(document.getElementById('horaConsulta').value)}` +
      (nome ? ` com ${nome}` : '') + '.\n\n' +
      (data.exige_pagamento
        ? `Esta é a ${data.numero_sessao}ª sessão e é PAGA.\nRepasse de 10% no PIX da CRMAP: ${data.pix_crmap}`
        : `Esta é a ${data.numero_sessao}ª sessão e é gratuita.`) +
      (ampliou ? '\n\nAjustei as datas da lista para você ver a consulta nova.' : '')
    );

    document.getElementById('nomePaciente').value = '';
    document.getElementById('telefonePaciente').value = '';
    document.getElementById('obsConsulta').value = '';
    document.getElementById('pacientePreview').classList.remove('show');
    document.getElementById('wrapComunicou').style.display = 'none';
    document.getElementById('comunicouPagamento').checked = false;
    await carregarAgenda();
    if (isCoord()) await carregarResumoAdmin();
  } catch (err) { alert(err.message); } finally { loader(false); }
}

/* Antes daqui a pergunta era só "Confirmar?" — sem dizer o que ia acontecer,
   nem com quem. Marcar "Não veio" na paciente errada era fácil e silencioso.
   Agora a pergunta diz a ação, o nome da paciente, o dia e a hora. */
function textoConfirmacao(id, status) {
  const c = consultasCarregadas.find(x => Number(x.id) === Number(id));
  const quem = c ? `${c.nome_paciente} — ${fmtData(c.data_consulta)} às ${fmtHora(c.hora_inicio)}` : 'esta consulta';
  return {
    falta:     `Marcar que ${quem} NÃO VEIO?\n\nDá para desfazer depois pelo botão Reabrir.`,
    cancelada: `CANCELAR a consulta de ${quem}?\n\nDá para desfazer depois pelo botão Reabrir.`,
    realizada: `Marcar que a consulta de ${quem} ACONTECEU?`,
    agendada:  `Voltar a consulta de ${quem} para MARCADA?`
  }[status] || 'Confirmar?';
}

function mudarStatus(id, status, numeroSessao, tipoCobranca) {
  if (status === 'realizada' && tipoCobranca === 'paga' && numeroSessao > state.limiteGratis) {
    state.consultaModalId = id;
    document.getElementById('modalPagoTxt').textContent = `Sessão ${numeroSessao} — informe valor e repasse 10%.`;
    document.getElementById('modalPix').textContent = 'PIX CRMAP: ' + (state.pixCrmap || '—');
    document.getElementById('valorConsulta').value = '';
    document.getElementById('repasseConfirmado').checked = false;
    document.getElementById('valorConsulta').oninput = function () {
      document.getElementById('valorRepassePreview').textContent = fmtMoeda((Number(this.value) || 0) * state.pctRepasse / 100);
    };
    document.getElementById('modalPago').classList.add('show');
    return;
  }
  if (!confirm(textoConfirmacao(id, status))) return;
  executarStatus(id, status);
}

async function confirmarRealizadaPaga() {
  const valor = Number(document.getElementById('valorConsulta').value);
  if (!valor) { alert('Informe o valor.'); return; }
  await executarStatus(state.consultaModalId, 'realizada', valor, document.getElementById('repasseConfirmado').checked);
  document.getElementById('modalPago').classList.remove('show');
}

async function executarStatus(id, status, valor, repasseOk) {
  loader(true);
  try {
    const { data, error } = await sb.rpc('atualizar_consulta_saude_v2', {
      p_modo: state.modo, p_senha: state.senha, p_profissional_id: state.profissionalId,
      p_id: id, p_status: status, p_valor_consulta: valor ?? null, p_repasse_confirmado: repasseOk ?? null
    });
    if (error) throw error;
    if (!data?.success) { alert(data?.message); return; }
    await carregarAgenda();
    if (isCoord()) await carregarResumoAdmin();
  } finally { loader(false); }
}

function sairAgenda() {
  state.modo = null;
  state.senha = '';
  sessionStorage.removeItem('crmap_saude_sessao');
  document.getElementById('app').classList.remove('visible');
  document.getElementById('loginOverlay').style.display = 'flex';
}

function salvarSessao() {
  sessionStorage.setItem('crmap_saude_sessao', JSON.stringify({
    page: window.SAUDE_PAGE,
    modo: state.modo, senha: state.senha, profissionalId: state.profissionalId,
    profissionalNome: state.profissionalNome, profissionalCargo: state.profissionalCargo,
    limiteGratis: state.limiteGratis, pixCrmap: state.pixCrmap, pctRepasse: state.pctRepasse
  }));
}

function restaurarSessao() {
  try {
    const raw = sessionStorage.getItem('crmap_saude_sessao');
    if (!raw) return false;
    const s = JSON.parse(raw);
    if (s.page !== window.SAUDE_PAGE || s.modo !== state.modo) return false;
    Object.assign(state, s);
    return true;
  } catch (e) { return false; }
}


// ---- Minhas pacientes ------------------------------------------------------
// A paciente nasce quando a terapeuta marca a primeira consulta. Esta lista
// existe para ela ver quem já atendeu e corrigir nome ou WhatsApp digitado
// errado — um dígito trocado cria uma ficha nova e a contagem das sessões
// gratuitas recomeça do zero.
let pacientesCarregadas = [];

async function carregarPacientes() {
  const alvo = document.getElementById('listaPacientes');
  if (!alvo) return;
  try {
    const { data, error } = await sb.rpc('listar_pacientes_da_profissional', {
      p_profissional_id: isCoord() ? null : state.profissionalId,
      p_senha: state.senha,
      p_modo: state.modo
    });
    if (error) throw error;
    if (!data?.success) { alvo.textContent = data?.message || 'Não consegui carregar.'; return; }

    pacientesCarregadas = data.pacientes || [];
    if (!pacientesCarregadas.length) {
      alvo.textContent = 'Nenhuma paciente ainda. A ficha nasce quando você marca a primeira consulta.';
      return;
    }
    alvo.innerHTML =
      '<table><thead><tr><th>Nome</th><th>WhatsApp</th><th>Consultas</th><th>Última</th><th></th></tr></thead><tbody>' +
      pacientesCarregadas.map(p => `<tr>
        <td data-rotulo="Nome">${esc(p.nome)}</td>
        <td data-rotulo="WhatsApp">${esc(fmtTelefone(p.telefone))}</td>
        <td data-rotulo="Consultas">${Number(p.consultas)}</td>
        <td data-rotulo="Última">${p.ultima_consulta ? dataBr(p.ultima_consulta) : '—'}</td>
        <td class="acoes"><button class="btn btn-sm btn-outline" onclick="abrirPaciente(${Number(p.id)})">Corrigir</button></td>
      </tr>`).join('') + '</tbody></table>';
  } catch (e) {
    alvo.textContent = 'Não consegui falar com o sistema. Tente de novo.';
  }
}

function dataBr(iso) {
  if (!iso) return '—';
  const p = String(iso).split('-');
  return p.length === 3 ? `${p[2]}/${p[1]}/${p[0]}` : iso;
}

function abrirPaciente(id) {
  const p = pacientesCarregadas.find(x => Number(x.id) === Number(id));
  if (!p) return;
  document.getElementById('pacId').value = p.id;
  document.getElementById('pacNome').value = p.nome || '';
  document.getElementById('pacTelefone').value = p.telefone || '';
  document.getElementById('avisoPaciente').textContent = '';
  document.getElementById('modalPaciente').classList.add('show');
}

async function salvarPaciente() {
  const aviso = document.getElementById('avisoPaciente');
  const botao = document.getElementById('btnSalvarPaciente');
  aviso.style.color = '#b3261e';
  aviso.textContent = '';
  if (botao.disabled) return;
  const original = botao.textContent;
  botao.disabled = true;
  botao.textContent = 'Salvando…';
  try {
    const { data, error } = await sb.rpc('corrigir_paciente_saude', {
      p_paciente_id: Number(document.getElementById('pacId').value),
      p_profissional_id: isCoord() ? null : state.profissionalId,
      p_senha: state.senha,
      p_nome: document.getElementById('pacNome').value,
      p_telefone: document.getElementById('pacTelefone').value,
      p_modo: state.modo
    });
    if (error) throw error;
    if (!data?.success) { aviso.textContent = data?.message || 'Não deu certo.'; return; }
    document.getElementById('modalPaciente').classList.remove('show');
    await carregarPacientes();
  } catch (e) {
    aviso.textContent = 'Não consegui falar com o sistema. Tente de novo.';
  } finally {
    botao.disabled = false;
    botao.textContent = original;
  }
}
