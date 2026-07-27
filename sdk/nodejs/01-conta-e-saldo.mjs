/**
 * 01 — Conta e saldo
 *
 * O básico: montar o cliente, confirmar que o gateway responde e ler os dados
 * da conta. Nada aqui gasta crédito.
 *
 *   node --env-file=../../.env 01-conta-e-saldo.mjs
 */
import { ApiBrasil, ApiBrasilError, AuthenticationError } from 'apigratis-sdk-nodejs';

// Sem argumentos, o cliente lê APIBRASIL_BEARER_TOKEN, APIBRASIL_DEVICE_TOKEN,
// APIBRASIL_SECRET_KEY e APIBRASIL_BASE_URL do ambiente.
const api = new ApiBrasil();

// /status é público — serve para separar "minha credencial está errada" de
// "o gateway está fora".
const status = await api.catalog.status();
console.log('Gateway:', status.message ?? status);

if (!process.env.APIBRASIL_BEARER_TOKEN) {
	console.error('\nDefina APIBRASIL_BEARER_TOKEN no .env para seguir.');
	process.exit(1);
}

try {
	const saldo = await api.account.balance();
	console.log('Saldo:', saldo);

	const plano = await api.account.plan();
	console.log('Plano:', plano);

	// Devices ativos na conta — cada um é uma instância de um serviço.
	const { devices = [] } = await api.devices.list();
	console.log(`\n${devices.length} device(s):`);
	for (const device of devices) {
		console.log(`  ${device.device_name} · ${device.api?.name ?? '—'} · ${device.status ?? '—'}`);
	}
} catch (error) {
	if (error instanceof AuthenticationError) {
		console.error('Bearer inválido ou expirado — refaça o login no painel.');
	} else if (error instanceof ApiBrasilError) {
		console.error(`Falhou (HTTP ${error.status}): ${error.message}`);
	} else {
		throw error;
	}
	process.exit(1);
}

// Login por email/senha, se você preferir não guardar o JWT:
//
//   const api = new ApiBrasil();
//   const sessao = await api.auth.login({ email, password });
//   if (sessao.requires_2fa) {
//     await api.auth.send2fa({ challenge: sessao.challenge, method: 'email' });
//     await api.auth.verify2fa({ challenge: sessao.challenge, code: '000000' });
//   }
//   // o token já ficou guardado no cliente — siga usando `api` normalmente
