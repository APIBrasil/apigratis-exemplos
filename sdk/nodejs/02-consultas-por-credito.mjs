/**
 * 02 — Consultas por crédito
 *
 * Rotas /consulta/{servico}/credits. Só precisam do bearer: debitam o saldo da
 * conta e ignoram o DeviceToken.
 *
 * Este exemplo roda em HOMOLOGAÇÃO por padrão (dados fictícios, sem cobrança).
 * Para valer, rode com COBRAR=1.
 *
 *   node --env-file=../../.env 02-consultas-por-credito.mjs
 *   COBRAR=1 node --env-file=../../.env 02-consultas-por-credito.mjs
 */
import { ApiBrasil, InsufficientBalanceError, ValidationError } from 'apigratis-sdk-nodejs';

const api = new ApiBrasil();

// `homolog: true` é o sandbox da plataforma — não existe URL separada de teste.
const homolog = process.env.COBRAR !== '1';
console.log(homolog ? '· modo homologação (sem cobrança)\n' : '· CONSULTAS REAIS — vai debitar saldo\n');

/** Toda consulta devolve o mesmo envelope: { error, message, balance, valor_consulta, data }. */
function resumir(rotulo, resposta) {
	console.log(`${rotulo}:`);
	console.log('  custou:', resposta.valor_consulta ?? '—', '| saldo restante:', resposta.balance ?? '—');
	console.log('  data:', JSON.stringify(resposta.data)?.slice(0, 300));
}

try {
	// CNPJ — cadastro básico.
	const empresa = await api.consulta.cnpj({ cnpj: '00000000000000', homolog });
	resumir('CNPJ', empresa);

	// O campo `tipo` é o que escolhe o PRODUTO dentro do serviço. Mesmo endpoint,
	// preço e retorno diferentes. São 210+ tipos no catálogo.
	const socios = await api.consulta.cnpj({ cnpj: '00000000000000', tipo: 'lista-socios', homolog });
	resumir('CNPJ · lista-socios', socios);

	// CPF.
	const pessoa = await api.consulta.cpf({ cpf: '00000000000', homolog });
	resumir('CPF', pessoa);

	// Veicular por placa.
	const veiculo = await api.consulta.veiculos({ placa: 'ABC1234', homolog });
	resumir('Veículos', veiculo);

	// Qualquer serviço do catálogo, inclusive os que não têm método dedicado.
	const score = await api.consulta.generic('cpf', { cpf: '00000000000', tipo: 'serasa-score-pf', homolog });
	resumir('Serasa Score PF', score);

	// Descobrindo o que existe: catálogo vivo do gateway.
	const { apis = [] } = await api.catalog.apis('consulta');
	console.log(`\n${apis.length} API(s) com "consulta" no nome. Primeiras:`);
	for (const item of apis.slice(0, 5)) {
		console.log(`  ${item.name} · R$ ${item.price ?? '—'}`);
	}
} catch (error) {
	if (error instanceof InsufficientBalanceError) {
		// 402 — a mensagem do gateway já traz o valor exato da consulta.
		console.error('Sem saldo:', error.message);
	} else if (error instanceof ValidationError) {
		// 422 — o template do body está em GET /api/v2/endpoint/body.
		console.error('Body inválido:', error.message, error.response);
	} else {
		throw error;
	}
	process.exit(1);
}
