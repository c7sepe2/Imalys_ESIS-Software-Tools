program r_Imalys;

{ R_IMALYS ersetzt Variable im "replace" Abschnitt eines Imalys Hooks und ruft
  "x_Imalys" mit den veränderten Variablen auf. Dazu übernimmt RI neben dem
  Hook eine Tabelle aus Variablen. Die Spalten müssn durch Tabs getrennt sein.
  Jede Zeile erzeugt einen neuen "x_Imalys"-Prozess. Die Spalten stehen für die
  Nummer der Variablen im Hook. Die Zahl der Spalten kann gerinder sein als die
  Zahl der Variablen. }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, loop, format;

const
  cPrm = 'Repeat Imalys call: Commands AND parameter files must be provided!';
begin
  if ParamCount>1
    then Change._LoopImalys(ParamStr(1),ParamStr(2))
    else raise Exception.Create(cPrm);
end.

