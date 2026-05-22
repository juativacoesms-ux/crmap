/* Rode no SQL Editor do Supabase — permite atualizar status no download */

DROP POLICY IF EXISTS "Site pode atualizar download" ON public.pagamentos_carteirinha;
CREATE POLICY "Site pode atualizar download"
ON public.pagamentos_carteirinha FOR UPDATE
USING (true)
WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.registrar_download_carteirinha(
  p_numero_credencial text,
  p_nome text,
  p_voluntario boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_numero_credencial IS NULL OR trim(p_numero_credencial) = '' THEN
    RETURN;
  END IF;

  UPDATE public.pagamentos_carteirinha
  SET
    nome_pagador = COALESCE(NULLIF(trim(p_nome), ''), nome_pagador),
    status = CASE
      WHEN p_voluntario THEN 'downloaded_voluntario'
      WHEN status = 'approved' THEN 'downloaded'
      ELSE COALESCE(status, 'downloaded')
    END
  WHERE numero_credencial = trim(p_numero_credencial);

  IF NOT FOUND THEN
    INSERT INTO public.pagamentos_carteirinha (nome_pagador, numero_credencial, valor, status)
    VALUES (
      NULLIF(trim(p_nome), ''),
      trim(p_numero_credencial),
      CASE WHEN p_voluntario THEN 0 ELSE 20 END,
      CASE WHEN p_voluntario THEN 'downloaded_voluntario' ELSE 'downloaded' END
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.registrar_download_carteirinha(text, text, boolean) TO anon, authenticated;
