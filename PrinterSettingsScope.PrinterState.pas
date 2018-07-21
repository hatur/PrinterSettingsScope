unit PrinterSettingsScope.PrinterState;

{$HINTS ON}
{$WARNINGS ON}

interface

uses
  Wintypes, Winspool;

type

{$SCOPEDENUMS ON}
TPrinterColor = (tpc_monochrome = 1, tpc_color = 2);
{$SCOPEDENUMS OFF}

TPrinterState = class
strict private
  fPrinterName: string;
  fDevMode: PDevMode;
  fOriginalDevModeState: DEVMODE;
  fPrinterHandle: THandle;
  fNewFields: DWORD;
  fPrinterInfo: PPrinterInfo2;

  function ApplyChangesInt(const aDEVMODE: PDevMode; const aBroadcastChanges: Boolean = true): Boolean;
  function RestoreChanges(const aBroadcastChanges: Boolean = true): Boolean;

public
  constructor Create(const aPrinterName: string);
  destructor Destroy; override;

  function ApplyChanges(const aBroadcastChanges: Boolean = true): Boolean;

  function GetColor: TPrinterColor;
  procedure SetColor(const aColor: TPrinterColor);

  property Color: TPrinterColor read GetColor write SetColor;
end;

implementation

uses
  Winapi.Messages, System.SysUtils, Winapi.Windows, PrinterSettingsScope.Exception;

{ TPrinterState }

constructor TPrinterState.Create(const aPrinterName: string);
var
  lPrinterDefaults: TPrinterDefaults;
  lOpenPrinterResult: Boolean;
  lPrinterInfoSize: NativeUInt;
  lDevmodeSize: NativeUInt;
  lDocPropertiesResult: LONG;
begin
  fPrinterName := aPrinterName;

  fPrinterHandle := 0;

  ZeroMemory(@lPrinterDefaults, sizeof(lPrinterDefaults));
  lPrinterDefaults.DesiredAccess := PRINTER_ALL_ACCESS;

  lOpenPrinterResult := OpenPrinter(PChar(fPrinterName), fPrinterHandle, @lPrinterDefaults);
  if (not lOpenPrinterResult) or (fPrinterHandle = 0) then
  begin
    raise EPrinterScopeException.Create('Could not get handle to printer with name ' + aPrinterName);
  end;

  SetLastError(0);
  lPrinterInfoSize := 0;
  lOpenPrinterResult := GetPrinter(fPrinterHandle, 2, nil, 0, @lPrinterInfoSize);
  if ((not lOpenPrinterResult) and (GetLastError <> ERROR_INSUFFICIENT_BUFFER)) or
    (lPrinterInfoSize = 0) then
  begin
    ClosePrinter(fPrinterHandle);
    raise EPrinterScopeException.Create('Could not get desired size for PRINTER_INFO2');
  end;

  // Any leak here, if the call fails?
  fPrinterInfo := PPrinterInfo2(GlobalAlloc(GPTR, lPrinterInfoSize));

  lOpenPrinterResult := GetPrinter(fPrinterHandle, 2, LPBYTE(fPrinterInfo), lPrinterInfoSize, @lPrinterInfoSize);

  if (not lOpenPrinterResult) then
  begin
    GlobalFree(NativeUInt(fPrinterInfo));
    ClosePrinter(fPrinterHandle);
    raise EPrinterScopeException.Create('Could not retrieve current printer settings');
  end;

  // If not reachable via device caps, try to get it with document properties instead.
  fDevMode := fPrinterInfo.pDevMode;
  if (not Assigned(fDevMode)) then
  begin
    lDevmodeSize := DocumentProperties(0, fPrinterHandle, PChar(fPrinterName), nil, nil, 0);

    if (lDevmodeSize <= 0) then
    begin
      GlobalFree(NativeUInt(fPrinterInfo));
      ClosePrinter(fPrinterHandle);
      raise EPrinterScopeException.Create('Could not get size for PDEVMODE, call to DocumentProperties failed');
    end;

    fDevMode := PDEVMODE(GlobalAlloc(GPTR, lDevmodeSize));
    if (not Assigned(fDevMode)) then
    begin
      GlobalFree(NativeUInt(fPrinterInfo));
      ClosePrinter(fPrinterHandle);
      raise EPrinterScopeException.Create('Could not allocate memory for PDEVMODE');
    end;

    lDocPropertiesResult := DocumentProperties(0, fPrinterHandle, PChar(fPrinterName), fDevMode, nil, DM_OUT_BUFFER);
    if (lDocPropertiesResult <> IDOK) or (fDevMode = nil) then
    begin
      GlobalFree(NativeUInt(fDevMode));
      GlobalFree(NativeUInt(fPrinterInfo));
      ClosePrinter(fPrinterHandle);
      raise EPrinterScopeException.Create('Could not retrieve PDEVMODE information from DocumentProperties');
    end;
  end;

  if Assigned(fDevMode) then
  begin
    Move(fDevMode^, fOriginalDevModeState, sizeof(fDevMode^));
  end;
end;

destructor TPrinterState.Destroy;
begin
  RestoreChanges;

  if Assigned(fPrinterInfo) then
  begin
    GlobalFree(NativeUInt(fPrinterInfo));
  end;

  if Assigned(fDevMode) then
  begin
    GlobalFree(NativeUInt(fDevMode));
  end;

  if (fPrinterHandle <> 0) then
  begin
    ClosePrinter(fPrinterHandle);
  end;

  inherited;
end;

function TPrinterState.ApplyChanges(const aBroadcastChanges: Boolean = true): Boolean;
begin
  fDevMode.dmFields := fNewFields;
  result := ApplyChangesInt(fDevMode, aBroadcastChanges);
end;

function TPrinterState.ApplyChangesInt(const aDEVMODE: PDevMode; const aBroadcastChanges: Boolean = true): Boolean;
var
  lDocPropertiesResult: LONG;
begin
  result := true;

  // Shouldn't be necessary, but just to be sure.
  fPrinterInfo.pDevMode := aDEVMODE;

  lDocPropertiesResult := DocumentProperties(0, fPrinterHandle, PCHAR(fPrinterName), aDEVMODE, aDEVMODE,
    DM_IN_BUFFER or DM_OUT_BUFFER);
  if (lDocPropertiesResult <> IDOK) then
  begin
    result := false;
  end
  else
  begin
    result := result and SetPrinter(fPrinterHandle, 2, LPBYTE(fPrinterInfo), 0);
  end;

  if result and aBroadcastChanges then
  begin
    SendMessageTimeout(HWND_BROADCAST, WM_DEVMODECHANGE, 0, LPARAM(PCHAR(fPrinterName)), SMTO_NORMAL, 1, nil);
  end;
end;

function TPrinterState.RestoreChanges(const aBroadcastChanges: Boolean = true): Boolean;
begin
  Move(fOriginalDevModeState, fDevMode^, sizeof(fOriginalDevModeState));
  ApplyChangesInt(fDevMode, aBroadcastChanges);
end;

function TPrinterState.GetColor: TPrinterColor;
begin
  result := TPrinterColor(fDevMode.dmColor);
end;

procedure TPrinterState.SetColor(const aColor: TPrinterColor);
begin
  fNewFields := fNewFields or DM_COLOR;
  fDevMode.dmColor := ord(aColor);
end;

end.
