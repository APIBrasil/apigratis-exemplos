// 02 — Consultas por crédito
//
// Rotas /consulta/{servico}/credits. Só precisam do bearer: debitam o saldo da
// conta e ignoram o DeviceToken.
//
// Roda em HOMOLOGAÇÃO por padrão (dados fictícios, sem cobrança).
// Para valer, rode com COBRAR=1.
//
//	go run ./cmd/02-consultas-por-credito
//	COBRAR=1 go run ./cmd/02-consultas-por-credito
package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/jhowbhz/apigratis-sdk-go/apibrasil"
)

// resumir imprime o envelope comum a toda consulta:
// { error, message, balance, tax, valor_consulta, data }.
func resumir(rotulo string, res apibrasil.CreditServiceResponse) {
	fmt.Printf("%s:\n", rotulo)
	fmt.Printf("  custou: %v | saldo restante: %v\n", res.ValorConsulta(), res.Balance())
	fmt.Printf("  data: %s\n", truncar(fmt.Sprint(res.Data()), 300))
}

func truncar(texto string, limite int) string {
	if len(texto) <= limite {
		return texto
	}
	return texto[:limite] + "…"
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	if os.Getenv("APIBRASIL_BEARER_TOKEN") == "" {
		log.Fatal("defina APIBRASIL_BEARER_TOKEN no ambiente")
	}

	api := apibrasil.New()

	// `homolog: true` é o sandbox da plataforma — não existe URL separada de teste.
	homolog := os.Getenv("COBRAR") != "1"
	if homolog {
		fmt.Print("· modo homologação (sem cobrança)\n\n")
	} else {
		fmt.Print("· CONSULTAS REAIS — vai debitar saldo\n\n")
	}

	// CNPJ — cadastro básico.
	empresa, err := api.Consulta.CNPJ(ctx, apibrasil.Json{
		"cnpj":    "00000000000000",
		"homolog": homolog,
	})
	switch {
	case errors.Is(err, apibrasil.ErrInsufficientBalance):
		// 402 — a mensagem do gateway já traz o valor exato da consulta.
		log.Fatal("sem saldo: recarregue em https://apibrasil.com.br")
	case errors.Is(err, apibrasil.ErrValidation):
		// 422 — o template do body está em GET /api/v2/endpoint/body.
		apiErr, _ := apibrasil.AsError(err)
		log.Fatalf("body inválido: %v", apiErr.Response)
	case err != nil:
		log.Fatalf("consulta falhou: %v", err)
	}
	resumir("CNPJ", empresa)

	// Decode tipa direto o campo `data` — sem json.Marshal na mão.
	var dados struct {
		RazaoSocial string `json:"razao_social"`
		Situacao    string `json:"situacao"`
	}
	if err := empresa.Decode(&dados); err == nil && dados.RazaoSocial != "" {
		fmt.Printf("  → %s (%s)\n", dados.RazaoSocial, dados.Situacao)
	}

	// O campo `tipo` é o que escolhe o PRODUTO dentro do serviço. Mesmo endpoint,
	// preço e retorno diferentes. São 210+ tipos no catálogo.
	socios, err := api.Consulta.CNPJ(ctx, apibrasil.Json{
		"cnpj":    "00000000000000",
		"tipo":    "lista-socios",
		"homolog": homolog,
	})
	if err != nil {
		log.Printf("lista-socios falhou: %v", err)
	} else {
		resumir("CNPJ · lista-socios", socios)
	}

	// CPF.
	if pessoa, err := api.Consulta.CPF(ctx, apibrasil.Json{"cpf": "00000000000", "homolog": homolog}); err == nil {
		resumir("CPF", pessoa)
	}

	// Veicular por placa.
	if veiculo, err := api.Consulta.Veiculos(ctx, apibrasil.Json{"placa": "ABC1234", "homolog": homolog}); err == nil {
		resumir("Veículos", veiculo)
	}

	// Qualquer serviço do catálogo, inclusive os sem método dedicado.
	score, err := api.Consulta.Generic(ctx, "cpf", apibrasil.Json{
		"cpf":     "00000000000",
		"tipo":    "serasa-score-pf",
		"homolog": homolog,
	})
	if err == nil {
		resumir("Serasa Score PF", score)
	}

	// Descobrindo o que existe: catálogo vivo do gateway.
	catalogo, err := api.Catalog.APIs(ctx, "consulta")
	if err != nil {
		return
	}
	apis, _ := catalogo["apis"].([]any)
	fmt.Printf("\n%d API(s) com \"consulta\" no nome. Primeiras:\n", len(apis))
	for i, item := range apis {
		if i >= 5 {
			break
		}
		if servico, ok := item.(map[string]any); ok {
			fmt.Printf("  %v · R$ %v\n", servico["name"], servico["price"])
		}
	}
}
