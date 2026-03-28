import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const MP_ACCESS_TOKEN = Deno.env.get('MP_ACCESS_TOKEN')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { nome, numero_credencial, valor } = await req.json()
    const unitPrice = parseFloat(valor) || 20.00

    // 1. Criar Preferência no Mercado Pago
    const response = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${MP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        items: [
          {
            title: valor ? `Doação CRMAP - ${nome || 'Anônimo'}` : `Carteirinha CRMAP - ${nome}`,
            unit_price: unitPrice,
            quantity: 1,
            currency_id: 'BRL'
          }
        ],
        external_reference: numero_credencial,
        payer: {
          email: 'contato@cdrmap.com.br',
          first_name: nome || 'Colaborador',
          last_name: 'CRMAP'
        },
        payment_methods: {
          included_payment_methods: [
            { id: 'pix' } // Tentativa direta pelo ID 'pix' 
          ],
          included_payment_types: [
            { id: 'ticket' },
            { id: 'bank_transfer' },
            { id: 'credit_card' },
            { id: 'debit_card' }
          ],
          installments: 1,
        },
        binary_mode: true,
        back_urls: {
          success: `${req.headers.get('origin')}/carteirinha.html?status=approved&num=${numero_credencial}`,
          failure: `${req.headers.get('origin')}/carteirinha.html?status=failure`,
          pending: `${req.headers.get('origin')}/carteirinha.html?status=pending`
        },
        auto_return: 'approved'
      })
    })

    const preference = await response.json()

    if (!response.ok) {
        return new Response(
            JSON.stringify({ error: `Mercado Pago Error: ${preference.message || response.statusText}` }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }

    // 2. Registrar intenção no Supabase (Opcional, mas bom para rastrear)
    const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)
    await supabase.from('pagamentos_carteirinha').insert({
        payment_id: preference.id,
        nome_pagador: nome,
        numero_credencial: numero_credencial,
        valor: 20.00,
        status: 'pending'
    })

    return new Response(
      JSON.stringify({ id: preference.id, init_point: preference.init_point }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
