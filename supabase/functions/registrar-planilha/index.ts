/**
 * Registro na planilha Google (fallback server-side com redirect follow).
 * Usado quando o POST do navegador falha ou para sincronizar após pagamento.
 */
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const GOOGLE_APPS_SCRIPT_URL =
  Deno.env.get('GOOGLE_APPS_SCRIPT_URL') ??
  'https://script.google.com/macros/s/AKfycbzRPMVu--BYlX51qU0Mj6P1SBTikDE7RKJhym0c_RMCJ-CoRM_4T4mNHjRudcvx6EK1/exec'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = await req.json()
    const params: Record<string, string> = {
      numero: String(body.numero || '').trim(),
      nome: String(body.nome || '').trim(),
      data: String(body.data || '').trim(),
      evento: String(body.evento || '').trim(),
      fluxo: String(body.fluxo || '').trim(),
      pago_confirmado: String(body.pago_confirmado || '').trim(),
    }

    if (!params.numero || !params.evento) {
      return new Response(JSON.stringify({ error: 'numero e evento obrigatórios' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (!params.data) {
      params.data = new Date().toLocaleDateString('pt-BR')
    }

    const gasRes = await fetch(GOOGLE_APPS_SCRIPT_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
      body: new URLSearchParams(params).toString(),
      redirect: 'follow',
    })

    const text = await gasRes.text()

    return new Response(
      JSON.stringify({ ok: gasRes.ok, status: gasRes.status, gas: text.slice(0, 500) }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
