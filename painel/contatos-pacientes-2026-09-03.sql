-- ============================================================================
-- CRMAP — a diretoria também corrige contato de paciente        03/09/2026
-- ============================================================================
-- A correção de nome e WhatsApp já existia desde 29/08/2026, mas só aparecia
-- na tela da profissional (/saude/). A diretoria não tinha por onde fazer,
-- então toda correção virava pedido manual. Esta migração fecha isso.
--
-- Duas mudanças, as duas só no modo coordenação:
--
--   1. LEFT JOIN em vez de JOIN. Com o join interno, uma ficha SEM consulta
--      marcada não aparecia para ninguém — e é justamente a ficha com o
--      WhatsApp errado que costuma ficar sem consulta, porque a mensagem
--      nunca chegou na paciente. Era um ponto cego.
--
--   2. A lista passa a dizer QUAL profissional atende cada paciente. A
--      diretoria vê todas as fichas; sem essa coluna não dá para saber com
--      quem falar antes de mexer no contato de alguém.
--
-- A visão da profissional continua igual: ela só enxerga e corrige quem ELA
-- atendeu. Nada muda para ela.
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

    -- Diretoria: todas as fichas, inclusive as que ainda não têm consulta.
    return json_build_object('success', true, 'pacientes', (
      select coalesce(json_agg(x order by x.nome), '[]'::json) from (
        select p.id,
               p.nome,
               p.telefone,
               count(c.id)              as consultas,
               max(c.data_consulta)     as ultima_consulta,
               (select string_agg(distinct pr.nome, ', ')
                  from public.consultas_agendadas c2
                  join public.profissionais_saude pr on pr.id = c2.profissional_id
                 where c2.paciente_id = p.id) as profissionais
          from public.pacientes_crmap p
          left join public.consultas_agendadas c on c.paciente_id = p.id
         group by p.id, p.nome, p.telefone
      ) x
    ));
  end if;

  if not public._saude_prof_ok(p_profissional_id, p_senha) then
    return json_build_object('success', false, 'message', 'Senha incorreta');
  end if;

  -- Profissional: só quem ela atendeu. Comportamento inalterado.
  return json_build_object('success', true, 'pacientes', (
    select coalesce(json_agg(x order by x.nome), '[]'::json) from (
      select p.id,
             p.nome,
             p.telefone,
             count(c.id)          as consultas,
             max(c.data_consulta) as ultima_consulta,
             null::text           as profissionais
        from public.pacientes_crmap p
        join public.consultas_agendadas c on c.paciente_id = p.id
       where c.profissional_id = p_profissional_id
       group by p.id, p.nome, p.telefone
    ) x
  ));
end;
$$;

grant execute on function public.listar_pacientes_da_profissional(bigint, text, text)
  to anon, authenticated;
