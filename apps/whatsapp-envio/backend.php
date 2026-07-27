<?php

/**
 * Envio de WhatsApp — backend.
 *
 * Serviço device-based: /whatsapp/{action}. Exige sessão iniciada e pareada —
 * veja o app whatsapp-devices para o fluxo de QR Code.
 *
 * Cada tipo de mensagem tem a sua action e o seu corpo. Uma allowlist por tipo
 * é melhor que aceitar `action` do cliente: assim o visitante não alcança
 * actions destrutivas do catálogo WPP (apagar chat, sair de grupo, bloquear).
 */

declare(strict_types=1);

require_once __DIR__ . '/../_comum/apibrasil.php';

use ApiBrasil\Comum\Entrada;
use ApiBrasil\Comum\Proxy;

/** Opções comuns às actions de /whatsapp. */
$whatsapp = fn (string $action, ?callable $corpo = null): array => array_filter([
    'caminho' => "/whatsapp/{$action}",
    'device' => true,
    'deviceEnv' => 'WHATSAPP',
    'corpo' => $corpo,
]);

Proxy::despachar([
    // ---------------------------------------------------------------------
    // Sessão
    // ---------------------------------------------------------------------
    'status' => $whatsapp('getConnectionStatus'),

    // ---------------------------------------------------------------------
    // Verificação antes de enviar
    // ---------------------------------------------------------------------
    // Confere se o número existe no WhatsApp. Vale a chamada: enviar para
    // número inválido consome cota e não entrega nada.
    'verificar' => $whatsapp('checkNumberStatus', fn (Entrada $e): array => [
        'number' => $e->telefone(),
    ]),

    // ---------------------------------------------------------------------
    // Envios
    // ---------------------------------------------------------------------
    'texto' => $whatsapp('sendText', fn (Entrada $e): array => [
        'number' => $e->telefone(),
        'text' => $e->texto('texto', 5000, 'mensagem'),
        // "digitando..." antes de entregar; deixa o envio menos robótico.
        'time_typing' => $e->inteiro('digitando', 0, 15000, 'Tempo digitando'),
    ]),

    'arquivo' => $whatsapp('sendFile', fn (Entrada $e): array => [
        'number' => $e->telefone(),
        // URL pública. Para base64 existe a action sendFile64.
        'path' => $e->url('url', 'URL do arquivo'),
        'caption' => $e->texto('legenda', 1000, 'legenda', false),
    ]),

    'audio' => $whatsapp('sendAudio', fn (Entrada $e): array => [
        'number' => $e->telefone(),
        // O gateway converte para mp3; máximo de 6 minutos.
        'path' => $e->url('url', 'URL do áudio'),
    ]),

    'link' => $whatsapp('sendLink', fn (Entrada $e): array => [
        'number' => $e->telefone(),
        'url' => $e->url('url', 'URL'),
        'text' => $e->texto('texto', 1000, 'texto', false),
    ]),

    'localizacao' => $whatsapp('sendLocation', fn (Entrada $e): array => [
        'number' => $e->telefone(),
        'lat' => $e->decimal('lat', -90, 90, 'Latitude'),
        'lng' => $e->decimal('lng', -180, 180, 'Longitude'),
        'title' => $e->texto('titulo', 200, 'título', false),
    ]),

    // ---------------------------------------------------------------------
    // Fila
    // ---------------------------------------------------------------------
    // Mesmo sendText, processado de forma assíncrona pelo gateway. Responde na
    // hora — é o caminho para volume.
    'texto-fila' => $whatsapp('sendText/queue', fn (Entrada $e): array => [
        'number' => $e->telefone(),
        'text' => $e->texto('texto', 5000, 'mensagem'),
    ]),
]);
