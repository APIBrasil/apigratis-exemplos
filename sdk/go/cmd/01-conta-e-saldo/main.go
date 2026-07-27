// 01 — Conta e saldo
//
// O básico: montar o cliente, confirmar que o gateway responde e ler os dados
// da conta. Nada aqui gasta crédito.
//
//	go run ./cmd/01-conta-e-saldo
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

func main() {
	// O context é o que cancela e limita a chamada — vale mais que Config.Timeout
	// porque cobre também os retries.
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Sem config, as credenciais vêm de APIBRASIL_BEARER_TOKEN, APIBRASIL_DEVICE_TOKEN,
	// APIBRASIL_SECRET_KEY e APIBRASIL_BASE_URL.
	api := apibrasil.New()

	// /status é público — separa "minha credencial está errada" de "o gateway caiu".
	status, err := api.Catalog.Status(ctx)
	if err != nil {
		log.Fatalf("gateway não respondeu: %v", err)
	}
	fmt.Println("Gateway:", status["message"])

	if os.Getenv("APIBRASIL_BEARER_TOKEN") == "" {
		log.Fatal("defina APIBRASIL_BEARER_TOKEN no ambiente para seguir")
	}

	saldo, err := api.Account.Balance(ctx)
	if err != nil {
		// Sentinelas em vez de tipos: errors.Is é o idioma do Go.
		if errors.Is(err, apibrasil.ErrAuthentication) {
			log.Fatal("bearer inválido ou expirado — refaça o login no painel")
		}
		log.Fatalf("não foi possível consultar o saldo: %v", err)
	}
	fmt.Println("Saldo:", saldo)

	plano, err := api.Account.Plan(ctx)
	if err != nil {
		log.Fatalf("não foi possível consultar o plano: %v", err)
	}
	fmt.Println("Plano:", plano)

	// Devices ativos na conta — cada um é uma instância de um serviço.
	// List recebe uma query opcional; nil traz todos.
	lista, err := api.Devices.List(ctx, nil)
	if err != nil {
		log.Fatalf("não foi possível listar os devices: %v", err)
	}

	// A resposta é um apibrasil.Json (map[string]any). Para tipar de verdade,
	// use core.DecodeValue ou o Decode dos envelopes tipados (ver exemplo 02).
	devices, _ := lista["devices"].([]any)
	fmt.Printf("\n%d device(s):\n", len(devices))
	for _, item := range devices {
		device, ok := item.(map[string]any)
		if !ok {
			continue
		}
		nomeAPI := "—"
		if info, ok := device["api"].(map[string]any); ok {
			nomeAPI = fmt.Sprint(info["name"])
		}
		fmt.Printf("  %v · %s · %v\n", device["device_name"], nomeAPI, device["status"])
	}

	// Login por email/senha, se você preferir não guardar o JWT:
	//
	//	api, sessao, err := apibrasil.Login(ctx, apibrasil.Json{
	//		"email":    os.Getenv("APIBRASIL_EMAIL"),
	//		"password": os.Getenv("APIBRASIL_PASSWORD"),
	//	})
	//
	// Contas com 2FA: api.Auth.Login + api.Auth.Send2FA + api.Auth.Verify2FA.
}
