/**
 * GOOGLE APPS SCRIPT - BACKEND SEGURO CRMAP
 *
 * Planilha (colunas): A=última atualização | B=número | C=nome | D=data emissão | E=status pagamento | F=voluntário | G=baixou
 *
 * DEPLOY: Cole no editor script.google.com, Salvar, Implantar > Nova implantação > App da Web > Executar como EU > Acesso: Qualquer pessoa.
 */

const MP_ACCESS_TOKEN = "APP_USR-5952635800834737-032621-b4f384773f3b340c4edaee6e08d0a250-3291408548";
const SUPABASE_URL = "https://qzjvzbvoxwhggvadaroq.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6anZ6YnZveHdoZ2d2YWRhcm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzOTA4NDEsImV4cCI6MjA4OTk2Njg0MX0.bTss42oILYSmAGP3vAP-9OQ1-qnKnZXbVxz2SDxWmW0";
const SPREADSHEET_ID = "1k1QTl5-OXekR_0MtWZRmd18RWLJn_SovZBV3MW9imak";
const SHEET_GID = 0;

const COL = {
  ATUALIZADO: 1,
  NUMERO: 2,
  NOME: 3,
  DATA_EMISSAO: 4,
  PAGAMENTO: 5,
  VOLUNTARIO: 6,
  BAIXOU: 7
};

function parseFormUrlEncoded_(raw) {
  var out = {};
  var pairs = String(raw).split("&");
  for (var i = 0; i < pairs.length; i++) {
    var pair = pairs[i];
    if (!pair) continue;
    var eq = pair.indexOf("=");
    var k = eq >= 0 ? pair.substring(0, eq) : pair;
    var v = eq >= 0 ? pair.substring(eq + 1) : "";
    k = decodeURIComponent(k.replace(/\+/g, " "));
    v = decodeURIComponent(v.replace(/\+/g, " "));
    out[k] = v;
  }
  return out;
}

function parsePostParams_(e) {
  e = e || {};
  var base = e.parameter || {};
  if (Object.keys(base).length > 0) {
    return base;
  }
  if (!e.postData || !e.postData.contents) {
    return {};
  }
  var raw = String(e.postData.contents).trim();
  if (!raw) {
    return {};
  }
  var ct = String(e.postData.type || "").toLowerCase();
  if (ct.indexOf("application/json") >= 0 || raw.charAt(0) === "{") {
    try {
      return JSON.parse(raw);
    } catch (err) {
      return {};
    }
  }
  if (raw.indexOf("=") >= 0) {
    return parseFormUrlEncoded_(raw);
  }
  try {
    return JSON.parse(raw);
  } catch (err2) {
    return {};
  }
}

function doPost(e) {
  e = e || {};
  var params = parsePostParams_(e);
  var action = params.action;
  var output = ContentService.createTextOutput();

  try {
    if (action === "create_preference") {
      return createPreference(params);
    }
    if (action === "webhook") {
      return handleWebhook(e.postData ? e.postData.contents : "");
    }
    salvarNaPlanilha(params);
    return output.setMimeType(ContentService.MimeType.JSON).setContent(JSON.stringify({ success: true }));
  } catch (err) {
    return output.setMimeType(ContentService.MimeType.JSON).setContent(JSON.stringify({ error: err.toString() }));
  }
}

function createPreference(params) {
  var url = "https://api.mercadopago.com/checkout/preferences";
  var options = {
    method: "post",
    headers: {
      Authorization: "Bearer " + MP_ACCESS_TOKEN,
      "Content-Type": "application/json"
    },
    payload: JSON.stringify({
      items: [{
        title: "Carteirinha CRMAP - " + params.nome,
        unit_price: 20.0,
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

  var response = UrlFetchApp.fetch(url, options);
  var data = JSON.parse(response.getContentText());

  registrarNoSupabase(params.nome, params.numero_credencial, "pending");
  salvarNaPlanilha({
    numero: params.numero_credencial,
    nome: params.nome,
    data: dataHojeBr_(),
    evento: "pagamento_pendente"
  });

  return ContentService.createTextOutput(JSON.stringify({
    init_point: data.init_point,
    id: data.id
  })).setMimeType(ContentService.MimeType.JSON);
}

function handleWebhook(contents) {
  var data = JSON.parse(contents || "{}");

  if (data.type === "payment" || data.action === "payment.created" || data.action === "payment.updated") {
    var paymentId = data.data ? data.data.id : data.id;
    var url = "https://api.mercadopago.com/v1/payments/" + paymentId;
    var response = UrlFetchApp.fetch(url, {
      headers: { Authorization: "Bearer " + MP_ACCESS_TOKEN }
    });
    var paymentData = JSON.parse(response.getContentText());

    if (paymentData.status === "approved") {
      var numeroCredencial = paymentData.external_reference;
      var nome =
        (paymentData.payer && paymentData.payer.first_name) ||
        (paymentData.additional_info && paymentData.additional_info.payer && paymentData.additional_info.payer.first_name) ||
        "";
      registrarNoSupabase(nome, numeroCredencial, "approved");
      salvarNaPlanilha({
        numero: numeroCredencial,
        nome: nome,
        data: dataHojeBr_(),
        evento: "pagamento_aprovado"
      });
    }
  }

  return ContentService.createTextOutput("OK").setMimeType(ContentService.MimeType.TEXT);
}

function registrarNoSupabase(nome, numero, status) {
  var url = SUPABASE_URL + "/rest/v1/pagamentos_carteirinha";
  var headers = {
    apikey: SUPABASE_KEY,
    Authorization: "Bearer " + SUPABASE_KEY,
    "Content-Type": "application/json",
    Prefer: "resolution=merge-duplicates"
  };

  var payload = {
    numero_credencial: numero,
    status: status,
    valor: 20.0
  };
  if (nome) payload.nome_pagador = nome;

  UrlFetchApp.fetch(url, {
    method: "post",
    headers: headers,
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  });
}

function dataHojeBr_() {
  var tz = Session.getScriptTimeZone() || "America/Sao_Paulo";
  return Utilities.formatDate(new Date(), tz, "dd/MM/yyyy");
}

function normalizarNumero_(numero) {
  return String(numero || "").trim().replace(/\s+/g, "");
}

function encontrarLinhaPorNumero_(sheet, numero) {
  var alvo = normalizarNumero_(numero);
  if (!alvo) return 0;
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return 0;
  var valores = sheet.getRange(2, COL.NUMERO, lastRow - 1, 1).getValues();
  for (var i = 0; i < valores.length; i++) {
    if (normalizarNumero_(valores[i][0]) === alvo) {
      return i + 2;
    }
  }
  return 0;
}

function lerLinha_(sheet, row) {
  var w = sheet.getLastColumn() >= COL.BAIXOU ? COL.BAIXOU : COL.VOLUNTARIO;
  var vals = sheet.getRange(row, 1, 1, w).getValues()[0];
  return {
    atualizado: vals[COL.ATUALIZADO - 1],
    numero: vals[COL.NUMERO - 1],
    nome: vals[COL.NOME - 1],
    dataEmissao: vals[COL.DATA_EMISSAO - 1],
    pagamento: vals[COL.PAGAMENTO - 1],
    voluntario: vals[COL.VOLUNTARIO - 1],
    baixou: vals[COL.BAIXOU - 1] || ""
  };
}

function gravarLinha_(sheet, row, dados) {
  var linha = [
    dados.atualizado || new Date(),
    dados.numero || "",
    dados.nome || "",
    dados.dataEmissao || "",
    dados.pagamento || "",
    dados.voluntario || "",
    dados.baixou || ""
  ];
  if (row > 0) {
    sheet.getRange(row, 1, 1, COL.BAIXOU).setValues([linha]);
  } else {
    sheet.appendRow(linha);
  }
}

function garantirCabecalho_(sheet) {
  if (sheet.getLastRow() > 0) return;
  sheet.appendRow([
    "Última atualização",
    "Número",
    "Nome",
    "Data emissão",
    "Pagamento",
    "Voluntário",
    "Baixou"
  ]);
}

function salvarNaPlanilha(params) {
  var numero = normalizarNumero_(params.numero);
  var nome = String(params.nome || "").trim();
  var dataEmissao = String(params.data || "").trim();
  var evento = String(params.evento || "").toLowerCase();
  var pagoCliente = String(params.pago_confirmado || "").toLowerCase() === "sim";

  if (!numero) return;
  if (!dataEmissao) dataEmissao = dataHojeBr_();

  var spreadsheet = SpreadsheetApp.openById(SPREADSHEET_ID);
  var sheet = spreadsheet.getSheets().find(function (s) { return s.getSheetId() === SHEET_GID; }) || spreadsheet.getSheets()[0];
  garantirCabecalho_(sheet);

  var rowIdx = encontrarLinhaPorNumero_(sheet, numero);
  var linha = rowIdx > 0 ? lerLinha_(sheet, rowIdx) : {
    numero: numero,
    nome: "",
    dataEmissao: "",
    pagamento: "",
    voluntario: "",
    baixou: ""
  };

  linha.numero = numero;
  if (nome) linha.nome = nome;
  if (dataEmissao) linha.dataEmissao = dataEmissao;
  linha.atualizado = new Date();

  var aprovadoSupabase = pagamentoAprovado(numero);

  if (evento === "pagamento_pendente") {
    linha.pagamento = "PENDENTE (aguardando pagamento)";
    linha.voluntario = "NÃO";
    linha.baixou = linha.baixou || "NÃO";
  } else if (evento === "pagamento_aprovado" || evento === "replay_db_approved") {
    linha.pagamento = "R$ 20,00 — PAGO";
    linha.voluntario = "NÃO";
  } else if (evento === "download_voluntario") {
    linha.pagamento = "Voluntário (sem cobrança)";
    linha.voluntario = "SIM";
    linha.baixou = "SIM";
  } else if (evento === "download_pos_pagamento") {
    linha.baixou = "SIM";
    linha.voluntario = "NÃO";
    if (aprovadoSupabase || pagoCliente) {
      linha.pagamento = "R$ 20,00 — PAGO";
    } else {
      linha.pagamento = "R$ 20,00 — baixou (pagamento não confirmado no sistema)";
    }
  } else {
    return;
  }

  gravarLinha_(sheet, rowIdx, linha);
}

function pagamentoAprovado(numero) {
  try {
    var filtroNumero = encodeURIComponent(numero);
    var url =
      SUPABASE_URL +
      "/rest/v1/pagamentos_carteirinha?select=id&numero_credencial=eq." +
      filtroNumero +
      "&status=eq.approved&limit=1";

    var response = UrlFetchApp.fetch(url, {
      method: "get",
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: "Bearer " + SUPABASE_KEY
      },
      muteHttpExceptions: true
    });

    if (response.getResponseCode() < 200 || response.getResponseCode() >= 300) return false;
    var rows = JSON.parse(response.getContentText() || "[]");
    return Array.isArray(rows) && rows.length > 0;
  } catch (err) {
    return false;
  }
}
