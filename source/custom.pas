unit custom;

{ CUSTOM interpretiert Imalys-Befehle und vergibt Aufgaben. Jeder Befehl ist
  mit einer Routine verknüpft. Die Routinen treffen logische Entscheidungen und
  rufen weitere Routinen auf. }

{ HOME:
  Imalys benötigt ein Arbeitsverzeichnis. Mit "home" kann jedes Verzeichnis mit
  Schreibrechten gewählt werden. "/home/USER/.imalys" übernimmt Anpassungen und
  aktuelle Befehle. }

{ IMPORT:
  Imalys extrahiert, formatiert, beschneidet und projiziert mit "archives" und
  "region" Bilddaten aus externen Quellen. "region" sammelt die Zwischen-
  Ergebnisse und speichert Bilder als "raster" und Polygone als "vector.csv" im
  Arbeitsverzeinis. Alle weiteren Prozesse übernehmen "raster" und vector.csv"
  als Eingangsdaten. }

{ PROZESSE:
  Imalys liest und schreibt Bilddaten im ENVI-Format und Vektor-Daten im WKT-
  Format. "reduce", "kernel", "index", "features", "mapping" und "compare"
  bearbeiten Bild- und Vektor-Daten. Sie speichern ihr Ergebnis mit dem Namen
  der aktiven Prozesse im Arbeitsspeicher. Bestehende Ergebnisse werden ohne
  Warnung überschrieben! }

{ EXPORT:
  Imalys exportiert Ergebnisse in verschiedene Raster- und Vektor-Formate.
  "target" sammelt die Ergebnisse im Arbeits-Verzeichnis, transformiert und
  vergibt neue Namen. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, format;

type
  tParse = class(tObject)
    private
      function Bonds(sVal:string):integer;
      function _Breaks(iLin:integer; slPrc:tStringList):integer;
      function Catalog(iLin:integer; slPrc:tStringList):integer;
      function Compare(iLin:integer; slPrc:tStringList):integer;
      function Compile(iLin:integer; slPrc:tStringList):integer;
      function _DataType(sKey:string):boolean;
      function Features(iLin:integer; slPrc:tStringList):integer;
      function Flatten(iLin:integer; slPrc:tStringList):integer;
      function Focus(iLin:integer; slPrc:tStringList):integer;
      function GetParam(sLin:string; var sKey,sVal:string):boolean;
      function Home(iLin:integer; slPrc:tStringList):integer;
      function Import(iLin:integer; slPrc:tStringList):integer;
      function Kernel(iLin:integer; slPrc:tStringList):integer;
      function _Limits_(iLin:integer; slPrc:tStringList):integer;
      function Mapping(iLin:integer; slPrc:tStringList):integer;
      function Period(sPrd:string):tStringList;
      function Protect(iLin:integer; slPrc:tStringList):integer;
      function Replace(iLin:integer; slPrc:tStringList):integer;
      function Search(sFlt:string):tStringList;
      function SplitCommands(slCmd:tStringList):tStringList;
      function wDir(sNme:string):string;
      function Zones(iLin:integer; slPrc:tStringList):integer;
    public
      procedure xChain(sPrc:string);
  end;

var
  Parse: tParse;

implementation

uses
  index, mutual, raster, thema, vector;

{ cGP extrahiert Schlüssel und Wert aus einer Parameter-Zeile. cGP orientiert
  sich dabei nur am "=" Zeichen. }

function tParse.GetParam(
  sLin:string; //aktuelle Zeile aus dem Script
  var sKey:string; //Schlüssel: vor dem "=" Zeichen
  var sVal:string): //Wert: nach dem "=" Zeichen
  boolean; //formal gültige Parameter-Zeile
var
  iPst:integer;
begin
  iPst:=pos('=',sLin); //Trenner
  Result:=iPst>0;
  if not Result then exit;
  sKey:=trim(copy(sLin,1,pred(iPst)));
  sVal:=trim(copy(sLin,succ(iPst),$FF));
end;

{ pWk ergänzt das Home-Verzeichnis für Dateinamen ohne Verzeichnis }

function tParse.wDir(sNme:string):string;
begin
  if ExtractFileDir(sNme)=''
    then Result:=eeHme+sNme
    else Result:=sNme;
end;

{ pF überträgt Werte aus Bilddaten auf Vektor-Punkte. pF übernimmt eine Punkt-
  Geometrie, transformiert die Projektion wenn sie nicht zu den Bilddaten
  passt, extrahiert Werte aus einzelnen Pixeln in den Bilddaten, trägt sie als
  Attribute in die Vektor-Daten ein erzeugt eine Vektor-Datei im gewünschten
  Format. Alle Bilddaten müssen im Imalys-Verzeichnis stehen. Die Attribut-
  Liste "sFtr" bestimmt Auswahl und Reihenfolge der übertragenen Attribute. }

function tParse.Focus(iLin:integer; slPrc:tStringList):integer;
var
  iEpg:integer; //Projektion
  sFtr:string=''; //Liste für Input-Attribute (Bilder), mit Kommas getrennt
  sPnt:string=''; //Geometrie für Attribut-Auswahl, Punkte
  sImg:string=''; //Vorbild
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
begin
  for I:=succ(iLin) to pred(slPrc.Count) do
  begin
    Result:=I; //aktuelle Zeile
    if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
    if sKey='points' then sPnt:=wDir(sVal) else //Punkt-Geometrie für Attribute
    if sKey='fields' then sFtr:=sVal else //Liste (Komma) mit Attributen
    if sKey='select' then sImg:=sVal else //Vorbild mit Werten
    begin end; //falsche Parameter?
  end;
  iEpg:=Cover.CrsInfo(sImg); //EPSG-Code
  Points.xPointAttrib(iEpg,sFtr,sPnt)
end;

function tParse._Limits_(iLin:integer; slPrc:tStringList):integer;
{ cL erzeugt eine Maske. Der Schwellwert ist inclusiv. }
var
  fMin:single=0; //Vorgabe kleinster zulässiger Wert
  sCmd:string=''; //Befehl = Prozess
  sImg:string=''; //Dateiname Raster-Import
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
begin
  sCmd:=trim(slPrc[iLin]); //aktueller Befehl
  for I:=succ(iLin) to pred(slPrc.Count) do
  begin
    Result:=I; //aktuelle Zeile
    if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
    if sKey='source' then sImg:=ChangeFileExt(sVal,'') else
    if sKey='minimum' then fMin:=StrToFloat(sVal) else
    if sKey='select' then sImg:=sVal else //Vorgabe Vorbild
    begin end; //falsche Parameter?
  end;
  Limits._Execute_(fMin,sCmd,sImg);
end;

function tParse.Compare(iLin:integer; slPrc:tStringList):integer;
{ pPt vergleicht eine Clusterung (mapping) mit einer Referenz auf Pixelebene }
{ Referenzen müssen mit der Clusterung deckungsgleich sein. Wird eine Vektor-
  Datei übergeben, transformiert pPt sie in eine passende Raster-Datei. Das
  Ergebnis sind Tabellen im Text-Format und ein Klassen-Bild mit IDs aus der
  Referenz. }
const
  cKey = 'pPt: Keyword not defined: ';
var
  bAcy:boolean=False; //Accuracy-Kontrolle (Bild + Tabellen)
  bAsg:boolean=False; //aktuelle Clusterung referenzieren
  bRst:boolean=False; //Referenz als Raster exportieren
  iEpg:integer=0; //EPSG-Code
  sFld:string=''; //Feldname mit Klassen-Namen aus Vektor-Referenz
  sImg:string=''; //Vorbild
  sRfz:string=''; //Referenz (Vektor oder Raster)
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
begin
  for I:=succ(iLin) to pred(slPrc.Count) do
  begin
    Result:=I;
    if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
    if sKey='reference' then sRfz:=sVal else //Referenz (raster oder vektor)
    if sKey='fieldname' then sFld:=sVal else //Feld in Referenz (nur vektor)
    if sKey='raster' then bRst:=sVal='true' else //Raster-Referenz exportieren
    if sKey='assign' then bAsg:=sVal='true' else //Klassen aus Referenz übernehmen
    if sKey='control' then bAcy:=sVal='true' else //Zusätzliche Tabellen
    if sKey='select' then sImg:=sVal else //Vorbld
    Tools.ErrorOut(cKey+sKey); //unzulässiger Parameter
  end;

  iEpg:=Cover.CrsInfo(eeHme+cfMap); //EPSG-Code
  if ExtractFileExt(sRfz)<>'' then //keine ENVI-Datei
  begin
    Rank.FieldToMap(iEpg,sFld,eeHme+cfMap,sRfz); //Referenz im Raster-Format
    if bRst then Tools.CopyEnvi(eeHme+cfRfz,ChangeFileExt(sRfz,'_raster')); // Raster-Version exportieren
  end
  else Tools.CopyEnvi(sRfz,eeHme+cfRfz); //Raster-Referenz importieren
  if bAsg //Klassen/Cluster vergleichen
    then Rank.xThemaFit(bAcy,eeHme+cfMap,eeHme+cfRfz)
    else Rank.xScalarFit(bAcy,sImg,eeHme+cfRfz); //Scalare vergleichen
end;

{ ToDo: [Parse.Protect] Zellindex, Attribute und Topologie in separates
        Verzeichnis kopieren. Das Verzeichnis kann dann für eine Klassifikation
        verwendet werden. }

{ pTg exportiert Bild- und Vektor-Daten aus dem Arbeitsverzeichnis an einen
  gewählten Ort. Die Extension steuert das Datenformat im Ziel.
    pTg exportiert Zonen als Shapes mit Attributen. Dazu bildet pTg eine CSV-
  Datei mit der Geometrie des Kontroll-Shapes "index.shp" im WKT-Format,
  ergänzt alle Attribute aus der Tabelle "index.bit" und speichert Geometrie
  und Attribute im Shape-Format. Ist nur das Kontroll-Shape (ohne Attribute)
  vorhanden, kopiert pTg es unverändert in das Ziel-Verzeichnis.
    pTg exportiert eine Klassifikation zusammen mit der Klassen-Definition. Das
  Bild ist immer im Byte-Format, die Definition im internen BIT-Format.
    pTg exportiert Bilddaten in das angegebene Verzeichnis. pTg exportiert
  Bilder ohne Extension im ENVI-Format. In diesem fall bleiben die erweiterten
  Header-Informationen erhalten. }

function tParse.Protect(iLin:integer; slPrc:tStringList):integer;
const
  cBnd = 0; //alle Kanäle exportieren
  cFmt = 1; //unverändert exportieren
  cCpy = 'pTg: Image export not successful: ';
  cKey = 'pTg: Keyword not defined: ';
  cPrc = 'pTg: Parameter combination not defined';
  cSrc = 'pTg: Source image not found: ';
var
  iEpg:integer=0; //EPSG-Code
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  sSrc:string=''; //Quelle
  sTrg:string=''; //Target-Name
  I:integer;
begin
  for I:=succ(iLin) to pred(slPrc.Count) do
  begin
    Result:=I; //aktuelle Zeile
    if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
    if sKey='select' then sSrc:=wDir(sVal) else
    if sKey='target' then sTrg:=wDir(sVal) else
    Tools.ErrorOut(cKey+sKey); //unzulässiger Parameter
  end;
  if not FileExists(sSrc) then Tools.ErrorOut(cSrc+sSrc);
  if length(sTrg)<1 then exit; //kein Befehl
  if DirectoryExists(ExtractFileDir(sTrg))=False then
    CreateDir(ExtractFileDir(sTrg)); //Sicherheit

  if ExtractFileName(sSrc)=cfIdx then //Zonen als Polygone
  begin
    if FileExists(eeHme+cfAtr) then //Attribute existieren
    begin
      iEpg:=Cover.CrsInfo(sSrc); //EPSG-Code
      Gdal.ImportVect(iEpg,eeHme+cfIdx+'.shp'); //CSV-Geometrie aus Kontroll-Shape
      Points.xPolyAttrib; //Attribute aus Index.bit in CSV-Geometrie eintragen
      Gdal.ExportShape(iEpg,eeHme+cfFcs,sTrg); //als Shape exportieren
    end
    else
    begin
      Tools.CopyShape(sSrc,sTrg); //unverändert kopieren
      Tools.HintOut('Tools.Export: '+ExtractFileName(sTrg))
    end;
  end
  else if ExtractFileName(sSrc)=cfMap then //Klassen: Bild + Definition
  begin
    Gdal.ExportTo(1,2,sSrc,sTrg) //ein Kanal, Byte
  end
  else if ExtractFileExt(sTrg)<>'' then //neues Bildformat, anderes Verzeichnis
  begin
    Gdal.ExportTo(cBnd,cFmt,sSrc,sTrg); //Bild im gewählten Format
    if not FileExists(sTrg) then Tools.ErrorOut(cCpy+sTrg); //Kontrolle
  end
  else if ExtractFileExt(sTrg)='' then //ENVI-Format, externes Verzeichnis
  begin
    Tools.CopyEnvi(sSrc,sTrg); //im ENVI-Format kopieren
    Tools.HintOut('Tools.Export: '+ExtractFileName(sTrg))
  end
  else Tools.ErrorOut(cPrc);
end;

{ pSC trennt die Prozesse aus "slCmd" in Prozesse zur Zonen-Geometrie für
  "Build.xFeatures" und in Kernel-Prozesse für einzelne Zonen mit
  "Build.xZonesKernel" }

function tParse.SplitCommands(slCmd:tStringList):tStringList;
var
  I:integer;
begin
  Result:=tStringList.Create;
  for I:=pred(slCmd.Count) downto 0 do
    if (slCmd[I]=cfEtp) or (slCmd[I]=cfNrm) then
    begin
      Result.Add(slCmd[I]);
      slCmd.Delete(I)
    end;
end;

{ pBs transformiert die Bezeichner "low"|"medium"|"high" in die Zahlen 1|2|3 }

function tParse.Bonds(sVal:string):integer;
const
  cBnd = 'pBs: Undefined Input to select [zones | bonds]';
begin
  Result:=1; //Vorgabe
  if sVal='accurate' then Result:=-1 else
  if sVal='low' then Result:=0 else
  if sVal='medium' then Result:=1 else
  if sVal='high' then Result:=2 else
    Tools.ErrorOut(cBnd);
end;

{ pKn berechnet Kernel- und DTM-Transformationen und speichert das Ergebnis
  unter dem Prozess-Namen. Der Prozess ist durch die Bezeichner in "execute"
  eindeutig bestimmt. Mit "radius">1 glättet pKn das Ergebnis in "R-1" Stufen
  mit einem Gauß-LowPass. pKn verwendet für DTM-Prozesse die GDAL-Bibliothek.
  Sie wird separat aufgerufen. }

function tParse.Kernel(iLin:integer; slPrc:tStringList):integer;
const
  cKey = 'pKl: Keyword not defined: ';
var
  iRds:integer=3; //Vorgabe Kernel-Radius
  sImg:string=''; //Dateiname Raster-Import
  sTrg:string=''; //Ergebnis-Name ODER leer für Prozess-Name
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  slExc:tStringList=nil; //ausführbare Befehle
  I:integer;
begin
  sImg:=eeHme+cfRst; //Vorgabe Vorbild
  try
    slExc:=tStringList.Create;
    for I:=succ(iLin) to pred(slPrc.Count) do
    begin
      Result:=I;
      if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
      if sKey='execute' then slExc.Add(sVal) else
      if sKey='radius' then iRds:=StrToInt(sVal) else
      if sKey='select' then sImg:=ChangeFileExt(wDir(sVal),'') else
      if sKey='target' then sTrg:=ChangeFileExt(wDir(sVal),'') else
        Tools.ErrorOut(cKey+sKey);
    end;

    for I:=0 to pred(slExc.Count) do
      if slExc[I]=cfHse
        then Filter.Hillshade(sImg) //GDAL-Transformation
        else Filter.xKernel(iRds,slExc[I],sImg,sTrg); //Kernel Transformationen
  finally
    slExc.Free;
  end;
end;

{ pRn reduziert die Kanäle aus dem mit "select" übergebenen Bild. Mit mehr als
  einem Prozess "execute" führt pFl alle Befehle nacheinander aus und speichert
  die Ergebnisse jeweils mit dem Prozess-Namen. }
{ Hauptkomponenten ("execute=principal") benötigen eine eigene Procedur, die
  "iCnt" Ergebnis-Kanäle zurückgibt. Mit "iCnt=1" hat das Ergebnis genau einen
  Kanal. Mit "iCnt=0" erzeugt "xSplice" ein Ergebnis mit denselben Kanälen wie
  die Vorbilder. Dabei wir jeder Kanal für sich reduziert. }

function tParse.Flatten(iLin:integer; slPrc:tStringList):integer;
const
  cKey = 'pFl: Undefined parameter under "flatten": ';
var
  bFlt:boolean=False; //auf einen Kanal reduzieren
  iCnt:integer=0; //Kanäle/Hauptkomponenten
  iNir:integer=3; //Kanal-ID "Infrarot"
  iRed:integer=2; //Kanal-ID "Rot"
  slCmd:tStringList=nil; //Prozesse für gleiche Bildquelle
  sImg:string=''; //Bildquelle
  sTrg:string=''; //gewählter Ergebnis-Name
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
begin
  try
    slCmd:=tStringList.Create;
    for I:=succ(iLin) to pred(slPrc.Count) do
    begin
      Result:=I; //aktuelle Zeile
      if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
      if sKey='count' then iCnt:=StrToInt(sVal) else //Anzahl Hauptkomponenten
      if sKey='execute' then slCmd.Add(sVal) else //Prozess-Namen (Liste)
      if sKey='flat' then bFlt:=sVal='true' else //auf einen Kanal reduzieren
      if sKey='nir' then iNir:=StrToInt(sVal) else //Kanal "Nahes Infrarot"
      if sKey='red' then iRed:=StrToInt(sVal) else //Kanal "Rot"
      if sKey='select' then sImg:=wDir(sVal) else //Bildquelle
      if sKey='target' then sTrg:=wDir(sVal) else //neuer Name
        Tools.ErrorOut(cKey);
    end;

    for I:=0 to pred(slCmd.Count) do //alle Befehle
      if slCmd[I]=cfPca then //alle Hauptkomponenten
      begin
        Image.AlphaMask(sImg); //gleicher Definitionsbereich für alle Kanäle
        Separate.xPrincipal(iCnt,sImg); //rotieren
        Image.HSV(eeHme+cfPca); //in HSV-Farben
      end
      else if bFlt or (slCmd[I]=cfNiv) or (slCmd[I]=cfNvi) or (slCmd[I]=cfLai)
        then Reduce.xReduce(iNir,iRed,slCmd[I],sImg,sTrg) //auf einen Kanal reduzieren
        else Reduce.xSplice(slCmd[I],sImg,sTrg); //multispektrale Reduktion
  finally
    slCmd.Free;
  end;
end;

{ pHe erzeugt oder verknüpft das Arbeitsverzeichnis und richtet die Protokolle
  ein. Mit "clear=true" löscht pHe das Arbeitsverzeichnis vollständig. Für die
  Protokolle sollten mit "log=Verzeichnis" ein anderer Ort gewählt werden. }

function tParse.Home(iLin:integer; slPrc:tStringList):integer;
const
  cDir = 'pHe: Cannot create directory: ';
  cHme = 'pHe: Imalys needs a working directory "user-home/.imalys" !';
var
  bClr:boolean=False; //Home-Verzeichnis leeren
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
begin
  for I:=succ(iLin) to pred(slPrc.Count) do
  begin
    Result:=I; //aktuelle Zeile
    if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
    if sKey='directory' then eeHme:=sVal  else //Arbeits-Verzeichnis
    if sKey='clear' then bClr:=sVal='true' else
    if sKey='log' then eeLog:=sVal else //Protokoll-Verzeichnis
      Tools.ErrorOut(cHme+sVal);
  end;

  if not DirectoryExists(eeHme) then CreateDir(eeHme); //Arbeitsverzeichnis
  eeHme:=Tools.SetDirectory(eeHme); //Delimiter ergänzen
  if bClr then Tools.OsCommand('sh','rm -R '+eeHme+'*'); //Verzeichnis leeren

  if not DirectoryExists(eeLog) then //Verzeichnis für Protokolle
    if not CreateDir(eeLog) then raise Exception.Create(cDir+eeLog);
  eeLog:=Tools.SetDirectory(eeLog); //Delimiter ergänzen
  Tools.TextAppend(eeLog+cfCmd,ccPrt+slPrc.Text); //aktuelle Befehle ergänzen
  Tools.TextAppend(eeLog+cfOut,ccPrt); //Trenn-Linie für Prozess-Output
end;

{ pSn übergibt alle Bilder im Arbeitsverzeichnis, die zur Maske "sFlt" passen.
  pSn sucht NICHT rekursiv. ENVI Bilddaten müssen mit der Extension ".hdr"
  gesucht werden, andernfalls werden sie doppelt erfasst. }

function tParse.Search(sFlt:string):tStringList;
var
  I:integer;
begin
  Result:=Tools.FileFilter(sFlt); //Liste aus Maske
  for I:=pred(Result.Count) downto 0 do
    if ExtractFileExt(Result[I])='.hdr' then
      Result[I]:=ChangeFileExt(Result[I],''); //Bild statt Header
  Tools.HintOut('Parse.Search: '+IntToStr(Result.Count)+' files');
end;

{ pRp ersetzt Variable im Format "$Ziffer" durch den Text nach dem "=" Zeichen.
  pRp ersetzt jedes Vorkommen im übergebenen Text. pRp ignoriert Leerzeichen,
  Tabs und dergl. nach dem Gleichheits-Zeichen.
  VARIABLE DÜRFEN NUR AUS ZWEI BUCHSTANEN (DOLLAR-ZEICHEN + ZIFFER) BESTEHEN }

function tParse.Replace(iLin:integer; slPrc:tStringList):integer;
const
  cKey = 'pRe: Alias definition must be formatted as "$Figure = Value"';
var
  iPst:integer; //Position "$" in slPrc-Zeile
  iRow:integer; //Zeile in "slVar" ab Null
  iVid:integer; //Variable-ID aus slPrc-Zeile
  slVar:tStringList=nil; //Variable als Liste
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  C,I:integer;
  qS:string;
begin
  try
    slVar:=tStringList.Create;
    for I:=succ(iLin) to pred(slPrc.Count) do
    begin
      Result:=I; //aktuelle Zeile
      if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
      if sKey[1]<>'$' then Tools.ErrorOut(cKey+sKey); //nicht definierte Eingabe
      iRow:=StrToInt(sKey[2]); //laufende Nummer = Zeile in "slVar"
      while slVar.Count<=iRow do
        slVar.Add(#32); //"leere" Zeile
      slVar[iRow]:=sVal; //eigegebener Wert
    end;

    for C:=I to pred(slPrc.Count) do //nicht Definitionen
    begin
      qS:=slPrc[C];
      iPst:=pos('$',slPrc[C]); //Variable suchen
      while iPst>0 do
      begin
        iVid:=StrToInt(slPrc[C][succ(iPst)]); //Variablen-ID als Zahl
        slPrc[C]:=copy(slPrc[C],1,pred(iPst))+slVar[iVid]+
          copy(slPrc[C],iPst+2,$FF); //Variable einsetzen
        iPst:=pos('$',slPrc[C]); //nächste Variable
      end;
      qS:=slPrc[C];
    end;
    slPrc.SaveToFile(eeHme+'commands'); //NUR KONTROLLE
  finally
    slVar.Free;
  end;
end;

{ pCg erzeugt eine Punkt-Geometrie im WKT-Format, die jedem Landsat-Archiv den
  Mittelpunt seiner Kachel zuordnet. pCg durchsucht das Verzeichnis mit der
  Maske "sMsk". Die Maske darf Platzhalter (*,?) enthalten. pCg speichert das
  Ergebnis unter dem übergebenen Namen. pCg verwendet geographische Koordinaten
  (EPSG = 4326). }

function tParse.Catalog(iLin:integer; slPrc:tStringList):integer;
const
  cFmt = 'WKT,Integer64(10),Real(24.15),Real(24.15),String(250)';
  cKey = 'pCg: Undefined parameter under "catalog": ';
var
  sMsk:string=''; //Maske Archiv-Namen
  sTrg:string='tilecenter.csv'; //Dateiname für Datenbank
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
  begin
  for I:=succ(iLin) to pred(slPrc.Count) do
  begin
    Result:=I; //aktuelle Zeile
    if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
    if sKey='archives' then sMsk:=sVal else
    if sKey='target' then sTrg:=ChangeFileExt(sVal,'.csv') else
      Tools.ErrorOut(cKey+sKey) //nicht definierte Eingabe
  end;

  Tools.TextOut(sTrg,Archive.Catalog(sMsk).Text); //Geometrie im CSV-Format
  Tools.TextOut(ChangeFileExt(sTrg,'.csvt'),cFmt); //Spaltendefinition
  Tools.TextOut(ChangeFileExt(sTrg,'.prj'),ccPrj); //EPSG = 4326
end;

function tParse._DataType(sKey:string):boolean;
begin
  Result:=sKey='single';
end;

{ pIt extrahiert Bilddaten aus Archiven, beschneidet sie auf einen Ausschnitt,
  kombiniert bei Bedarf Teile aus verschiedenen Kacheln, kalibriert die Werte
  auf Reflektanz oder Strahlung und bewertet die Bildqualität. pIt speichert
  alle Ergebnisse im ENVI-Format im Arbeitsverzeichnis. }
{ Die Archive können mit "select" direkt angegeben werden oder mit "period",
  "distance" und "quality" aus einer Archiv-Liste "database" gewählt werden.
  Dabei filtert "period" das Datum der Aufnahmen und "distance" den maximalen
  Abstand zwischen den Mittelpunkten von Kachel und Auswahlrahmen. "quality"
  begrenzt den Anteil von fehlerhaften Pixeln im Auswahlrahmen. }
{ pIt scaliert die Bilddaten mit "offset" und "factor", beschneidet das Bild
  auf "frame" und vereinigt die in "bands" angegebenen Kanäle zu einem
  Multi-Layer-Bild. pIt reprojiziert bei Bedarf mit "warp" auf die angegebene
  Projektion. Sind Teile des Auswahlrahmens auf verschiedene Kacheln mit
  gleichem Aufnahmedatum verteilt, vereinigt pIt die Teile zu einem nahtlosen
  Bild des ausgewählten Bereichs. }
{ pIt spechert den Anteil ungestörter Pixel als Zeiger in der Liste der Bild-
  Namen und überträgt sie von dort in den Header. Auf diesem Weg muss pIt nur
  Bilder mit hoher Qualität extrahieren. }

function tParse.Import(iLin:integer; slPrc:tStringList):integer;
const
  cKey = 'pRn: Undefined parameter under "import": ';
var
  fCvr:single=0.9; //kleinste akzeptierte Abdeckung des ROI
  fDst:single=1.0; //Maximum Distanz ROI-Kachel
  fFct:single=1.0; //Faktor für Kalibrierung
  fLmt:single=0.0; //Minimum fehlerfreie Pixel
  fOfs:single=0.0; //Offset für Kalibrierung
  iPix:integer=10; //Pixelgröße in Metern
  iWrp:integer=0; //EPSG-Code für Umprojektion
  sFrm:string=''; //Rahmen für Kachel-Ausschnitt
  sGrv:string=''; //Archiv-Zentren-Liste
  sMsk:string=''; //Filter für Kanal-Namen, kommagetrennt
  sPrd:string=''; //Zeitperiodde für Auswahl
  slArc:tStringList=nil; //Archiv-Namen
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
begin
  try
    slArc:=tStringList.Create;
    for I:=succ(iLin) to pred(slPrc.Count) do
    begin
      Result:=I; //gültige Zeile
      if not GetParam(slPrc[I],sKey,sVal) then break; //neuer Befehl
      if sKey='bands' then sMsk:=sVal else //Kanal-Namen-Masken, kommagetrennt
      if sKey='cover' then fCvr:=StrToFloat(sVal) else //Minimum Abdeckung des ROI
      if sKey='database' then sGrv:=sVal else //Position und Namen im WKT-Format
      if sKey='distance' then fDst:=StrToFloat(sVal) else //Maximale Distanz zum Kachelzentrum
      if sKey='frame' then sFrm:=wDir(sVal) else //Rahmen für Beschnitt
      if sKey='factor' then fFct:=StrToFloat(sVal) else //Faktor für Kalibrierung
      if sKey='offset' then fOfs:=StrToFloat(sVal) else //Offset für Kalibrierung
      if sKey='warp' then iWrp:=StrToInt(sVal) else //Ziel-Projektion
      if sKey='period' then sPrd:=sVal else //Zeitperiode
      if sKey='pixel' then iPix:=StrToInt(sVal) else //Pixelgröße [m]
      if sKey='quality' then fLmt:=StrToFloat(sVal) else //Maximum Fehler
      if sKey='select' then slArc.Add(wDir(sVal)) else //direkt gewähltes Archiv
        Tools.ErrorOut(cKey+sKey);
    end;

    if length(sGrv)>0 then //Namen aus Datenbank
      slArc.Assign(Archive.xSelect(fDst,fLmt,sFrm,sGrv,sPrd)) //Archive auswählen
    else if slArc.Count>0 then //Namen direkt eingegeben
      Archive.xQuality(fLmt,sFrm,slArc); //Qualitäts-ID im "slArc"-Objektzeiger
    for I:=pred(slArc.Count) downto 0 do //alle Archive
    begin
      slArc[I]:=Archive.ImportBands(fFct,fOfs,slArc[I],sMsk,sFrm);
      if length(slArc[I])>0 then //passende Layer gefunden?
      begin
        if iWrp<>Cover.CrsInfo(slArc[I]) then //umprojizieren
        begin
          Gdal.Warp(iWrp,iPix,slArc[I]); //neue Projektion, neue Pixelgröße
          Tools.EnviRename(eeHme+cfWrp,slArc[I]); //alten Namen übernehmen
        end;
        Header.WriteLine('quality',Header.PtrString(slArc.Objects[I]),slArc[I]); //Quality im Header ergänzen
        slArc.Objects[I]:=nil; //Flag wird auch von "CommonDate" verwendet
      end
      else slArc.Delete(I); //Eintrag löschen
    end;
//- slArc ohne Import ----------------------------------------------------------
    {slArc:=Tools.FileFilter(eeHme+'*.hdr');
    for I:=0 to pred(slArc.Count) do
      slArc[I]:=ChangeFileExt(slArc[I],'');}
//------------------------------------------------------------------------------
    Reduce.xOverlay(slArc); //Teilbilder aus gleichem Flugpfad vereinigen → SL_ARC WIRD REDUZIERT
    Image.xDeleteAlpha(fCvr,sFrm,slArc); //Bilder mit geringer Abdeckung löschen
  finally
    slArc.Free;
  end;
end;

{ pMp erzeugt ein Klassen-Modell und clustert damit Bilddaten. Mit "pixel" als
  Modell clustert pMp den Import auf Pixelbasis, mit "zonal" Zonen-Attribute
  und mit "fabric" Zonen-Kontakte. Für "region" und "fabric" muss ein Zonen-
  Index erzeugt oder importiert werden. Der "entropy" Prozess benötigt eine
  Pixel-Klassifikation. }

function tParse.Mapping(iLin:integer; slPrc:tStringList):integer;
const
  cKey = 'pMg: Keyword not defined: ';
var
  bDbl:boolean=False; //zweischichtige Nachbarschaft
  bEql:boolean=False; //Werte auf 0.5±2s normalisieren
  bVal:boolean=False; //Klassen in Bildfarben
  iFtr:integer=30; //Vorgabe Anzahl Cluster
  iRds:integer=2; //Vorgabe Kernel-Radius
  iSmp:integer=30000; //Vorgabe Stichproben
  sImg:string=''; //Vorbild
  sMdl:string=''; //Klassen-Typ
  sRun:string=''; //Prozess, von Klassen abhängig
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
begin
  for I:=succ(iLin) to pred(slPrc.Count) do
  begin
    Result:=I; //aktuelle Zeile
    if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
    if sKey='double' then bDbl:=sVal='true' else
    if sKey='equalize' then bEql:=True else
    if sKey='execute' then sRun:=sVal else //Prozess-Name
    if sKey='classes' then iFtr:=StrToInt(sVal) else //Anzahl Cluster
    if sKey='model' then sMdl:=sVal else //Klassen-Typ
    if sKey='radius' then iRds:=StrToInt(sVal) else //Radius für Entropy Kernel
    if sKey='samples' then iSmp:=StrToInt(sVal) else //Anzahl Stichproben
    if sKey='select' then sImg:=wDir(sVal) else //Vorbild
    if sKey='values' then bVal:=sVal='true' else
      Tools.ErrorOut(cKey+sKey) //nicht definierte Eingabe
  end;

  if sMdl<>'existing' then
  begin
    if sMdl='pixels' then Image.AlphaMask(sImg); //NoData in allen Kanälen gleich
    if bEql then Separate.xNormalize(3,sImg); //Stack normalisieren ← analog Merkmale
    if sMdl='pixels' then Model.xImageMap(iFtr,iSmp,sImg) else //Pixel clustern
    if sMdl='zones' then Model.xZonesMap(iFtr,iSmp,sImg) else //Zonen clustern
    if sMdl='fabric' then Fabric.xFabricMap(bDbl,iFtr,iSmp); //Objekte erzeugen
  end;
  if bVal then Model.ClassValues(1,2,3); //RGB-Palette aus Klassen-Definition
  if sRun=cfEtp then Filter.xRaosDiv(iRds,eeHme+cfMap) //Entropie aus Klassen
end;

{ pZs erzeugt aus dem mit "select" übergebenen Bild neue Zonen und visualisiert
  sie als ESRI-Shape ohne Attribute. pZs erzeugt die thematische Datei "index"
  mit den Zonen als Klassen, die Grenzen der Zonen "index.shp" und die Zonen-
  Verknüpfungs-Tabelle "topology.bit". Zonen-Attribute (index.bit) werden mit
  dem Befehl "Features" erzeugt. }

function tParse.Zones(iLin:integer; slPrc:tStringList):integer;
const
  cCmd = 'Key misspelled or not appropriate for "zones": ';
  cGrw = 'Key misspelled or not appropriate for "zones": ';
var
  iGrw:integer=1; //Typ Zonen-Wachstum (Vorgabe = medium)
  iMin:integer=0; //kleine Zonen nachträglich löschen
  iSze:integer=50; //Pixel pro Zone (Mittelwert)
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  sImg:string=''; //Vorbild ODER externer Index
  I:integer;
begin
  for I:=succ(iLin) to pred(slPrc.Count) do
  begin
    Result:=I; //aktuelle Zeile
    if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
    if sKey='bonds' then iGrw:=Bonds(sVal) else
    if sKey='select' then sImg:=wDir(sVal) else
    if sKey='sieve' then iMin:=StrToInt(sVal) else
    if sKey='size' then iSze:=StrToInt(sVal) else
      Tools.ErrorOut(cCmd+sKey) //nicht definierte Eingabe
  end;

  if iGrw>=0 then
  begin
    Image.AlphaMask(sImg); //NoData-Maske auf alle Kanäle ausdehnen
    Union.xZones(iGrw,iSze,sImg); //Zonen erzeugen
  end
  else if iGrw=-1 then Union.xBorders(sImg) //Klassen abgrenzen
  else Tools.ErrorOut(cGrw); //nicht definierte Eingabe

  if iMin>0 then Limits.xSieveZones(iMin); //kleine Zonen löschen
end;

{ pSn übergibt alle Bilder im Arbeitsverzeichnis, die ein passendes Datum im
  Namen haben. pSn unterstellt, dass der Dateiname mit dem Datum endet und das
  Datum als YYYYMMDD codiert ist. "sPrd" muss aus zwei solchen Blöcken mit dem
  ersten und dem letzten zulässigen Datum bestehen. }

function tParse.Period(
  sPrd:string): //Zeitperiode [YYYYMMDD-YYYYMMDD]
  tStringList; //akzeptierte Bilder
var
  sDat:string; //Dateiname
  I:integer;
begin
  Result:=Search(eeHme+'*.hdr'); //ENVI-Bilder im Arbeitsverzeichnis
  for I:=pred(Result.Count) downto 0 do
  begin
    sDat:=RightStr(ChangeFileExt(Result[I],''),8); //Datum im Dateinamen NOTWENDIG
    if not Archive.QueryDate(sDat,sPrd) then
      Result.Delete(I) //Bild aus Liste löschen
  end;
  Tools.HintOut('Parse.Season: '+IntToStr(Result.Count)+' files');
end;

{ pCe erzeugt einen Stack aus den übergebenen Bildern. Die Dateinamen können
  direkt übergeben werden (select), mit Wildchars (search) oder über ein Zeit-
  Intervall (period). Ohne "select" oder "search" sucht "period" im Arbeits-
  Verzeichnis. Gibt es bereits eine Auswahl, filtert "period" die bestehende
  Auswahl wirt dem übergebenen Datum.
    pCe bricht nicht ab, wenn einzelne gewählte Bilder nicht existieren. pCe
  vergrößert die Ergebnis-Fläche so, dass alle Teile abgebildet werden. Mit
  "frame" kann das Ergebnis in eine beliebige Form geschnitten werden. pCe
  füllt nicht abgedeckte Flächen mit NoData. pCe schreibt im ENVI-Format in da
  Arbeitsverzeichnis. Der Default-Name "compile" kann mit "target" verändert
  werden. }

function tParse.Compile(iLin:integer; slPrc:tStringList):integer;
const
  cImg = 'pCompile: Image names not defined or empty image list!';
  cKey = 'pCompile: Undefined parameter under "compile": ';
var
  bSgl:boolean=true; //Bild im Single-Format importieren = Vorgabe
  slImg:tStringList=nil; //ausgewählte Kanäle im Archiv
  sCrs:string=''; //Vorbild für Projektion und CRS
  sFrm:string=''; //Ergebnis-Name optional
  sTrg:string; //Ergebnis-Name (Vorgabe)
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
  qS:string;
begin
  sTrg:=eeHme+cfCpl; //Vorgabe-Name
  try
    slImg:=tStringList.Create;
    for I:=succ(iLin) to pred(slPrc.Count) do
    begin
      Result:=I; //gültige Zeile
      if not GetParam(slPrc[I],sKey,sVal) then break; //neuer Befehl
      if sKey='format' then bSgl:=_DataType(sVal) else //Datenformat = Original oder Single
      if sKey='frame' then sFrm:=sVal else //Maske aus Polygon
      if sKey='projection' then sCrs:=sVal else //Projektion eintragen <== "assign = EPSG-Code"
      if sKey='search' then slImg.AddStrings(Search(wDir(sVal))) else //Dateinamen-Filter
      if sKey='select' then slImg.Add(wDir(sVal)) else //einzelner Name, "eeHme" ist Vorgabe
      if sKey='target' then sTrg:=wDir(sVal) else //neuer Name
      if sKey='period' then slImg.AddStrings(Period(sVal)) else //Zeitperiode aus Selektion selektieren
        Tools.ErrorOut(cKey+sKey);
    end;
    for I:=pred(slImg.Count) downto 0 do
    begin
      qS:=slImg[I];
      if FileExists(slImg[I])=False then
        slImg.Delete(I);
    end;
    if slImg.Count=0 then Tools.ErrorOut(cImg); //keine Aufgabe

    slImg.Sort; //bei richtigen Namen nach Zeitangaben
    for I:=0 to pred(slImg.Count) do
      if ExtractFileExt(slImg[I])=''
        then slImg[I]:=Tools.CopyEnvi(slImg[I],eeHme+ExtractFileName(slImg[I])) //kopieren
        else slImg[I]:=Image._Translate(bSgl,slImg[I]); //im ENVI-Format speichern
    if slImg.Count>1
      then Image.StackImages(slImg,sTrg) //Stack aus Bilder-Liste im ENVI-Format
      else Tools.EnviRename(slImg[0],sTrg); //ein Bild umbenennen
    if length(sCrs)>0 then Header._Projection(sCrs,sTrg); //Projektion überschreiben
    if length(sFrm)>0 then Cover.ClipToFrame(sFrm,sTrg); //auf ROI zuschneiden
  finally
    slImg.Free;
  end;
end;

{ pFs ersetzt die Zonen-Attribut-Tabelle "Index.bit". Mit "select" übernimmt
  pFs alle Kanäle aus dem Bild "sImg" als Attribute. "sImg" muss nicht das Bild
  sein, mit dem die Zonen gebildet wurden, es muss lediglich dieselbe Länge und
  Breite haben. Mit "execute" erzeugt pFs Attribute aus der Geometrie der Zonen
  und aus den Pixeln einzelner Zonen. Dazu trennt pFs die Befehle in die Listen
  "slCmd" und "slKrn". "diffusion" implementiert einen Werteausgleich für
  Geometrie-Attribute. Mit "values" erzeugt pFs ein Attribut-Kontroll-Bild. }

function tParse.Features(iLin:integer; slPrc:tStringList):integer;
const
  cCmd = 'pFs: Key misspelled or not appropriate for "attribute": ';
  cFit = 'pFs: Image size must fit zones geometry!';
var
  bApd:boolean=False; //Attribute nicht erweitern sondern neu rechnen
  bVal:boolean=False; //Bild aus Attribut-Tabelle
  iGen:integer=0; //Generationen für Attribut-Ausgleich
  sImg:string=''; //Bilddaten für Attribute + SCHALTER
  slCmd:tStringList=nil; //Befehle für Zonen-Attribute
  slKrn:tStringList=nil; //Befehle für Zonen-Kernel
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
begin
  try
    slCmd:=tStringList.Create;
    for I:=succ(iLin) to pred(slPrc.Count) do
    begin
      Result:=I; //aktuelle Zeile
      if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
      if sKey='append' then bApd:=sVal='true' else //Attribute an bestehende Liste anhängen
      if sKey='diffusion' then iGen:=StrToInt(sVal) else //Attribute "weich" rechnen
      if sKey='execute' then slCmd.Add(sVal) else //Attribute aus Zonen-Geometrie
      if sKey='select' then sImg:=wDir(sVal) else //Bilddaten (Stack) für Attribute
      if sKey='values' then bVal:=sVal='true' else //Attribute-Bild erzeugen
        Tools.ErrorOut(cCmd+sKey) //nicht definierte Eingabe
    end;

    if bApd=False then DeleteFile(eeHme+cfAtr); //bestehende Attribute löschen
    slKrn:=SplitCommands(slCmd); //Kernel-Befehle getrennt verarbeiten!
    if length(sImg)>0 then //Bilddaten verwenden
    begin
      if not Build.SizeFit(eeHme+cfIdx,sImg) then Tools.ErrorOut(cCmd+sKey); //nicht definierte Eingabe
      Image.AlphaMask(sImg); //NoData-Maske auf alle Kanäle ausdehnen
      Build.xAttributes(sImg); //Attribute aus allen Bilddaten (Mittelwerte)
      if slKrn.Count>0 then Build.xKernels(slKrn,sImg); //Attrubute aus Zonen-Kerneln
    end;
    if slCmd.Count>0 then Build.xFeatures(iGen,sImg,slCmd); //Attribute aus Zonen-Geometrie
    if bVal then Image.ZoneValues; //Raster-Bild aus Attributen
  finally
    slCmd.Free;
    slKrn.Free;
  end;
end;

{ TODO: [Imalys] Das Ablauf-Protokoll sollte automatisch in eine Process-Chain
        verwandelt werden können }

{ pCh interpretiert die Prozess-Kette "sPrc". Die Kette besteht aus Befehlen
  und Parametern. Jeder Befehl oder Parameter steht in einer eigenen Zeile.
  Parameter haben die Form [Schlüssel = Wert]. Das "=" Zeichen macht eine Zeile
  zur Parameter-Zeile. Jeder Befehl ist mit einer Routine verknüpft, die seine
  Parameter liest und die passenden Funktionen aufruft. }
{ pCh liest die Prozess-Kette bis zu einem Befehl. Die entsprechende Procedur
  liest die folgenden Parameter bis zum nächsten Befehl, führt die Parameter
  aus und gibt den Index der zuletzt gelesenen Zeile zurück. }
{ Nur "archives", "import" und "images" importieren Bild- und Vektor-Daten. Nur
  "target" exportiert sie. Alle anderen Prozesse bearbeiten Daten im Arbeits-
  Verzeichnis. }
{ Nur "Import" kann beliebige Formate lesen, nur "Target" kann sie schreiben.
  Alle anderen Ergebnisse werden als Raw Binary mit Header (ENVI), als CSV-
  Dateien (OSF) oder im BIT-Format (Tabellen) gelesen und geschrieben. }

procedure tParse.xChain(sPrc:string);
const
  cCmd = 'pCn: Unknown command: ';
  cFmt = 'Second line must contain a command. Found: ';
  cIdf = 'Process chain must start with key "IMALYS"';
var
  iSkp:integer=0; //Zeilen überspringen
  sCmd:string=''; //aktuelle Zeile
  slPrc:tStringList=nil; //Prozess
  I:integer;
begin
  if FileExists(sPrc) then
  try
    slPrc:=Tools.LoadClean(sPrc); //Hook laden und säubern
    if pos('IMALYS',slPrc[0])<1 then Tools.ErrorOut(cIdf);
    if pos('=',slPrc[1])>0 then Tools.ErrorOut(cFmt+slPrc[1]);
    writeln(ccPrt); //Trenner
    for I:=1 to pred(slPrc.Count) do
    begin
      if I<iSkp then continue; //Zeilen sind gelesen
      if pos('=',slPrc[I])>0 then continue; //Parameter-Zeile ignorieren
      sCmd:=trim(slPrc[I]);
      if sCmd='' then continue; //leere Zeile
      if sCmd='breaks' then iSkp:=_Breaks(I,slPrc) else //Brüche in Zeitreihen
      if sCmd='catalog' then iSkp:=Catalog(I,slPrc) else //Kachel-Mitten-Katalog
      if sCmd='compare' then iSkp:=Compare(I,slPrc) else //Referenz vergleichen
      if sCmd='compile' then iSkp:=Compile(I,slPrc) else //Stack aus Zwischenprodukten
      if sCmd='export' then iSkp:=Protect(I,slPrc) else //Export
      if sCmd='focus' then iSkp:=Focus(I,slPrc) else //focale Attribute NICHT ÜBERNOMMEN
      if sCmd='features' then iSkp:=Features(I,slPrc) else //Zell-Attribute ergänzen
      if sCmd='home' then iSkp:=Home(I,slPrc) else //Arbeits-Verzeichnis
      if sCmd='import' then iSkp:=Import(I,slPrc) else //Extraktion und Import für zahlreiche Archive
      if sCmd='kernel' then iSkp:=Kernel(I,slPrc) else //Kernel-Prozesse
      if sCmd='mapping' then iSkp:=Mapping(I,slPrc) else //Clusterer
      if sCmd='reduce' then iSkp:=Flatten(I,slPrc) else //Kanäle reduzieren + Indices
      if sCmd='replace' then iSkp:=Replace(I,slPrc) else //Variable ersetzen
      if sCmd='zones' then iSkp:=Zones(I,slPrc) else //Clusterer
        Tools.ErrorOut(cCmd+sCmd);
    end;
    Tools.HintOut('DONE');
  finally
    slPrc.Free;
  end
  else Tools.ErrorOut('pCn: provide commands!');
end;

// instabile Punkte in Zeitreihe suchen

function tParse._Breaks(iLin:integer; slPrc:tStringList):integer;
const
  cKey = 'pBk: Undefined parameter under "break": ';
var
  sImg:string=''; //Vorbild
  sCmd:string=''; //Befehl
  sKey,sVal:string; //linke, rechte Hälfte der Parameter-Zeile
  I:integer;
begin
  for I:=succ(iLin) to pred(slPrc.Count) do
  begin
    Result:=I; //aktuelle Zeile
    if not GetParam(slPrc[I],sKey,sVal) then break; //Parameter, Wert
    if sKey='execute' then sCmd:=(sVal) else //Befehl
    if sKey='select' then sImg:=wDir(sVal) else //Bilddaten (Zeitverlauf) für Statistik
      Tools.ErrorOut(cKey+sKey); //nicht definierte Eingabe
  end;

  if sCmd=cfHry then Reduce.xHistory(sImg) else
  if sCmd='equalize' then Rank.xEqualize(2,sImg);
end;

end.

{==============================================================================}

{ pSn übergibt alle Bilder im Arbeitsverzeichnis, die ein passendes Datum im
  Namen haben. pSn unterstellt, dass der Dateiname mit dem Datum endet und das
  Datum als YYYYMMDD codiert ist. "sPrd" muss aus zwei solchen Blöcken mit dem
  ersten und dem letzten zulässigen Datum bestehen. }

procedure tParse.Period_(
  slImg:tStringList; //bestehende Auswahl
  sPrd:string); //Zeitperiode [YYYYMMDD-YYYYMMDD]
var
  sDat:string; //Dateiname
  I:integer;
begin
  if slImg.Count=0 then
  begin
    slImg:=Tools.FileFilter(eeHme+'*.hdr'); //alle ENVI-Dateien
    for I:=0 to pred(slImg.Count) do
      ChangeFileExt(slImg[I],''); //Bild statt Metadaten
  end;
  for I:=pred(slImg.Count) downto 0 do
  begin
    sDat:=RightStr(ChangeFileExt(slImg[I],''),8); //Datum im Dateinamen
    if not Archive.QueryDate(sDat,sPrd) then
      slImg.Delete(I) //Bild aus Liste löschen
  end;
  Tools.HintOut('Parse.Season: '+IntToStr(slImg.Count)+' files');
end;

