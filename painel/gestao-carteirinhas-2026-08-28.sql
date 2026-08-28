-- ============================================================================
-- CRMAP — a diretora resolve as carteirinhas sozinha            28/08/2026
-- ============================================================================
-- Hoje a tela "Carteirinhas emitidas" só mostra a lista e aprova doação
-- manual. Nome digitado errado, alguém que precisa baixar de novo ou uma
-- emissão que não devia existir viram pedido para a Iara.
--
-- Como o site decide se a pessoa pode baixar (conferido em carteirinha.html):
-- ele procura uma linha com aquele número de credencial e status 'approved'.
-- Quando a pessoa baixa, o status vira 'downloaded' — e a partir daí ela NÃO
-- consegue baixar de novo. É por isso que existe a ação "liberar de novo".
--
-- Guarda: a senha do painel, igual às outras funções.
-- ============================================================================

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
  v_acao   text := lower(trim(coalesce(p_acao, '')));
  v_nome   text;
  v_numero text;
  v_status text;
begin
  if not public._senha_painel_ok(p_senha) then
    return json_build_object('success', false, 'message', 'Senha incorreta');
  end if;

  select nome_pagador, numero_credencial, status
    into v_nome, v_numero, v_status
    from public.pagamentos_carteirinha
   where id = p_id;

  if v_numero is null and v_nome is null and v_status is null then
    return json_build_object('success', false, 'message', 'Carteirinha não encontrada.');
  end if;

  -- --------------------------------------------------------- corrigir nome
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

  -- ------------------------------------------------- liberar novo download
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

  -- ----------------------------------------------------------- cancelar
  if v_acao = 'cancelar' then
    if v_status = 'cancelado' then
      return json_build_object('success', false, 'message', 'Esta carteirinha já estava cancelada.');
    end if;
    update public.pagamentos_carteirinha
       set status = 'cancelado'
     where id = p_id;
    return json_build_object('success', true,
      'message', 'Carteirinha ' || coalesce(v_numero, '') || ' cancelada. Ela deixa de conseguir baixar.');
  end if;

  -- ------------------------------------------------------------- reabrir
  if v_acao = 'reabrir' then
    if v_status <> 'cancelado' then
      return json_build_object('success', false,
        'message', 'Esta carteirinha não está cancelada.');
    end if;
    update public.pagamentos_carteirinha
       set status = 'pending'
     where id = p_id;
    return json_build_object('success', true,
      'message', 'Carteirinha reaberta como pendente. Se a doação já foi paga, use "Liberar de novo".');
  end if;

  return json_build_object('success', false, 'message', 'Ação desconhecida: ' || v_acao);
end;
$$;

grant execute on function public.gerenciar_carteirinha(text, text, bigint, text) to anon, authenticated;
