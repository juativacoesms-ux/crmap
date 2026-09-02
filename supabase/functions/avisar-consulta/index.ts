// ---------------------------------------------------------------------------
// CRMAP — aviso de consulta por e-mail                          02/09/2026
//
// Ao marcar uma consulta sai um e-mail para a PROFISSIONAL e, quando a
// paciente tem e-mail cadastrado, outro para a PACIENTE. Os dois levam um
// anexo .ics — é ele que faz o celular oferecer "adicionar na agenda".
//
// OS DOIS E-MAILS SÃO DIFERENTES DE PROPÓSITO.
// A CRMAP atende mulheres em acompanhamento psicológico, e isso é dado
// sensível de saúde (LGPD). Caixa de e-mail costuma ser compartilhada. Então
// o aviso da paciente NÃO diz o tipo de atendimento, nem o número da sessão,
// nem valor, nem a palavra terapia: diz que ela tem um atendimento na CRMAP,
// o dia, a hora e um WhatsApp de contato. O da profissional é completo, é a
// ficha de trabalho dela. Decisão da Iara em 02/09/2026 — não "uniformizar"
// os dois textos depois sem falar com ela.
//
// Falhar aqui NÃO desfaz a consulta: ela já está salva. O aviso é um extra.
// ---------------------------------------------------------------------------
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const REMETENTE = 'CRMAP <naoresponda@envio.crmapoficial.org.br>'

function json(corpo: unknown, status = 200) {
  return new Response(JSON.stringify(corpo), {
    status, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

const DIAS = ['domingo', 'segunda-feira', 'terça-feira', 'quarta-feira',
              'quinta-feira', 'sexta-feira', 'sábado']

/** "2026-09-03" -> "quarta-feira, 03/09/2026". Construído com UTC de
 *  propósito: `new Date('2026-09-03')` já é meia-noite UTC, e usar getDay()
 *  local devolveria o dia anterior em qualquer fuso a oeste. */
function dataPorExtenso(iso: string) {
  const [a, m, d] = iso.split('-').map(Number)
  const dia = DIAS[new Date(Date.UTC(a, m - 1, d)).getUTCDay()]
  return `${dia}, ${String(d).padStart(2, '0')}/${String(m).padStart(2, '0')}/${a}`
}

function fmtTelefone(t: string) {
  const n = String(t || '').replace(/\D/g, '')
  if (n.length === 11) return `(${n.slice(0, 2)}) ${n.slice(2, 7)}-${n.slice(7)}`
  if (n.length === 10) return `(${n.slice(0, 2)}) ${n.slice(2, 6)}-${n.slice(6)}`
  return t || ''
}

/** A consulta é marcada em horário de Brasília (UTC−3). O .ics guarda em UTC
 *  com sufixo Z, que todo calendário converte de volta sozinho — mais seguro
 *  do que embutir um VTIMEZONE à mão. */
function paraUTC(dataISO: string, hora: string, somarMin = 0) {
  const [a, m, d] = dataISO.split('-').map(Number)
  const [hh, mm] = hora.split(':').map(Number)
  const t = Date.UTC(a, m - 1, d, hh + 3, mm + somarMin, 0)
  return new Date(t).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')
}

/** Vírgula, ponto-e-vírgula, barra e quebra de linha têm significado no
 *  formato .ics — sem escapar, um nome com vírgula corrompe o arquivo. */
function esc(s: string) {
  // Atenção: '\\;' com DUAS barras. Em JavaScript '\;' não é escape válido e
  // o navegador simplesmente descarta a barra — o ponto-e-vírgula sairia sem
  // escapar e um nome com ";" quebraria o arquivo de agenda.
  return String(s || '').replace(/\\/g, '\\\\').replace(/;/g, '\\;')
    .replace(/,/g, '\\,').replace(/\r?\n/g, '\\n')
}

function montarIcs(o: {
  id: number; data: string; hora: string; duracao: number;
  titulo: string; descricao: string;
}) {
  // O .ics exige quebra de linha CRLF.
  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//CRMAP//Agenda Saude//PT-BR',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:consulta-${o.id}@crmapoficial.org.br`,
    `DTSTAMP:${new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '')}`,
    `DTSTART:${paraUTC(o.data, o.hora)}`,
    `DTEND:${paraUTC(o.data, o.hora, o.duracao)}`,
    `SUMMARY:${esc(o.titulo)}`,
    `DESCRIPTION:${esc(o.descricao)}`,
    'BEGIN:VALARM',
    'TRIGGER:-PT2H',           // lembrete 2 horas antes
    'ACTION:DISPLAY',
    `DESCRIPTION:${esc(o.titulo)}`,
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n')
}

const ESTILO_BASE =
  "margin:0;background:#f4f6f4;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#1c2a20"

function moldura(interno: string) {
  return `<!doctype html><html lang="pt-BR"><body style="${ESTILO_BASE}">
  <div style="max-width:480px;margin:0 auto;padding:24px 16px">
    <div style="background:#fff;border-radius:12px;padding:28px 24px;border:1px solid #dfe6e0">
      ${interno}
    </div>
    <p style="margin:16px 0 0;text-align:center;font-size:12px;color:#7b8a80">
      CRMAP · crmapoficial.org.br<br>Este endereço não recebe respostas.
    </p>
  </div></body></html>`
}

function linhaQuando(dataExt: string, hora: string) {
  return `<table role="presentation" style="margin:0 0 20px;font-size:16px;line-height:1.9">
    <tr><td style="padding-right:10px">📅</td><td><strong>${dataExt}</strong></td></tr>
    <tr><td style="padding-right:10px">🕒</td><td><strong>${hora}</strong></td></tr>
  </table>`
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body = await req.json().catch(() => ({}))
    const url = Deno.env.get('SUPABASE_URL')!
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    const { data: d, error } = await admin.rpc('_aviso_consulta', {
      p_modo: String(body?.modo || ''),
      p_senha: String(body?.senha || ''),
      p_profissional_id: body?.profissional_id ?? null,
      p_consulta_id: Number(body?.consulta_id || 0),
      p_email_paciente: body?.email_paciente ? String(body.email_paciente) : null,
    })
    if (error) {
      console.error('erro ao buscar a consulta:', error)
      return json({ success: false, message: 'Não consegui montar o aviso.' }, 500)
    }
    if (!d?.success) return json(d, 403)

    const resendKey = Deno.env.get('RESEND_API_KEY')
    if (!resendKey) {
      console.error('RESEND_API_KEY não configurada')
      return json({ success: false, message: 'Envio de e-mail não configurado.' }, 500)
    }

    const dataExt = dataPorExtenso(d.data)
    const curto = d.data.slice(8, 10) + '/' + d.data.slice(5, 7)
    const telProf = fmtTelefone(d.profissional_telefone)
    const telPac = fmtTelefone(d.paciente_telefone)
    const enviados: string[] = []
    const falhas: string[] = []

    async function enviar(para: string, assunto: string, html: string, ics: string) {
      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + resendKey, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from: REMETENTE, to: [para], subject: assunto, html,
          attachments: [{
            filename: 'consulta-crmap.ics',
            content: btoa(unescape(encodeURIComponent(ics))),
          }],
        }),
      })
      if (r.ok) { enviados.push(para); return true }
      console.error('Resend recusou para', para, r.status, (await r.text()).slice(0, 250))
      falhas.push(para)
      return false
    }

    // ------------------------------------------------ e-mail da PROFISSIONAL
    if (d.profissional_email) {
      const paga = d.tipo_cobranca === 'paga'
      const ics = montarIcs({
        id: d.consulta_id, data: d.data, hora: d.hora, duracao: d.duracao_min,
        titulo: `CRMAP: ${d.paciente_nome}`,
        descricao: `${d.tipo_atendimento || 'Atendimento'} — ${d.numero_sessao}ª sessão`
          + `\nWhatsApp: ${telPac}` + (d.observacoes ? `\nObs.: ${d.observacoes}` : ''),
      })
      await enviar(d.profissional_email,
        `Consulta marcada: ${d.paciente_nome} — ${curto} às ${d.hora}`,
        moldura(`
          <p style="margin:0 0 4px;font-size:13px;color:#4a6b55;letter-spacing:.04em;text-transform:uppercase">CRMAP — sua agenda</p>
          <h1 style="margin:0 0 16px;font-size:20px;color:#0f301d">Consulta marcada</h1>
          <p style="margin:0 0 6px;font-size:17px"><strong>${d.paciente_nome}</strong></p>
          ${linhaQuando(dataExt, d.hora)}
          <table role="presentation" style="width:100%;font-size:15px;line-height:1.8;border-top:1px solid #eef2ef;padding-top:12px">
            <tr><td style="color:#5a6b5e;padding:2px 12px 2px 0">WhatsApp</td>
                <td><a href="https://wa.me/55${String(d.paciente_telefone || '').replace(/\D/g, '')}"
                       style="color:#1b7340;font-weight:600">${telPac}</a></td></tr>
            <tr><td style="color:#5a6b5e;padding:2px 12px 2px 0">Sessão</td>
                <td>${d.numero_sessao}ª — ${paga ? '<strong style="color:#991b1b">paga</strong>' : 'gratuita'}</td></tr>
            <tr><td style="color:#5a6b5e;padding:2px 12px 2px 0">Tipo</td><td>${d.tipo_atendimento || '—'}</td></tr>
            <tr><td style="color:#5a6b5e;padding:2px 12px 2px 0">Duração</td><td>${d.duracao_min} minutos</td></tr>
            ${d.observacoes ? `<tr><td style="color:#5a6b5e;padding:2px 12px 2px 0">Obs.</td><td>${d.observacoes}</td></tr>` : ''}
          </table>
          ${paga ? `<p style="margin:16px 0 0;background:#fff8e6;border-left:4px solid #b45309;padding:10px 12px;border-radius:6px;font-size:14px">
            Esta sessão é <strong>paga</strong>. Lembre do repasse de 10% no PIX da CRMAP ao marcar como realizada.</p>` : ''}
          <p style="margin:18px 0 0;font-size:14px;color:#41564a">
            O anexo <strong>consulta-crmap.ics</strong> adiciona isto na agenda do seu celular.</p>`),
        ics)
    }

    // --------------------------------------------------- e-mail da PACIENTE
    // Discreto de propósito — ver o comentário no topo do arquivo.
    if (d.paciente_email) {
      const ics = montarIcs({
        id: d.consulta_id, data: d.data, hora: d.hora, duracao: d.duracao_min,
        titulo: 'Atendimento na CRMAP',
        descricao: `Atendimento marcado na CRMAP.` + (telProf ? `\nContato: ${telProf}` : ''),
      })
      const primeiro = String(d.paciente_nome || '').trim().split(/\s+/)[0] || ''
      await enviar(d.paciente_email,
        `Seu atendimento na CRMAP — ${curto} às ${d.hora}`,
        moldura(`
          <p style="margin:0 0 4px;font-size:13px;color:#4a6b55;letter-spacing:.04em;text-transform:uppercase">CRMAP</p>
          <h1 style="margin:0 0 16px;font-size:20px;color:#0f301d">Seu atendimento está marcado</h1>
          <p style="margin:0 0 14px;font-size:15px;line-height:1.6">
            Olá${primeiro ? ', ' + primeiro : ''}. Este é o lembrete do seu atendimento:</p>
          ${linhaQuando(dataExt, d.hora)}
          ${telProf ? `<p style="margin:0 0 6px;font-size:15px;line-height:1.6;border-top:1px solid #eef2ef;padding-top:14px">
            Qualquer dúvida, ou se precisar remarcar, fale pelo WhatsApp
            <a href="https://wa.me/55${String(d.profissional_telefone || '').replace(/\D/g, '')}"
               style="color:#1b7340;font-weight:600">${telProf}</a>.</p>` : ''}
          <p style="margin:18px 0 0;font-size:14px;color:#41564a">
            O anexo <strong>consulta-crmap.ics</strong> guarda isto na agenda do seu celular.</p>`),
        ics)
    }

    return json({
      success: true, enviados, falhas,
      sem_email: {
        profissional: !d.profissional_email,
        paciente: !d.paciente_email,
      },
    })
  } catch (e) {
    console.error(e)
    return json({ success: false, message: 'Erro inesperado ao avisar.' }, 500)
  }
})
