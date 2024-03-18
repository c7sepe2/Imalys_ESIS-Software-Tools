unit parse;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  tFilter = class(tObject)
    private
      function ImageSource(sDir:string):tStringList;
    public
  end;

implementation

uses
  format;

function _OsFind(
  const rDat:TSearchRec; //Datei-Attribute
  sDir:string; //aktulles Verzeichnis
  sNme:string): //aktueller Such-String
  string; //Nachricht ODER leer
begin
  if copy(rDat.Name,1,length(sNme))=sNme
    then Result:=sDir+rDat.Name
    else Result:='';
end;

function tFilter.ImageSource(
  sDir:string): //Stammverzeichnis
  tStringList;
begin
  Result:=Tools._FileTree(sDir,@_OsFind());



  tTreeRes = function(const rSrc:TSearchRec; sDir:string):string;

  FileTree(sDir:string; yRes:TTreeRes):TStringList;
end;

end.

