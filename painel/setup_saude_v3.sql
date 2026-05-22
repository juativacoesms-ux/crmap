/*
  SAÚDE v3 — cadastro da profissional + login por WhatsApp/telefone
  Rode após setup_saude_v2.sql
*/

ALTER TABLE public.profissionais_saude
  ADD COLUMN IF NOT EXISTS telefone text,
  ADD COLUMN IF NOT EXISTS telefone_norm text,
  ADD COLUMN IF NOT EXISTS email text;

CREATE UNIQUE INDEX IF NOT EXISTS idx_profissionais_telefone_norm
  ON public.profissionais_saude (telefone_norm)
  WHERE telefone_norm IS NOT NULL AND telefone_norm <> '';

CREATE OR REPLACE FUNCTION public.cadastrar_profissional_saude(
  p_nome text,
  p_cargo text,
  p_telefone text,
  p_senha text,
  p_email text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_norm text;
  v_id bigint;
  v_ordem integer;
BEGIN
  IF length(trim(COALESCE(p_senha, ''))) < 6 THEN
    RETURN json_build_object('success', false, 'message', 'Senha com no mínimo 6 caracteres.');
  END IF;
  IF trim(COALESCE(p_nome, '')) = '' OR trim(COALESCE(p_cargo, '')) = '' THEN
    RETURN json_build_object('success', false, 'message', 'Nome e função/cargo são obrigatórios.');
  END IF;

  v_norm := public._normalizar_telefone(p_telefone);
  IF v_norm IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'WhatsApp/telefone inválido.');
  END IF;

  IF EXISTS (SELECT 1 FROM public.profissionais_saude WHERE telefone_norm = v_norm) THEN
    RETURN json_build_object('success', false, 'message', 'Este WhatsApp já está cadastrado. Use Entrar.');
  END IF;

  SELECT COALESCE(max(ordem), 0) + 1 INTO v_ordem FROM public.profissionais_saude;

  INSERT INTO public.profissionais_saude (nome, cargo, telefone, telefone_norm, email, senha_acesso, ativo, ordem)
  VALUES (
    trim(p_nome),
    trim(p_cargo),
    trim(p_telefone),
    v_norm,
    NULLIF(trim(p_email), ''),
    p_senha,
    true,
    v_ordem
  )
  RETURNING id INTO v_id;

  RETURN json_build_object(
    'success', true,
    'profissional_id', v_id,
    'message', 'Cadastro realizado. Use seu WhatsApp e senha para entrar.'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.login_profissional_telefone(
  p_telefone text,
  p_senha text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_norm text;
  v_row record;
BEGIN
  v_norm := public._normalizar_telefone(p_telefone);
  IF v_norm IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'WhatsApp/telefone inválido.');
  END IF;

  SELECT id, nome, cargo INTO v_row
  FROM public.profissionais_saude
  WHERE telefone_norm = v_norm AND ativo AND senha_acesso = p_senha;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'message', 'WhatsApp ou senha incorretos.');
  END IF;

  RETURN json_build_object(
    'success', true,
    'role', 'profissional',
    'profissional_id', v_row.id,
    'nome', v_row.nome,
    'cargo', v_row.cargo
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.listar_profissionais_coord_saude(p_senha text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public._saude_senha_coord_ok(p_senha) THEN
    RETURN json_build_object('success', false, 'message', 'Senha incorreta');
  END IF;

  RETURN json_build_object(
    'success', true,
    'profissionais', (
      SELECT COALESCE(json_agg(json_build_object(
        'id', id,
        'nome', nome,
        'cargo', cargo,
        'telefone', telefone,
        'email', email,
        'ativo', ativo,
        'ordem', ordem
      ) ORDER BY ordem, nome), '[]'::json)
      FROM public.profissionais_saude
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.cadastrar_profissional_saude(text, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.login_profissional_telefone(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.listar_profissionais_coord_saude(text) TO anon, authenticated;
