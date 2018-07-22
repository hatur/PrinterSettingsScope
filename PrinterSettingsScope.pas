unit PrinterSettingsScope;

interface

uses
  Wintypes, System.Classes, System.SysUtils, Winspool,
  PrinterSettingsScope.PrinterState;

type

TPrinterSettingsScope = class
strict private
  fHasDefaultPrinter: Boolean;
  fPrinter: TPrinterState;
  fSilent: Boolean;
  fIsValid: Boolean;

public
  /// Uses the default printer.
  constructor Create(const aSilent: Boolean); overload;
  /// Uses a printer with given name.
  constructor Create(const aPrinterName: string; const aSilent: Boolean); overload;
  destructor Destroy; override;

  property IsValid: Boolean read fIsValid write fIsValid;
  property Instance: TPrinterState read fPrinter;
end;

implementation

uses
  Winapi.Windows, Winapi.Messages, PrinterSettingsScope.Exception;

{ TPrinterSettingsScope }

constructor TPrinterSettingsScope.Create(const aSilent: Boolean);
var
  lPrinterName: string;
  lPrinterNameSZ: DWORD;
  lErrorCode: Cardinal;
begin
  fSilent := aSilent;

  IsValid := false;
  fHasDefaultPrinter := false;
  SetLastError(0);
  GetDefaultPrinter(nil, @lPrinterNameSZ);
  SetLength(lPrinterName, lPrinterNameSZ);

  fHasDefaultPrinter := GetDefaultPrinter(PChar(lPrinterName), @lPrinterNameSZ);
  if fHasDefaultPrinter then
  begin
    try
      fPrinter := TPrinterState.Create(PChar(lPrinterName), aSilent);
      IsValid := true;
    except on
      E: EPrinterScopeException do
      begin
        if (not aSilent) then
        begin
          raise;
        end;
      end;
    end;
  end;
end;

constructor TPrinterSettingsScope.Create(const aPrinterName: string; const aSilent: Boolean);
begin
  IsValid := false;

  try
    fPrinter := TPrinterState.Create(PChar(aPrinterName), aSilent);
    IsValid := true;
  except on
    E: EPrinterScopeException do
    begin
      if (not aSilent) then
      begin
        raise;
      end
    end;

  end;
end;

destructor TPrinterSettingsScope.Destroy;
begin
  fPrinter.Free;

  inherited;
end;

end.
