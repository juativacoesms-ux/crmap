-- ============================================================================
-- CRMAP — carteirinha por PIX, sem Mercado Pago            29/08/2026
-- ============================================================================
-- Decisão da Iara: "pode tirar o Mercado Pago, hoje usamos apenas chave pix".
--
-- O que se descobriu antes de mexer: o aviso automático do Mercado Pago
-- NUNCA funcionou. Nenhum dos 22 registros tem confirmação vinda de lá, e a
-- página só libera o download quando o banco diz 'approved'. Resultado: as
-- pessoas pagavam, voltavam, viam "aguarde 1–2 minutos" e nunca baixavam.
-- Havia 13 pessoas reais nessa fila, a mais antiga desde 29/05/2026.
--
-- Esta função substitui o papel de registro que a create-preference tinha:
-- guarda a intenção como pendente, para a diretora aprovar depois de conferir
-- o PIX no extrato. Sem token, sem chave de pagamento, sem intermediário.
-- ============================================================================

create or replace function public.registrar_intencao_carteirinha(
  p_nome   text,
  p_numero text
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_nome   text := trim(coalesce(p_nome, ''));
  v_numero text := trim(coalesce(p_numero, ''));
  v_existe text;
begin
  if v_nome = '' then
    return json_build_object('success', false, 'message', 'Informe o nome.');
  end if;
  if v_numero !~ '^[0-9]+/[0-9]{4}$' then
    return json_build_object('success', false,
      'message', 'Número de credencial inválido. Recarregue a página.');
  end if;
  if length(v_nome) > 120 then
    return json_build_object('success', false, 'message', 'Nome muito longo.');
  end if;

  -- Se a pessoa clicar duas vezes, não cria duas linhas para o mesmo número.
  select status into v_existe
    from public.pagamentos_carteirinha
   where numero_credencial = v_numero
   order by created_at desc
   limit 1;

  if v_existe is not null then
    return json_build_object('success', true, 'ja_existia', true,
      'situacao', v_existe,
      'message', 'Pedido já registrado. Faça o PIX e depois use "Já doei, verificar liberação".');
  end if;

  insert into public.pagamentos_carteirinha
    (payment_id, nome_pagador, numero_credencial, valor, status)
  values ('pix-' || v_numero, v_nome, v_numero, 20.00, 'pending');

  return json_build_object('success', true, 'ja_existia', false,
    'message', 'Pedido registrado. Faça o PIX de R$ 20,00 e depois use "Já doei, verificar liberação".');
end;
$$;

grant execute on function public.registrar_intencao_carteirinha(text, text) to anon, authenticated;
