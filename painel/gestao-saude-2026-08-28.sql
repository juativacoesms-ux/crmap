-- ============================================================================
-- CRMAP — a coordenação passa a RESOLVER, não só olhar        28/08/2026
-- ============================================================================
-- Hoje a tela /saude/controle/ só LISTA as profissionais. Qualquer correção
-- (telefone errado, alguém que saiu, senha perdida) vira pedido para a Iara.
-- Esta função dá essas ações para a própria diretora.
--
-- Segurança: mesma porta das outras funções do painel — a senha do painel,
-- conferida por _senha_painel_ok. Nada aqui aceita chamada sem senha.
--
-- Estado do banco em 28/08/2026, conferido antes de escrever isto:
--   31 cadastradas, 26 ativas, nenhuma ativa sem WhatsApp.
--   As 5 desativadas (ids 1 a 5) são a COORDENAÇÃO — inclusive a Coord. de
--   Saúde Mental e a Vice/Diretora. Foram desativadas por estarem sem
--   WhatsApp e seguem sem conseguir entrar. Com esta função a diretora
--   preenche o WhatsApp delas e reativa, sem depender de ninguém.
-- ============================================================================

create or replace function public.gerenciar_profissional_saude(
  p_senha       text,
  p_acao        text,
  p_id          bigint,
  p_nome        text default null,
  p_cargo       text default null,
  p_telefone    text default null,
  p_email       text default null,
  p_senha_nova  text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_acao  text := lower(trim(coalesce(p_acao, '')));
  v_norm  text;
  v_nome  text;
begin
  if not public._senha_painel_ok(p_senha) then
    return json_build_object('success', false, 'message', 'Senha incorreta');
  end if;

  select nome into v_nome from public.profissionais_saude where id = p_id;
  if v_nome is null then
    return json_build_object('success', false, 'message', 'Profissional não encontrada.');
  end if;

  -- ------------------------------------------------------------------ ativar
  if v_acao = 'ativar' then
    update public.profissionais_saude set ativo = true where id = p_id;
    return json_build_object('success', true, 'message', v_nome || ' foi reativada.');
  end if;

  -- -------------------------------------------------------------- desativar
  if v_acao = 'desativar' then
    update public.profissionais_saude set ativo = false where id = p_id;
    return json_build_object('success', true,
      'message', v_nome || ' foi desativada e não consegue mais entrar.');
  end if;

  -- ---------------------------------------------------------- definir senha
  if v_acao = 'definir_senha' then
    if length(trim(coalesce(p_senha_nova, ''))) < 6 then
      return json_build_object('success', false,
        'message', 'A senha nova precisa ter pelo menos 6 caracteres.');
    end if;
    update public.profissionais_saude
       set senha_hash  = crypt(trim(p_senha_nova), gen_salt('bf')),
           senha_acesso = null            -- derruba a senha velha e previsível
     where id = p_id;
    return json_build_object('success', true,
      'message', 'Senha de ' || v_nome || ' trocada. Avise ela qual é.');
  end if;

  -- ------------------------------------------------------------- atualizar
  if v_acao = 'atualizar' then
    if trim(coalesce(p_nome, '')) = '' then
      return json_build_object('success', false, 'message', 'O nome não pode ficar vazio.');
    end if;

    -- telefone é a chave de entrada dela: normaliza e não deixa repetir
    if trim(coalesce(p_telefone, '')) <> '' then
      v_norm := public._normalizar_telefone(p_telefone);
      if v_norm is null then
        return json_build_object('success', false,
          'message', 'WhatsApp inválido. Use DDD + número, ex: 67 99999-9999.');
      end if;
      if exists (
        select 1 from public.profissionais_saude
         where telefone_norm = v_norm and id <> p_id
      ) then
        return json_build_object('success', false,
          'message', 'Esse WhatsApp já está cadastrado em outra profissional.');
      end if;
    else
      v_norm := null;
    end if;

    update public.profissionais_saude
       set nome          = trim(p_nome),
           cargo         = nullif(trim(coalesce(p_cargo, '')), ''),
           telefone      = nullif(trim(coalesce(p_telefone, '')), ''),
           telefone_norm = v_norm,
           email         = nullif(trim(coalesce(p_email, '')), '')
     where id = p_id;

    return json_build_object('success', true,
      'message', 'Dados de ' || trim(p_nome) || ' salvos.',
      'entra_por_whatsapp', v_norm is not null);
  end if;

  return json_build_object('success', false, 'message', 'Ação desconhecida: ' || v_acao);
end;
$$;

grant execute on function public.gerenciar_profissional_saude(
  text, text, bigint, text, text, text, text, text
) to anon, authenticated;

-- ============================================================================
-- Conferência (roda depois de aplicar; não muda nada)
-- ============================================================================
-- Quantas ainda não conseguem entrar por falta de WhatsApp:
--   select count(*) from public.profissionais_saude
--    where ativo and (telefone_norm is null or telefone_norm = '');
