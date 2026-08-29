-- ============================================================================
-- CRMAP — textos editáveis das OUTRAS páginas                   28/08/2026
-- ============================================================================
-- Complementa conteudo-site-2026-08-28.sql, que cobriu só a home.
-- Aqui entram: página da campanha, Ações, Terreno e Produtos.
--
-- Os valores abaixo são exatamente os textos que já estão publicados hoje.
-- Só foram marcados elementos de TEXTO PURO: parágrafos com link ou negrito
-- dentro ficaram de fora de propósito, porque a troca usa textContent e
-- apagaria o link.
-- ============================================================================
insert into public.conteudo_site (chave, valor, rotulo, grupo, ordem, linhas) values
  -- ---------------------------------------------------- página da campanha
  ('campanha.titulo1', '🏠 Uma Casa de Recomeços',
   'Título — primeira linha', 'Campanha da Casa — topo', 1, 1),
  ('campanha.titulo2', 'Apoie a Construção da Nossa Casa de Acolhimento',
   'Título — segunda linha', 'Campanha da Casa — topo', 2, 2),
  ('campanha.frase', '“Quando uma mulher se levanta, todas as outras se levantam com ela.”',
   'Frase de efeito', 'Campanha da Casa — topo', 3, 3),

  ('campanha.pix.titulo', '📱 Doe agora pelo PIX',
   'Título do bloco do PIX', 'Campanha da Casa — bloco do PIX', 1, 1),
  ('campanha.pix.texto', 'Escaneie o QR Code ou copie a chave. Você escolhe o valor.',
   'Texto do bloco do PIX', 'Campanha da Casa — bloco do PIX', 2, 2),

  ('campanha.porque.titulo', 'Por que esta casa',
   'Título da seção', 'Campanha da Casa — Por que esta casa', 1, 1),
  ('campanha.porque.texto', 'O CRMAP (Centro de Referência das Mulheres Atingidas da Bacia do Paraopeba e Três Marias) atua na linha de frente oferecendo escuta, suporte psicossocial, atendimento psicológico e projetos de autonomia financeira para centenas de mulheres. Mas para que o cuidado seja completo e contínuo, precisamos de um porto seguro físico.',
   'Primeiro parágrafo', 'Campanha da Casa — Por que esta casa', 2, 6),

  ('campanha.etapas.titulo', '🧱 Como sua doação será aplicada?',
   'Título da seção', 'Campanha da Casa — Etapas da obra', 1, 1),
  ('campanha.etapas.texto', 'Nossa campanha está dividida em etapas claras para garantir transparência absoluta:',
   'Texto de apresentação', 'Campanha da Casa — Etapas da obra', 2, 3),

  ('campanha.formas.titulo', '🔴 Faça parte dessa construção agora mesmo',
   'Título da seção', 'Campanha da Casa — Formas de ajudar', 1, 1),
  ('campanha.formas.texto', 'Cada tijolo conta. Escolha a forma mais fácil para você contribuir:',
   'Texto de apresentação', 'Campanha da Casa — Formas de ajudar', 2, 2),
  ('campanha.card1.titulo', '📱 Doação direta via PIX',
   'Card 1 — título', 'Campanha da Casa — Formas de ajudar', 3, 1),
  ('campanha.card1.texto', 'Abra o aplicativo do seu banco, escolha “Pagar com Chave PIX” ou escaneie o QR Code no topo desta página.',
   'Card 1 — texto', 'Campanha da Casa — Formas de ajudar', 4, 3),
  ('campanha.card2.titulo', '💳 Seja uma Guardiã Mantenedora',
   'Card 2 — título', 'Campanha da Casa — Formas de ajudar', 5, 1),
  ('campanha.card2.texto', 'Se você deseja apoiar nossa causa de forma contínua, ou fazer uma doação de fora da nossa região, emita sua Carteirinha Oficial de Guardiã do CRMAP atrelando seu cadastro a uma contribuição para a nossa obra.',
   'Card 2 — texto', 'Campanha da Casa — Formas de ajudar', 6, 4),
  ('campanha.card3.titulo', '📦 Doação de materiais de construção',
   'Card 3 — título', 'Campanha da Casa — Formas de ajudar', 7, 1),
  ('campanha.card3.texto', 'Se você está na região de Pompéu ou municípios vizinhos e deseja doar cimento, tijolos, ferragens ou acabamentos, fale com a nossa equipe de coordenação:',
   'Card 3 — texto', 'Campanha da Casa — Formas de ajudar', 8, 4),

  ('campanha.transparencia.titulo', '📊 Transparência e prestação de contas',
   'Título da seção', 'Campanha da Casa — Transparência', 1, 1),

  -- ------------------------------------------------------------ página Ações
  ('acoes.titulo', 'Transformando Vidas na Prática',
   'Título da capa', 'Página Ações', 1, 1),
  ('acoes.texto', 'Nossas ações no território fortalecem vínculos e promovem a autonomia das mulheres atingidas.',
   'Texto da capa', 'Página Ações', 2, 3),
  ('acoes.momentos.titulo', 'Nossos Momentos',
   'Título da galeria', 'Página Ações', 3, 1),
  ('acoes.arraia.titulo', 'Arraiá CRMAP',
   'Título do bloco do Arraiá', 'Página Ações', 4, 1),
  ('acoes.arraia.legenda', '25 de julho de 2026 &middot; Fazendinhas Baú, Pompéu (MG)',
   'Data e local do Arraiá', 'Página Ações', 5, 1),

  -- ---------------------------------------------------------- página Terreno
  ('terreno.titulo', 'Terreno doado à CRMAP',
   'Título da página', 'Página Terreno', 1, 1),
  ('terreno.texto', 'Registro fotográfico do terreno doado à instituição, um passo importante para fortalecer a estrutura da CRMAP e ampliar ações em prol das mulheres atingidas.',
   'Texto de apresentação', 'Página Terreno', 2, 4),

  -- --------------------------------------------------------- página Produtos
  ('produtos.titulo', 'Cooperativa Solidária',
   'Título da página', 'Página Produtos', 1, 1),
  ('produtos.texto', 'Produtos produzidos pelas atingidas da cooperativa. As compras são realizadas diretamente via WhatsApp.',
   'Texto de apresentação', 'Página Produtos', 2, 3)
on conflict (chave) do nothing;
