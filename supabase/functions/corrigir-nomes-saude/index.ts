import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const CORRECOES: { id: number; nome: string; cargo: string }[] = [
  { id: 1, nome: 'Fátima Maria de Jesus Chaves Soares', cargo: 'Dra. em Psicanálise — Coord. Saúde Mental' },
  { id: 2, nome: 'Jórsia Chaves Horta Nascimento', cargo: 'Psicanalista — Vice / Diretora Saúde Mental' },
  { id: 3, nome: 'Rosilaine Ribeiro de Moura Rocha', cargo: 'Psicóloga' },
  { id: 4, nome: 'Márcia Rodrigues Daian', cargo: 'Psicóloga' },
  { id: 5, nome: 'Érika Danúbia da Silva', cargo: 'Assistente de Saúde' },
]

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const { senha } = await req.json()
    if (!senha) {
      return new Response(JSON.stringify({ success: false, message: 'Senha obrigatória' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const url = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const anon = createClient(url, anonKey)
    const { data: login } = await anon.rpc('login_coordenacao_saude', { p_senha: senha })
    if (!login?.success) {
      return new Response(JSON.stringify({ success: false, message: 'Senha incorreta' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const admin = createClient(url, serviceKey)
    let updated = 0
    for (const row of CORRECOES) {
      const { error } = await admin
        .from('profissionais_saude')
        .update({ nome: row.nome, cargo: row.cargo })
        .eq('id', row.id)
      if (!error) updated++
      else console.error('id', row.id, error)
    }

    return new Response(JSON.stringify({ success: true, updated }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    console.error(e)
    return new Response(JSON.stringify({ success: false, message: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
