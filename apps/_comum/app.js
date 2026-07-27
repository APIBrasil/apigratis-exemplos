/**
 * Helpers compartilhados dos apps de exemplo.
 *
 * Importe como módulo:
 *   import { chamar, avisar, definicoes } from '../_comum/app.js';
 */

/** Mensagens amigáveis para os status semânticos do gateway. */
const EXPLICACOES = {
	400: 'Requisição inválida — confira os campos.',
	401: 'Bearer inválido ou expirado — refaça o login no painel.',
	402: 'Sem saldo ou créditos. Recarregue em apibrasil.com.br.',
	403: 'Sem permissão: confira o DeviceToken, a whitelist de IPs e se a API exige cadastro PJ.',
	404: 'Sem dados para o que foi informado.',
	410: 'Rota descontinuada — atualize a integração.',
	422: 'Payload inválido — confira os campos.',
	429: 'Limite por minuto atingido. Aguarde e tente de novo.',
	500: 'Falha no servidor do app.',
	502: 'O gateway não respondeu.',
};

/**
 * Chama o backend do app (nunca o gateway direto — o token fica no servidor).
 *
 * @param {string} acao chave da allowlist no backend.php
 * @param {object} dados campos do formulário
 * @param {{endpoint?: string}} opcoes
 * @returns {Promise<any>} corpo da resposta do gateway
 */
export async function chamar(acao, dados = {}, { endpoint = 'backend.php' } = {}) {
	let resposta;

	try {
		resposta = await fetch(endpoint, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ acao, ...dados }),
		});
	} catch {
		// Falha antes de haver resposta: rede, DNS, servidor parado.
		throw new Error('Não foi possível falar com o servidor do app.');
	}

	const corpo = await resposta.json().catch(() => ({}));

	if (!resposta.ok) {
		// A mensagem do gateway é mais específica que a nossa tabela — quando
		// vem, ela ganha.
		throw new Error(corpo.message ?? EXPLICACOES[resposta.status] ?? `HTTP ${resposta.status}`);
	}

	return corpo;
}

/**
 * Desembrulha o dado útil das duas famílias de resposta:
 *   device-based → { error, message, response, api_limit }
 *   por crédito  → { error, message, balance, valor_consulta, data }
 */
export function conteudo(resposta) {
	if (resposta === null || typeof resposta !== 'object') return resposta;
	return resposta.response ?? resposta.data ?? resposta;
}

/** Custo e saldo de uma consulta por crédito, quando presentes. */
export function cobranca(resposta) {
	if (resposta === null || typeof resposta !== 'object') return null;
	if (resposta.valor_consulta === undefined && resposta.balance === undefined) return null;

	return {
		custo: resposta.valor_consulta ?? null,
		saldo: resposta.balance ?? null,
		homolog: resposta.homolog === true,
	};
}

/** Escreve na caixa de mensagem (elemento `#mensagem` por padrão). */
export function avisar(texto, tipo = 'erro', seletor = '#mensagem') {
	const caixa = document.querySelector(seletor);
	if (!caixa) return;

	caixa.className = `mensagem ${tipo}`;
	caixa.textContent = texto;
	caixa.hidden = false;
}

export function limparAviso(seletor = '#mensagem') {
	const caixa = document.querySelector(seletor);
	if (caixa) caixa.hidden = true;
}

/** Desabilita o botão enquanto a promessa não resolve. */
export async function ocupado(botao, tarefa) {
	const original = botao.textContent;
	botao.disabled = true;

	try {
		return await tarefa();
	} finally {
		botao.disabled = false;
		botao.textContent = original;
	}
}

/**
 * Preenche um <dl> com os campos escalares de um objeto.
 * Ignora vazios e aninhados — quem quiser o resto usa o <pre> do JSON bruto.
 *
 * @returns {number} quantidade de pares escritos
 */
export function definicoes(alvo, objeto, { rotulos = {} } = {}) {
	const lista = typeof alvo === 'string' ? document.querySelector(alvo) : alvo;
	lista.replaceChildren();

	for (const [chave, valor] of Object.entries(objeto ?? {})) {
		if (valor === null || valor === '' || typeof valor === 'object') continue;

		const dt = document.createElement('dt');
		dt.textContent = rotulos[chave] ?? chave.replaceAll('_', ' ');

		const dd = document.createElement('dd');
		dd.textContent = typeof valor === 'boolean' ? (valor ? 'sim' : 'não') : String(valor);

		lista.append(dt, dd);
	}

	return lista.childElementCount / 2;
}

/**
 * Monta uma tabela a partir de uma lista de objetos.
 *
 * @returns {{colunas: string[], linhas: object[]}} pronto para exportarCsv
 */
export function tabela(alvo, linhas, { colunas, numericas = [] } = {}) {
	const tabelaEl = typeof alvo === 'string' ? document.querySelector(alvo) : alvo;
	const cabecalho = tabelaEl.querySelector('thead tr') ?? tabelaEl.createTHead().insertRow();
	const corpo = tabelaEl.querySelector('tbody') ?? tabelaEl.createTBody();

	cabecalho.replaceChildren();
	corpo.replaceChildren();

	const dados = Array.isArray(linhas) ? linhas : [];
	if (dados.length === 0) {
		tabelaEl.hidden = true;
		return { colunas: [], linhas: [] };
	}

	// Sem colunas explícitas, usa a união das chaves escalares.
	const usadas =
		colunas ??
		[...new Set(dados.flatMap((item) => Object.keys(item ?? {})))].filter((coluna) =>
			dados.every((item) => typeof item?.[coluna] !== 'object')
		);

	for (const coluna of usadas) {
		const th = document.createElement('th');
		th.textContent = coluna.replaceAll('_', ' ');
		if (numericas.includes(coluna)) th.className = 'numerico';
		cabecalho.append(th);
	}

	for (const item of dados) {
		const tr = document.createElement('tr');
		for (const coluna of usadas) {
			const td = document.createElement('td');
			td.textContent = item?.[coluna] ?? '';
			if (numericas.includes(coluna)) td.className = 'numerico';
			tr.append(td);
		}
		corpo.append(tr);
	}

	tabelaEl.hidden = false;
	return { colunas: usadas, linhas: dados };
}

/** Acha o primeiro array de objetos dentro de uma resposta. */
export function primeiraLista(objeto) {
	if (Array.isArray(objeto)) return objeto;
	if (objeto === null || typeof objeto !== 'object') return null;

	for (const valor of Object.values(objeto)) {
		if (Array.isArray(valor) && valor.length > 0 && typeof valor[0] === 'object') {
			return valor;
		}
	}

	return null;
}

/**
 * Baixa um CSV. Escapa por RFC 4180 e leva BOM para o Excel abrir em UTF-8.
 */
export function exportarCsv(nomeArquivo, colunas, linhas, extras = []) {
	const celula = (valor) => `"${String(valor ?? '').replaceAll('"', '""')}"`;

	const conteudoCsv = [
		...extras.map(([chave, valor]) => `${celula(chave)},${celula(valor)}`),
		...(extras.length && colunas.length ? [''] : []),
		...(colunas.length ? [colunas.map(celula).join(',')] : []),
		...linhas.map((item) => colunas.map((coluna) => celula(item?.[coluna])).join(',')),
	].join('\r\n');

	const blob = new Blob(['﻿' + conteudoCsv], { type: 'text/csv;charset=utf-8' });
	const link = document.createElement('a');

	link.href = URL.createObjectURL(blob);
	link.download = nomeArquivo;
	link.click();
	URL.revokeObjectURL(link.href);
}

/**
 * Mostra um QR Code num <dialog>.
 *
 * A API WhatsApp devolve data URI em `response.qrcode`; a Evolution devolve
 * base64 puro em `response.qrcode.base64`. Aceitamos os dois.
 */
export function mostrarQrCode(titulo, valor, respostaCompleta, seletor = '#modal') {
	const modal = document.querySelector(seletor);
	modal.querySelector('h2').textContent = titulo;

	const alvo = modal.querySelector('.corpo-modal');
	const bruto = typeof valor === 'object' ? (valor?.base64 ?? '') : (valor ?? '');

	if (typeof bruto === 'string' && bruto.length > 0) {
		const img = document.createElement('img');
		img.src = bruto.startsWith('data:') ? bruto : `data:image/png;base64,${bruto}`;
		img.alt = titulo;

		const dica = document.createElement('p');
		dica.className = 'sutil pequeno';
		dica.textContent = 'WhatsApp → Aparelhos conectados → Conectar aparelho';

		alvo.replaceChildren(img, dica);
	} else {
		const p = document.createElement('p');
		p.textContent =
			respostaCompleta?.message ?? 'Sem QR Code — a sessão provavelmente já está conectada.';
		alvo.replaceChildren(p);
	}

	modal.showModal();
}

/** Preenche um <select> com opções. */
export function opcoes(alvo, itens, { valor, rotulo, vazio } = {}) {
	const select = typeof alvo === 'string' ? document.querySelector(alvo) : alvo;
	select.replaceChildren();

	if (vazio !== undefined) select.append(new Option(vazio, ''));

	for (const item of itens ?? []) {
		const v = valor ? valor(item) : item;
		select.append(new Option(rotulo ? rotulo(item) : v, v));
	}

	select.disabled = (itens?.length ?? 0) === 0;
	return select;
}

/** Escreve o JSON bruto no <pre> de depuração e revela o <details>. */
export function mostrarJson(resposta, seletor = '#json') {
	const alvo = document.querySelector(seletor);
	if (!alvo) return;

	alvo.textContent = JSON.stringify(resposta, null, 2);
	alvo.closest('details')?.removeAttribute('hidden');
}

/** Formata um número como moeda brasileira. Passa strings adiante intactas. */
export function moeda(valor) {
	const numero = typeof valor === 'string' ? Number(valor.replace(/[^\d,.-]/g, '').replace(',', '.')) : valor;

	if (typeof numero !== 'number' || Number.isNaN(numero)) return valor ?? '—';

	return numero.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

/** Formata uma data ISO ou brasileira para dd/mm/aaaa hh:mm. */
export function dataHora(valor) {
	if (!valor) return '—';

	const data = new Date(valor);
	if (Number.isNaN(data.getTime())) return String(valor);

	return data.toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
}
