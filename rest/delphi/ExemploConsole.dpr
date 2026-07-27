{
  Exemplos do gateway APIBrasil em Delphi.

  Credenciais vêm do ambiente — não escreva token no fonte:
    set APIBRASIL_BEARER_TOKEN=...
    set APIBRASIL_DEVICE_TOKEN=...
    set NUMERO=5511999999999

  Compile:
    dcc32 ExemploConsole.dpr
}
program ExemploConsole;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  ApiBrasil in 'ApiBrasil.pas';

function Truncar(const Texto: string; Limite: Integer): string;
begin
  if Length(Texto) <= Limite then
    Result := Texto
  else
    Result := Copy(Texto, 1, Limite) + '...';
end;

var
  Api: TApiBrasilClient;
  Bearer, Device, Numero: string;
begin
  Bearer := GetEnvironmentVariable('APIBRASIL_BEARER_TOKEN');
  Device := GetEnvironmentVariable('APIBRASIL_DEVICE_TOKEN');
  Numero := GetEnvironmentVariable('NUMERO');

  if Bearer = '' then
  begin
    Writeln(ErrOutput, 'Defina APIBRASIL_BEARER_TOKEN no ambiente.');
    Halt(1);
  end;

  Api := TApiBrasilClient.Create(Bearer, Device);
  try
    // -----------------------------------------------------------------------
    // Saldo
    // -----------------------------------------------------------------------
    try
      Writeln('Saldo: ', Truncar(Api.Get('/balance'), 300));
    except
      on E: EApiBrasilError do
      begin
        if E.Status = 401 then
          Writeln(ErrOutput, 'Bearer inválido ou expirado — refaça o login.')
        else
          Writeln(ErrOutput, Format('Falhou (HTTP %d): %s', [E.Status, E.Message]));
        Halt(1);
      end;
    end;

    // -----------------------------------------------------------------------
    // Consulta por crédito
    // -----------------------------------------------------------------------
    // Só precisa do Authorization. "homolog": true roda em sandbox, sem debitar.
    try
      Writeln;
      Writeln('CNPJ (homologação): ', Truncar(
        Api.Post('/consulta/cnpj/credits',
          '{"cnpj":"00000000000000","homolog":true}'), 400));

      // O campo "tipo" escolhe o PRODUTO dentro do serviço: mesmo endpoint,
      // preço e retorno diferentes.
      Writeln;
      Writeln('Sócios: ', Truncar(
        Api.Post('/consulta/cnpj/credits',
          '{"cnpj":"00000000000000","tipo":"lista-socios","homolog":true}'), 400));
    except
      on E: EApiBrasilError do
        case E.Status of
          402: Writeln(ErrOutput, 'Sem saldo: ', E.Message);
          410: Writeln(ErrOutput, 'Rota descontinuada: ', E.Message);
        else
          Writeln(ErrOutput, Format('HTTP %d: %s', [E.Status, E.Message]));
        end;
    end;

    // -----------------------------------------------------------------------
    // Serviços device-based
    // -----------------------------------------------------------------------
    if Device <> '' then
    begin
      try
        Writeln;
        Writeln('CEP: ', Truncar(Api.Post('/cep/cep', '{"cep":"01001000"}'), 300));
      except
        on E: EApiBrasilError do
          // 403 tem três causas: DeviceToken de outra API, IP fora da
          // whitelist, ou API que exige cadastro PJ. A mensagem diz qual.
          Writeln(ErrOutput, Format('CEP falhou (HTTP %d): %s', [E.Status, E.Message]));
      end;

      if Numero <> '' then
      begin
        try
          // A sessão precisa estar iniciada e pareada.
          Api.Post('/whatsapp/start', '{}');

          Writeln;
          Writeln('WhatsApp: ', Truncar(
            Api.Post('/whatsapp/sendText',
              Format('{"number":"%s","text":"Olá! Enviado em Delphi","time_typing":1500}',
                [Numero])), 300));

          // Fila: o gateway processa de forma assíncrona. Caminho certo para
          // disparos em volume — responde na hora.
          Api.Post('/whatsapp/sendText/queue',
            Format('{"number":"%s","text":"Esta foi pela fila"}', [Numero]));

          // Evolution API — rota com um nível a mais:
          // /evolution/{controller}/{action}
          Writeln;
          Writeln('Evolution: ', Truncar(
            Api.Post('/evolution/message/sendText',
              Format('{"number":"%s",' +
                     '"options":{"delay":1200,"presence":"composing"},' +
                     '"textMessage":{"text":"Via Evolution API"}}', [Numero])), 300));
        except
          on E: EApiBrasilError do
            Writeln(ErrOutput, Format('Envio falhou (HTTP %d): %s', [E.Status, E.Message]));
        end;
      end;
    end;

  finally
    Api.Free;
  end;

  Writeln;
  Writeln('Pressione ENTER para sair.');
  Readln;
end.
