/**
 * 05 — Erros, retry e observabilidade
 *
 * A parte que separa um script de uma integração de produção.
 *
 *   node --env-file=../../.env 05-erros-e-retry.mjs
 */
import {
	ApiBrasil,
	ApiBrasilError,
	AuthenticationError,
	InsufficientBalanceError,
	NetworkError,
	NotFoundError,
	PermissionError,
	RateLimitError,
	ServerError,
	TimeoutError,
	ValidationError,
} from 'apigratis-sdk-nodejs';

// ---------------------------------------------------------------------------
// Retry
// ---------------------------------------------------------------------------
// O padrão são 2 tentativas extras, backoff exponencial, SÓ em 429 e falha de
// conexão — e respeitando o Retry-After da resposta.
//
// Timeout e erro de negócio nunca são repetidos: um sendText que deu timeout
// pode ter sido entregue, e uma consulta repetida cobra duas vezes.
const api = new ApiBrasil({
	timeout: 30_000,
	retry: {
		retries: 3,
		minDelayMs: 500,
		retryOnStatuses: [429, 503],
	},
	// Hooks: é aqui que você pluga log estruturado, métricas ou tracing.
	hooks: {
		onRequest: ({ method, url, attempt }) => console.log(`→ ${method} ${url} (tentativa ${attempt})`),
		onResponse: ({ status, durationMs }) => console.log(`← ${status} em ${durationMs}ms`),
		onRetry: ({ delayMs, reason }) => console.warn(`↻ retry em ${delayMs}ms: ${reason}`),
	},
});

// Para desligar: `retry: false`.

// ---------------------------------------------------------------------------
// Erros
// ---------------------------------------------------------------------------
// Cada status HTTP do gateway vira uma classe. Todas estendem ApiBrasilError e
// carregam .status, .code, .message e .response (o corpo original do gateway).
try {
	await api.consulta.cpf({ cpf: '00000000000' });
} catch (error) {
	if (error instanceof ValidationError) {
		// 400/422 — o body está errado. O template certo vem de
		// GET /api/v2/endpoint/body, e a doc está em doc.apibrasil.io.
		console.error('Payload inválido:', error.message, error.response);
	} else if (error instanceof AuthenticationError) {
		// 401 — bearer ausente/expirado. Refaça o login; não faça retry cego.
		console.error('Refaça o login.');
	} else if (error instanceof InsufficientBalanceError) {
		// 402 — a mensagem já traz o valor exato da consulta que faltou.
		console.error('Recarregue:', error.message);
	} else if (error instanceof PermissionError) {
		// 403 — DeviceToken de outra API, IP fora da whitelist, ou API que
		// exige cadastro PJ. São três causas com o mesmo status: leia a mensagem.
		console.error('Sem permissão:', error.message);
	} else if (error instanceof NotFoundError) {
		// 404 = não achou o dado. 410 = rota desativada, e a mensagem aponta a nova.
		console.error(error.status === 410 ? 'Rota descontinuada:' : 'Sem dados:', error.message);
	} else if (error instanceof RateLimitError) {
		// 429 — a SDK já tentou de novo antes de chegar aqui.
		console.error(`Limite atingido. Aguarde ${error.retryAfterMs}ms.`);
	} else if (error instanceof ServerError) {
		// 5xx — gateway ou provedor upstream. Repetir com backoff faz sentido.
		console.error('Falha do servidor:', error.status, error.message);
	} else if (error instanceof TimeoutError) {
		// Estourou o tempo. ATENÇÃO: a operação pode ter completado no servidor.
		// Em envios e consultas, confirme o estado antes de repetir.
		console.error('Timeout — verifique o estado antes de tentar de novo.');
	} else if (error instanceof NetworkError) {
		// Não chegou a haver resposta: DNS, TLS, conexão recusada.
		console.error('Falha de rede:', error.message);
	} else if (error instanceof ApiBrasilError) {
		console.error(`Erro da SDK (HTTP ${error.status}, código ${error.code}):`, error.message);
	} else {
		throw error; // não é da SDK — deixe estourar
	}
}

// ---------------------------------------------------------------------------
// Idempotência na prática
// ---------------------------------------------------------------------------
// Operações que cobram ou enviam merecem cuidado extra. O padrão abaixo repete
// só o que é seguro repetir.
async function comRetrySeguro(fn, tentativas = 3) {
	for (let i = 1; i <= tentativas; i++) {
		try {
			return await fn();
		} catch (error) {
			const podeRepetir = error instanceof ServerError || error instanceof NetworkError;
			if (!podeRepetir || i === tentativas) throw error;
			// TimeoutError herda de NetworkError, mas indica trabalho possivelmente
			// concluído — trate à parte se a operação não for idempotente.
			if (error instanceof TimeoutError) throw error;
			await new Promise((r) => setTimeout(r, 2 ** i * 250));
		}
	}
}

try {
	const saldo = await comRetrySeguro(() => api.account.balance());
	console.log('\nSaldo:', saldo);
} catch (error) {
	console.error('Desisti:', error.message);
}
