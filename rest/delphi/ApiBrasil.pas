{
  ApiBrasil — unit mínima para o gateway APIBrasil em Delphi (Indy).

  Duas famílias de serviço:
    device-based  -> Authorization + DeviceToken   (/whatsapp, /sms, /cep, /vehicles...)
    por crédito   -> Authorization                 (/consulta/{servico}/credits)

  Requer as DLLs do OpenSSL na pasta do executável.
}
unit ApiBrasil;

interface

uses
  System.Classes, System.SysUtils,
  IdHTTP, IdSSLOpenSSL;

type
  /// Erro do gateway, com o status e o corpo original preservados.
  /// A mensagem do gateway é a parte útil: diz qual campo faltou, quanto
  /// custava a consulta, ou qual rota substituiu a que morreu.
  EApiBrasilError = class(Exception)
  private
    FStatus: Integer;
    FCorpo: string;
  public
    constructor Create(AStatus: Integer; const ACorpo, AMensagem: string);
    property Status: Integer read FStatus;
    property Corpo: string read FCorpo;
  end;

  TApiBrasilClient = class
  private
    FHttp: TIdHTTP;
    FSSL: TIdSSLIOHandlerSocketOpenSSL;
    FBaseUrl: string;
    FBearerToken: string;
    FDeviceToken: string;

    procedure AplicarHeaders(const ADeviceToken, ASecretKey: string);
    function ExtrairMensagem(const ACorpo: string): string;
  public
    constructor Create(const ABearerToken: string; const ADeviceToken: string = '';
      const ABaseUrl: string = 'https://gateway.apibrasil.io/api/v2');
    destructor Destroy; override;

    /// POST em qualquer rota do gateway. ADeviceToken sobrescreve o do cliente.
    function Post(const ACaminho, AJsonBody: string;
      const ADeviceToken: string = ''): string;

    /// GET em qualquer rota do gateway.
    function Get(const ACaminho: string): string;

    /// Cria um device. ESTE é o único lugar onde a SecretKey tem função —
    /// em rotas de envio ela não serve para nada.
    function CriarDevice(const ANome, ASecretKey: string): string;

    property DeviceToken: string read FDeviceToken write FDeviceToken;
  end;

implementation

{ EApiBrasilError }

constructor EApiBrasilError.Create(AStatus: Integer; const ACorpo, AMensagem: string);
begin
  inherited Create(AMensagem);
  FStatus := AStatus;
  FCorpo := ACorpo;
end;

{ TApiBrasilClient }

constructor TApiBrasilClient.Create(const ABearerToken, ADeviceToken, ABaseUrl: string);
begin
  inherited Create;

  FBearerToken := ABearerToken;
  FDeviceToken := ADeviceToken;
  FBaseUrl := ABaseUrl.TrimRight(['/']);

  FHttp := TIdHTTP.Create(nil);
  FHttp.Request.ContentType := 'application/json';
  FHttp.Request.CharSet := 'utf-8';
  FHttp.Request.Accept := 'application/json';
  FHttp.ConnectTimeout := 15000;
  FHttp.ReadTimeout := 30000;

  // O Indy exige um IOHandler explícito para HTTPS, senão dá
  // "Could not load SSL library".
  FSSL := TIdSSLIOHandlerSocketOpenSSL.Create(FHttp);
  FSSL.SSLOptions.SSLVersions := [sslvTLSv1_2];
  FHttp.IOHandler := FSSL;
end;

destructor TApiBrasilClient.Destroy;
begin
  FHttp.Free;   // libera o FSSL também, por ser Owner
  inherited;
end;

procedure TApiBrasilClient.AplicarHeaders(const ADeviceToken, ASecretKey: string);
var
  Device: string;
begin
  FHttp.Request.CustomHeaders.Clear;
  FHttp.Request.CustomHeaders.AddValue('Authorization', 'Bearer ' + FBearerToken);

  // DeviceToken só nas rotas device-based. Nas de crédito é ignorado.
  if ADeviceToken <> '' then
    Device := ADeviceToken
  else
    Device := FDeviceToken;

  if Device <> '' then
    FHttp.Request.CustomHeaders.AddValue('DeviceToken', Device);

  if ASecretKey <> '' then
    FHttp.Request.CustomHeaders.AddValue('SecretKey', ASecretKey);
end;

function TApiBrasilClient.ExtrairMensagem(const ACorpo: string): string;
var
  Inicio, Fim: Integer;
begin
  // Extração simples do campo "message" sem depender de System.JSON.
  // Num projeto real, use TJSONObject.ParseJSONValue.
  Inicio := Pos('"message":"', ACorpo);
  if Inicio = 0 then
    Exit(Copy(ACorpo, 1, 200));

  Inc(Inicio, Length('"message":"'));
  Fim := Inicio;
  while (Fim <= Length(ACorpo)) and (ACorpo[Fim] <> '"') do
    Inc(Fim);

  Result := Copy(ACorpo, Inicio, Fim - Inicio);
end;

function TApiBrasilClient.Post(const ACaminho, AJsonBody, ADeviceToken: string): string;
var
  Corpo: TStringStream;
begin
  AplicarHeaders(ADeviceToken, '');

  // TStringStream com TEncoding.UTF8: sem isso, acento chega corrompido.
  // E o try/finally é obrigatório — o TIdHTTP.Post NÃO assume a posse do stream.
  Corpo := TStringStream.Create(AJsonBody, TEncoding.UTF8);
  try
    try
      Result := FHttp.Post(FBaseUrl + ACaminho, Corpo);
    except
      // Status >= 400 vira exceção, e a mensagem do gateway está em
      // ErrorMessage — não em E.Message.
      on E: EIdHTTPProtocolException do
        raise EApiBrasilError.Create(E.ErrorCode, E.ErrorMessage,
          ExtrairMensagem(E.ErrorMessage));
    end;
  finally
    Corpo.Free;
  end;
end;

function TApiBrasilClient.Get(const ACaminho: string): string;
begin
  AplicarHeaders('', '');

  try
    Result := FHttp.Get(FBaseUrl + ACaminho);
  except
    on E: EIdHTTPProtocolException do
      raise EApiBrasilError.Create(E.ErrorCode, E.ErrorMessage,
        ExtrairMensagem(E.ErrorMessage));
  end;
end;

function TApiBrasilClient.CriarDevice(const ANome, ASecretKey: string): string;
var
  Corpo: TStringStream;
begin
  AplicarHeaders('', ASecretKey);

  Corpo := TStringStream.Create(
    Format('{"device_name":"%s","type":"server"}', [ANome]), TEncoding.UTF8);
  try
    try
      Result := FHttp.Post(FBaseUrl + '/devices/store', Corpo);
    except
      on E: EIdHTTPProtocolException do
        raise EApiBrasilError.Create(E.ErrorCode, E.ErrorMessage,
          ExtrairMensagem(E.ErrorMessage));
    end;
  finally
    Corpo.Free;
  end;
end;

end.
