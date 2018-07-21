unit PrinterSettingsScope;

interface

uses
  Wintypes, System.Classes, System.SysUtils, Winspool,
  PrinterSettingsScope.PrinterState;

type

TPrinterSettingsScope = class
strict private
  fHasDefaultPrinter: Boolean;
  fDefaultPrinter: TPrinterState;
  fSilent: Boolean;
  fIsValid: Boolean;

public
  /// Uses the default printer.
  constructor Create(const aSilent: Boolean); overload;
  /// Uses a printer with given name.
  constructor Create(const aPrinterName: string; const aSilent: Boolean); overload;
  destructor Destroy; override;

  property IsValid: Boolean read fIsValid write fIsValid;
  property Instance: TPrinterState read fDefaultPrinter;
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

  fHasDefaultPrinter := false;
  SetLastError(0);
  GetDefaultPrinter(nil, @lPrinterNameSZ);
  SetLength(lPrinterName, lPrinterNameSZ);

  fHasDefaultPrinter := GetDefaultPrinter(PChar(lPrinterName), @lPrinterNameSZ);

  if fHasDefaultPrinter then
  begin
    try
      fDefaultPrinter := TPrinterState.Create(PChar(lPrinterName));
      IsValid := true;
    except on
      E: EPrinterScopeException do
      begin
        if (not aSilent) then
        begin
          raise;
        end
        else
        begin
          IsValid := false;
        end;
      end;
    end;
  end;
end;

constructor TPrinterSettingsScope.Create(const aPrinterName: string; const aSilent: Boolean);
begin
  try
    fDefaultPrinter := TPrinterState.Create(PChar(aPrinterName));
  except on
    E: EPrinterScopeException do
    begin
      if (not aSilent) then
      begin
        raise;
      end
      else
      begin
        IsValid := false;
      end;
    end;

  end;
end;

destructor TPrinterSettingsScope.Destroy;
begin
  fDefaultPrinter.Free;

  inherited;
end;

end.
