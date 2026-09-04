-- ============================================================================
-- CRMAP — contato de paciente: apaga o que não confere, exige 11 dígitos
--                                                              03/09/2026
-- ============================================================================
-- Seis das sete fichas estavam com WhatsApp de 10 dígitos. Celular tem 11.
--
-- A pergunta era se dava para reconstruir o dígito perdido. Testado número a
-- número: existe UM ÚNICO celular válido que gera aquele de 10 dígitos ao
-- perder um algarismo? Só em dois casos. Nos outros quatro há 2, 67 ou mais
-- respostas possíveis — e não há como escolher entre elas.
--
--   CORRIGIDO (a resposta é única, não é palpite):
--     id 1  Helena Rosário Ramos    31 8841-8250 -> (31) 98841-8250
--           Três fontes: o sistema e a ficha da Fátima dizem 8841-8250, o PDF
--           diz 98418-250. Só 31988418250 gera as duas ao perder um dígito.
--     id 9  Vânia Lima Fernandes    31 8313-6303 -> (31) 98313-6303
--           Os oito dígitos começam com 8, então o 9 só cabe na frente:
--           qualquer outra posição deixaria o número começando com 8, o que
--           não existe em celular.
--
--   APAGADO (não dá para saber, e chutar manda mensagem de saúde a estranho):
--     id 2   Viviane Aparecida          67 possibilidades
--     id 7   Erica Eliane Guimarães     67 possibilidades, e a lista traz um
--            número completamente diferente (31 99549148 contra 38 9976-6937)
--     id 8   Liderjane Gomes da Mata    2 possibilidades, e o DDD conflita
--            entre as fontes (37 contra 31)
--     id 10  Lucilene Felizardo Ribeiro 67 possibilidades
--
-- O número antigo NÃO se perde: vai para `observacoes`. Se alguém reconhecer
-- a pessoa por ele depois, está lá.
-- ============================================================================

-- ---------------------------------------------------------- 1. permitir vazio
-- `telefone_norm` é UNIQUE. Com quatro fichas vazias, quatro strings ''
-- colidiriam entre si e o UPDATE falharia. NULL não colide com NULL no
-- Postgres, então é NULL que a ficha sem contato precisa guardar.
alter table public.pacientes_crmap
  alter column telefone      drop not null,
  alter column telefone_norm drop not null;

-- ------------------------------------------- 2. as duas que ficaram provadas
update public.pacientes_crmap
   set telefone = '(31) 98841-8250', telefone_norm = '31988418250',
       updated_at = timezone('utc', now())
 where id = 1 and telefone_norm = '3188418250';

update public.pacientes_crmap
   set telefone = '(31) 98313-6303', telefone_norm = '31983136303',
       updated_at = timezone('utc', now())
 where id = 9 and telefone_norm = '3183136303';

-- ---------------------------------------------- 3. as quatro sem resposta
-- O `where telefone_norm = ...` evita apagar algo que já tenha sido corrigido
-- por uma profissional entre a escrita deste arquivo e a execução dele.
update public.pacientes_crmap
   set observacoes = trim(coalesce(observacoes || ' | ', '')
        || 'WhatsApp retirado em 03/09/2026 por não conferir (só 10 dígitos, '
        || 'sem como saber o que falta). Estava: ' || telefone
        || '. Perguntar à paciente e cadastrar de novo.'),
       telefone = null, telefone_norm = null,
       updated_at = timezone('utc', now())
 where id in (2, 7, 8, 10)
   and telefone_norm in ('3899394890', '3899766937', '3798714029', '3196189930');

-- ------------------------------------------------ 4. a trava, no próprio banco
-- A tela já recusa número curto, mas tela se contorna. Quem grava é o banco,
-- e é aqui que a regra tem que valer de verdade.
create or replace function public._celular_valido(p_tel text)
returns boolean
language plpgsql
immutable
security definer
set search_path = public, extensions
as $$
declare
  d text;
begin
  d := regexp_replace(coalesce(p_tel, ''), '\D', '', 'g');
  if length(d) >= 12 and left(d, 2) = '55' then d := substring(d from 3); end if;
  -- 11 dígitos, DDD entre 11 e 99 e o 9 obrigatório depois do DDD.
  -- NÃO exigir que o dígito seguinte seja de 6 a 9: essa regra, testada contra
  -- os cadastros reais, barraria a Joaci — profissional ATIVA, número
  -- (11) 94039-8890 — e ela pararia de conseguir entrar.
  return length(d) = 11
     and substring(d, 1, 2) between '11' and '99'
     and substring(d, 3, 1) = '9';
end;
$$;

grant execute on function public._celular_valido(text) to anon, authenticated;

-- ------------------------------------ 5. a trava dentro de corrigir_paciente
-- Mesma regra da tela, agora no banco. `_normalizar_telefone` continua
-- aceitando 10 dígitos porque também serve ao login das profissionais — a
-- exigência dos 11 entra só onde a paciente é gravada.
create or replace function public.corrigir_paciente_saude(
  p_paciente_id     bigint,
  p_profissional_id bigint,
  p_senha           text,
  p_nome            text,
  p_telefone        text,
  p_modo            text default 'profissional'
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_coord   boolean := (lower(coalesce(p_modo,'')) = 'coordenacao');
  v_nome    text := trim(coalesce(p_nome, ''));
  v_norm    text;
  v_atende  boolean;
  v_outra   bigint;
begin
  if v_coord then
    if not public._saude_senha_coord_ok(p_senha) then
      return json_build_object('success', false, 'message', 'Senha incorreta');
    end if;
  else
    if not public._saude_prof_ok(p_profissional_id, p_senha) then
      return json_build_object('success', false, 'message', 'Senha incorreta');
    end if;
    -- A terapeuta só mexe em quem ela atendeu.
    select exists (
      select 1 from public.consultas_agendadas
       where paciente_id = p_paciente_id and profissional_id = p_profissional_id
    ) into v_atende;
    if not v_atende then
      return json_build_object('success', false,
        'message', 'Esta paciente não está na sua lista.');
    end if;
  end if;

  if v_nome = '' then
    return json_build_object('success', false, 'message', 'O nome não pode ficar vazio.');
  end if;
  if length(v_nome) > 120 then
    return json_build_object('success', false, 'message', 'Nome muito longo.');
  end if;

  -- AQUI está a diferença: 11 dígitos, sem exceção.
  if not public._celular_valido(p_telefone) then
    return json_build_object('success', false,
      'message', 'WhatsApp inválido. Um celular tem 11 números com o DDD — ex: (31) 98888-7777.');
  end if;

  v_norm := public._normalizar_telefone(p_telefone);
  if v_norm is null then
    return json_build_object('success', false,
      'message', 'WhatsApp inválido. Use DDD + número, ex: 31 98888-7777.');
  end if;

  -- Se o número já é de outra paciente, avisa em vez de criar confusão:
  -- juntar históricos é decisão de quem conhece o caso, não do sistema.
  select id into v_outra from public.pacientes_crmap
   where telefone_norm = v_norm and id <> p_paciente_id limit 1;
  if v_outra is not null then
    return json_build_object('success', false,
      'message', 'Esse WhatsApp já está em outra ficha. Provavelmente a mesma pessoa foi cadastrada duas vezes — avise a coordenação para juntar as duas.');
  end if;

  update public.pacientes_crmap
     set nome = v_nome,
         telefone = trim(coalesce(p_telefone, '')),
         telefone_norm = v_norm,
         updated_at = timezone('utc'::text, now())
   where id = p_paciente_id;

  if not found then
    return json_build_object('success', false, 'message', 'Paciente não encontrada.');
  end if;

  return json_build_object('success', true, 'message', 'Dados de ' || v_nome || ' corrigidos.');
end;
$$;

grant execute on function public.corrigir_paciente_saude(bigint, bigint, text, text, text, text)
  to anon, authenticated;
