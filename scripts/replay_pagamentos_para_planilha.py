"""Reenvia pagamentos aprovados do Supabase para a planilha Google Apps Script.

Uso:
  python scripts/replay_pagamentos_para_planilha.py --since 2026-05-01T00:00:00Z
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

SUPABASE_URL = "https://qzjvzbvoxwhggvadaroq.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF6anZ6YnZveHdoZ2d2YWRhcm9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQzOTA4NDEsImV4cCI6MjA4OTk2Njg0MX0.bTss42oILYSmAGP3vAP-9OQ1-qnKnZXbVxz2SDxWmW0"
GOOGLE_SCRIPT_URL = "https://script.google.com/macros/s/AKfycbzRPMVu--BYlX51qU0Mj6P1SBTikDE7RKJhym0c_RMCJ-CoRM_4T4mNHjRudcvx6EK1/exec"


def iso_para_br(iso_ts: str) -> str:
    try:
        data = dt.datetime.fromisoformat(iso_ts.replace("Z", "+00:00"))
        return data.strftime("%d/%m/%Y")
    except Exception:
        return ""


def buscar_aprovados(since_iso: str) -> list[dict]:
    endpoint = (
        f"{SUPABASE_URL}/rest/v1/pagamentos_carteirinha"
        "?select=numero_credencial,nome_pagador,created_at,status"
        "&status=eq.approved"
        f"&created_at=gte.{urllib.parse.quote(since_iso, safe=':-T.Z')}"
        "&order=created_at.asc"
    )
    req = urllib.request.Request(
        endpoint,
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def reenviar_para_planilha(registro: dict) -> None:
    payload = urllib.parse.urlencode(
        {
            "numero": (registro.get("numero_credencial") or "").strip(),
            "nome": (registro.get("nome_pagador") or "").strip(),
            "data": iso_para_br(registro.get("created_at") or ""),
            "fluxo": "principal",
            "evento": "replay_db_approved",
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        GOOGLE_SCRIPT_URL,
        data=payload,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"},
    )
    with urllib.request.urlopen(req, timeout=20):
        return


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--since",
        default=(dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        help="Data ISO inicial (UTC). Ex: 2026-05-01T00:00:00Z",
    )
    args = parser.parse_args()

    try:
        registros = buscar_aprovados(args.since)
    except urllib.error.HTTPError as err:
        print(f"Erro HTTP ao consultar Supabase: {err.code} {err.reason}")
        return 1
    except Exception as err:
        print(f"Erro ao consultar Supabase: {err}")
        return 1

    # Evita duplicar por número dentro do próprio replay
    unicos = {}
    for r in registros:
        numero = (r.get("numero_credencial") or "").strip()
        if numero and numero not in unicos:
            unicos[numero] = r

    enviados = 0
    falhas = 0
    for numero, registro in unicos.items():
        try:
            reenviar_para_planilha(registro)
            enviados += 1
            print(f"OK: {numero}")
        except Exception as err:
            falhas += 1
            print(f"FALHA: {numero} -> {err}")

    print(f"Resumo: {enviados} enviados, {falhas} falhas, {len(unicos)} elegíveis")
    return 0 if falhas == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
