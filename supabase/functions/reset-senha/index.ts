// ---------------------------------------------------------------------------
// CRMAP — "Esqueci minha senha" das profissionais de saúde     02/09/2026
//
// Esta função é a ÚNICA que pode chamar `_reset_gerar_codigo` e
// `_reset_confirmar`. Aquelas funções não têm permissão para `anon` de
// propósito: se tivessem, qualquer pessoa pediria o código de qualquer outra
// pelo navegador e leria o código na própria resposta.
//
// Duas ações:
//   { acao: 'solicitar',  email }
//   { acao: 'confirmar',  email, codigo, senha_nova }
//
// A resposta de 'solicitar' é SEMPRE a mesma, exista o e-mail ou não. Isso é
// de propósito: senão dava para descobrir quem está cadastrada testando
// e-mails um a um. A única exceção é o freio de 3 pedidos por hora, que
// precisa avisar para a pessoa não ficar clicando à toa.
// ---------------------------------------------------------------------------
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// SUBDOMÍNIO de propósito, não o domínio raiz. O crmapoficial.org.br já usa
// o Email Routing da Cloudflare (MX route1/2/3.mx.cloudflare.net) e tem
// DMARC com p=reject. Colocar o Resend no domínio raiz exigiria trocar o SPF
// e o MX de lá — quebrando o e-mail que a CRMAP já usa hoje. Com
// `envio.crmapoficial.org.br` os dois convivem: o Routing continua no raiz,
// o Resend fica só no subdomínio, e o DMARC do raiz vale para os dois.
const REMETENTE = 'CRMAP <naoresponda@envio.crmapoficial.org.br>'
const RESPOSTA_NEUTRA =
  'Se esse e-mail estiver cadastrado, o código chega em instantes. ' +
  'Confira também a caixa de spam.'

function json(corpo: unknown, status = 200) {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function corpoDoEmail(nome: string, codigo: string, minutos: number) {
  const primeiro = (nome || '').trim().split(/\s+/)[0] || ''
  return `<!doctype html>
<html lang="pt-BR"><body style="margin:0;background:#f4f6f4;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif;color:#1c2a20">
  <div style="max-width:480px;margin:0 auto;padding:24px 16px">
    <div style="background:#fff;border-radius:12px;padding:28px 24px;border:1px solid #dfe6e0">
      <p style="margin:0 0 4px;font-size:13px;color:#4a6b55;letter-spacing:.04em;text-transform:uppercase">CRMAP — Área da Saúde</p>
      <h1 style="margin:0 0 16px;font-size:20px;color:#0f301d">Seu código para criar uma senha nova</h1>
      <p style="margin:0 0 20px;font-size:15px;line-height:1.6">
        Olá${primeiro ? ', ' + primeiro : ''}. Você pediu para redefinir a senha da sua agenda.
        Digite o código abaixo na tela do site:
      </p>
      <p style="margin:0 0 20px;text-align:center">
        <span style="display:inline-block;background:#eef5ef;border:1px solid #cfe0d4;border-radius:10px;padding:14px 22px;font-size:30px;letter-spacing:8px;font-weight:700;color:#0f301d">${codigo}</span>
      </p>
      <p style="margin:0 0 8px;font-size:14px;line-height:1.6;color:#41564a">
        O código vale por <strong>${minutos} minutos</strong> e só pode ser usado uma vez.
      </p>
      <p style="margin:0;font-size:14px;line-height:1.6;color:#41564a">
        <strong>Não foi você que pediu?</strong> Pode ignorar este e-mail — sua senha
        continua a mesma. Ninguém troca sua senha sem este código.
      </p>
    </div>
    <p style="margin:16px 0 0;text-align:center;font-size:12px;color:#7b8a80">
      Casa de Recuperação e Reintegração — CRMAP · crmapoficial.org.br<br>
      Este é um endereço que não recebe respostas.
    </p>
  </div>
</body></html>`
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const body = await req.json().catch(() => ({}))
    const acao = String(body?.acao || '').trim()
    const email = String(body?.email || '').trim()

    const url = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(url, serviceKey)

    // ----------------------------------------------------------- confirmar
    if (acao === 'confirmar') {
      const { data, error } = await admin.rpc('_reset_confirmar', {
        p_email: email,
        p_codigo: String(body?.codigo || ''),
        p_senha_nova: String(body?.senha_nova || ''),
      })
      if (error) {
        console.error('erro ao confirmar:', error)
        return json({ success: false, message: 'Erro de conexão. Tente de novo.' }, 500)
      }
      return json(data)
    }

    // ----------------------------------------------------------- solicitar
    if (acao !== 'solicitar') {
      return json({ success: false, message: 'Ação desconhecida.' }, 400)
    }

    const resendKey = Deno.env.get('RESEND_API_KEY')
    if (!resendKey) {
      // Falha explícita: sem isto o e-mail não sai e a pessoa ficaria
      // esperando para sempre um código que nunca foi enviado.
      console.error('RESEND_API_KEY não está configurada')
      return json({
        success: false,
        message: 'O envio de e-mail ainda não está configurado. Fale com a coordenação.',
      }, 500)
    }

    const { data, error } = await admin.rpc('_reset_gerar_codigo', { p_email: email })
    if (error) {
      console.error('erro ao gerar codigo:', error)
      return json({ success: false, message: 'Erro de conexão. Tente de novo.' }, 500)
    }

    if (!data?.found) {
      if (data?.motivo === 'muitos_pedidos') {
        return json({
          success: false,
          message: 'Você já pediu o código 3 vezes na última hora. Espere um pouco ou fale com a coordenação.',
        })
      }
      if (data?.motivo === 'ambiguo') {
        // Não conta para quem pediu QUAL é o problema, mas registra para nós.
        console.error('e-mail repetido em mais de uma profissional')
      }
      // Silêncio proposital: mesma resposta de quando o e-mail existe.
      return json({ success: true, message: RESPOSTA_NEUTRA })
    }

    const envio = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + resendKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: REMETENTE,
        to: [data.email],
        subject: `Seu código CRMAP: ${data.codigo}`,
        html: corpoDoEmail(data.nome, data.codigo, data.minutos),
      }),
    })

    if (!envio.ok) {
      // O código já foi gravado, mas o e-mail não saiu. Dizer "enviamos"
      // aqui seria mentira e ela esperaria à toa.
      const detalhe = await envio.text()
      console.error('Resend recusou:', envio.status, detalhe.slice(0, 300))
      return json({
        success: false,
        message: 'Não consegui enviar o e-mail agora. Tente de novo em alguns minutos ou fale com a coordenação.',
      }, 502)
    }

    return json({ success: true, message: RESPOSTA_NEUTRA })
  } catch (e) {
    console.error(e)
    return json({ success: false, message: 'Erro inesperado. Tente de novo.' }, 500)
  }
})
