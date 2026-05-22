/*
  Corrige nomes/cargos com acentuação corrompida (??) na tabela profissionais_saude.
  Rode no SQL Editor do Supabase com encoding UTF-8.
*/

UPDATE public.profissionais_saude SET nome = 'Fátima Maria de Jesus Chaves Soares', cargo = 'Dra. em Psicanálise — Coord. Saúde Mental' WHERE id = 1;
UPDATE public.profissionais_saude SET nome = 'Jórsia Chaves Horta Nascimento', cargo = 'Psicanalista — Vice / Diretora Saúde Mental' WHERE id = 2;
UPDATE public.profissionais_saude SET nome = 'Rosilaine Ribeiro de Moura Rocha', cargo = 'Psicóloga' WHERE id = 3;
UPDATE public.profissionais_saude SET nome = 'Márcia Rodrigues Daian', cargo = 'Psicóloga' WHERE id = 4;
UPDATE public.profissionais_saude SET nome = 'Érika Danúbia da Silva', cargo = 'Assistente de Saúde' WHERE id = 5;

-- Corrige por padrão corrompido (caso IDs tenham mudado)
UPDATE public.profissionais_saude SET nome = 'Fátima Maria de Jesus Chaves Soares', cargo = 'Dra. em Psicanálise — Coord. Saúde Mental' WHERE nome LIKE 'F%tima%' OR nome LIKE 'F??tima%';
UPDATE public.profissionais_saude SET nome = 'Jórsia Chaves Horta Nascimento', cargo = 'Psicanalista — Vice / Diretora Saúde Mental' WHERE nome LIKE 'J%rsia%' OR nome LIKE 'J??rsia%';
UPDATE public.profissionais_saude SET nome = 'Márcia Rodrigues Daian', cargo = 'Psicóloga' WHERE nome LIKE 'M%rcia%' OR nome LIKE 'M??rcia%';
UPDATE public.profissionais_saude SET nome = 'Érika Danúbia da Silva', cargo = 'Assistente de Saúde' WHERE nome LIKE '%rika Dan%bia%' OR nome LIKE '??rika%';
UPDATE public.profissionais_saude SET cargo = 'Psicóloga' WHERE cargo LIKE 'Psic??loga%' OR cargo = 'Psic??loga';
UPDATE public.profissionais_saude SET cargo = REPLACE(REPLACE(cargo, 'Sa??de', 'Saúde'), 'Psican??lise', 'Psicanálise') WHERE cargo LIKE '%??%';
