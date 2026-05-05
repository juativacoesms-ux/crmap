/*
  SEQUÊNCIA GLOBAL DE CARTEIRINHA (pago + voluntário)
  Rode no SQL Editor do Supabase (projeto CRMAP).

  Gera valores no formato 001/2026 (zeros à esquerda, ano em America/Sao_Paulo).
*/

CREATE TABLE IF NOT EXISTS public.carteirinha_contador_ano (
  ano integer PRIMARY KEY,
  ultimo bigint NOT NULL DEFAULT 0 CHECK (ultimo >= 0)
);

ALTER TABLE public.carteirinha_contador_ano ENABLE ROW LEVEL SECURITY;

-- Bloqueio explícito: só a função SECURITY DEFINER manipula a tabela.
REVOKE ALL ON public.carteirinha_contador_ano FROM PUBLIC;
REVOKE ALL ON public.carteirinha_contador_ano FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.reservar_proximo_numero_carteirinha()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  yr integer;
  n bigint;
BEGIN
  yr := (EXTRACT(YEAR FROM timezone('America/Sao_Paulo', clock_timestamp())))::integer;

  INSERT INTO public.carteirinha_contador_ano (ano, ultimo)
  VALUES (yr, 1)
  ON CONFLICT (ano) DO UPDATE
  SET ultimo = public.carteirinha_contador_ano.ultimo + 1
  RETURNING public.carteirinha_contador_ano.ultimo INTO n;

  RETURN lpad(n::text, 3, '0') || '/' || yr::text;
END;
$$;

REVOKE ALL ON FUNCTION public.reservar_proximo_numero_carteirinha() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reservar_proximo_numero_carteirinha() TO anon, authenticated;

/*
  Opcional — se já houver carteirinhas antigas emitidas pelo site, defina manualmente o contador:
  INSERT INTO public.carteirinha_contador_ano (ano, ultimo) VALUES (2026, 50)
  ON CONFLICT (ano) DO UPDATE SET ultimo = GREATEST(carteirinha_contador_ano.ultimo, EXCLUDED.ultimo);
*/
