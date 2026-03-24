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

// Configuração do Multer para salvar fotos na pasta de produtos do site
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, path.join(__dirname, '../produtos'));
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'prod-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

// Rota para cadastrar produto
app.post('/api/produtos', upload.single('foto'), (req, res) => {
  const { nome, descricao, preco, whatsapp } = req.body;
  const fotoPath = req.file ? req.file.filename : 'foto-padrao.jpg';
  
  // Limpar WhatsApp (apenas números)
  const whatsappLimpo = whatsapp.replace(/\D/g, '');
  
  // Criar o HTML do novo card
  const novoCardHtml = `
        <!-- INÍCIO DO PRODUTO -->
        <div class="card" style="border-top-color: #1b7340; max-width: 320px; padding: 1.5rem;">
          <img src="${fotoPath}" alt="${nome}" style="width: 100%; height: 250px; object-fit: cover; border-radius: 8px; margin-bottom: 1rem; background-color: #f0f7f2;">
          <h4>${nome}</h4>
          <p style="margin-bottom: 0.5rem; font-weight: bold; color: #1b7340;">R$ ${preco}</p>
          <p style="margin-bottom: 1.5rem;">${descricao}</p>
          <a href="https://wa.me/${whatsappLimpo}?text=Olá,%20gostaria%20de%20saber%20mais%20sobre%20o%20${encodeURIComponent(nome)}" target="_blank" class="btn-secondary" style="font-size: 0.95rem; padding: 0.6rem 1.2rem; width: 100%; display: flex; justify-content: center; align-items: center; gap: 0.5rem; border-color: #25D366; color: #25D366; text-decoration: none; border-radius: 30px; border: 2px solid #25D366;">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 16 16">
              <path d="M13.601 2.326A7.854 7.854 0 0 0 7.994 0C3.627 0 .068 3.558.064 7.926c0 1.399.366 2.76 1.057 3.965L0 16l4.204-1.102a7.933 7.933 0 0 0 3.79.965h.004c4.368 0 7.926-3.558 7.93-7.93A7.898 7.898 0 0 0 13.6 2.326zM7.994 14.521a6.573 6.573 0 0 1-3.356-.92l-.24-.144-2.494.654.666-2.433-.156-.251a6.56 6.56 0 0 1-1.007-3.505c0-3.626 2.957-6.584 6.591-6.584a6.56 6.56 0 0 1 4.66 1.931 6.557 6.557 0 0 1 1.928 4.66c-.004 3.639-2.961 6.592-6.592 6.592zm3.615-4.934c-.197-.099-1.17-.578-1.353-.646-.182-.065-.315-.099-.445.099-.133.197-.513.646-.627.775-.114.133-.232.148-.43.05-.197-.1-.836-.308-1.592-.985-.59-.525-.985-1.175-1.103-1.372-.114-.198-.011-.304.088-.403.087-.088.197-.232.296-.346.1-.114.133-.198.198-.33.065-.134.034-.248-.015-.347-.05-.099-.445-1.076-.612-1.47-.16-.389-.323-.335-.445-.34-.114-.007-.247-.007-.38-.007a.729.729 0 0 0-.529.247c-.182.198-.691.677-.691 1.654 0 .977.71 1.916.81 2.049.098.133 1.394 2.132 3.383 2.992.47.205.84.326 1.129.418.475.152.904.129 1.246.08.38-.058 1.171-.48 1.338-.943.164-.464.164-.86.114-.943-.049-.084-.182-.133-.38-.232z"/>
            </svg>
            Comprar (WhatsApp)
          </a>
        </div>
        <!-- FIM DO PRODUTO -->
        
        <!-- ++ NOVO PRODUTO AQUI ++ -->`;

  const htmlPath = path.join(__dirname, '../produtos/index.html');
  
  try {
    let content = fs.readFileSync(htmlPath, 'utf8');
    content = content.replace('<!-- ++ NOVO PRODUTO AQUI ++ -->', novoCardHtml);
    fs.writeFileSync(htmlPath, content, 'utf8');
    
    // Automatizar o Git Push
    exec('git add . && git commit -m "Novo produto adicionado via Painel: ' + nome + '" && git push origin main', { cwd: path.join(__dirname, '..') }, (error, stdout, stderr) => {
      if (error) {
        console.error('Erro no Git:', error);
        return res.status(500).json({ success: true, message: 'Produto salvo localmente, mas erro ao enviar para o site (Git).', error: stderr });
      }
      res.json({ success: true, message: 'Produto publicado com sucesso no site!' });
    });
    
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, message: 'Erro ao salvar o arquivo HTML.' });
  }
});

app.listen(port, () => {
  console.log(`Painel administrativo rodando em http://localhost:${port}`);
});
