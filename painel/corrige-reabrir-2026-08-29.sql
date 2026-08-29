-- ============================================================================
-- CRMAP — corrige o "Reabrir" das carteirinhas            29/08/2026
-- ============================================================================
-- DEFEITO ENCONTRADO no teste da Iara (28/08/2026, à noite):
--   "Reabrir" devolvia TODA carteirinha para 'pending', mesmo as que eram
--   voluntárias (gratuitas). Uma voluntária cancelada e reaberta passava a
--   aparecer como "Doação pendente" — a informação de que era gratuita se
--   perdia, e a diretora poderia acabar cobrando quem não devia pagar.
--
--   No teste isso aconteceu com a linha 103/2026 ("iarateste", de 22/05/2026),
--   que é registro de teste antigo, não pessoa real. Nenhuma carteirinha de
--   verdade foi afetada.
--
-- CORREÇÃO: ao cancelar, guardamos qual era a situação. Ao reabrir, ela volta
-- exatamente para o que era antes.
-- ============================================================================

alter table public.pagamentos_carteirinha
  add column if not exists status_anterior text;

create or replace function public.gerenciar_carteirinha(
  p_senha text,
  p_acao  text,
  p_id    bigint,
  p_texto text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_acao     text := lower(trim(coalesce(p_acao, '')));
  v_nome     text;
  v_numero   text;
  v_status   text;
  v_anterior text;
  v_volta    text;
begin
  if not public._senha_painel_ok(p_senha) then
    return json_build_object('success', false, 'message', 'Senha incorreta');
  end if;

  select nome_pagador, numero_credencial, status, status_anterior
    into v_nome, v_numero, v_status, v_anterior
    from public.pagamentos_carteirinha
   where id = p_id;

  if v_numero is null and v_nome is null and v_status is null then
    return json_build_object('success', false, 'message', 'Carteirinha não encontrada.');
  end if;

  if v_acao = 'corrigir_nome' then
    if trim(coalesce(p_texto, '')) = '' then
      return json_build_object('success', false, 'message', 'O nome não pode ficar vazio.');
    end if;
    if length(trim(p_texto)) > 120 then
      return json_build_object('success', false, 'message', 'Nome muito longo.');
    end if;
    update public.pagamentos_carteirinha
       set nome_pagador = trim(p_texto)
     where id = p_id;
    return json_build_object('success', true,
      'message', 'Nome corrigido para ' || trim(p_texto) || '. Ela precisa gerar a carteirinha de novo para sair com o nome certo.');
  end if;

  if v_acao = 'liberar_download' then
    if v_status = 'cancelado' then
      return json_build_object('success', false,
        'message', 'Esta carteirinha está cancelada. Reabra antes de liberar.');
    end if;
    update public.pagamentos_carteirinha
       set status = 'approved'
     where id = p_id;
    return json_build_object('success', true,
      'message', 'Liberado. ' || coalesce(v_nome, 'A pessoa') || ' já pode baixar a carteirinha de novo.');
  end if;

  if v_acao = 'cancelar' then
    if v_status = 'cancelado' then
      return json_build_object('success', false, 'message', 'Esta carteirinha já estava cancelada.');
    end if;
    -- Guarda a situação para o "Reabrir" saber ao que voltar.
    update public.pagamentos_carteirinha
       set status = 'cancelado', status_anterior = v_status
     where id = p_id;
    return json_build_object('success', true,
      'message', 'Carteirinha ' || coalesce(v_numero, '') || ' cancelada. Ela deixa de conseguir baixar.');
  end if;

  if v_acao = 'reabrir' then
    if v_status <> 'cancelado' then
      return json_build_object('success', false,
        'message', 'Esta carteirinha não está cancelada.');
    end if;
    -- Volta ao que era. Só cai em 'pending' quando não há registro anterior
    -- (carteirinha cancelada antes desta correção existir).
    v_volta := coalesce(nullif(v_anterior, ''), 'pending');
    update public.pagamentos_carteirinha
       set status = v_volta, status_anterior = null
     where id = p_id;
    return json_build_object('success', true,
      'message', case
        when v_volta = 'downloaded_voluntario' then 'Reaberta como voluntária (gratuita), do jeito que estava antes.'
        when v_volta = 'approved' then 'Reaberta como doação paga, do jeito que estava antes.'
        when v_volta = 'downloaded' then 'Reaberta como paga e baixada, do jeito que estava antes.'
        else 'Reaberta como pendente. Se a doação já foi paga, use "Liberar de novo".'
      end);
  end if;

  return json_build_object('success', false, 'message', 'Ação desconhecida: ' || v_acao);
end;
$$;

grant execute on function public.gerenciar_carteirinha(text, text, bigint, text) to anon, authenticated;
