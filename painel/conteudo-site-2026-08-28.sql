-- ============================================================================
-- CRMAP — a diretora edita frases e cards do site               28/08/2026
-- ============================================================================
-- Pedido da Iara: "quero que ela possa editar o site, trocar frases, cards".
-- Hoje qualquer vírgula da home exige mexer no HTML e publicar.
--
-- Como funciona, e por que assim:
--   O texto ORIGINAL continua escrito dentro do index.html. O banco guarda
--   apenas o que foi alterado, e o site troca depois de carregar. Se o
--   JavaScript falhar (internet ruim, celular antigo, bloqueador), a página
--   mostra o texto original em vez de ficar vazia — a mesma regra da página
--   de doação, decidida em 31/07/2026.
--
--   O site LÊ sem senha (é conteúdo público). Só a ESCRITA pede a senha.
-- ============================================================================

create table if not exists public.conteudo_site (
  chave          text primary key,
  valor          text not null,
  rotulo         text not null,          -- o nome que a diretora vê na tela
  grupo          text not null,          -- para agrupar na tela do painel
  ordem          integer not null default 0,
  linhas         integer not null default 1,  -- 1 = campo curto; >1 = caixa de texto
  atualizado_em  timestamptz not null default now()
);

alter table public.conteudo_site enable row level security;

-- Leitura pública: é o conteúdo do site, aparece para qualquer visitante.
-- Escrita: ninguém direto na tabela; só pela função, que confere a senha.
drop policy if exists "conteudo_site leitura publica" on public.conteudo_site;
create policy "conteudo_site leitura publica"
  on public.conteudo_site for select to anon, authenticated using (true);

revoke insert, update, delete on public.conteudo_site from anon, authenticated;
grant select on public.conteudo_site to anon, authenticated;

-- ---------------------------------------------------------------- o site lê
create or replace function public.conteudo_site_publico()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(json_object_agg(chave, valor), '{}'::json) from public.conteudo_site;
$$;

grant execute on function public.conteudo_site_publico() to anon, authenticated;

-- ------------------------------------------------------- o painel lê e grava
create or replace function public.listar_conteudo_site(p_senha text)
returns json
language plpgsql
stable
security definer
set search_path = public, extensions
as $$
begin
  if not public._senha_painel_ok(p_senha) then
    return json_build_object('success', false, 'message', 'Senha incorreta');
  end if;
  return json_build_object('success', true, 'itens', (
    select coalesce(json_agg(json_build_object(
      'chave', chave, 'valor', valor, 'rotulo', rotulo,
      'grupo', grupo, 'linhas', linhas
    ) order by grupo, ordem, chave), '[]'::json)
    from public.conteudo_site
  ));
end;
$$;

grant execute on function public.listar_conteudo_site(text) to anon, authenticated;

create or replace function public.salvar_conteudo_site(
  p_senha text,
  p_chave text,
  p_valor text
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_valor text := coalesce(p_valor, '');
  v_rotulo text;
begin
  if not public._senha_painel_ok(p_senha) then
    return json_build_object('success', false, 'message', 'Senha incorreta');
  end if;

  select rotulo into v_rotulo from public.conteudo_site where chave = p_chave;
  if v_rotulo is null then
    return json_build_object('success', false,
      'message', 'Esse pedaço do site não existe na lista. Nada foi alterado.');
  end if;

  -- Texto vazio deixaria um buraco na página. Melhor recusar e explicar.
  if trim(v_valor) = '' then
    return json_build_object('success', false,
      'message', 'O texto não pode ficar vazio. Se quiser esconder algo, avise a Iara.');
  end if;

  if length(v_valor) > 2000 then
    return json_build_object('success', false,
      'message', 'Texto muito longo (limite de 2000 letras).');
  end if;

  update public.conteudo_site
     set valor = v_valor, atualizado_em = now()
   where chave = p_chave;

  return json_build_object('success', true,
    'message', v_rotulo || ' foi salvo. Aparece no site em alguns instantes.');
end;
$$;

grant execute on function public.salvar_conteudo_site(text, text, text) to anon, authenticated;

-- ============================================================================
-- Carga inicial: exatamente os textos que já estão na home hoje (28/08/2026).
-- Assim a tela do painel nasce mostrando o que está publicado, e a diretora
-- edita a partir do texto real em vez de campos vazios.
-- ============================================================================
insert into public.conteudo_site (chave, valor, rotulo, grupo, ordem, linhas) values
  ('home.capa.titulo', 'Transformando Realidades',
   'Título grande da capa', 'Capa da página inicial', 1, 1),
  ('home.capa.frase', 'Apoiamos e fortalecemos mulheres atingidas, promovendo autonomia, direitos e dignidade.',
   'Frase abaixo do título', 'Capa da página inicial', 2, 3),

  ('home.campanha.selo', '🧱 Campanha aberta',
   'Etiqueta da campanha', 'Bloco da campanha da Casa', 1, 1),
  ('home.campanha.titulo', '🏠 Ajude a construir a Casa de Acolhimento',
   'Título da campanha', 'Bloco da campanha da Casa', 2, 2),
  ('home.campanha.texto', 'Um refúgio seguro para as mulheres atingidas da Bacia do Paraopeba e Três Marias, no terreno doado em Pompéu/MG. Doe pelo PIX — você escolhe o valor.',
   'Texto da campanha', 'Bloco da campanha da Casa', 3, 4),
  ('home.campanha.botao', 'Quero ajudar a construir',
   'Texto do botão', 'Bloco da campanha da Casa', 4, 1),

  ('home.identidade.titulo', 'Nossa Identidade',
   'Título da seção', 'Seção Nossa Identidade', 1, 1),

  ('home.pilares.titulo', 'Pilares de Atuação',
   'Título da seção', 'Seção Pilares de Atuação', 1, 1),
  ('home.pilares.texto', 'O CRMAP atua em diversas frentes estatutárias para apoiar, fortalecer e promover o desenvolvimento comunitário e individual das mulheres.',
   'Texto abaixo do título', 'Seção Pilares de Atuação', 2, 3),

  ('home.pilar1.titulo', 'Apoio em Saúde Mental',
   'Card 1 — título', 'Seção Pilares de Atuação', 3, 1),
  ('home.pilar1.texto', 'Atendimento psicológico, psicanalítico e social, visando o acolhimento e fortalecimento das mulheres atingidas.',
   'Card 1 — texto', 'Seção Pilares de Atuação', 4, 3),
  ('home.pilar2.titulo', 'Geração de Renda',
   'Card 2 — título', 'Seção Pilares de Atuação', 5, 1),
  ('home.pilar2.texto', 'Iniciativas de impacto, incluindo cooperativa solidária, feiras, horta comunitária e projetos estruturantes.',
   'Card 2 — texto', 'Seção Pilares de Atuação', 6, 3),
  ('home.pilar3.titulo', 'Formação e Projetos',
   'Card 3 — título', 'Seção Pilares de Atuação', 7, 1),
  ('home.pilar3.texto', 'Desenvolvimento de oficinas, cursos, Farmácia Viva e programas educacionais focados na autonomia.',
   'Card 3 — texto', 'Seção Pilares de Atuação', 8, 3),
  ('home.pilar4.titulo', 'Defesa de Direitos',
   'Card 4 — título', 'Seção Pilares de Atuação', 9, 1),
  ('home.pilar4.texto', 'Representação institucional, defesa de políticas públicas e reparação justa e igualitária na Bacia do Paraopeba.',
   'Card 4 — texto', 'Seção Pilares de Atuação', 10, 3)
on conflict (chave) do nothing;
