-- ============================================================================
-- CRMAP — aviso de consulta por e-mail                          02/09/2026
-- ============================================================================
-- Ao marcar uma consulta, sai um e-mail para a PROFISSIONAL e, se a paciente
-- tiver e-mail e tiver concordado, outro para a PACIENTE. Os dois levam um
-- anexo .ics, que é o que faz o celular oferecer "adicionar na agenda".
--
-- PRIVACIDADE — o motivo de o e-mail da paciente ser diferente do da
-- profissional. A CRMAP atende mulheres em acompanhamento psicológico, e isso
-- é dado sensível de saúde (LGPD, art. 5º, II). Caixa de e-mail é
-- frequentemente compartilhada com companheiro ou familiar. Por isso o aviso
-- da paciente NÃO diz o tipo de atendimento, nem o número da sessão, nem
-- valor, nem que é terapia: diz que ela tem um atendimento na CRMAP, o dia, a
-- hora e um WhatsApp de contato. Decisão da Iara em 02/09/2026.
-- O e-mail da profissional pode ser completo — é a ficha de trabalho dela.
--
-- O campo `email` da paciente é OPCIONAL e só deve ser preenchido se ela
-- concordar em receber. Sem e-mail, nada muda: o fluxo segue como antes.
-- ============================================================================

-- ------------------------------------------------- onde o e-mail dela fica
alter table public.pacientes_crmap
  add column if not exists email text;

comment on column public.pacientes_crmap.email is
  'Opcional. Só com o consentimento da paciente — usado apenas para o aviso '
  'de consulta, que de propósito não revela o tipo de atendimento.';

-- ============================================================================
-- Dados para o aviso. Chamada SÓ pela Edge Function (chave de serviço).
--
-- Faz três coisas numa ida só: confere quem está pedindo, grava o e-mail da
-- paciente se veio um, e devolve o que os dois e-mails precisam. Deixar isso
-- no banco (e não no navegador) é o que impede alguém de mandar e-mail em
-- nome da CRMAP com dados inventados.
-- ============================================================================
create or replace function public._aviso_consulta(
  p_modo           text,
  p_senha          text,
  p_profissional_id bigint,
  p_consulta_id    bigint,
  p_email_paciente text default null
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  c        record;
  v_email  text := lower(trim(coalesce(p_email_paciente, '')));
begin
  -- Mesma porta das outras funções da Saúde.
  if p_modo = 'coordenacao' then
    if not public._saude_senha_coord_ok(p_senha) then
      return json_build_object('success', false, 'message', 'Senha incorreta');
    end if;
  elsif p_modo = 'profissional' then
    if not public._saude_prof_ok(p_profissional_id, p_senha) then
      return json_build_object('success', false, 'message', 'Senha incorreta');
    end if;
  else
    return json_build_object('success', false, 'message', 'Modo inválido');
  end if;

  select co.id, co.data_consulta, co.hora_inicio, co.duracao_min,
         co.tipo_atendimento, co.observacoes, co.numero_sessao, co.tipo_cobranca,
         co.nome_paciente, co.telefone as telefone_paciente, co.paciente_id,
         co.profissional_id,
         pa.email as email_paciente,
         pr.nome  as profissional_nome,
         pr.cargo as profissional_cargo,
         pr.email as profissional_email,
         pr.telefone as profissional_telefone
    into c
    from public.consultas_agendadas co
    join public.profissionais_saude pr on pr.id = co.profissional_id
    left join public.pacientes_crmap pa on pa.id = co.paciente_id
   where co.id = p_consulta_id;

  if c.id is null then
    return json_build_object('success', false, 'message', 'Consulta não encontrada.');
  end if;

  -- Uma profissional só avisa as consultas dela.
  if p_modo = 'profissional' and c.profissional_id <> p_profissional_id then
    return json_build_object('success', false, 'message', 'Esta consulta não é sua.');
  end if;

  -- Guarda o e-mail que a terapeuta acabou de digitar, para os próximos
  -- avisos já saírem sem ela precisar redigitar.
  if v_email <> '' and position('@' in v_email) > 1 then
    update public.pacientes_crmap set email = v_email where id = c.paciente_id;
    c.email_paciente := v_email;
  end if;

  return json_build_object(
    'success', true,
    'consulta_id',      c.id,
    'data',             to_char(c.data_consulta, 'YYYY-MM-DD'),
    'hora',             to_char(c.hora_inicio, 'HH24:MI'),
    'duracao_min',      coalesce(c.duracao_min, 50),
    'tipo_atendimento', c.tipo_atendimento,
    'observacoes',      c.observacoes,
    'numero_sessao',    c.numero_sessao,
    'tipo_cobranca',    c.tipo_cobranca,
    'paciente_nome',     c.nome_paciente,
    'paciente_telefone', c.telefone_paciente,
    'paciente_email',    nullif(trim(coalesce(c.email_paciente, '')), ''),
    'profissional_nome',     c.profissional_nome,
    'profissional_cargo',    c.profissional_cargo,
    'profissional_email',    nullif(trim(coalesce(c.profissional_email, '')), ''),
    'profissional_telefone', c.profissional_telefone
  );
end;
$$;

-- ============================================================================
-- Permissões — NENHUM grant para o navegador.
-- Com grant para anon, qualquer pessoa leria nome, telefone e e-mail de
-- qualquer paciente só chutando o número da consulta.
-- ============================================================================
revoke all on function public._aviso_consulta(text, text, bigint, bigint, text)
  from public, anon, authenticated;

-- ============================================================================
-- Conferência (roda depois; não muda nada)
-- ============================================================================
-- Quantas pacientes já têm e-mail:
--   select count(*) filter (where coalesce(trim(email),'') <> '') as com_email,
--          count(*) as total
--     from public.pacientes_crmap;
