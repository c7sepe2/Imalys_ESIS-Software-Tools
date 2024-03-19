program x_Imalys;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, raster, format, mutual, thema, index, custom, vector;

const
  cPrm = 'Imalys call: Parameter file must be provided!';
begin
  if ParamCount>0
    then Parse.xChain(ParamStr(1))
    else raise Exception.Create(cPrm);
end.

