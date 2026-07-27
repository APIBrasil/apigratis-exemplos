/**
 * Client MCP da APIBrasil — Node.js
 *
 * Conecta no servidor MCP, lista as tools disponíveis e faz algumas chamadas.
 *
 *   node --env-file=../../.env app.mjs
 */
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

const MCP_URL = process.env.APIBRASIL_MCP_URL ?? 'https://mcp.apibrasil.cloud/mcp';
const BEARER = process.env.APIBRASIL_BEARER_TOKEN;
const DEVICE_TOKEN = process.env.APIBRASIL_DEVICE_TOKEN;

if (!BEARER) {
	console.error('Defina APIBRASIL_BEARER_TOKEN no .env da raiz.');
	process.exit(1);
}

// ---------------------------------------------------------------------------
// Conexão
// ---------------------------------------------------------------------------
// Streamable HTTP — o transporte atual do MCP. (O SSEClientTransport que
// aparecia em exemplos antigos foi descontinuado.)
//
// As credenciais vão por HEADER, não como argumento de tool. Assim elas não
// entram no contexto do modelo nem nos logs de tool do client.
const transport = new StreamableHTTPClientTransport(new URL(MCP_URL), {
	requestInit: {
		headers: {
			'X-Apibrasil-Bearer': BEARER,
			...(DEVICE_TOKEN ? { DeviceToken: DEVICE_TOKEN } : {}),
			// SecretKey: process.env.APIBRASIL_SECRET_KEY,   // só para criar devices
			// Se o deploy do MCP exigir autenticação própria (MCP_AUTH_TOKEN):
			...(process.env.APIBRASIL_MCP_TOKEN
				? { Authorization: `Bearer ${process.env.APIBRASIL_MCP_TOKEN}` }
				: {}),
		},
	},
});

const client = new Client({ name: 'apibrasil-exemplos', version: '1.0.0' }, { capabilities: {} });

await client.connect(transport);
console.log(`Conectado em ${MCP_URL}`);

/**
 * Extrai o dado útil de um resultado de tool.
 *
 * O MCP devolve `content[]` com blocos tipados. As tools da APIBrasil trazem um
 * bloco `text` com JSON e também `structuredContent` — prefira o segundo.
 */
function ler(resultado) {
	if (resultado.structuredContent) return resultado.structuredContent;

	const texto = resultado.content?.find((bloco) => bloco.type === 'text')?.text;
	if (typeof texto !== 'string') return resultado;

	try {
		return JSON.parse(texto);
	} catch {
		return texto;
	}
}

/** Chama uma tool e trata o erro de negócio, que vem como resultado, não exceção. */
async function chamar(nome, argumentos = {}) {
	const resultado = await client.callTool({ name: nome, arguments: argumentos });

	if (resultado.isError) {
		// 402 saldo, 403 device/IP, 410 rota morta, 422 validação — o servidor
		// preserva a mensagem original do gateway em vez de um "HTTP 402" opaco.
		throw new Error(`${nome}: ${JSON.stringify(ler(resultado))}`);
	}

	return ler(resultado);
}

try {
	// -----------------------------------------------------------------------
	// Tools disponíveis
	// -----------------------------------------------------------------------
	// No profile `core` (padrão) são ~23 tools + 3 de descoberta. No `full`,
	// ~223 — mais tools ocupam mais contexto do modelo, então o core é melhor
	// ponto de partida.
	const { tools } = await client.listTools();
	console.log(`\n${tools.length} tool(s). Por domínio:`);

	const porDominio = new Map();
	for (const tool of tools) {
		const dominio = tool.name.split('.')[1] ?? '?';
		porDominio.set(dominio, (porDominio.get(dominio) ?? 0) + 1);
	}
	for (const [dominio, total] of [...porDominio].sort()) {
		console.log(`  apibrasil.${dominio}.* — ${total}`);
	}

	// -----------------------------------------------------------------------
	// Chamadas
	// -----------------------------------------------------------------------
	// Nomes na convenção 2.0: apibrasil.<domínio>.<ação>, sempre três segmentos.
	// O bearer já foi pelo header — não precisa repetir nos argumentos.

	// Saldo da conta (leitura pura, não gasta nada).
	console.log('\nSaldo:', await chamar('apibrasil.balance.get'));

	// Chamadas independentes em paralelo. A sessão MCP é única e multiplexa.
	const [cep, clima] = await Promise.all([
		chamar('apibrasil.cep.lookup', { cep: '01001000' }),
		chamar('apibrasil.weather.city', { city: 'São Paulo' }),
	]);
	console.log('\nCEP:', JSON.stringify(cep)?.slice(0, 300));
	console.log('\nClima:', JSON.stringify(clima)?.slice(0, 300));

	// Consulta por crédito. `homolog: true` roda em sandbox, sem debitar.
	const cnpj = await chamar('apibrasil.credits.consulta', {
		service: 'cnpj',
		payload: { cnpj: '00000000000000', homolog: true },
	});
	console.log('\nCNPJ (homologação):', JSON.stringify(cnpj)?.slice(0, 400));

	// WhatsApp exige DeviceToken — que também já foi pelo header.
	if (DEVICE_TOKEN && process.env.NUMERO) {
		const enviado = await chamar('apibrasil.wpp.send_text', {
			number: process.env.NUMERO,
			text: 'Olá! Enviado via MCP 👋',
		});
		console.log('\nWhatsApp:', JSON.stringify(enviado)?.slice(0, 300));
	}

	// -----------------------------------------------------------------------
	// Prompts e resources
	// -----------------------------------------------------------------------
	// Além de tools, o servidor publica prompts (apibrasil.flow.*, apibrasil.help.*)
	// e resources (apibrasil://catalog). Resources não ocupam espaço na lista de
	// tools — é o lugar certo para dados de referência.
	const { prompts = [] } = await client.listPrompts().catch(() => ({ prompts: [] }));
	const { resources = [] } = await client.listResources().catch(() => ({ resources: [] }));
	console.log(`\n${prompts.length} prompt(s), ${resources.length} resource(s)`);
} catch (erro) {
	console.error('\nFalhou:', erro.message);
	process.exitCode = 1;
} finally {
	await client.close();
}
