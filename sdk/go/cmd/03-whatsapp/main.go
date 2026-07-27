// 03 — WhatsApp
//
// Serviço device-based: exige Authorization: Bearer + header DeviceToken.
// O DeviceToken identifica UMA sessão de WhatsApp; o bearer identifica a conta.
//
// Fluxo completo: device → sessão → QR Code → pareamento → envio.
//
//	go run ./cmd/03-whatsapp                        # usa o device do ambiente
//	CRIAR_DEVICE=1 go run ./cmd/03-whatsapp         # cria um device novo
//	NUMERO=5511999999999 go run ./cmd/03-whatsapp   # e envia de verdade
package main

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/jhowbhz/apigratis-sdk-go/apibrasil"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	if os.Getenv("APIBRASIL_BEARER_TOKEN") == "" {
		log.Fatal("defina APIBRASIL_BEARER_TOKEN no ambiente")
	}

	api := apibrasil.New()
	temDevice := os.Getenv("APIBRASIL_DEVICE_TOKEN") != ""

	// -----------------------------------------------------------------------
	// 1. O device
	// -----------------------------------------------------------------------
	// A SecretKey (painel → API WhatsApp → SecretKey) é a única credencial que
	// cria devices. Depois de criado, o device_token substitui ela no dia a dia.
	if os.Getenv("CRIAR_DEVICE") == "1" {
		secretKey := os.Getenv("APIBRASIL_SECRET_KEY")
		if secretKey == "" {
			log.Fatal("CRIAR_DEVICE=1 exige APIBRASIL_SECRET_KEY")
		}

		criado, err := api.Devices.Store(ctx,
			apibrasil.Json{"device_name": "exemplo-go", "type": "server"},
			apibrasil.RequestOptions{SecretKey: secretKey},
		)
		if err != nil {
			log.Fatalf("não foi possível criar o device: %v", err)
		}

		var token string
		if device, ok := criado["device"].(map[string]any); ok {
			token = fmt.Sprint(device["device_token"])
		}
		fmt.Println("Device criado. Guarde este token no seu ambiente:")
		fmt.Printf("APIBRASIL_DEVICE_TOKEN=%s\n\n", token)

		api.SetDeviceToken(token)
		temDevice = true
	}

	if !temDevice {
		log.Fatal("defina APIBRASIL_DEVICE_TOKEN, ou rode com CRIAR_DEVICE=1")
	}

	// -----------------------------------------------------------------------
	// 2. A sessão
	// -----------------------------------------------------------------------
	// Os webhooks são opcionais, mas é aqui que se registram — não existe outra
	// chamada para isso. Sem eles você só descobre mensagens recebidas por polling.
	webhooks := apibrasil.Json{}
	for chave, envVar := range map[string]string{
		"webhook_wh_message": "WEBHOOK_MENSAGENS", // mensagem recebida
		"webhook_wh_status":  "WEBHOOK_STATUS",    // status da sessão mudou
		"webhook_wh_connect": "WEBHOOK_CONEXAO",   // conectou/desconectou
		"webhook_wh_qrcode":  "WEBHOOK_QRCODE",    // novo QR Code gerado
	} {
		if valor := os.Getenv(envVar); valor != "" {
			webhooks[chave] = valor
		}
	}

	sessao, err := api.WhatsApp.Start(ctx, webhooks)
	if err != nil {
		// 403 aqui é quase sempre DeviceToken de outra API, ou IP fora da whitelist.
		if errors.Is(err, apibrasil.ErrPermission) {
			log.Fatalf("sem permissão para esse device: %v", err)
		}
		log.Fatalf("não foi possível iniciar a sessão: %v", err)
	}
	fmt.Println("Sessão:", sessao.Message())

	// -----------------------------------------------------------------------
	// 3. O QR Code
	// -----------------------------------------------------------------------
	// Vem como data URI base64. Numa aplicação real você joga isso num <img src>;
	// aqui gravamos em disco para escanear.
	qr, err := api.WhatsApp.QRCode(ctx, nil)
	if err != nil {
		log.Fatalf("não foi possível obter o QR Code: %v", err)
	}

	var dataURI string
	if resposta, ok := qr.Response().(map[string]any); ok {
		dataURI = fmt.Sprint(resposta["qrcode"])
	}

	if strings.HasPrefix(dataURI, "data:image") {
		bruto := dataURI[strings.Index(dataURI, ",")+1:]
		imagem, err := base64.StdEncoding.DecodeString(bruto)
		if err == nil {
			if err := os.WriteFile("qrcode.png", imagem, 0o644); err == nil {
				fmt.Println("QR Code salvo em qrcode.png — escaneie no WhatsApp → aparelhos conectados.")
			}
		}
	} else {
		fmt.Println("QR Code:", qr.Message(), "(sessão provavelmente já conectada)")
	}

	// -----------------------------------------------------------------------
	// 4. Envios
	// -----------------------------------------------------------------------
	numero := os.Getenv("NUMERO")
	if numero == "" {
		fmt.Println("\nDefina NUMERO=5511999999999 para enviar de verdade.")
		return
	}

	// Texto. time_typing simula "digitando..." antes de entregar.
	texto, err := api.WhatsApp.SendText(ctx, apibrasil.Json{
		"number":      numero,
		"text":        "Olá! Mensagem enviada pela SDK Go da APIBrasil 👋",
		"time_typing": 1500,
	})
	if err != nil {
		log.Fatalf("não foi possível enviar: %v", err)
	}
	fmt.Println("Texto:", texto.Message())

	// Arquivo por URL pública. Para base64, use SendFile64.
	if _, err := api.WhatsApp.SendFile(ctx, apibrasil.Json{
		"number":  numero,
		"path":    "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf",
		"caption": "Segue o documento",
	}); err != nil {
		log.Printf("sendFile falhou: %v", err)
	}

	// Áudio (o gateway converte para mp3; máx. 6 min) e localização.
	api.WhatsApp.SendAudio(ctx, apibrasil.Json{
		"number": numero,
		"path":   "https://filesamples.com/samples/audio/mp3/sample3.mp3",
	})
	api.WhatsApp.SendLocation(ctx, apibrasil.Json{"number": numero, "lat": -23.5613, "lng": -46.6565})

	// Qualquer action da documentação, mesmo sem método dedicado na SDK.
	api.WhatsApp.Request(ctx, "sendLink", apibrasil.Json{
		"number": numero,
		"url":    "https://apibrasil.com.br",
		"text":   "Conheça",
	})

	// Fila: mesma action, processada de forma assíncrona pelo gateway. É o
	// caminho certo para disparos em volume — devolve na hora e não segura
	// a sua requisição.
	enfileirado, err := api.WhatsApp.Queue(ctx, "sendText", apibrasil.Json{
		"number": numero,
		"text":   "Esta foi pela fila 🚀",
	})
	if err == nil {
		fmt.Println("Fila:", enfileirado.Message())
	}

	// -----------------------------------------------------------------------
	// 5. Vários devices no mesmo processo
	// -----------------------------------------------------------------------
	// WithDevice devolve um cliente novo, sem alterar o original.
	if suporteToken := os.Getenv("APIBRASIL_DEVICE_TOKEN_SUPORTE"); suporteToken != "" {
		suporte := api.WithDevice(suporteToken)
		suporte.WhatsApp.SendText(ctx, apibrasil.Json{
			"number": numero,
			"text":   "Falando pela sessão do suporte",
		})
	}
}
