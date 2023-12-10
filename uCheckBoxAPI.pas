unit uCheckBoxAPI;

interface

uses

  CodeSiteLogging,
  StrUtils,
  IniFiles,
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Dialogs, Vcl.StdCtrls, IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, System.Net.HttpClient, System.Json;

type

  TTaxInfo = record
    ID: string;
    Code: Integer;
    TaxLabel: string; // изменено с Label
    Symbol: string;
    Rate: Double;
    ExtraRate: Double;
    Included: Boolean;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
    NoVAT: Boolean;
    AdvancedCode: string; // добавлено поле
    Sales: Int64;
    Returns: Int64;
    SalesTurnover: Int64;
    ReturnsTurnover: Int64;
  end;

  TCashRegisterInfo = record
    ID: string;
    FiscalNumber: string;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
    Address: string;
    Title: string;
    OfflineMode: Boolean;
    StayOffline: Boolean;
    HasShift: Boolean;
    LastReceiptCode: Integer;
    LastReportCode: Integer;
    LastZReportCode: Integer;
    // Вы можете добавить другие поля, если они вам нужны
  end;

  TBalanceInfo = record
    Initial: Int64;
    CurrentBalance: Int64; // изменено с Balance
    CashSales: Int64;
    CardSales: Int64;
    DiscountsSum: Int64;
    ExtraChargeSum: Int64;
    CashReturns: Int64;
    CardReturns: Int64;
    ServiceIn: Int64;
    ServiceOut: Int64;
    UpdatedAt: TDateTime;
  end;

  TPermissions = record
    Orders: Boolean;
    AddDiscounts: Boolean;
    EditingGoodsSum: Boolean;
    DeferredReceipt: Boolean;
    EditingGoodPrice: Boolean;
    CanAddManualGood: Boolean;
    ServiceIn: Boolean;
    ServiceOut: Boolean;
    Returns: Boolean;
    Sales: Boolean;
    CardPayment: Boolean;
    CashPayment: Boolean;
    OtherPayment: Boolean;
    MixedPayment: Boolean;
    BranchParams: Boolean;
    ReportsHistory: Boolean;
    AdditionalServiceReceipt: Boolean;
    FreeReturn: Boolean;
  end;

  TCashierInfo = record
    ID: string;
    FullName: string;
    NIN: string;
    KeyID: string;
    SignatureType: string;
    Permissions: TPermissions;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
    CertificateEnd: TDateTime;
    Blocked: Boolean;
  end;

//  TCashRegisterInfo = record
//    ID: string;
//    FiscalNumber: string;
//    Active: Boolean;
//    CreatedAt: TDateTime;
//    UpdatedAt: TDateTime;
//    Number: string;
//  end;

  TTransactionInfo = record
    ID: string;
    TransactionType: string; // изменено с Type
    Serial: Integer;
    Status: string;
    RequestSignedAt: TDateTime;
    RequestReceivedAt: TDateTime;
    ResponseStatus: string;
    ResponseErrorMessage: string;
    ResponseID: string;
    OfflineID: string;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
    OriginalDatetime: TDateTime;
    PreviousHash: string;
  end;

  TShiftResponse = record
    ID: string;
    Serial: Integer;
    Status: string;
    ZReport: string; // null в вашем примере
    OpenedAt: TDateTime; // null в вашем примере
    ClosedAt: TDateTime; // null в вашем примере
    InitialTransaction: TTransactionInfo;
    ClosingTransaction: TTransactionInfo; // null в вашем примере
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime; // null в вашем примере
    Balance: TBalanceInfo;
    Taxes: TArray<TTaxInfo>;
    EmergencyClose: TDateTime; // null в вашем примере
    EmergencyCloseDetails: string; // null в вашем примере
    CashRegister: TCashRegisterInfo;
    Cashier: TCashierInfo;
  end;

  TOfflineCode = record
    FiscalCode: string;
    SerialID: Integer;
    CashRegisterID: string;
    CreatedAt: TDateTime;
  end;

const
  SignInURL = 'https://api.checkbox.ua/api/v1/cashier/signin';
  SignOutURL = 'https://api.checkbox.ua/api/v1/cashier/signout';
  ClientName = 'LaPosudAI'; // Замените на название вашей интеграции
  ClientVersion = '1'; // Замените на версию вашей интеграции
  LicenseKey = 'test932fb68d489dcbbcbdb0c044';
  OfflineCodesURL = 'https://api.checkbox.ua/api/v1/cash-registers/ask-offline-codes?count=2000&sync=true';
  GetOfflineCodesURL = 'https://api.checkbox.ua/api/v1/cash-registers/get-offline-codes?count=%d';
  GoOnlineURL = 'https://api.checkbox.ua/api/v1/cash-registers/go-online';

function DeactivateToken(const AccessToken: string): Integer;
function AuthorizeAndGetToken(out Token: string): Integer;
function GetCashRegisterInfo(const AccessToken: string; out Info: TCashRegisterInfo): Integer;
function CheckDPSConnection(const AccessToken: string ): Integer;
function LoadToken(aIniFileName: string): string;
procedure SaveToken(aToken: string; aIniFileName: string);
function RequestOfflineCodes(const AccessToken: string; out Status: string): Integer;
function GetUnusedOfflineCodes(const AccessToken: string; const Count: Integer; out OfflineCodes: TArray<TOfflineCode>): Integer;
function GoOnline(const AccessToken: string): Integer;
procedure SaveOfflineCodesToFile(const OfflineCodes: TArray<TOfflineCode>; const FileName: string);
function LoadOfflineCodesFromFile(const FileName: string; out OfflineCodes: TArray<TOfflineCode>): Boolean;
function OpenShift(const AccessToken, LicenseKey: string; out ShiftResponse: TShiftResponse): Integer;

implementation

function ISO8601ToDate(const AValue: string): TDateTime;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := TFormatSettings.Create;
  FormatSettings.DateSeparator := '-';
  FormatSettings.TimeSeparator := ':';
  FormatSettings.ShortDateFormat := 'yyyy-mm-dd';
  FormatSettings.ShortTimeFormat := 'hh:nn:ss';

  try
    Result := StrToDateTime(AValue, FormatSettings);
  except
    on E: EConvertError do
      Result := 0; // Или обработайте ошибку соответствующим образом
  end;
end;

function AuthorizeAndGetToken(out Token: string): Integer;
var
  HttpClient: THttpClient;
  Response: IHttpResponse;
  RequestBody: TStringStream;
  Login, Password: string;
begin
  Token := '';
  Login := 'test_oec8vdu0d';
  Password := 'test_oec8vdu0d';
  HttpClient := THttpClient.Create;
  HttpClient.CustomHeaders['X-Client-Name'] := ClientName;
  HttpClient.CustomHeaders['X-Client-Version'] := ClientVersion;
  HttpClient.CustomHeaders['X-License-Key'] := LicenseKey;

  try
    RequestBody := TStringStream.Create(TJSONObject.Create
                                         .AddPair('login', Login)
                                         .AddPair('password', Password)
                                         .ToString);
    try
      RequestBody.Position := 0;
      Response := HttpClient.Post(SignInURL, RequestBody);
      CodeSite.Send(Response.ContentAsString());
      if Response.StatusCode = 200 then
      begin
        Token := TJSONObject.ParseJSONValue(Response.ContentAsString)
                            .GetValue<string>('access_token');
        CodeSite.Send('Token: ', Token);
      end;
      Result := Response.StatusCode;
    finally
      RequestBody.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

function DeactivateToken(const AccessToken: string): Integer;
const
  SignOutURL = 'https://api.checkbox.ua/api/v1/cashier/signout';
var
  HttpClient: THttpClient;
  Response: IHttpResponse;
  EmptyBody: TStringStream;
begin
  HttpClient := THttpClient.Create;
  EmptyBody := TStringStream.Create('');
  HttpClient.CustomHeaders['X-Client-Name'] := ClientName;
  HttpClient.CustomHeaders['X-Client-Version'] := ClientVersion;
  try
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AccessToken;
    Response := HttpClient.Post(SignOutURL, EmptyBody);
    Result := Response.StatusCode;
  finally
    EmptyBody.Free;
    HttpClient.Free;
  end;
end;

function GetCashRegisterInfo(const AccessToken: string; out Info: TCashRegisterInfo): Integer;
const
  CashRegisterInfoURL = 'https://api.checkbox.ua/api/v1/cash-registers'; // URL может отличаться
var
  HttpClient: THttpClient;
  Response: IHttpResponse;
  JSONValue: TJSONValue;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
  procedure ParseJSON(const Item: TJSONObject);
  begin
    if Item <> nil then
    begin
      if Item.TryGetValue<string>('id', Info.ID) then
      begin
        Info.FiscalNumber := Item.GetValue<string>('fiscal_number');
        Info.CreatedAt := ISO8601ToDate(Item.GetValue<string>('created_at'));
        Info.UpdatedAt := ISO8601ToDate(Item.GetValue<string>('updated_at'));
        Info.Address := Item.GetValue<string>('address');
        Info.OfflineMode := Item.GetValue<boolean>('offline_mode');
        Info.StayOffline := Item.GetValue<boolean>('stay_offline');
        // Дополните или измените код для остальных полей, если они доступны
      end;
    end;
  end;

begin
  HttpClient := THttpClient.Create;
  try
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AccessToken;
    HttpClient.CustomHeaders['X-Client-Name'] := ClientName;
    HttpClient.CustomHeaders['X-Client-Version'] := ClientVersion;
    Response := HttpClient.Get(CashRegisterInfoURL);
    Result := Response.StatusCode;
    if Response.StatusCode = 200 then
    begin
      JSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString);
      if JSONValue <> nil then
      try
        JSONArray := TJSONObject(JSONValue).GetValue<TJSONArray>('results');
        if JSONArray.Count > 0 then
        begin
          JSONObj := JSONArray.Items[0] as TJSONObject;
          ParseJSON(JSONObj);
        end;
      finally
        JSONValue.Free;
      end;
    end;
  finally
    HttpClient.Free;
  end;
end;

function CheckDPSConnection(const AccessToken: string): Integer;
const
  DPSConnectionURL = 'https://api.checkbox.ua/api/v1/cash-registers/ping-tax-service';
var
  HttpClient: THttpClient;
  Response: IHttpResponse;
  RequestBody: TStringStream;
begin
  HttpClient := THttpClient.Create;
  RequestBody := TStringStream.Create('');
  try
    // Установка заголовков запроса
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AccessToken;
    HttpClient.CustomHeaders['accept'] := 'application/json';
    HttpClient.CustomHeaders['X-Client-Name'] := ClientName;
    HttpClient.CustomHeaders['X-Client-Version'] := ClientVersion;
    HttpClient.CustomHeaders['X-License-Key'] := LicenseKey;
    // Отправка POST запроса с пустым телом
    Response := HttpClient.Post(DPSConnectionURL, RequestBody);
    // Логирование ответа для отладки
     CodeSite.Send( 'Response.ContentAsString()', Response.ContentAsString() );
     CodeSite.Send( 'Response.StatusCode', Response.StatusCode );
    // Возвращаем код состояния HTTP-ответа
    Result := Response.StatusCode;
  finally
    RequestBody.Free;
    HttpClient.Free;
  end;
end;

function LoadToken(aIniFileName: string): string;
var
  IniFile: TIniFile;
begin
  Result:= EmptyStr;
  if not FileExists(aIniFileName) then
  begin
    Exit;
  end;

  IniFile:= TIniFile.Create(aIniFileName);
  try
    Result:= IniFile.ReadString('Checkbox', 'Token', '');
  finally
    IniFile.Free;
  end;
end;

procedure SaveToken(aToken: string; aIniFileName: string);
var
  IniFile: TIniFile;
begin
  IniFile:= TIniFile.Create(aIniFileName);
  try
    IniFile.WriteString('Checkbox', 'Token', aToken);
  finally
    IniFile.Free;
  end;
end;

function RequestOfflineCodes(const AccessToken: string; out Status: string): Integer;

var
  HttpClient: THttpClient;
  Response: IHttpResponse;
  JSONValue: TJSONValue;
begin
  HttpClient := THttpClient.Create;
  try
    // Установка заголовков запроса
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AccessToken;
    HttpClient.CustomHeaders['accept'] := 'application/json';
    HttpClient.CustomHeaders['X-Client-Name'] := ClientName;
    HttpClient.CustomHeaders['X-Client-Version'] := ClientVersion;
    HttpClient.CustomHeaders['X-License-Key'] := LicenseKey;
    // Отправка GET запроса
    Response := HttpClient.Get(OfflineCodesURL);
    Result := Response.StatusCode;
    // Логирование ответа для отладки
    CodeSite.Send( 'Response.ContentAsString()', Response.ContentAsString() );

    if Response.StatusCode = 200 then
    begin
      JSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString);
      if JSONValue <> nil then
      try
        // Получение статуса запроса из ответа
        Status := JSONValue.GetValue<string>('status');
      finally
        JSONValue.Free;
      end;
    end;
  finally
    HttpClient.Free;
  end;
end;

function GetUnusedOfflineCodes(const AccessToken: string; const Count: Integer;
                               out OfflineCodes: TArray<TOfflineCode>): Integer;
var
  HttpClient: THttpClient;
  Response: IHttpResponse;
  JSONValue, JSONItem: TJSONValue;
  JSONArray: TJSONArray;
  I: Integer;
begin
  HttpClient := THttpClient.Create;
  try
    // Установка заголовков запроса
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AccessToken;
    HttpClient.CustomHeaders['accept'] := 'application/json';
    HttpClient.CustomHeaders['X-Client-Name'] := ClientName;
    HttpClient.CustomHeaders['X-Client-Version'] := ClientVersion;
    HttpClient.CustomHeaders['X-License-Key'] := LicenseKey;
    // Отправка GET запроса
    Response := HttpClient.Get(Format(GetOfflineCodesURL, [Count]));
    // Логирование ответа для отладки
     CodeSite.Send( 'Response.ContentAsString()', Response.ContentAsString() );
     CodeSite.Send( 'Response.StatusCode', Response.StatusCode );

    Result := Response.StatusCode;
    if Response.StatusCode = 200 then
    begin
      JSONValue := TJSONObject.ParseJSONValue(Response.ContentAsString);
      if JSONValue <> nil then
      try
        JSONArray := JSONValue as TJSONArray;
        SetLength(OfflineCodes, JSONArray.Count);
        for I := 0 to JSONArray.Count - 1 do
        begin
          JSONItem := JSONArray.Items[I];
          with OfflineCodes[I] do
          begin
            FiscalCode := JSONItem.GetValue<string>('fiscal_code');
            SerialID := JSONItem.GetValue<Integer>('serial_id');
            CashRegisterID := JSONItem.GetValue<string>('cash_register_id');
            CreatedAt := ISO8601ToDate(JSONItem.GetValue<string>('created_at'));
          end;
        end;
      finally
        JSONValue.Free;
      end;
    end;
  finally
    HttpClient.Free;
  end;
end;

function GoOnline(const AccessToken: string): Integer;
var
  HttpClient: THttpClient;
  Response: IHttpResponse;
  RequestBody: TStringStream;
begin
  HttpClient := THttpClient.Create;
  RequestBody := TStringStream.Create('');
  try
    // Установка заголовков запроса
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AccessToken;
    HttpClient.CustomHeaders['accept'] := 'application/json';
    HttpClient.CustomHeaders['X-Client-Name'] := ClientName;
    HttpClient.CustomHeaders['X-Client-Version'] := ClientVersion;
    HttpClient.CustomHeaders['X-License-Key'] := LicenseKey;
    // Отправка POST запроса с пустым телом
    Response := HttpClient.Post(GoOnlineURL, RequestBody);
    // Возвращаем код состояния HTTP-ответа
    Result := Response.StatusCode;
  finally
    RequestBody.Free;
    HttpClient.Free;
  end;
end;

procedure SaveOfflineCodesToFile(const OfflineCodes: TArray<TOfflineCode>; const FileName: string);
var
  FileStream: TFileStream;
  Writer: TStreamWriter;
  I: Integer;
begin
  FileStream := TFileStream.Create(FileName, fmCreate);
  try
    Writer := TStreamWriter.Create(FileStream);
    try
      for I := 0 to High(OfflineCodes) do
      begin
        with OfflineCodes[I] do
          Writer.WriteLine(Format('%s,%d,%s,%s', [FiscalCode, SerialID, CashRegisterID, DateTimeToStr(CreatedAt)]));
      end;
    finally
      Writer.Free;
    end;
  finally
    FileStream.Free;
  end;
end;

function LoadOfflineCodesFromFile(const FileName: string; out OfflineCodes: TArray<TOfflineCode>): Boolean;
var
  FileStream: TFileStream;
  Reader: TStreamReader;
  Line, S: string;
  Code: TOfflineCode;
  Parts: TArray<string>;
begin
  Result := False;
  if not FileExists(FileName) then Exit;
  FileStream := TFileStream.Create(FileName, fmOpenRead);
  try
    Reader := TStreamReader.Create(FileStream);
    try
      while not Reader.EndOfStream do
      begin
        Line := Reader.ReadLine;
        Parts := Line.Split([',']);
        if Length(Parts) = 4 then
        begin
          Code.FiscalCode := Parts[0];
          Code.SerialID := StrToInt(Parts[1]);
          Code.CashRegisterID := Parts[2];
          Code.CreatedAt := StrToDateTime(Parts[3]);
          SetLength(OfflineCodes, Length(OfflineCodes) + 1);
          OfflineCodes[High(OfflineCodes)] := Code;
        end;
      end;
      Result := True;
    finally
      Reader.Free;
    end;
  finally
    FileStream.Free;
  end;
end;

procedure FillShiftResponseFromJSON(const JSONShift: TJSONObject; var ShiftResponse: TShiftResponse);
begin
  // Проверка на nil для JSONShift рекомендуется
  if Assigned(JSONShift) then
  begin
    ShiftResponse.ID := JSONShift.GetValue<string>('id');
    ShiftResponse.Serial := JSONShift.GetValue<Integer>('serial');
    ShiftResponse.Status := JSONShift.GetValue<string>('status');
    // Заполнение остальных полей ShiftResponse
    // ...
  end;
end;

function OpenShift(const AccessToken, LicenseKey: string; out ShiftResponse: TShiftResponse): Integer;
var
  HttpClient: THttpClient;
  RequestBody: TStringStream;
  Response: IHTTPResponse;
  JSONShift: TJSONObject;
begin
  HttpClient := THttpClient.Create;
  try
    // Настройка HTTP-клиента
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AccessToken;
    HttpClient.CustomHeaders['accept'] := 'application/json';
    HttpClient.CustomHeaders['X-Client-Name'] := 'YourClientName'; // Замените на свое название клиента
    HttpClient.CustomHeaders['X-Client-Version'] := 'YourClientVersion'; // Замените на свою версию клиента
    HttpClient.CustomHeaders['X-License-Key'] := LicenseKey;

    RequestBody := TStringStream.Create(TJSONObject.Create.AddPair('id', TGuid.NewGuid.ToString).ToString, TEncoding.UTF8);
    try
      // Отправка запроса
      Response := HttpClient.Post('https://api.checkbox.ua/api/v1/shifts', RequestBody, nil); // nil для заголовков
      Result := Response.StatusCode;
      CodeSite.Send( 'Response.ContentAsString()', Response.ContentAsString() );
      CodeSite.Send( 'Response.StatusCode', Response.StatusCode );
      if Result = 200 then
      begin
        JSONShift := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
        try
          // Заполнение полей структуры TShiftResponse из JSONShift
          FillShiftResponseFromJSON(JSONShift, ShiftResponse);

        finally
          JSONShift.Free;
        end;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

end.
