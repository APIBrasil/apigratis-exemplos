<?php

/**
 * 05 — Erros, retry e observabilidade
 *
 * A parte que separa um script de uma integração de produção.
 *
 *   php 05-erros-e-retry.php
 */

declare(strict_types=1);

require_once __DIR__ . '/env.php';

use ApiBrasil\ApiBrasil;
use ApiBrasil\Core\Errors\ApiBrasilError;
use ApiBrasil\Core\Errors\AuthenticationError;
use ApiBrasil\Core\Errors\InsufficientBalanceError;
use ApiBrasil\Core\Errors\NetworkError;
use ApiBrasil\Core\Errors\NotFoundError;
use ApiBrasil\Core\Errors\PermissionError;
use ApiBrasil\Core\Errors\RateLimitError;
use ApiBrasil\Core\Errors\ServerError;
use ApiBrasil\Core\Errors\TimeoutError;
use ApiBrasil\Core\Errors\ValidationError;

exigir('APIBRASIL_BEARER_TOKEN');

// ---------------------------------------------------------------------------
// Retry
// ---------------------------------------------------------------------------
// O padrão são 2 tentativas extras, backoff exponencial, SÓ em 429 e falha de
// conexão — e respeitando o Retry-After da resposta.
//
// Timeout e erro de negócio nunca são repetidos: um sendText que deu timeout
// pode ter sido entregue, e uma consulta repetida cobra duas vezes.
$api = new ApiBrasil([
    'timeout' => 30_000, // milissegundos
    'retry' => [
        'retries' => 3,
        'minDelayMs' => 500,
        'retryOnStatuses' => [429, 503],
    ],
    // Hooks: é aqui que você pluga log estruturado, métricas ou tracing.
    'hooks' => [
        'onRequest' => fn (array $i) => printf("→ %s %s (tentativa %d)\n", $i['method'], $i['url'], $i['attempt']),
        'onResponse' => fn (array $i) => printf("← %d em %dms\n", $i['status'], $i['durationMs']),
        'onRetry' => fn (array $i) => printf("↻ retry em %dms: %s\n", $i['delayMs'], $i['reason']),
    ],
]);

// Para desligar: 'retry' => false.

// ---------------------------------------------------------------------------
// Erros
// ---------------------------------------------------------------------------
// Cada status HTTP do gateway vira uma classe. Todas estendem ApiBrasilError e
// expõem getStatus(), getErrorCode(), getMessage() e getResponse() (o corpo original).
try {
    $api->consulta->cpf(['cpf' => '00000000000']);
} catch (ValidationError $e) {
    // 400/422 — o body está errado. O template certo vem de
    // GET /api/v2/endpoint/body, e a doc está em doc.apibrasil.io.
    fwrite(STDERR, 'Payload inválido: ' . $e->getMessage() . ' ' . json_encode($e->getResponse()) . PHP_EOL);
} catch (AuthenticationError $e) {
    // 401 — bearer ausente/expirado. Refaça o login; não faça retry cego.
    fwrite(STDERR, 'Refaça o login.' . PHP_EOL);
} catch (InsufficientBalanceError $e) {
    // 402 — a mensagem já traz o valor exato da consulta que faltou.
    fwrite(STDERR, 'Recarregue: ' . $e->getMessage() . PHP_EOL);
} catch (PermissionError $e) {
    // 403 — DeviceToken de outra API, IP fora da whitelist, ou API que exige
    // cadastro PJ. São três causas com o mesmo status: leia a mensagem.
    fwrite(STDERR, 'Sem permissão: ' . $e->getMessage() . PHP_EOL);
} catch (NotFoundError $e) {
    // 404 = não achou o dado. 410 = rota desativada, e a mensagem aponta a nova.
    $rotulo = $e->getStatus() === 410 ? 'Rota descontinuada' : 'Sem dados';
    fwrite(STDERR, "{$rotulo}: " . $e->getMessage() . PHP_EOL);
} catch (RateLimitError $e) {
    // 429 — a SDK já tentou de novo antes de chegar aqui.
    fwrite(STDERR, sprintf("Limite atingido. Aguarde %dms.\n", $e->getRetryAfterMs() ?? 0));
} catch (ServerError $e) {
    // 5xx — gateway ou provedor upstream. Repetir com backoff faz sentido.
    fwrite(STDERR, sprintf("Falha do servidor: %s %s\n", $e->getStatus() ?? '—', $e->getMessage()));
} catch (TimeoutError $e) {
    // Estourou o tempo. ATENÇÃO: a operação pode ter completado no servidor.
    // Em envios e consultas, confirme o estado antes de repetir.
    fwrite(STDERR, 'Timeout — verifique o estado antes de tentar de novo.' . PHP_EOL);
} catch (NetworkError $e) {
    // Não chegou a haver resposta: DNS, TLS, conexão recusada.
    fwrite(STDERR, 'Falha de rede: ' . $e->getMessage() . PHP_EOL);
} catch (ApiBrasilError $e) {
    fwrite(STDERR, sprintf(
        "Erro da SDK (HTTP %s, código %s): %s\n",
        $e->getStatus() ?? '—',
        $e->getErrorCode() ?? '—',
        $e->getMessage()
    ));
}

// ---------------------------------------------------------------------------
// Idempotência na prática
// ---------------------------------------------------------------------------
// Operações que cobram ou enviam merecem cuidado extra. O padrão abaixo repete
// só o que é seguro repetir.
function comRetrySeguro(callable $fn, int $tentativas = 3)
{
    for ($i = 1; $i <= $tentativas; $i++) {
        try {
            return $fn();
        } catch (TimeoutError $e) {
            // TimeoutError estende NetworkError, mas indica trabalho
            // possivelmente concluído — não repita operação não idempotente.
            throw $e;
        } catch (ServerError | NetworkError $e) {
            if ($i === $tentativas) {
                throw $e;
            }
            usleep((2 ** $i) * 250_000);
        }
    }
}

try {
    echo PHP_EOL . 'Saldo: ' . json_encode(comRetrySeguro(fn () => $api->account->balance())) . PHP_EOL;
} catch (ApiBrasilError $e) {
    fwrite(STDERR, 'Desisti: ' . $e->getMessage() . PHP_EOL);
}
