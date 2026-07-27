/**
 * 03 — WhatsApp
 *
 * Serviço device-based: exige Authorization: Bearer + header DeviceToken.
 * O DeviceToken identifica UMA sessão de WhatsApp; o bearer identifica a conta.
 *
 * Fluxo completo: device → sessão → QR Code → pareamento → envio.
 *
 *   node --env-file=../../.env 03-whatsapp.mjs                      # usa o device do .env
 *   CRIAR_DEVICE=1 node --env-file=../../.env 03-whatsapp.mjs       # cria um device novo
 *   NUMERO=5511999999999 node --env-file=../../.env 03-whatsapp.mjs # e envia de verdade
 */
import { writeFile } from 'node:fs/promises';
import { ApiBrasil, PermissionError } from 'apigratis-sdk-nodejs';

const api = new ApiBrasil();
let temDevice = Boolean(process.env.APIBRASIL_DEVICE_TOKEN);

// ---------------------------------------------------------------------------
// 1. O device
// ---------------------------------------------------------------------------
// A SecretKey (painel → API WhatsApp → SecretKey) é a única credencial que cria
// devices. Depois de criado, o device_token substitui ela no dia a dia.
if (process.env.CRIAR_DEVICE === '1') {
	if (!process.env.APIBRASIL_SECRET_KEY) {
		console.error('CRIAR_DEVICE=1 exige APIBRASIL_SECRET_KEY no .env.');
		process.exit(1);
	}

	const criado = await api.devices.store(
		{ device_name: 'exemplo-nodejs', type: 'server' },
		{ secretKey: process.env.APIBRASIL_SECRET_KEY }
	);

	const token = criado.device?.device_token;
	console.log('Device criado. Guarde este token no seu .env:');
	console.log(`APIBRASIL_DEVICE_TOKEN=${token}\n`);
	api.setDeviceToken(token);
	temDevice = true;
}

if (!temDevice) {
	console.error('Defina APIBRASIL_DEVICE_TOKEN no .env, ou rode com CRIAR_DEVICE=1.');
	process.exit(1);
}

// ---------------------------------------------------------------------------
// 2. A sessão
// ---------------------------------------------------------------------------
// Os webhooks são opcionais, mas é aqui que se registram — não existe outra
// chamada para isso. Sem eles você só descobre mensagens recebidas por polling.
try {
	const sessao = await api.whatsapp.start({
		webhook_wh_message: process.env.WEBHOOK_MENSAGENS, // mensagem recebida
		webhook_wh_status: process.env.WEBHOOK_STATUS, // status da sessão mudou
		webhook_wh_connect: process.env.WEBHOOK_CONEXAO, // conectou/desconectou
		webhook_wh_qrcode: process.env.WEBHOOK_QRCODE, // novo QR Code gerado
	});
	console.log('Sessão:', sessao.message ?? sessao);
} catch (error) {
	if (error instanceof PermissionError) {
		// 403 aqui é quase sempre DeviceToken de outra API, ou IP fora da whitelist.
		console.error('Sem permissão para esse device:', error.message);
		process.exit(1);
	}
	throw error;
}

// ---------------------------------------------------------------------------
// 3. O QR Code
// ---------------------------------------------------------------------------
// Vem como data URI base64. Numa aplicação real você joga isso num <img src>;
// aqui gravamos em disco para escanear.
const qr = await api.whatsapp.qrcode();
const dataUri = qr.response?.qrcode;

if (dataUri?.startsWith('data:image')) {
	await writeFile('qrcode.png', Buffer.from(dataUri.split(',')[1], 'base64'));
	console.log('QR Code salvo em qrcode.png — escaneie no WhatsApp → aparelhos conectados.');
} else {
	console.log('QR Code:', qr.response ?? qr.message ?? 'sessão provavelmente já conectada');
}

// ---------------------------------------------------------------------------
// 4. Envios
// ---------------------------------------------------------------------------
const numero = process.env.NUMERO;
if (!numero) {
	console.log('\nDefina NUMERO=5511999999999 para enviar de verdade.');
	process.exit(0);
}

// Texto. `time_typing` simula "digitando..." antes de entregar.
const texto = await api.whatsapp.sendText({
	number: numero,
	text: 'Olá! Mensagem enviada pela SDK Node da APIBrasil 👋',
	time_typing: 1500,
});
console.log('Texto:', texto.message ?? texto);

// Arquivo por URL pública. Para base64, use sendFile64.
await api.whatsapp.sendFile({
	number: numero,
	path: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
	caption: 'Segue o documento',
});

// Áudio (o gateway converte para mp3; máx. 6 min) e localização.
await api.whatsapp.sendAudio({ number: numero, path: 'https://filesamples.com/samples/audio/mp3/sample3.mp3' });
await api.whatsapp.sendLocation({ number: numero, lat: -23.5613, lng: -46.6565 });

// Qualquer action da documentação, mesmo sem método dedicado na SDK.
await api.whatsapp.request('sendLink', { number: numero, url: 'https://apibrasil.com.br', text: 'Conheça' });

// Fila: mesma action, processada de forma assíncrona pelo gateway. É o caminho
// certo para disparos em volume — devolve na hora e não segura sua requisição.
const enfileirado = await api.whatsapp.queue('sendText', {
	number: numero,
	text: 'Esta foi pela fila 🚀',
});
console.log('Fila:', enfileirado.message ?? enfileirado);

// ---------------------------------------------------------------------------
// 5. Vários devices no mesmo processo
// ---------------------------------------------------------------------------
// withDevice devolve um cliente novo, sem alterar o original.
if (process.env.APIBRASIL_DEVICE_TOKEN_SUPORTE) {
	const suporte = api.withDevice(process.env.APIBRASIL_DEVICE_TOKEN_SUPORTE);
	await suporte.whatsapp.sendText({ number: numero, text: 'Falando pela sessão do suporte' });
}
