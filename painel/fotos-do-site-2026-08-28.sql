-- ============================================================================
-- CRMAP — a diretora troca as FOTOS do site                     28/08/2026
-- ============================================================================
-- Completa a edição de textos: agora também imagem.
--
-- Onde a foto fica: bucket 'fotos-site' no Storage, separado do
-- 'fotos-produtos'. Este novo já nasce com limite de 5 MB por arquivo e só
-- aceita imagem — o de produtos não tem limite nenhum, o que deixa o
-- armazenamento aberto a abuso.
--
-- O que é guardado em conteudo_site é o ENDEREÇO público da foto. Para não
-- permitir apontar o site para uma imagem de qualquer lugar da internet, a
-- função só aceita endereço do Storage deste projeto.
-- ============================================================================

alter table public.conteudo_site
  add column if not exists tipo text not null default 'texto';

alter table public.conteudo_site
  drop constraint if exists conteudo_site_tipo_valido;
alter table public.conteudo_site
  add constraint conteudo_site_tipo_valido check (tipo in ('texto', 'imagem'));

-- ------------------------------------------------------------ o bucket novo
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos-site', 'fotos-site', true, 5242880,
        array['image/jpeg','image/png','image/webp','image/gif'])
on conflict (id) do update
  set public = true,
      file_size_limit = 5242880,
      allowed_mime_types = array['image/jpeg','image/png','image/webp','image/gif'];

-- ------------------------------------- a função passa a entender foto também
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
  v_valor  text := coalesce(p_valor, '');
  v_rotulo text;
  v_tipo   text;
  c_storage constant text := 'https://qzjvzbvoxwhggvadaroq.supabase.co/storage/v1/object/public/';
begin
  if not public._senha_painel_ok(p_senha) then
    return json_build_object('success', false, 'message', 'Senha incorreta');
  end if;

  select rotulo, tipo into v_rotulo, v_tipo
    from public.conteudo_site where chave = p_chave;
  if v_rotulo is null then
    return json_build_object('success', false,
      'message', 'Esse pedaço do site não existe na lista. Nada foi alterado.');
  end if;

  if trim(v_valor) = '' then
    return json_build_object('success', false,
      'message', 'Não pode ficar vazio. Se quiser esconder algo, avise a Iara.');
  end if;

  if v_tipo = 'imagem' then
    -- Só endereço de foto guardada no nosso próprio Storage. Sem isso, um
    -- endereço qualquer da internet poderia ser colocado na página.
    if position(c_storage in v_valor) <> 1 then
      return json_build_object('success', false,
        'message', 'Endereço de foto inválido. Envie a foto pelo botão, não cole endereço.');
    end if;
    if length(v_valor) > 500 then
      return json_build_object('success', false, 'message', 'Endereço da foto muito longo.');
    end if;
  else
    if length(v_valor) > 2000 then
      return json_build_object('success', false,
        'message', 'Texto muito longo (limite de 2000 letras).');
    end if;
  end if;

  update public.conteudo_site
     set valor = v_valor, atualizado_em = now()
   where chave = p_chave;

  return json_build_object('success', true,
    'message', v_rotulo || ' foi salvo. Aparece no site em alguns instantes.');
end;
$$;

grant execute on function public.salvar_conteudo_site(text, text, text) to anon, authenticated;

-- ------------------------------------- o painel precisa saber o tipo de cada
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
      'grupo', grupo, 'linhas', linhas, 'tipo', tipo
    ) order by grupo, ordem, chave), '[]'::json)
    from public.conteudo_site
  ));
end;
$$;

grant execute on function public.listar_conteudo_site(text) to anon, authenticated;

-- ---------------------------------------------- as fotos que ficam editáveis
insert into public.conteudo_site (chave, valor, rotulo, grupo, ordem, linhas, tipo) values
  ('home.capa.foto', 'fotopginicial.jpg',
   'Foto grande da capa', 'Capa da página inicial', 3, 1, 'imagem'),
  ('terreno.foto1', '../images/lote_doado/foto1.jpeg',
   'Foto 1', 'Página Terreno — fotos', 1, 1, 'imagem'),
  ('terreno.foto2', '../images/lote_doado/foto2.jpeg',
   'Foto 2', 'Página Terreno — fotos', 2, 1, 'imagem'),
  ('terreno.foto3', '../images/lote_doado/foto3.jpeg',
   'Foto 3', 'Página Terreno — fotos', 3, 1, 'imagem'),
  ('terreno.foto4', '../images/lote_doado/foto4.jpeg',
   'Foto 4', 'Página Terreno — fotos', 4, 1, 'imagem')
on conflict (chave) do nothing;
