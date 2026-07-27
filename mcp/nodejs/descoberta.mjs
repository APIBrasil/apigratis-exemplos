/**
 * Descoberta dinâmica via MCP
 *
 * O gateway roteia por catch-all (`/{servico}/{action}`) e expõe o catálogo
 * vivo. Por isso três tools cobrem QUALQUER serviço, inclusive os que ainda não
 * têm tool dedicada — e API nova aparece sem redeploy do MCP.
 *
 *   catalog   → que APIs existem?
 *   describe  → qual o body dessa action?
 *   call      → executa
 *
 * É esse fluxo que um agente segue quando não conhece o endpoint de antemão.
 *
 *   node --env-file=../../.env descoberta.mjs
 *   node --env-file=../../.env descoberta.mjs cep
 */
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';

const MCP_URL = process.env.APIBRASIL_MCP_URL ?? 'https://mcp.apibrasil.cloud/mcp';
const BEARER = process.env.APIBRASIL_BEARER_TOKEN;
const BUSCA = process.argv[2] ?? 'cep';

if (!BEARER) {
	console.error('Defina APIBRASIL_BEARER_TOKEN no .env da raiz.');
	process.exit(1);
}

const transport = new StreamableHTTPClientTransport(new URL(MCP_URL), {
	requestInit: {
		headers: {
			'X-Apibrasil-Bearer': BEARER,
			...(process.env.APIBRASIL_DEVICE_TOKEN
				? { DeviceToken: process.env.APIBRASIL_DEVICE_TOKEN }
				: {}),
		},
	},
});

const client = new Client({ name: 'apibrasil-descoberta', version: '1.0.0' }, { capabilities: {} });
await client.connect(transport);

function ler(resultado) {
	if (resultado.structuredContent) return resultado.structuredContent;
	const texto = resultado.content?.find((b) => b.type === 'text')?.text;
	try {
		return typeof texto === 'string' ? JSON.parse(texto) : resultado;
	} catch {
		return texto;
	}
}

async function chamar(nome, argumentos = {}) {
	const resultado = await client.callTool({ name: nome, arguments: argumentos });
	if (resultado.isError) throw new Error(`${nome}: ${JSON.stringify(ler(resultado))}`);
	return ler(resultado);
}

try {
	// -----------------------------------------------------------------------
	// 1. catalog — o que existe?
	// -----------------------------------------------------------------------
	// Equivale a GET /api/v2/apis. Traz slug, serviço e preço de cada API ativa.
	console.log(`Buscando APIs com "${BUSCA}"…\n`);
	const catalogo = await chamar('apibrasil.discovery.catalog', { search: BUSCA });

	const apis = catalogo.apis ?? catalogo.data ?? (Array.isArray(catalogo) ? catalogo : []);
	if (apis.length === 0) {
		console.log('Nenhuma API encontrada. Tente outro termo.');
		process.exit(0);
	}

	for (const api of apis.slice(0, 10)) {
		console.log(`  ${api.slug ?? api.name} · serviço: ${api.service ?? '—'} · R$ ${api.price ?? '—'}`);
	}

	const escolhida = apis[0];
	const servico = escolhida.service ?? escolhida.slug;
	console.log(`\n→ Escolhendo "${servico}"`);

	// -----------------------------------------------------------------------
	// 2. describe — qual o body?
	// -----------------------------------------------------------------------
	// Equivale a GET /api/v2/endpoint/body. É o que evita o 422: em vez de
	// adivinhar os campos, o modelo pede o template.
	const acao = escolhida.action ?? 'cep';
	const template = await chamar('apibrasil.discovery.describe', {
		service: servico,
		action: acao,
	});
	console.log('\nTemplate do body:');
	console.log(JSON.stringify(template, null, 2).slice(0, 600));

	// -----------------------------------------------------------------------
	// 3. call — executa
	// -----------------------------------------------------------------------
	// Despacha para ANY /api/v2/{service}/{action} com o payload montado.
	// Aqui usamos um payload de exemplo; um agente montaria a partir do template.
	console.log('\nChamando…');
	const resposta = await chamar('apibrasil.discovery.call', {
		service: servico,
		action: acao,
		payload: { cep: '01001000' },
	});
	console.log(JSON.stringify(resposta, null, 2).slice(0, 800));

	// -----------------------------------------------------------------------
	// O catálogo também é resource
	// -----------------------------------------------------------------------
	// `apibrasil://catalog` e o template `apibrasil://api/{slug}` entregam o
	// mesmo dado sem ocupar espaço na lista de tools do modelo.
	const recurso = await client.readResource({ uri: 'apibrasil://catalog' }).catch(() => null);
	if (recurso) {
		console.log(`\nResource apibrasil://catalog: ${recurso.contents?.length ?? 0} bloco(s)`);
	}
} catch (erro) {
	console.error('\nFalhou:', erro.message);
	process.exitCode = 1;
} finally {
	await client.close();
}
