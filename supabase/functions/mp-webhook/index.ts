import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const MP_ACCESS_TOKEN = Deno.env.get('MP_ACCESS_TOKEN')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
const GOOGLE_APPS_SCRIPT_URL =
  Deno.env.get('GOOGLE_APPS_SCRIPT_URL') ??
  'https://script.google.com/macros/s/AKfycbxta2QnUbWxVA9DRuy5NdKwSjDv_RjfIht0Qgt5C6CRnUlzZ_QnVB7G1V2DxamDMMLW/exec'

async function notificarPlanilha(params: Record<string, string>) {
  try {
    await fetch(GOOGLE_APPS_SCRIPT_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
      body: new URLSearchParams(params).toString(),
      redirect: 'follow',
    })
  } catch (e) {
    console.error('Falha ao atualizar planilha:', e)
  }
}

serve(async (req) => {
  try {
    const url = new URL(req.url)
    const queryType = url.searchParams.get('type') || url.searchParams.get('topic')
    const queryPaymentId = url.searchParams.get('data.id') || url.searchParams.get('id')

    let body: any = {}
    try {
      body = await req.json()
    } catch (_) {
      body = {}
    }

    const bodyAction = body?.action
    const bodyPaymentId = body?.data?.id
    const bodyType = body?.type

    const isPaymentEvent =
      bodyAction === 'payment.created' ||
      bodyAction === 'payment.updated' ||
      bodyType === 'payment' ||
      queryType === 'payment'

    const paymentId = bodyPaymentId || queryPaymentId

    if (isPaymentEvent && paymentId) {

      // 1. Buscar detalhes do pagamento no Mercado Pago
      const response = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
        headers: {
          'Authorization': `Bearer ${MP_ACCESS_TOKEN}`,
        }
      })
      const paymentData = await response.json()

      // 2. Atualizar no Supabase
      const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)
      const { status, external_reference } = paymentData

      if (status === 'approved' && external_reference) {
        await supabase.from('pagamentos_carteirinha')
          .update({ status: 'approved' })
          .eq('numero_credencial', external_reference)

        const nomePagador =
          paymentData?.payer?.first_name ||
          paymentData?.additional_info?.payer?.first_name ||
          ''

        await notificarPlanilha({
          evento: 'pagamento_aprovado',
          numero: String(external_reference),
          nome: nomePagador,
          data: new Date().toLocaleDateString('pt-BR'),
        })
      }
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 })
  } catch (error) {
    console.error('Webhook Error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})
