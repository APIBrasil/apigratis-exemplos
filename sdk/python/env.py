"""Carregador mínimo de .env para os exemplos.

Lê o .env da raiz do repositório e popula os.environ com o que ainda não estiver
definido — variáveis reais do ambiente sempre vencem.

Em produção você não precisa disso: exporte as variáveis e a SDK as lê sozinha.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

CAMINHO = Path(__file__).resolve().parents[2] / ".env"


def carregar() -> None:
    """Popula os.environ a partir do .env da raiz, sem sobrescrever o ambiente."""
    if not CAMINHO.is_file():
        return

    for linha in CAMINHO.read_text(encoding="utf-8").splitlines():
        linha = linha.strip()
        if not linha or linha.startswith("#") or "=" not in linha:
            continue

        chave, _, valor = linha.partition("=")
        chave = chave.strip()
        valor = valor.strip().strip("\"'")

        if chave and valor and chave not in os.environ:
            os.environ[chave] = valor


def exigir(chave: str, dica: str = "") -> str:
    """Encerra o exemplo se uma credencial obrigatória estiver faltando."""
    valor = os.environ.get(chave)
    if not valor:
        print(f"Defina {chave} no .env da raiz do repositório.", file=sys.stderr)
        if dica:
            print(dica, file=sys.stderr)
        raise SystemExit(1)
    return valor


carregar()
