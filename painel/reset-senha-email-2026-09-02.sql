-- ============================================================================
-- CRMAP — "Esqueci minha senha" por e-mail                     02/09/2026
-- ============================================================================
-- POR QUE ISTO EXISTE
--
-- Até hoje a profissional que esquecia a senha NÃO tinha saída nenhuma: a tela
-- /saude/ só oferece Entrar e Primeiro cadastro, e no banco não havia nenhuma
-- função de recuperação. A única forma era alguém com a senha institucional
-- abrir /saude/controle/ e clicar em "Senha".
--
-- O custo disso apareceu no banco em 31/08/2026: a Jórsia (id 2, Vice/Diretora
-- Saúde Mental) se CADASTROU DE NOVO às 22:31 — id 39 — porque não conseguia
-- entrar. E digitou o WhatsApp com um dígito a menos, então o cadastro novo
-- também não abria. Ficou com dois cadastros e nenhum caminho.
--
-- COMO FUNCIONA
--
-- 1. Ela pede pelo e-mail. Um código de 6 dígitos é gerado e GUARDADO
--    EMBARALHADO (bcrypt) — nem no banco ele fica legível.
-- 2. O código sai por e-mail, enviado pela Edge Function `reset-senha`.
--    O código NUNCA volta para o navegador: se voltasse, qualquer pessoa
--    pediria o código de qualquer outra e leria na resposta.
-- 3. Ela digita o código e a senha nova. Vale por 30 minutos e 5 tentativas.
--
-- SEGURANÇA — o que foi pensado de propósito
--
-- * As duas funções abaixo NÃO recebem grant para `anon`. Só a Edge Function
--   as chama, com a chave de serviço. Isso é o que impede alguém de pedir o
--   código pelo navegador e ver a resposta.
-- * A tabela tem RLS ligada e NENHUMA policy. Sem policy, ninguém de fora lê.
-- * No máximo 3 pedidos por hora para a mesma pessoa.
-- * Pedir código para e-mail que não existe não dá erro diferente — quem
--   responde igual nos dois casos é a Edge Function. Assim ninguém descobre
--   quem está cadastrada só ficando testando e-mails.
-- ============================================================================

-- ------------------------------------------------------------------- tabela
create table if not exists public.senha_reset_codigos (
  id              bigserial primary key,
  profissional_id bigint not null
                  references public.profissionais_saude(id) on delete cascade,
  codigo_hash     text not null,
  criado_em       timestamptz not null default now(),
  expira_em       timestamptz not null,
  usado_em        timestamptz,
  tentativas      integer not null default 0
);

create index if not exists idx_reset_prof_criado
  on public.senha_reset_codigos (profissional_id, criado_em desc);

-- RLS ligada e sem policy nenhuma: nem `anon` nem `authenticated` enxergam
-- esta tabela. Só as funções abaixo (security definer) e a chave de serviço.
alter table public.senha_reset_codigos enable row level security;

revoke all on public.senha_reset_codigos from anon, authenticated;

-- ============================================================================
-- 1) Gerar o código. Chamada SÓ pela Edge Function (chave de serviço).
-- ============================================================================
create or replace function public._reset_gerar_codigo(p_email text)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_email  text := lower(trim(coalesce(p_email, '')));
  v_id     bigint;
  v_nome   text;
  v_quant  integer;
  v_codigo text;
begin
  if v_email = '' or position('@' in v_email) = 0 then
    return json_build_object('found', false, 'motivo', 'email_invalido');
  end if;

  -- Só profissional ATIVA. Quem foi desativada não recupera acesso sozinha.
  select count(*) into v_quant
    from public.profissionais_saude
   where ativo and lower(trim(coalesce(email, ''))) = v_email;

  -- Duas pessoas com o mesmo e-mail: não dá para adivinhar qual. Manda para
  -- a coordenação em vez de trocar a senha da pessoa errada.
  if v_quant <> 1 then
    return json_build_object('found', false,
      'motivo', case when v_quant = 0 then 'nao_encontrado' else 'ambiguo' end);
  end if;

  select id, nome into v_id, v_nome
    from public.profissionais_saude
   where ativo and lower(trim(coalesce(email, ''))) = v_email;

  -- Freio: no máximo 3 pedidos por hora para a mesma pessoa.
  select count(*) into v_quant
    from public.senha_reset_codigos
   where profissional_id = v_id
     and criado_em > now() - interval '1 hour';

  if v_quant >= 3 then
    return json_build_object('found', false, 'motivo', 'muitos_pedidos');
  end if;

  -- Pedir um código novo derruba os anteriores que ainda não foram usados.
  update public.senha_reset_codigos
     set expira_em = now()
   where profissional_id = v_id
     and usado_em is null
     and expira_em > now();

  -- gen_random_bytes é sorteio de verdade (pgcrypto). random() não é.
  -- 3 bytes = 0 a 16.777.215, sempre positivo — sem risco de sinal negativo.
  v_codigo := lpad(
    ((('x' || encode(gen_random_bytes(3), 'hex'))::bit(24)::int) % 1000000)::text,
    6, '0');

  insert into public.senha_reset_codigos
         (profissional_id, codigo_hash, expira_em)
  values (v_id, crypt(v_codigo, gen_salt('bf')), now() + interval '30 minutes');

  return json_build_object(
    'found',  true,
    'codigo', v_codigo,
    'nome',   v_nome,
    'email',  v_email,
    'minutos', 30
  );
end;
$$;

-- ============================================================================
-- 2) Conferir o código e trocar a senha. Também SÓ pela Edge Function.
-- ============================================================================
create or replace function public._reset_confirmar(
  p_email      text,
  p_codigo     text,
  p_senha_nova text
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_email  text := lower(trim(coalesce(p_email, '')));
  v_codigo text := trim(coalesce(p_codigo, ''));
  v_nova   text := coalesce(p_senha_nova, '');
  v_id     bigint;
  v_nome   text;
  v_reg    public.senha_reset_codigos%rowtype;
begin
  -- Espaço nas pontas é a causa clássica de "digitei certo e não entra".
  -- Aparar em silêncio deixaria ela com senha diferente da que pensa.
  if v_nova <> trim(v_nova) then
    return json_build_object('success', false,
      'message', 'A senha nova não pode começar nem terminar com espaço.');
  end if;

  if length(v_nova) < 6 then
    return json_build_object('success', false,
      'message', 'A senha nova precisa ter pelo menos 6 caracteres.');
  end if;

  select id, nome into v_id, v_nome
    from public.profissionais_saude
   where ativo and lower(trim(coalesce(email, ''))) = v_email;

  if v_id is null then
    return json_build_object('success', false,
      'message', 'Código inválido ou vencido. Peça um novo.');
  end if;

  select * into v_reg
    from public.senha_reset_codigos
   where profissional_id = v_id
     and usado_em is null
     and expira_em > now()
   order by criado_em desc
   limit 1;

  if v_reg.id is null then
    return json_build_object('success', false,
      'message', 'Código inválido ou vencido. Peça um novo.');
  end if;

  if v_reg.tentativas >= 5 then
    return json_build_object('success', false,
      'message', 'Você errou o código 5 vezes. Peça um código novo.');
  end if;

  if v_reg.codigo_hash <> crypt(v_codigo, v_reg.codigo_hash) then
    update public.senha_reset_codigos
       set tentativas = tentativas + 1
     where id = v_reg.id;
    return json_build_object('success', false,
      'message', 'Código errado. Confira o e-mail e tente de novo.');
  end if;

  update public.profissionais_saude
     set senha_hash   = crypt(v_nova, gen_salt('bf')),
         senha_acesso = null          -- derruba a senha velha e previsível
   where id = v_id;

  update public.senha_reset_codigos
     set usado_em = now()
   where id = v_reg.id;

  return json_build_object('success', true, 'nome', v_nome,
    'message', 'Senha trocada. Agora entre com seu WhatsApp e a senha nova.');
end;
$$;

-- ============================================================================
-- Permissões — o ponto mais importante deste arquivo
-- ============================================================================
-- NENHUM grant para anon/authenticated. Se um dia alguém acrescentar um
-- `grant ... to anon` aqui, a recuperação vira porta aberta: dá para pedir o
-- código de qualquer pessoa e ler o código na própria resposta.
revoke all on function public._reset_gerar_codigo(text) from public, anon, authenticated;
revoke all on function public._reset_confirmar(text, text, text) from public, anon, authenticated;

-- ============================================================================
-- Conferência (roda depois de aplicar; não muda nada)
-- ============================================================================
-- Quem consegue usar a recuperação hoje (ativa e com e-mail):
--   select count(*) from public.profissionais_saude
--    where ativo and coalesce(trim(email),'') <> '';
--
-- Quem NÃO consegue (vai continuar dependendo da coordenação):
--   select id, nome from public.profissionais_saude
--    where ativo and coalesce(trim(email),'') = '' order by nome;
