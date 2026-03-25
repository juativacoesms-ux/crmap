/* 
  SCRIPT DE CORREÇÃO - COPIE TUDO E RODE NO SQL EDITOR
*/

-- 1. Remover políticas antigas para evitar erro de duplicidade
DROP POLICY IF EXISTS "Acesso público para leitura" ON public.produtos;

-- 2. Recriar a política de leitura pública
CREATE POLICY "Acesso público para leitura" ON public.produtos FOR SELECT USING (true);

-- 3. Criar a política de inserção via Service Role (necessário para a função SECURITY DEFINER funcionar bem)
-- Em Supabase, SECURITY DEFINER costuma ignorar RLS, mas vamos garantir:
ALTER TABLE public.produtos FORCE ROW LEVEL SECURITY;
CREATE POLICY "Função segura pode gerenciar" ON public.produtos FOR ALL USING (true) WITH CHECK (true);

-- 4. REINSTALAR A FUNÇÃO (Garantindo que ela exista)
CREATE OR REPLACE FUNCTION public.gerenciar_produto(
    p_acao text,
    p_senha text,
    p_id bigint DEFAULT NULL,
    p_nome text DEFAULT NULL,
    p_descricao text DEFAULT NULL,
    p_preco text DEFAULT NULL,
    p_whatsapp text DEFAULT NULL,
    p_foto_url text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER -- ATENÇÃO: Isso aqui faz a função ter "super poderes" para pular o RLS
AS $$
BEGIN
    IF p_senha <> '270797crmap*' THEN
        RETURN json_build_object('success', false, 'message', 'Senha incorreta');
    END IF;

    IF p_acao = 'inserir' THEN
        INSERT INTO public.produtos (nome, descricao, preco, whatsapp, foto_url)
        VALUES (p_nome, p_descricao, p_preco, p_whatsapp, p_foto_url);
        RETURN json_build_object('success', true, 'message', 'Produto adicionado!');
    
    ELSIF p_acao = 'deletar' THEN
        DELETE FROM public.produtos WHERE id = p_id;
        RETURN json_build_object('success', true, 'message', 'Produto removido!');
    ELSE
        RETURN json_build_object('success', false, 'message', 'Ação inválida');
    END IF;
END;
$$;

-- 5. PERMISSÃO DE STORAGE (Para as fotos aparecerem e serem enviadas)
-- No menu STORAGE, clique em "Policies" no bucket 'fotos-produtos' e:
--   a) Adicione uma política de "SELECT" para "Public" (Anon).
--   b) Adicione uma política de "INSERT" para "Public" (Anon).
