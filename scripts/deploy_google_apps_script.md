# Publicar correção da planilha (Google Apps Script) — obrigatório uma vez

Teste em 22/05/2026: o App da Web publicado hoje responde com erro  
`Cannot read properties of null (reading 'getActiveSheet')` — por isso **nenhuma linha era gravada**.

O site e o Supabase já enviam os eventos corretos, mas a **lógica de upsert na planilha** só vale depois de colar e publicar o `google_apps_script.gs` abaixo.

1. Abra https://script.google.com e o projeto ligado à URL `/macros/s/AKfycbxta2QnUbWxVA9DRuy5NdKwSjDv_RjfIht0Qgt5C6CRnUlzZ_QnVB7G1V2DxamDMMLW/exec`
2. Substitua todo o código pelo ficheiro `google_apps_script.gs` deste repositório.
3. **Salvar** (Ctrl+S).
4. **Implantar** → **Nova implantação** → tipo **App da Web** → Executar como **Eu** → Quem tem acesso: **Qualquer pessoa**.
5. Use a mesma URL `/exec` (ou atualize `crmap-planilha-client.js` se mudar).

Colunas na planilha: **Pagamento** (PENDENTE / PAGO / Voluntário) e **Baixou** (SIM/NÃO).
