// 04 — Serviços device-based (fora do WhatsApp)
//
// Todos seguem o mesmo formato: POST /{servico}/{action} com Bearer + DeviceToken.
// O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
// em /vehicles.
//
//	go run ./cmd/04-servicos-device
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

// deviceDe devolve o token específico do serviço, caindo para o token padrão.
func deviceDe(servico string) apibrasil.RequestOptions {
	token := os.Getenv("APIBRASIL_DEVICE_TOKEN_" + servico)
	if token == "" {
		token = os.Getenv("APIBRASIL_DEVICE_TOKEN")
	}
	return apibrasil.RequestOptions{DeviceToken: token}
}

// tentar roda um bloco e reporta a falha sem derrubar os outros exemplos.
func tentar(rotulo string, fn func() (apibrasil.DeviceServiceResponse, error)) {
	res, err := fn()
	switch {
	case errors.Is(err, apibrasil.ErrNotFound):
		fmt.Printf("\n%s: sem dados\n", rotulo)
	case err != nil:
		fmt.Printf("\n%s: %v\n", rotulo, err)
	default:
		texto := fmt.Sprint(res.Response())
		if len(texto) > 600 {
			texto = texto[:600] + "…"
		}
		fmt.Printf("\n%s:\n%s\n", rotulo, texto)
	}
}

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	if os.Getenv("APIBRASIL_BEARER_TOKEN") == "" {
		log.Fatal("defina APIBRASIL_BEARER_TOKEN no ambiente")
	}

	api := apibrasil.New()

	// CEP — endereço completo com geolocalização.
	tentar("CEP", func() (apibrasil.DeviceServiceResponse, error) {
		return api.Cep.CEP(ctx, apibrasil.Json{"cep": "01001000"}, deviceDe("CEP"))
	})

	// Ainda em /cep: cidades por DDD, bairros, cidades, estados, distância.
	tentar("Cidades por DDD", func() (apibrasil.DeviceServiceResponse, error) {
		return api.Cep.CidadesPorDDD(ctx, apibrasil.Json{"ddd": "11"}, deviceDe("CEP"))
	})

	// Correios — rastreio de encomenda.
	tentar("Rastreio", func() (apibrasil.DeviceServiceResponse, error) {
		return api.Correios.Rastreio(ctx, apibrasil.Json{"code": "AA123456789BR"}, deviceDe("CORREIOS"))
	})

	// Veículos por placa. Diferente de Consulta.Veiculos (créditos): aqui é device.
	tentar("Placa · dados", func() (apibrasil.DeviceServiceResponse, error) {
		return api.Vehicles.Dados(ctx, apibrasil.Json{"placa": "ABC1234"}, deviceDe("VEICULOS"))
	})
	tentar("Placa · FIPE", func() (apibrasil.DeviceServiceResponse, error) {
		return api.Vehicles.Fipe(ctx, apibrasil.Json{"placa": "ABC1234"}, deviceDe("VEICULOS"))
	})

	// Tabela FIPE navegável: referência → marcas → modelos → ano → valor.
	tentar("FIPE · marcas", func() (apibrasil.DeviceServiceResponse, error) {
		return api.Fipe.ConsultarMarcas(ctx, apibrasil.Json{
			"codigoTabelaReferencia": 300,
			"codigoTipoVeiculo":      1,
		}, deviceDe("VEICULOS"))
	})

	// Clima por cidade ou por coordenadas.
	tentar("Clima", func() (apibrasil.DeviceServiceResponse, error) {
		return api.Weather.City(ctx, apibrasil.Json{"city": "São Paulo"}, deviceDe("CLIMA"))
	})

	// Feriados do ano. Request cobre qualquer action, inclusive sem método dedicado.
	tentar("Feriados", func() (apibrasil.DeviceServiceResponse, error) {
		return api.Holidays.Request(ctx, "feriados", apibrasil.Json{
			"year": time.Now().Year(),
		}, deviceDe("CLIMA"))
	})

	// GeoIP.
	tentar("GeoIP", func() (apibrasil.DeviceServiceResponse, error) {
		return api.DatabaseIP.IP(ctx, apibrasil.Json{"ip": "8.8.8.8"}, deviceDe("CEP"))
	})

	// SMS — device-based. Só envia de verdade com NUMERO definido.
	if numero := os.Getenv("NUMERO"); numero != "" {
		tentar("SMS", func() (apibrasil.DeviceServiceResponse, error) {
			return api.SMS.Send(ctx, apibrasil.Json{
				"number":  numero,
				"message": "Seu código: 123456",
			}, deviceDe("SMS"))
		})

		// Alternativa sem device, debitando créditos da conta:
		// api.SMS.SendWithCredits(ctx, apibrasil.Json{"number": numero, "message": "Olá!"})
	}

	// Serviço sem método dedicado? A saída genérica cobre o gateway inteiro.
	// api.Request(ctx, apibrasil.MethodPost, "/translate/text", apibrasil.Json{"text": "Olá", "to": "en"})
}
