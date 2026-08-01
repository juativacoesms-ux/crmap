-- ============================================================================
-- CRMAP — migração de segurança
-- Escrito em 01/08/2026 (horário de Brasília)
--
-- ONDE RODAR: supabase.com -> projeto qzjvzbvoxwhggvadaroq -> SQL Editor
--             -> New query -> colar TUDO -> Run.
--
-- ATENÇÃO: eu (Claude) NÃO consigo executar nem testar nada disto. Não há
-- credencial do Supabase nesta máquina e o CLI não está instalado. Este
-- arquivo foi escrito lendo os .sql do repositório e o código do site, mas
-- nunca rodou. Leia a seção "COMO TESTAR" no fim ANTES de considerar pronto.
--
-- ORDEM IMPORTA. As partes estão na ordem em que devem rodar:
--   PARTE 1 — senha do painel vira hash e sai do código
--   PARTE 2 — senhas das 31 profissionais viram hash
--   PARTE 3 — o painel ganha uma função para ler as doações
--   PARTE 4 — só então a leitura pública é fechada
--
-- A PARTE 4 é a última de propósito: se ela rodasse antes, o painel e o
-- login parariam antes de existir a substituição.
-- ============================================================================


-- ############################################################################
-- ANTES DE RODAR: escolha a senha nova do painel
--
-- A senha atual ('270797crmap*') esteve PÚBLICA na internet, em
-- crmapoficial.org.br/painel/setup_supabase.sql, até 01/08/2026. Tem que ser
-- trocada — não dá para só escondê-la.
--
-- Troque COLOQUE_A_SENHA_NOVA_AQUI abaixo pela senha nova, entre aspas
-- simples. É o ÚNICO lugar deste arquivo que você precisa editar.
-- Se a senha tiver aspas simples, dobre cada uma ('' no lugar de ').
-- ############################################################################


-- ============================================================================
-- PARTE 1 — a senha do painel vira hash e sai de dentro do código
-- ============================================================================

create extension if not exists pgcrypto;

-- Tabela que guarda o hash. Ninguém de fora enxerga: sem GRANT para anon,
-- e as funções abaixo são SECURITY DEFINER, então elas leem mesmo assim.
create table if not exists public.painel_config (
  chave text primary key,
  valor text not null,
  atualizado_em timestamptz not null default now()
);

alter table public.painel_config enable row level security;
revoke all on public.painel_config from anon, authenticated;

-- Grava o hash da senha nova. bf = bcrypt, custo 10.
insert into public.painel_config (chave, valor)
values ('senha_painel_hash', crypt('COLOQUE_A_SENHA_NOVA_AQUI', gen_salt('bf', 10)))
on conflict (chave) do update
  set valor = excluded.valor, atualizado_em = now();

-- Verificador único. Todas as funções passam a chamar este.
create or replace function public._senha_painel_ok(p_senha text)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from public.painel_config
     where chave = 'senha_painel_hash'
       and valor = crypt(coalesce(p_senha, ''), valor)
  );
$$;

-- Usada pela tela de login do painel, para dizer "senha certa" ou "errada"
-- sem que o painel precise conhecer a senha.
create or replace function public.validar_senha_painel(p_senha text)
returns json
language sql
stable
security definer
set search_path = public, extensions
as $$
  select json_build_object('success', public._senha_painel_ok(p_senha));
$$;

grant execute on function public.validar_senha_painel(text) to anon;

-- --- as funções que já existiam passam a usar o hash -----------------------

-- gerenciar_produto: mesma assinatura e mesmo corpo, só troca a linha da
-- senha. O restante do corpo é recriado igual ao que está em
-- painel/fix_supabase.sql.
create or replace function public.gerenciar_produto(
    p_acao text,
    p_senha text,
    p_id bigint default null,
    p_nome text default null,
    p_descricao text default null,
    p_preco text default null,
    p_whatsapp text default null,
    p_foto_url text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
    if not public._senha_painel_ok(p_senha) then
        return json_build_object('success', false, 'message', 'Senha incorreta');
    end if;

    if p_acao = 'inserir' then
        insert into public.produtos (nome, descricao, preco, whatsapp, foto_url)
        values (p_nome, p_descricao, p_preco, p_whatsapp, p_foto_url);
        return json_build_object('success', true, 'message', 'Produto inserido');

    elsif p_acao = 'atualizar' then
        update public.produtos
           set nome = p_nome, descricao = p_descricao, preco = p_preco,
               whatsapp = p_whatsapp, foto_url = p_foto_url
         where id = p_id;
        return json_build_object('success', true, 'message', 'Produto atualizado');

    elsif p_acao = 'deletar' then
        delete from public.produtos where id = p_id;
        return json_build_object('success', true, 'message', 'Produto removido');
    end if;

    return json_build_object('success', false, 'message', 'Ação desconhecida');
end;
$$;

-- confirmar_pagamento: é ESTA que aprova doação manual. Mesma assinatura.
create or replace function public.confirmar_pagamento(
    p_senha text,
    p_payment_id text,
    p_status text
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
    if not public._senha_painel_ok(p_senha) then
        return json_build_object('success', false, 'message', 'Senha incorreta');
    end if;

    update public.pagamentos_carteirinha
       set status = p_status
     where payment_id = p_payment_id;

    if not found then
        return json_build_object('success', false, 'message', 'Doação não encontrada');
    end if;

    return json_build_object('success', true, 'message', 'Status atualizado');
end;
$$;

-- As duas portas da área da Saúde. Atenção: _saude_senha_coord_ok aceitava
-- DUAS senhas — a do painel e 'secretaria2026'. A segunda também estava
-- pública. Aqui as duas saem do código; se você quiser manter uma senha
-- separada para a secretaria, me avise que eu acrescento outra chave.
create or replace function public._saude_senha_coord_ok(p_senha text)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select public._senha_painel_ok(p_senha);
$$;

create or replace function public._saude_senha_ok(p_senha text)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select public._senha_painel_ok(p_senha);
$$;


-- ============================================================================
-- PARTE 2 — as senhas das 31 profissionais viram hash
--
-- Elas continuam entrando com a MESMA senha de hoje. O que muda é que o
-- banco passa a guardar só o hash, que não dá para ler de volta.
--
-- A coluna senha_acesso NÃO é apagada agora, de propósito: fica como rede de
-- segurança até você confirmar que os logins funcionam. O passo para apagar
-- está no fim do arquivo, separado.
-- ============================================================================

alter table public.profissionais_saude
  add column if not exists senha_hash text;

-- Gera o hash a partir da senha atual, só para quem ainda não tem hash.
update public.profissionais_saude
   set senha_hash = crypt(senha_acesso, gen_salt('bf', 10))
 where senha_hash is null
   and senha_acesso is not null
   and trim(senha_acesso) <> '';

-- Conferência: as duas contagens têm que ser iguais.
select
  count(*) filter (where senha_acesso is not null and trim(senha_acesso) <> '') as com_senha_antiga,
  count(*) filter (where senha_hash is not null)                                as com_hash
from public.profissionais_saude;

-- Verificação de senha por hash, aceitando também a antiga em texto puro
-- enquanto a coluna existir. Isso é o que garante que ninguém fica de fora
-- se algum registro escapar do UPDATE acima.
create or replace function public._saude_prof_ok(p_prof_id bigint, p_senha text)
returns boolean
language sql
stable
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from public.profissionais_saude
     where id = p_prof_id
       and ativo
       and (
         (senha_hash is not null and senha_hash = crypt(coalesce(p_senha,''), senha_hash))
         or
         (senha_hash is null and senha_acesso is not null and senha_acesso = p_senha)
       )
  );
$$;

-- Login por WhatsApp — mesma lógica.
create or replace function public.login_profissional_telefone(
  p_telefone text,
  p_senha text
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_norm text;
  v_id bigint;
  v_nome text;
begin
  v_norm := public._normalizar_telefone(p_telefone);
  if v_norm is null then
    return json_build_object('success', false, 'message', 'WhatsApp/telefone inválido.');
  end if;

  select id, nome into v_id, v_nome
    from public.profissionais_saude
   where telefone_norm = v_norm
     and ativo
     and (
       (senha_hash is not null and senha_hash = crypt(coalesce(p_senha,''), senha_hash))
       or
       (senha_hash is null and senha_acesso is not null and senha_acesso = p_senha)
     );

  if v_id is null then
    return json_build_object('success', false, 'message', 'WhatsApp ou senha incorretos');
  end if;

  return json_build_object(
    'success', true,
    'role', 'profissional',
    'profissional_id', v_id,
    'nome', v_nome
  );
end;
$$;

-- Cadastro novo passa a gravar SÓ o hash.
create or replace function public.cadastrar_profissional_saude(
  p_nome text,
  p_cargo text,
  p_telefone text,
  p_senha text,
  p_email text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_norm text;
  v_id bigint;
  v_ordem integer;
begin
  if length(trim(coalesce(p_senha, ''))) < 6 then
    return json_build_object('success', false, 'message', 'Senha com no mínimo 6 caracteres.');
  end if;
  if trim(coalesce(p_nome, '')) = '' or trim(coalesce(p_cargo, '')) = '' then
    return json_build_object('success', false, 'message', 'Nome e função/cargo são obrigatórios.');
  end if;

  v_norm := public._normalizar_telefone(p_telefone);
  if v_norm is null then
    return json_build_object('success', false, 'message', 'WhatsApp/telefone inválido.');
  end if;

  if exists (select 1 from public.profissionais_saude where telefone_norm = v_norm) then
    return json_build_object('success', false, 'message', 'Este WhatsApp já está cadastrado. Use Entrar.');
  end if;

  select coalesce(max(ordem), 0) + 1 into v_ordem from public.profissionais_saude;

  insert into public.profissionais_saude
    (nome, cargo, telefone, telefone_norm, email, senha_hash, ativo, ordem)
  values (
    trim(p_nome), trim(p_cargo), trim(p_telefone), v_norm,
    nullif(trim(p_email), ''),
    crypt(p_senha, gen_salt('bf', 10)),
    true, v_ordem
  )
  returning id into v_id;

  return json_build_object('success', true, 'profissional_id', v_id, 'nome', trim(p_nome));
end;
$$;


-- ============================================================================
-- PARTE 3 — o painel ganha como ler as doações sem leitura pública
--
-- Hoje painel/index.html faz select('*') direto na tabela. Se a PARTE 4
-- rodasse sem isto, o relatório de doações ficaria vazio.
-- ============================================================================

create or replace function public.listar_pagamentos_painel(p_senha text)
returns json
language sql
stable
security definer
set search_path = public, extensions
as $$
  select coalesce(
    (select json_agg(t order by t.created_at desc)
       from (select * from public.pagamentos_carteirinha) t
      where public._senha_painel_ok(p_senha)),
    '[]'::json
  );
$$;

grant execute on function public.listar_pagamentos_painel(text) to anon;


-- ============================================================================
-- PARTE 4 — fecha a leitura pública (rodar por último)
--
-- O site continua funcionando porque:
--   - a lista de profissionais usa só id, nome, cargo, ativo, ordem
--     (saude/saude-common.js:93)
--   - a carteirinha usa só numero_credencial e status
--     (carteirinha.html:566)
--   - todo login e toda escrita passam por função SECURITY DEFINER
-- ============================================================================

-- 4.1 — esconde senha_acesso, senha_hash, telefone e e-mail das 31.
revoke select on public.profissionais_saude from anon;
grant  select (id, nome, cargo, ativo, ordem)
       on public.profissionais_saude to anon;

-- 4.2 — esconde nome, e-mail e payment_id das doadoras.
revoke select on public.pagamentos_carteirinha from anon;
grant  select (numero_credencial, status)
       on public.pagamentos_carteirinha to anon;

-- 4.3 — ninguém de fora insere, altera ou APAGA produtos, nem cria doação
-- falsa. As funções SECURITY DEFINER acima continuam podendo.
drop policy if exists "Função segura pode gerenciar"  on public.produtos;
drop policy if exists "Site pode registrar pagamentos" on public.pagamentos_carteirinha;
drop policy if exists "Site pode atualizar download"   on public.pagamentos_carteirinha;


-- ============================================================================
-- CONFERIR DEPOIS DE RODAR
-- ============================================================================

-- 1) Políticas que sobraram:
select tablename, policyname, cmd
  from pg_policies where schemaname = 'public' order by tablename;

-- 2) Todas as 31 têm hash?
select count(*) as total,
       count(senha_hash) as com_hash,
       count(*) - count(senha_hash) as SEM_HASH_ATENCAO
  from public.profissionais_saude;

-- 3) A senha nova do painel funciona? (tem que voltar true)
select public._senha_painel_ok('COLOQUE_A_SENHA_NOVA_AQUI') as senha_nova_ok;

-- 4) A senha antiga foi mesmo derrubada? (tem que voltar false)
select public._senha_painel_ok('270797crmap*') as senha_antiga_ainda_funciona;


-- ============================================================================
-- SÓ DEPOIS DE TUDO TESTADO — apagar as senhas em texto puro
--
-- NÃO rode junto. Rode só quando as profissionais tiverem entrado e você
-- tiver confirmado que o login funciona. Depois disto não há volta: as
-- senhas originais deixam de existir.
-- ============================================================================

-- alter table public.profissionais_saude drop column senha_acesso;


-- ============================================================================
-- COMO DESFAZER, se algo quebrar
--
-- A rede de segurança é a coluna senha_acesso, que continua lá. Para voltar
-- ao comportamento antigo do login das profissionais:
--
--   create or replace function public._saude_prof_ok(p_prof_id bigint, p_senha text)
--   returns boolean language sql stable security definer set search_path = public as $$
--     select exists (select 1 from public.profissionais_saude
--                     where id = p_prof_id and ativo and senha_acesso = p_senha);
--   $$;
--
-- Para reabrir a leitura pública (só se algo realmente quebrar):
--   grant select on public.profissionais_saude to anon;
--   grant select on public.pagamentos_carteirinha to anon;
-- ============================================================================


-- ============================================================================
-- COMO TESTAR — nesta ordem, antes de dar por pronto
--
-- 1. Abra /saude/ e faça login com UMA profissional, com a senha de hoje.
--    Se falhar, PARE e rode o "COMO DESFAZER" acima.
-- 2. Abra /produtos/ — os 59 produtos têm que continuar aparecendo.
-- 3. Abra /carteirinha, digite um número e clique em
--    "Já doei, verificar liberação" — tem que continuar respondendo.
-- 4. Abra /painel/ e entre com a senha NOVA. Confira se a lista de doações
--    aparece e se aprovar uma doação funciona.
--    (Isto só funciona depois que eu publicar a versão nova do painel —
--     me avise assim que rodar este SQL.)
-- 5. Peça para uma das profissionais entrar de verdade, do celular dela.
--    Conferência técnica não substitui isso — foi a lição do teste do Pix.
-- ============================================================================
