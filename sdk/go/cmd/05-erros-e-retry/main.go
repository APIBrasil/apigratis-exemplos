// 05 — Erros, retry e observabilidade
//
// A parte que separa um script de uma integração de produção.
//
//	go run ./cmd/05-erros-e-retry
package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/jhowbhz/apigratis-sdk-go/apibrasil"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	if os.Getenv("APIBRASIL_BEARER_TOKEN") == "" {
		log.Fatal("defina APIBRASIL_BEARER_TOKEN no ambiente")
	}

	// -----------------------------------------------------------------------
	// Retry
	// -----------------------------------------------------------------------
	// O padrão são 2 tentativas extras, backoff exponencial, SÓ em 429 e falha
	// de conexão — e respeitando o Retry-After da resposta.
	//
	// Timeout e erro de negócio nunca são repetidos: um SendText que deu timeout
	// pode ter sido entregue, e uma consulta repetida cobra duas vezes.
	api := apibrasil.New(apibrasil.Config{
		Timeout: 30 * time.Second,
		Retry: &apibrasil.RetryConfig{
			Retries:         3,
			MinDelay:        500 * time.Millisecond,
			RetryOnStatuses: []int{http.StatusTooManyRequests, http.StatusServiceUnavailable},
		},
		// Hooks: é aqui que você pluga log estruturado, métricas ou tracing.
		Hooks: &apibrasil.Hooks{
			OnRequest: func(_ context.Context, info apibrasil.RequestHookInfo) {
				log.Printf("→ %s %s (tentativa %d)", info.Method, info.URL, info.Attempt)
			},
			OnResponse: func(_ context.Context, info apibrasil.ResponseHookInfo) {
				log.Printf("← %d em %s", info.Status, info.Duration)
			},
			OnRetry: func(_ context.Context, info apibrasil.RetryHookInfo) {
				log.Printf("↻ retry em %s: %s", info.Delay, info.Reason)
			},
		},
	})

	// Para desligar: Retry: apibrasil.NoRetry().

	// -----------------------------------------------------------------------
	// Erros
	// -----------------------------------------------------------------------
	// O Go usa sentinelas em vez de tipos. Cada categoria tem a sua, e
	// errors.Is atravessa o wrapping.
	_, err := api.Consulta.CPF(ctx, apibrasil.Json{"cpf": "00000000000"})

	switch {
	case errors.Is(err, apibrasil.ErrValidation):
		// 400/422 — o body está errado. O template certo vem de
		// GET /api/v2/endpoint/body, e a doc está em doc.apibrasil.io.
		apiErr, _ := apibrasil.AsError(err)
		log.Printf("payload inválido: %v", apiErr.Response)

	case errors.Is(err, apibrasil.ErrAuthentication):
		// 401 — bearer ausente/expirado. Refaça o login; não faça retry cego.
		log.Println("refaça o login")

	case errors.Is(err, apibrasil.ErrInsufficientBalance):
		// 402 — a mensagem já traz o valor exato da consulta que faltou.
		log.Printf("recarregue: %v", err)

	case errors.Is(err, apibrasil.ErrPermission):
		// 403 — DeviceToken de outra API, IP fora da whitelist, ou API que exige
		// cadastro PJ. São três causas com o mesmo status: leia a mensagem.
		log.Printf("sem permissão: %v", err)

	case errors.Is(err, apibrasil.ErrNotFound):
		// 404 = não achou o dado. 410 = rota desativada, e a mensagem aponta a nova.
		apiErr, _ := apibrasil.AsError(err)
		if apiErr != nil && apiErr.Status == http.StatusGone {
			log.Printf("rota descontinuada: %v", err)
		} else {
			log.Printf("sem dados: %v", err)
		}

	case errors.Is(err, apibrasil.ErrRateLimit):
		// 429 — a SDK já tentou de novo antes de chegar aqui.
		apiErr, _ := apibrasil.AsError(err)
		log.Printf("limite atingido, aguarde %s", apiErr.RetryAfter)

	case errors.Is(err, apibrasil.ErrServer):
		// 5xx — gateway ou provedor upstream. Repetir com backoff faz sentido.
		log.Printf("falha do servidor: %v", err)

	case errors.Is(err, apibrasil.ErrTimeout):
		// Estourou o tempo. ATENÇÃO: a operação pode ter completado no servidor.
		// Em envios e consultas, confirme o estado antes de repetir.
		log.Println("timeout — verifique o estado antes de tentar de novo")

	case errors.Is(err, apibrasil.ErrNetwork):
		// Não chegou a haver resposta: DNS, TLS, conexão recusada.
		log.Printf("falha de rede: %v", err)

	case errors.Is(err, apibrasil.ErrAPIBrasil):
		// Qualquer erro da SDK que não caiu nos casos acima.
		apiErr, _ := apibrasil.AsError(err)
		log.Printf("erro da SDK (HTTP %d, código %s): %s", apiErr.Status, apiErr.Code, apiErr.Message)
	}

	// -----------------------------------------------------------------------
	// Idempotência na prática
	// -----------------------------------------------------------------------
	saldo, err := comRetrySeguro(ctx, 3, func() (apibrasil.Json, error) {
		return api.Account.Balance(ctx)
	})
	if err != nil {
		log.Printf("desisti: %v", err)
		return
	}
	fmt.Println("\nSaldo:", saldo)
}

// comRetrySeguro repete só o que é seguro repetir: falha de servidor e de rede.
// Timeout fica de fora — pode indicar trabalho já concluído no servidor.
func comRetrySeguro(ctx context.Context, tentativas int, fn func() (apibrasil.Json, error)) (apibrasil.Json, error) {
	var err error
	for i := 1; i <= tentativas; i++ {
		var res apibrasil.Json
		if res, err = fn(); err == nil {
			return res, nil
		}

		if errors.Is(err, apibrasil.ErrTimeout) {
			return nil, err
		}
		if !errors.Is(err, apibrasil.ErrServer) && !errors.Is(err, apibrasil.ErrNetwork) {
			return nil, err
		}
		if i == tentativas {
			break
		}

		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(time.Duration(1<<i) * 250 * time.Millisecond):
		}
	}
	return nil, err
}
