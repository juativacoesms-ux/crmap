-- ============================================================================
-- CRMAP — rodapé e página da carteirinha                        28/08/2026
-- ============================================================================
-- Últimos pedaços de texto abertos para a diretora.
--
-- O telefone do rodapé da campanha é um LINK e ficou de fora: trocá-lo por
-- texto apagaria o link do WhatsApp. Só o endereço virou editável, dentro de
-- um <span> próprio ao lado dele.
--
-- Os nomes do MENU não foram abertos de propósito: eles orientam quem visita
-- e um nome trocado sem querer atrapalha a navegação do site inteiro. Se for
-- preciso mudar, é pedido para quem mexe no código.
-- ============================================================================
insert into public.conteudo_site (chave, valor, rotulo, grupo, ordem, linhas, tipo) values
  ('carteirinha.titulo', 'Gerar Carteirinha Guardiã',
   'Título da página', 'Página da Carteirinha', 1, 1, 'texto'),
  ('carteirinha.texto', 'Preencha seus dados abaixo, adicione uma foto de perfil e gere sua carteirinha digital da CRMAP instantaneamente.',
   'Texto de apresentação', 'Página da Carteirinha', 2, 3, 'texto'),

  ('rodape.copyright', '© 2026 CRMAP – Centro de Referência das Mulheres Atingidas do Paraopeba. Todos os direitos reservados.',
   'Linha de direitos (página inicial)', 'Rodapé', 1, 3, 'texto'),
  ('rodape.endereco', 'Avenida Beira Rio 13, Fazendinhas Baú, Pompéu – MG',
   'Endereço (rodapé da campanha)', 'Rodapé', 2, 2, 'texto'),

  ('produtos.aviso', 'O CRMAP (Centro de Referência das Mulheres Atingidas do Paraopeba) não realiza vendas, não intermedeia pagamentos e não aufere renda por meio da cooperativa solidária. Esta possui caráter exclusivamente de apoio e divulgação, sendo cada produtor integralmente responsável por seus produtos, negociações, recebimentos e entregas.',
   'Aviso legal do rodapé', 'Página Produtos', 3, 6, 'texto')
on conflict (chave) do nothing;
