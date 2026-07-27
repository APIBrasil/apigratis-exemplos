<?php

/**
 * Carregador mínimo de .env para os exemplos.
 *
 * Lê o .env da raiz do repositório e popula $_ENV/getenv() com o que ainda não
 * estiver definido no ambiente — variáveis reais do servidor sempre vencem.
 *
 * Em produção você não precisa disso: exporte as variáveis no ambiente
 * (ou use o .env do seu framework) e a SDK as lê sozinha.
 */

declare(strict_types=1);

require_once __DIR__ . '/vendor/autoload.php';

(function (): void {
    $caminho = __DIR__ . '/../../.env';

    if (!is_readable($caminho)) {
        return;
    }

    foreach (file($caminho, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $linha) {
        $linha = trim($linha);

        if ($linha === '' || str_starts_with($linha, '#') || !str_contains($linha, '=')) {
            continue;
        }

        [$chave, $valor] = explode('=', $linha, 2);
        $chave = trim($chave);
        $valor = trim($valor, " \t\n\r\0\x0B\"'");

        if ($chave === '' || $valor === '' || getenv($chave) !== false) {
            continue;
        }

        putenv("{$chave}={$valor}");
        $_ENV[$chave] = $valor;
    }
})();

/** Lê uma variável de ambiente com valor padrão. */
function env(string $chave, ?string $padrao = null): ?string
{
    $valor = getenv($chave);

    return $valor === false || $valor === '' ? $padrao : $valor;
}

/** Encerra o exemplo se uma credencial obrigatória estiver faltando. */
function exigir(string $chave, string $dica = ''): string
{
    $valor = env($chave);

    if ($valor === null) {
        fwrite(STDERR, "Defina {$chave} no .env da raiz do repositório.\n");
        if ($dica !== '') {
            fwrite(STDERR, "{$dica}\n");
        }
        exit(1);
    }

    return $valor;
}
