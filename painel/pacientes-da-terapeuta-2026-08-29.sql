-- ============================================================================
-- CRMAP — a terapeuta vê e corrige as próprias pacientes    29/08/2026
-- ============================================================================
-- Hoje a paciente é criada automaticamente quando a terapeuta marca a
-- primeira consulta. Funciona, mas faltavam três coisas:
--   1. ver a lista das próprias pacientes (só dava para lembrar o WhatsApp);
--   2. corrigir nome ou telefone digitado errado;
--   3. o pior: um dígito errado no WhatsApp cria uma paciente "nova" e a
--      contagem das 8 sessões gratuitas recomeça do zero — o que decide quem
--      paga.
--
-- Cada terapeuta só enxerga e corrige as pacientes que ELA atendeu. A
-- coordenação, com a senha do painel, enxerga todas.
-- ============================================================================

create or replace function public.listar_pacientes_da_profissional(
  p_profissional_id bigint,
  p_senha           text,
  p_modo            text default 'profissional'
)
returns json
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
declare
  v_coord boolean := (lower(coalesce(p_modo,'')) = 'coordenacao');
begin
  if v_coord then
    if not public._saude_senha_coord_ok(p_senha) then
      return json_build_object('success', false, 'message', 'Senha incorreta');
    end if;
  else
    if not public._saude_prof_ok(p_profissional_id, p_senha) then
      return json_build_object('success', false, 'message', 'Senha incorreta');
    end if;
  end if;

  return json_build_object('success', true, 'pacientes', (
    select coalesce(json_agg(x order by x.nome), '[]'::json) from (
      select p.id, p.nome, p.telefone,
             count(c.id) as consultas,
             max(c.data_consulta) as ultima_consulta
        from public.pacientes_crmap p
        join public.consultas_agendadas c on c.paciente_id = p.id
       where v_coord or c.profissional_id = p_profissional_id
       group by p.id, p.nome, p.telefone
    ) x
  ));
end;
$$;

grant execute on function public.listar_pacientes_da_profissional(bigint, text, text) to anon, authenticated;

-- ----------------------------------------------------------- corrigir dados
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

  v_norm := public._normalizar_telefone(p_telefone);
  if v_norm is null then
    return json_build_object('success', false,
      'message', 'WhatsApp inválido. Use DDD + número, ex: 31 99999-9999.');
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
         telefone_norm = v_norm
   where id = p_paciente_id;

  if not found then
    return json_build_object('success', false, 'message', 'Paciente não encontrada.');
  end if;

  return json_build_object('success', true, 'message', 'Dados de ' || v_nome || ' corrigidos.');
end;
$$;

grant execute on function public.corrigir_paciente_saude(bigint, bigint, text, text, text, text) to anon, authenticated;
