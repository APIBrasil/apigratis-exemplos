// package.json -> { "type": "module" }
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { SSEClientTransport } from '@modelcontextprotocol/sdk/client/sse.js';

// Configurações fixas
const MCP_URL  = 'https://server.mcp.apibrasil.io/mcp';
const EMAIL    = 'jhondoe@gmail.com';
const PASSWORD = '123456';

// Tokens de cada API
const TOKENS = {
  'apibrasil.cep_lookup':        'TOKEN_CEP_AQUI',
  'apibrasil.vehicles_consulta': 'TOKEN_VEICULOS_AQUI',
  'apibrasil.weather_city':      'TOKEN_CLIMA_AQUI',
  'apibrasil.sms_send':          'TOKEN_SMS_AQUI',
};

// Converte resposta para JSON se possível
const parseJSON = r => {
  const t = r?.content?.[0];
  if (t?.type === 'text' && typeof t.text === 'string') {
    try { return JSON.parse(t.text); } catch { return t.text; }
  }
  return r;
};

// Helper para chamar tool com token correto
const call = (client, name, args) =>
  client.callTool({ name, arguments: { deviceToken: TOKENS[name], ...args } });

async function main() {
  const client = new Client({ name: 'meu-app', version: '1.0.0' });
  await client.connect(new SSEClientTransport(new URL(MCP_URL)));

  // Login
  const login = parseJSON(await call(client, 'apibrasil.auth_login', { email: EMAIL, password: PASSWORD, checkBalance: true }));
  const bearer = login?.bearer ?? login?.token ?? login?.data?.bearer ?? login?.data?.token;
  if (!bearer) throw new Error('Bearer não retornado no login');

  // Chamadas em paralelo
  const [cep, veic, clima, sms] = await Promise.all([
    call(client, 'apibrasil.cep_lookup',        { bearer, cep: '01001000' }),
    call(client, 'apibrasil.vehicles_consulta', { bearer, tipo: 'agregados-basica', placa: 'ABC1234' }),
    call(client, 'apibrasil.weather_city',      { bearer, cidade: 'São Paulo' }),
    call(client, 'apibrasil.sms_send',          { bearer, numero: '11999999999', mensagem: 'Teste MCP' }),
  ].map(p => p.then(parseJSON)));

  console.log('CEP:', cep);
  console.log('Veículos:', veic);
  console.log('Clima:', clima);
  console.log('SMS:', sms);

  await client.close();
}

main().catch(console.error);
