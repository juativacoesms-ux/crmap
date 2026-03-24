const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { exec } = require('child_process');
const cors = require('cors');

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

const DATA_FILE = path.join(__dirname, 'data/products.json');
const HTML_FILE = path.join(__dirname, '../produtos/index.html');

// Configuração do Multer para fotos
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, '../produtos')),
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'prod-' + uniqueSuffix + path.extname(file.originalname));
  }
});
const upload = multer({ storage });

// Função para regenerar o HTML do site
function regenerarSite() {
  const produtos = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  let cardsHtml = produtos.map(p => `
        <div class="card" id="card-${p.id}" style="border-top-color: #1b7340; max-width: 320px; padding: 1.5rem;">
          <img src="${p.foto}" alt="${p.nome}" style="width: 100%; height: 250px; object-fit: cover; border-radius: 8px; margin-bottom: 1rem; background-color: #f0f7f2;">
          <h4>${p.nome}</h4>
          <p style="margin-bottom: 0.5rem; font-weight: bold; color: #1b7340;">R$ ${p.preco}</p>
          <p style="margin-bottom: 1.5rem;">${p.descricao}</p>
          <a href="https://wa.me/${p.whatsapp.replace(/\D/g, '')}?text=Olá,%20gostaria%20de%20saber%20mais%20sobre%20o%20${encodeURIComponent(p.nome)}" target="_blank" class="btn-secondary" style="font-size: 0.95rem; padding: 0.6rem 1.2rem; width: 100%; display: flex; justify-content: center; align-items: center; gap: 0.5rem; border-color: #25D366; color: #25D366; text-decoration: none; border-radius: 30px; border: 2px solid #25D366;">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 16 16">
              <path d="M13.601 2.326A7.854 7.854 0 0 0 7.994 0C3.627 0 .068 3.558.064 7.926c0 1.399.366 2.76 1.057 3.965L0 16l4.204-1.102a7.933 7.933 0 0 0 3.79.965h.004c4.368 0 7.926-3.558 7.93-7.93A7.898 7.898 0 0 0 13.6 2.326zM7.994 14.521a6.573 6.573 0 0 1-3.356-.92l-.24-.144-2.494.654.666-2.433-.156-.251a6.56 6.56 0 0 1-1.007-3.505c0-3.626 2.957-6.584 6.591-6.584a6.56 6.56 0 0 1 4.66 1.931 6.557 6.557 0 0 1 1.928 4.66c-.004 3.639-2.961 6.592-6.592 6.592zm3.615-4.934c-.197-.099-1.17-.578-1.353-.646-.182-.065-.315-.099-.445.099-.133.197-.513.646-.627.775-.114.133-.232.148-.43.05-.197-.1-.836-.308-1.592-.985-.59-.525-.985-1.175-1.103-1.372-.114-.198-.011-.304.088-.403.087-.088.197-.232.296-.346.1-.114.133-.198.198-.33.065-.134.034-.248-.015-.347-.05-.099-.445-1.076-.612-1.47-.16-.389-.323-.335-.445-.34-.114-.007-.247-.007-.38-.007a.729.729 0 0 0-.529.247c-.182.198-.691.677-.691 1.654 0 .977.71 1.916.81 2.049.098.133 1.394 2.132 3.383 2.992.47.205.84.326 1.129.418.475.152.904.129 1.246.08.38-.058 1.171-.48 1.338-.943.164-.464.164-.86.114-.943-.049-.084-.182-.133-.38-.232z"/>
            </svg>
            Comprar (WhatsApp)
          </a>
        </div>`).join('\n');

  let content = fs.readFileSync(HTML_FILE, 'utf8');
  const regex = /<!-- START PRODUCTS -->([\s\S]*?)<!-- END PRODUCTS -->/;
  content = content.replace(regex, `<!-- START PRODUCTS -->\n${cardsHtml}\n        <!-- END PRODUCTS -->`);
  fs.writeFileSync(HTML_FILE, content, 'utf8');
}

// Rota: Listar Produtos
app.get('/api/produtos', (req, res) => {
  const produtos = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  res.json(produtos);
});

// Rota: Adicionar Produto
app.post('/api/produtos', upload.single('foto'), (req, res) => {
  const { nome, descricao, preco, whatsapp } = req.body;
  const produtos = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  
  const novo = {
    id: Date.now().toString(),
    nome, descricao, preco, whatsapp,
    foto: req.file ? req.file.filename : 'foto-padrao.jpg'
  };
  
  produtos.unshift(novo);
  fs.writeFileSync(DATA_FILE, JSON.stringify(produtos, null, 2));
  
  regenerarSite();
  
  exec('git add . && git commit -m "Adiciona ' + nome + '" && git push origin main', { cwd: path.join(__dirname, '..') }, (err) => {
    res.json({ success: true, message: 'Publicado!' });
  });
});

// Rota: Excluir Produto
app.delete('/api/produtos/:id', (req, res) => {
  const id = req.params.id;
  let produtos = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
  
  const removido = produtos.find(p => p.id === id);
  if (!removido) return res.status(404).json({ success: false });
  
  produtos = produtos.filter(p => p.id !== id);
  fs.writeFileSync(DATA_FILE, JSON.stringify(produtos, null, 2));
  
  regenerarSite();
  
  exec('git add . && git commit -m "Remove produto" && git push origin main', { cwd: path.join(__dirname, '..') }, () => {
    res.json({ success: true, message: 'Removido com sucesso!' });
  });
});

app.listen(port, () => console.log(`Rodando em http://localhost:${port}`));
