/**
 * GOOGLE APPS SCRIPT - BACKEND SEGURO CRMAP
 * 
 * Este script processa pagamentos do Mercado Pago e integra com Supabase e Google Sheets.
 * O Token de acesso não é exposto no site, apenas o Google tem acesso a ele.
 */

const MP_ACCESS_TOKEN = "APP_USR-34c58bdf-0820-4d12-91c3-0a615de9117d";
const SUPABASE_URL = "https://qzjvzbvoxwhggvadaroq.supabase.co";
const SUPABASE_KEY = "sb_publishable_LAlIOr94LYGTN8-BvHuT1A_BC1xScEQ"; // Pode ser a chave pública ou service role se necessário

function doPost(e) {
  const params = e.parameter;
  const action = params.action;

  // Lógica de CORS para navegadores
  const output = ContentService.createTextOutput();
  
  try {
    if (action === "create_preference") {
      return createPreference(params);
    } 
    else if (action === "webhook") {
      return handleWebhook(e.postData.contents);
    }
    else {
      // Lógica legada: Salvar na Planilha
      salvarNaPlanilha(params);
      return output.setMimeType(ContentService.MimeType.JSON).setContent(JSON.stringify({success: true}));
    }
  } catch (err) {
    return output.setMimeType(ContentService.MimeType.JSON).setContent(JSON.stringify({error: err.toString()}));
  }
}

/**
 * Cria o link de pagamento no Mercado Pago
 */
function createPreference(params) {
  const url = "https://api.mercadopago.com/checkout/preferences";
  const options = {
    method: "post",
    headers: {
      "Authorization": "Bearer " + MP_ACCESS_TOKEN,
      "Content-Type": "application/json"
    },
    payload: JSON.stringify({
      items: [{
        title: "Carteirinha CRMAP - " + params.nome,
        unit_price: 20.00,
        quantity: 1,
        currency_id: "BRL"
      }],
      external_reference: params.numero_credencial,
      back_urls: {
        success: params.origin + "/carteirinha.html?status=approved&num=" + params.numero_credencial,
        failure: params.origin + "/carteirinha.html?status=failure",
        pending: params.origin + "/carteirinha.html?status=pending"
      },
      auto_return: "approved"
    })
  };

  const response = UrlFetchApp.fetch(url, options);
  const data = JSON.parse(response.getContentText());
  
  // Registrar no Supabase como pendente
  registrarNoSupabase(params.nome, params.numero_credencial, "pending");

  return ContentService.createTextOutput(JSON.stringify({
    init_point: data.init_point,
    id: data.id
  })).setMimeType(ContentService.MimeType.JSON);
}

/**
 * Processa as notificações de pagamento do Mercado Pago
 */
function handleWebhook(contents) {
  const data = JSON.parse(contents);
  
  if (data.type === "payment" || data.action === "payment.created" || data.action === "payment.updated") {
    const paymentId = data.data ? data.data.id : data.id;
    
    // Consultar detalhes do pagamento
    const url = "https://api.mercadopago.com/v1/payments/" + paymentId;
    const options = {
      headers: { "Authorization": "Bearer " + MP_ACCESS_TOKEN }
    };
    
    const response = UrlFetchApp.fetch(url, options);
    const paymentData = JSON.parse(response.getContentText());
    
    if (paymentData.status === "approved") {
      const numeroCredencial = paymentData.external_reference;
      // Atualizar no Supabase para 'approved'
      registrarNoSupabase(null, numeroCredencial, "approved");
    }
  }
  
  return ContentService.createTextOutput("OK").setMimeType(ContentService.MimeType.TEXT);
}

function registrarNoSupabase(nome, numero, status) {
  const url = SUPABASE_URL + "/rest/v1/pagamentos_carteirinha";
  const headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": "Bearer " + SUPABASE_KEY,
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
  };

  const payload = {
    numero_credencial: numero,
    status: status
  };
  
  if (nome) payload.nome_pagador = nome;
  payload.valor = 20.00;

  const options = {
    method: "post",
    headers: headers,
    payload: JSON.stringify(payload)
  };

  UrlFetchApp.fetch(url, options);
}

function salvarNaPlanilha(params) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  sheet.appendRow([new Date(), params.numero, params.nome, params.data, "R$ 20,00"]);
}
