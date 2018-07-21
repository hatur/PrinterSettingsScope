program PSS;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  PrinterSettingsScope in 'PrinterSettingsScope.pas',
  WinTypes,
  PrinterSettingsScope.PrinterState in 'PrinterSettingsScope.PrinterState.pas',
  PrinterSettingsScope.Exception in 'PrinterSettingsScope.Exception.pas';

var
  PrinterScope: TPRinterSettingsScope;

begin
  try
    { TODO -oUser -cConsole Main : Code hier einfügen }
    PrinterScope := TPrinterSettingsScope.Create(false);
    try
      PrinterScope.Instance.Color := TPrinterColor.tpc_monochrome;
      PrinterScope.Instance.ApplyChanges;
    finally
      PrinterScope.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
