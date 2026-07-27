/**
 * 04 — Serviços device-based (fora do WhatsApp)
 *
 * Todos seguem o mesmo formato: POST /{servico}/{action} com Bearer + DeviceToken.
 * O device precisa ser da API correspondente — um DeviceToken de WhatsApp dá 403
 * em /vehicles.
 *
 *   node --env-file=../../.env 04-servicos-device.mjs
 */
import { ApiBrasil, ApiBrasilError, NotFoundError } from 'apigratis-sdk-nodejs';

const api = new ApiBrasil();

/**
 * Cada API tem o seu device. Rode com o token certo por serviço, ou passe
 * `{ deviceToken }` nas opções da chamada — que é o que fazemos aqui.
 */
const devices = {
	cep: process.env.APIBRASIL_DEVICE_TOKEN_CEP ?? process.env.APIBRASIL_DEVICE_TOKEN,
	correios: process.env.APIBRASIL_DEVICE_TOKEN_CORREIOS ?? process.env.APIBRASIL_DEVICE_TOKEN,
	veiculos: process.env.APIBRASIL_DEVICE_TOKEN_VEICULOS ?? process.env.APIBRASIL_DEVICE_TOKEN,
	clima: process.env.APIBRASIL_DEVICE_TOKEN_CLIMA ?? process.env.APIBRASIL_DEVICE_TOKEN,
	sms: process.env.APIBRASIL_DEVICE_TOKEN_SMS ?? process.env.APIBRASIL_DEVICE_TOKEN,
};

/** Roda um bloco e reporta a falha sem derrubar os outros exemplos. */
async function tentar(rotulo, fn) {
	try {
		const resposta = await fn();
		console.log(`\n${rotulo}:`);
		console.log(JSON.stringify(resposta.response ?? resposta, null, 2).slice(0, 600));
	} catch (error) {
		if (error instanceof NotFoundError) {
			console.log(`\n${rotulo}: sem dados (HTTP ${error.status})`);
		} else if (error instanceof ApiBrasilError) {
			console.log(`\n${rotulo}: ${error.message} (HTTP ${error.status})`);
		} else {
			throw error;
		}
	}
}

// CEP — endereço completo com geolocalização.
await tentar('CEP', () => api.cep.cep({ cep: '01001000' }, { deviceToken: devices.cep }));

// Ainda em /cep: cidades por DDD, bairros, cidades, estados, distância.
await tentar('Cidades por DDD', () =>
	api.cep.request('cidadesPorDDD', { ddd: '11' }, { deviceToken: devices.cep })
);

// Correios — rastreio de encomenda.
await tentar('Rastreio', () =>
	api.correios.rastreio({ code: 'AA123456789BR' }, { deviceToken: devices.correios })
);

// Veículos por placa. Diferente de consulta.veiculos (créditos): aqui é device.
await tentar('Placa · dados', () =>
	api.vehicles.dados({ placa: 'ABC1234' }, { deviceToken: devices.veiculos })
);
await tentar('Placa · FIPE', () =>
	api.vehicles.fipe({ placa: 'ABC1234' }, { deviceToken: devices.veiculos })
);

// Tabela FIPE navegável: referência → marcas → modelos → ano → valor.
await tentar('FIPE · marcas', () =>
	api.fipe.request('ConsultarMarcas', { codigoTabelaReferencia: 300, codigoTipoVeiculo: 1 }, {
		deviceToken: devices.veiculos,
	})
);

// Clima por cidade ou por coordenadas.
await tentar('Clima', () =>
	api.weather.request('city', { city: 'São Paulo' }, { deviceToken: devices.clima })
);

// Feriados do ano (nacionais, estaduais, facultativos — o `type` decide).
await tentar('Feriados', () =>
	api.holidays.request('feriados', { year: new Date().getFullYear() }, { deviceToken: devices.clima })
);

// GeoIP.
await tentar('GeoIP', () => api.databaseIp.ip({ ip: '8.8.8.8' }, { deviceToken: devices.cep }));

// SMS — device-based. Só envia de verdade com NUMERO definido.
if (process.env.NUMERO) {
	await tentar('SMS', () =>
		api.sms.send(
			{ number: process.env.NUMERO, message: 'Seu código: 123456' },
			{ deviceToken: devices.sms }
		)
	);
	// Alternativa sem device, debitando créditos da conta:
	// await api.sms.sendWithCredits({ number: process.env.NUMERO, message: 'Olá!' });
}

// Serviço sem método dedicado? A saída genérica cobre o gateway inteiro.
// await api.request('POST', '/translate/text', { text: 'Olá', to: 'en' });
