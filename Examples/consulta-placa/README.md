# Consulta de placa — Node.js

## Como iniciar
1. Instale Node.js 18 ou superior.
2. Abra o terminal nesta pasta e execute `npm install`.
3. Copie `.env.example` para `.env`.
4. Para testar sem gastar créditos, mantenha `DEMO_MODE=true`.
5. Execute `npm start` e abra http://localhost:3000.
6. Para consultar de verdade, configure `APIBRASIL_TOKEN` no `.env` e altere `DEMO_MODE=false`. Reinicie o servidor.

A pasta `public` contém apenas o frontend. Nunca coloque a chave nela. O arquivo `.env` não deve ser versionado nem exposto em hospedagem pública.

**Atenção:** modo demonstração devolve o mesmo veículo de exemplo para qualquer placa válida, apenas para testar o layout. Em produção, adicione autenticação de usuários, controle de consumo por cliente e monitoramento de custos, além do rate limit básico incluído.
