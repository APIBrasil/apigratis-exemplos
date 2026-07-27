// 05 — Erros, retry e observabilidade
//
// A parte que separa um script de uma integração de produção.
//
//     ./build/05-erros-e-retry

#include <chrono>
#include <cmath>
#include <functional>
#include <iostream>
#include <thread>

#include <apibrasil/apibrasil.hpp>

namespace {

// Repete só o que é seguro repetir: falha de servidor e de rede.
// Timeout fica de fora — pode indicar trabalho já concluído no servidor.
apibrasil::Json comRetrySeguro(const std::function<apibrasil::Json()>& chamada, int tentativas = 3) {
    using namespace apibrasil;

    for (int i = 1;; ++i) {
        try {
            return chamada();
        } catch (const TimeoutError&) {
            // TimeoutError deriva de NetworkError — capture antes dele.
            throw;
        } catch (const ApiBrasilError& e) {
            const bool podeRepetir = dynamic_cast<const ServerError*>(&e) != nullptr ||
                                     dynamic_cast<const NetworkError*>(&e) != nullptr;
            if (!podeRepetir || i >= tentativas) throw;

            std::this_thread::sleep_for(std::chrono::milliseconds(
                static_cast<long>(std::pow(2, i) * 250)));
        }
    }
}

}  // namespace

int main() {
    using namespace apibrasil;

    // -----------------------------------------------------------------------
    // Retry
    // -----------------------------------------------------------------------
    // O padrão são 2 tentativas extras, backoff exponencial, SÓ em 429 e falha
    // de conexão — e respeitando o Retry-After da resposta.
    //
    // Timeout e erro de negócio nunca são repetidos: um sendText que deu timeout
    // pode ter sido entregue, e uma consulta repetida cobra duas vezes.
    Config cfg;
    cfg.timeoutMs = 30000;

    RetryConfig retry;
    retry.retries = 3;
    retry.minDelayMs = 500;
    retry.retryOnStatuses = {429, 503};
    cfg.retry = retry;  // ou RetryConfig::disabled()

    // Hooks: é aqui que você pluga log estruturado, métricas ou tracing.
    cfg.hooks.onRequest = [](const RequestHookInfo& i) {
        std::cout << "→ " << i.method << " " << i.url << " (tentativa " << i.attempt << ")\n";
    };
    cfg.hooks.onResponse = [](const ResponseHookInfo& i) {
        std::cout << "← " << i.status << " em " << i.durationMs << "ms\n";
    };
    cfg.hooks.onRetry = [](const RetryHookInfo& i) {
        std::cerr << "↻ retry em " << i.delayMs << "ms: " << i.reason << "\n";
    };

    ApiBrasil api(cfg);

    if (api.http().bearerToken().empty()) {
        std::cerr << "Defina APIBRASIL_BEARER_TOKEN no ambiente.\n";
        return 1;
    }

    // -----------------------------------------------------------------------
    // Erros
    // -----------------------------------------------------------------------
    // Cada status HTTP do gateway vira uma exceção da hierarquia
    // ApiBrasilError, com status(), code() e response(). Capture da mais
    // específica para a mais genérica.
    try {
        api.consulta.cpf({{"cpf", "00000000000"}});

    } catch (const ValidationError& e) {
        // 400/422 — o body está errado. O template certo vem de
        // GET /api/v2/endpoint/body, e a doc está em doc.apibrasil.io.
        std::cerr << "Payload inválido: " << e.what() << "\n";

    } catch (const AuthenticationError&) {
        // 401 — bearer ausente/expirado. Refaça o login; não faça retry cego.
        std::cerr << "Refaça o login.\n";

    } catch (const InsufficientBalanceError& e) {
        // 402 — a mensagem já traz o valor exato da consulta que faltou.
        std::cerr << "Recarregue: " << e.what() << "\n";

    } catch (const PermissionError& e) {
        // 403 — DeviceToken de outra API, IP fora da whitelist, ou API que
        // exige cadastro PJ. Três causas, um só status: leia a mensagem.
        std::cerr << "Sem permissão: " << e.what() << "\n";

    } catch (const NotFoundError& e) {
        // 404 = não achou o dado. 410 = rota desativada, e a mensagem aponta a nova.
        std::cerr << (e.status().value_or(0) == 410 ? "Rota descontinuada: " : "Sem dados: ")
                  << e.what() << "\n";

    } catch (const RateLimitError& e) {
        // 429 — a SDK já tentou de novo antes de chegar aqui.
        std::cerr << "Limite atingido. Aguarde " << e.retryAfterMs().value_or(0) << "ms.\n";

    } catch (const ServerError& e) {
        // 5xx — gateway ou provedor upstream. Repetir com backoff faz sentido.
        std::cerr << "Falha do servidor: " << e.status().value_or(0) << " " << e.what() << "\n";

    } catch (const TimeoutError&) {
        // Estourou o tempo. ATENÇÃO: a operação pode ter completado no servidor.
        // Em envios e consultas, confirme o estado antes de repetir.
        std::cerr << "Timeout — verifique o estado antes de tentar de novo.\n";

    } catch (const NetworkError& e) {
        // Não chegou a haver resposta: DNS, TLS, conexão recusada.
        std::cerr << "Falha de rede: " << e.what() << "\n";

    } catch (const ApiBrasilError& e) {
        std::cerr << "Erro da SDK (HTTP " << e.status().value_or(0) << "): " << e.what() << "\n";
    }

    // -----------------------------------------------------------------------
    // Idempotência na prática
    // -----------------------------------------------------------------------
    try {
        Json saldo = comRetrySeguro([&] { return api.account.balance(); });
        std::cout << "\nSaldo: " << saldo.dump() << "\n";
    } catch (const ApiBrasilError& e) {
        std::cerr << "Desisti: " << e.what() << "\n";
    }

    return 0;
}
