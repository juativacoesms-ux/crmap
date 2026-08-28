-- ============================================================================
-- CRMAP — a diretora troca a própria senha                     28/08/2026
-- ============================================================================
-- Até hoje a senha do painel só era trocada rodando `~/bin/senha-painel` no
-- terminal da Iara. Em 05/08/2026 a senha se perdeu e a diretora ficou sem
-- acesso até a Iara ter tempo de rodar o script. Isso não pode se repetir.
--
-- ATENÇÃO, e a tela precisa avisar isso: esta senha é a MESMA que abre
-- /painel/ e /saude/controle/. Trocar aqui troca as duas.
--
-- Exige a senha ATUAL. Sem isso, quem conseguisse abrir o painel esquecido
-- numa tela poderia trancar a diretora para fora.
-- ============================================================================

create or replace function public.trocar_senha_painel(
  p_senha_atual text,
  p_senha_nova  text
)
returns json
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_nova text := coalesce(p_senha_nova, '');
begin
  if not public._senha_painel_ok(p_senha_atual) then
    return json_build_object('success', false,
      'message', 'A senha atual não confere. Nada foi alterado.');
  end if;

  -- Espaço nas pontas é a causa clássica de "digitei certo e não entra".
  -- Aparar em silêncio deixaria a pessoa com senha diferente da que pensa.
  if v_nova <> trim(v_nova) then
    return json_build_object('success', false,
      'message', 'A senha nova não pode começar nem terminar com espaço.');
  end if;

  if length(v_nova) < 10 then
    return json_build_object('success', false,
      'message', 'A senha nova precisa ter pelo menos 10 caracteres.');
  end if;

  if v_nova = p_senha_atual then
    return json_build_object('success', false,
      'message', 'A senha nova é igual à atual. Escolha uma diferente.');
  end if;

  update public.painel_config
     set valor = crypt(v_nova, gen_salt('bf'))
   where chave = 'senha_painel_hash';

  if not found then
    return json_build_object('success', false,
      'message', 'Não encontrei onde a senha é guardada. Avise a Iara.');
  end if;

  return json_build_object('success', true,
    'message', 'Senha trocada. Ela vale para o Painel E para o Controle da Saúde. Anote em lugar seguro: ninguém consegue ver essa senha depois, nem eu.');
end;
$$;

grant execute on function public.trocar_senha_painel(text, text) to anon, authenticated;
