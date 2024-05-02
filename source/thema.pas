unit thema;

{ THEMA sammelt Routinen zur Clusterung und Klassifikation von Bilddaten. Dabei
  clustert "Model" Bildmerkmale anhand einzelner Pixel und "Fabric" verwendet
  aus der Zellbildung (index) abgeleitete Teilflächen und ihre räumliche
  Verknüpfung. In jedem Fall nimmt "Thema" zuerst Stichproben ("Samples") aus
  den Bilddaten, erzeugt ein "Model" mit verschiedenen Clustern und
  klassifiziert damit das Bild.

  FABRIC: erzeugt und clustert Objekte aus verknüpften Zonen
  LIMITS: extrahiert Masken(Grenzen) aus Werten im Bild
  MODEL:  clustert multidimensionale Bilddaten
  REDUCE: selektiert und analysiert Drei- und mehrdimensionale Bilddaten

  BEGRIFFE MIT SPEZIFISCHER ANWENDUNG:
  Band:    Bildkanal
  Dict:    Zuweisung von Begriffen oder Werten: Bezeichner = Wert
  Feature: Bild-Merkmal (Dichte) in einem →Modell oder einer →Sample-Liste
  Key:     Zonen-Merkmal = Häufigkeit von Kontakten in einem →Model oder einer
           →Sample-Liste
  Layer:   Bildkanal oder Bild-Merkmal
  Model:   Ergebnis einer Clusterung (Selbstorganisation) mit den typischen
           Merkmalen (Werten) der Klassen als Matrix[Klasse,Merkmal].
           Model[?,0] speichert das Quadrat des Suchradius (für SOM-Neurone),
           alle anderen Werte sind Bildmerkmale, auch NoData.
  Samples: Stichproben mit allen Merkmalen eines Pixels oder einer →Zone als
           Matrix[Probe,Merkmal]. Die erste Stelle (Sample[?,0]) bleibt frei
           für den Suchradius (SOM-Neurone).
  Stack:   Stapel aus Kanälen mit Bilddaten, gleiche Geometrie
  Sync:    Imalys kann Merkmale von mehr als einem Bild gemeinsam bearbeiten.
           Dazu müssen die Bilder einen Teil des Namens gemeinsam haben. Lage
           und Geometrie der Bilder sind frei.
  Wave:    zeitlich konstante Periode in der Veränderung von Werten
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, StrUtils, DateUtils, format;

type
  tFig2Int = function(fVal,fFct:single):string;

  tFabric = class(tObject)
    private
      iacDim: tnInt; //Index auf "iacNbr, iacPrm"
      iacMap: tnInt; //Klassen-Attribut
      iacNbr: tnInt; //Index der Nachbarzelle
      iacPrm: tnInt; //Kontakte zur Nachbarzelle
      procedure DoubleKey(iIdx:integer; pSmp:tnSgl);
      function FabricClassify(bDbl:boolean; fxKey:tn2Sgl):TnInt;
      function FabricSamples(bDbl:boolean; iMap,iSmp:integer):Tn2Sgl;
      procedure SingleKey(iIdx:integer; pSmp:TnSgl);
    public
      procedure xFabricMap(bDbl:boolean; iFbr,iSmp:integer);
  end;

  tLimits = class(tObject)
    private
      function SieveZones(iaFix:tnInt; iMin:integer; ixTpl:tn2Int):integer;
      function _MaskLimit_(fMin:single; fxBnd:tn2Sgl):tn2Byt;
      procedure MergeZones(ixTpl:tn2Int; iaFix:tnInt);
      function RecodeIndex(iaFix:tnInt; ixIdx:tn2Int):integer;
    public
      procedure _Execute_(fMin:single; sCmd,sImg:string);
      procedure xSieveZones(iMin:integer); //Minimum innere Kontakte
  end;

  tModel = class(tObject) //Multi-Trait-Listen clustern und klassifizieren
    const
      ccFct = 3; //Dämpfung bei Werte-Anpassung
      ccScl = 9; //Radius-Scalierung (quadriert)
    private
      function CountDiff(iaBck,iaThm:tnInt):integer;
      procedure ModelAdjust(fxMdl,fxSmp:tn2Sgl; iaThm:tnInt);
      function ModelSelect(fxSmp:tn2Sgl;iMap:integer):tn2Sgl;
      function PixelClassify(fxMdl:tn2Sgl; sImg:string):tn2Byt;
      function PixelSamples(iSmp:integer; sImg:string):Tn2Sgl;
      function SampleClassify(fxMdl,fxSmp:tn2Sgl):tnInt;
      function SampleModel(fxSmp:tn2Sgl; iMap:integer; sRes:string):tn2Sgl;
      function SampleThema(faSmp:TnSgl; fLmt:single; fxMdl:tn2Sgl):integer;
      procedure ThemaLayer(iMap:integer; ixMap:tn2Byt; sImg:string);
      function ZonesClassify(fxMdl:tn2Sgl):tnInt;
      function ZonesSamples(iSmp:integer):tn2Sgl;
    public
      procedure ClassValues(iRed,iGrn,iBlu:integer);
      function FeatureDist:tn2Sgl;
      procedure xImageMap(iMap,iSmp:integer; sImg:string);
      procedure xZonesMap(iMap,iSmp:integer; sImg:string);
  end;

  tReduce = class(tObject)
    private
      function BestOf(fxImg:tn3Sgl; sQap:string):tn2Sgl;
      function CommonDate(slImg:tStringList):tStringList;
      function _CoVariance_(fxImg:tn3Sgl; iaTms:tnInt):tn2Sgl;
      function DateIndex(var rHdr:trHdr):tnInt;
      function Distance(fxImg:tn3Sgl):tn2Sgl;
      function Execute(fxImg:tn3Sgl; iNir,iRed:integer; sCmd:string; var rHdr:trHdr):tn2Sgl;
      function ImageDate(sImg:string):integer;
      function IntToStrSize(iInt,iSze:integer):string;
      function _LeafAreaIndex(fxImg:tn3Sgl; iNir,iRed:integer):tn2Sgl;
      function _LeafAreaIndex_(fxImg:tn3Sgl; iNir,iRed:integer):tn2Sgl;
      function MeanValue(fxImg:tn3Sgl):tn2Sgl;
      function Median(fxImg:tn3Sgl):tn2Sgl;
      function Overlay(fxImg:tn3Sgl):tn2Sgl;
      function Quality(sQlt:string):single;
      function Regression(fxImg:tn3Sgl; var rHdr:trHdr):tn2Sgl;
      function _SentinelQuality_(rFrm:trFrm; sImg,sMsk:string):tn2Byt;
      function Vegetation(fxImg:tn3Sgl; iNir,iRed,iTyp:integer):tn2Sgl;
    public
      procedure IndexSort(iaIdx:tnInt; faVal:tnSgl);
      function Brightness(fxImg:tn3Sgl):tn2Sgl;
      procedure QuickSort(faDev:tnSgl; iDim:integer);
      function Variance(fxImg:tn3Sgl):tn2Sgl; //Vorbild: Varianz
      procedure xHistory(sImg:string);
      procedure xOverlay(slImg:tStringList);
      procedure xSplice(sCmd,sImg,sTrg:string);
      procedure xReduce(iNir,iRed:integer; sCmd,sImg,sTrg:string);
  end;

var
  Fabric: tFabric;
  Limits: tLimits;
  Model: tModel;
  Reduce: tReduce;

implementation

uses
  index, mutual, raster, vector;

function Float2Number(fVal,fFct:single):string;
begin
  Result:=FloatToStrF(fVal*fFct,ffFixed,7,0)
end;

function Int2Number(fVal,fFct:single):string;
begin
  Result:=FloatToStrF(integer(fVal)*fFct,ffFixed,7,0)
end;

function tReduce._CoVariance_(
  fxImg:tn3Sgl; //Bilddaten-Stack
  iaTms:tnInt): //Zeitstempel pro Bild
  tn2Sgl; //CoVarianz
{ rVc }
{ CoVarianz = (∑xy - ∑x∑y/n)/(n-1) }
var
  fPrd:single=0; //Produkt beider Variablen
  fSum:single=0; //Summe der ersten Variablen
  fMus:single=0; //Summe der zweiten Variablen
  iCnt:integer; //Anzahl gültiger Kanäle (n)
  B,X,Y: integer;
begin
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  for B:=0 to high(fxImg) do //alle Kanäle
    fMus+=iaTms[B]; //Summe aller Zeitstempel
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
    begin
      fPrd:=0; fSum:=0; iCnt:=0;
      for B:=0 to high(fxImg) do //alle Kanäle
      begin
        if IsNan(fxImg[B,Y,X]) then continue;
        fPrd:=fxImg[B,Y,X]*iaTms[B];
        fSum+=fxImg[B,Y,X];
        inc(iCnt) //Anzahl gültige Schritte
      end;
      if iCnt>1
        then Result[Y,X]:=(fPrd-fSum*fMus/iCnt)/pred(iCnt)
        else Result[Y,X]:=NaN;
    end;
end;

{ tMFD bestimmt die (spektrale) Distanz zwischen allen Klassen-Kombinationen im
  aktuellen Modell "fxMdl" und gibt das Ergebnis als Matrix zurück. Nicht
  definierte Kombinationen sind auf Null gesetzt. }

function tModel.FeatureDist:tn2Sgl; //Distanzen-Matrix
var
  fRes: single; //Zwischenergebnis
  fxMdl: tn2Sgl=nil; //aktuelles Modell
  I,N,M: integer;
begin
  Result:=nil;
  fxMdl:=Tools.BitRead(eeHme+cfMdl); //aktuelles Modell lesen
  Result:=Tools.Init2Single(length(fxMdl),length(fxMdl),0);
  for M:=2 to high(fxMdl) do
    for N:=1 to pred(M) do
    begin
      fRes:=0; //Vorgabe
      for I:=1 to high(fxMdl[0]) do //alle Merkmale
        fRes+=sqr(fxMdl[M,I]-fxMdl[N,I]); //Summe Quadrate
      Result[N,M]:=sqrt(fRes); //Hauptkomponente
      Result[M,N]:=Result[N,M]; //symmetrisch füllen
    end;
end;

{ rMV gibt den Mittelwert aller Kanäle aus "fxImg" zurück. rMV überprüft NoData
  in jedem Kanal. }

function tReduce.MeanValue(fxImg:tn3Sgl):tn2Sgl; //Vorbild: Mittelwert
var
  fRes:single=0; //Summe Werte in allen Kanälen
  iCnt:integer; //Anzahl gültiger Kanäle
  B,X,Y: integer;
begin
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
    begin
      fRes:=0; iCnt:=0;
      for B:=0 to high(fxImg) do
      begin
        if IsNan(fxImg[B,Y,X]) then continue;
        fRes+=fxImg[B,Y,X]; //Summe
        inc(iCnt) //Anzahl Summanden
      end;
      if iCnt>0
        then Result[Y,X]:=fRes/iCnt //Mittelwert
        else Result[Y,X]:=NaN;
    end;
end;

function tLimits._MaskLimit_(
  fMin:single; //Schwelle = kleinster zulässiger Wert
  fxBnd:tn2Sgl): //Vorbild
  tn2Byt; //Maske [0,1]
{ lML erzeugt mit der Schwelle "fMin" eine Maske ([0,1]-Kanal) aus einem
  scalaren Bild. }
var
  X,Y:integer;
begin
  Result:=Tools.Init2Byte(length(fxBnd),length(fxBnd[0])); //Maske
  for Y:=0 to high(fxBnd) do
    for X:=0 to high(fxBnd[0]) do
      if not isNan(fxBnd[Y,X]) then
        Result[Y,X]:=byte(fxBnd[Y,X]>=fMin); //Schwelle anwenden
end;

{ lE erzeugt Masken aus einem Kanal und speichert sie unter dem Namen des
  Befehls im Imalys-Verzeichnis. "sCmd" steuert die verwendete Methode. }

procedure tLimits._Execute_(
  fMin:single; //kleinster zulässiger Wert
  sCmd:string; //Befehl
  sImg:string); //Vorbild für Header
const
  cCmd = 'lE: Command not appropriate to call "limits": ';
var
  fxBnd:tn2Sgl; //Kanal
  ixMsk:tn2Byt=nil; //Ergebnis = Maske
  rHdr:trHdr; //gemeinsame Metadaten
begin
  //Result:=eeHme+cfMap;
  rHdr:=Header.Read(sImg); //gemeinsame Metadaten
  fxBnd:=Image.ReadBand(0,rHdr,sImg); //Kanal lesen
  if sCmd=cfLmt then ixMsk:=_MaskLimit_(fMin,fxBnd) else //Maske für Werte >= Null
    Tools.ErrorOut(cCmd+sCmd);
  Header.WriteThema(2,rHdr,'',eeHme+sCmd); //Maske als Klassen-Bild speichern
  Image.WriteThema(ixMsk,eeHme+sCmd); //Maske mit Klassen-Attribut
  Header.Clear(rHdr);
  Tools.HintOut('Limits.Execute: '+sCmd);
end;

function tReduce._SentinelQuality_(
  rFrm:trFrm; //Rahmen oder Vorgabe
  sImg:string; //Vorbild
  sMsk:string): //Sentinel-2 Maske im xml-Format
  tn2Byt;
begin
  Result:=nil; //leeren
  Gdal.Import(1,1,1,rFrm,sImg); //Import ohne Veränderung, Beschnitt
  Gdal.Rasterize(0,'OPAQUE',sImg,sMsk); //Polygone mit Null einbrennen
  Result:=Image.SkipMask(eeHme+cfMsk); //Maske aus Bild, Null für alle gültigen Werte
end;

function tReduce._LeafAreaIndex_(
  fxImg:tn3Sgl; //Vorbild
  iNir,iRed:integer): //Parameter
  tn2Sgl; //Vorbild: Vegetationsindex
{ rLA gibt eine Näherung für den Leaf Area Index als Kanal zurück. "iRed" und
  "iNir" müssen die Wellenländen von Rot und nahem Infrarot bezeichnen. Formel
  nach Yao et.al, 2017 }
const
  cDim = 'tFV: Vegetation index calculation needs two bands!';
var
  X,Y: integer;
begin
  if length(fxImg)<2 then Tools.ErrorOut(cDim);
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
      if not IsNan(fxImg[0,Y,X]) then
        Result[Y,X]:=exp((fxImg[iNir,Y,X]-fxImg[iRed,Y,X])/(fxImg[iNir,Y,X]+
          fxImg[iRed,Y,X])*0.08); //LAI-Näherung
end;

function tReduce._LeafAreaIndex(
  fxImg:tn3Sgl; //Vorbild
  iNir,iRed:integer): //Parameter
  tn2Sgl; //Vorbild: Vegetationsindex
{ rLA gibt eine Näherung für den Leaf Area Index als Kanal zurück. "iRed" und
  "iNir" müssen die Wellenländen von Rot und nahem Infrarot bezeichnen
  (vgl. Liu_2012 "LAI") }
//fEvi:=2.5 × (NIR − RED) / (1 + NIR + 6 × RED − 7.5 × GRN)
const
  cDim = 'tFV: Vegetation index calculation needs two bands!';
var
  fEvi:single;
  X,Y:integer;
begin
  if length(fxImg)<2 then Tools.ErrorOut(cDim);
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
      if not IsNan(fxImg[0,Y,X]) then
      begin
        fEvi:=2.5*(fxImg[iNir,Y,X]-fxImg[iRed,Y,X])/
          (fxImg[iNir,Y,X]+2.4*fxImg[iRed,Y,X]+1.0);
        Result[Y,X]:=-(1/0.273)*ln(1.102*(1.0-0.910*fEvi));
      end;
end;

{ rPc bestimmt die erste Hauptkomponente im Stack "fxImg" und gibt das Ergebnis
  als Kanal zurück. rPc prüft jeden Kanal auf NoData, so dass auch lückige
  Stacks verarbeitet werden können. }

function tReduce.Brightness(fxImg:tn3Sgl):tn2Sgl; //Vorbild: Erste Hauptkomponente
const
  cDim = 'tFP: A principal component needs more than one band';
var
  //fMin:single; //kleinster Wert in allen Kanälen
  fSed: double=0; //aktuelles Ergebnis
  B,X,Y: integer;
begin
  if (length(fxImg)<2) or (length(fxImg[0,0])<1) then
    Tools.ErrorOut(cDim);
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
    begin
      fSed:=0; //Vorgabe
      for B:=0 to high(fxImg) do //alle Kanäle
        if not IsNan(fxImg[B,Y,X]) then
          fSed+=sqr(fxImg[B,Y,X]);
      Result[Y,X]:=sqrt(fSed); //Länge im n-Raum
    end;
end;

{ rDt gibt die Distanz im Merkmalsraum zwischen zwei Kanälen zurück. Der Import
  muss GENAU zwei Kanäle enthalten. }

function tReduce.Distance(fxImg:tn3Sgl):tn2Sgl; //Vorbild, Distanz
const
  cBnd = 'fSD: Import images must have equal number of bands';
var
  X,Y:integer;
begin
  if length(fxImg)<>2 then Tools.ErrorOut(cBnd);
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN));
  for Y:=0 to high(Result) do
    for X:=0 to high(Result[0]) do
    begin
      if isNan(fxImg[0,Y,X]) then continue; //erstes Bild
      if isNan(fxImg[1,Y,X]) then continue; //zweites Bild
      Result[Y,X]:=fxImg[0,Y,X]-fxImg[1,Y,X]; //Differenz
    end;
end;

{ rOy überlagert alle definierten Pixel im Vorbild "fxImg" in einem Kanal. }

function tReduce.Overlay(fxImg:tn3Sgl):tn2Sgl; //Vorbilder: Mischung
var
  B,X,Y: integer;
begin
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
      for B:=0 to high(fxImg) do
        if not isNan(fxImg[B,Y,X]) then
          Result[Y,X]:=fxImg[B,Y,X]; //definierte Werte überlagern
end;

procedure tReduce.QuickSort(
  faDev:tnSgl; //unsortiertes Array
  iDim:integer); //gültige Stellen im Array
{ rQS sortiert das Array "fxDev" aufsteigend. Dazu vertauscht rQS Werte, bis
  alle Vergliche passen. rQS verwendet zu Beginn große Abstände zwischen den
  Positionen im Array und reduziert sie schrittweise. }
var
  fTmp:single; //Zwischenlager
  iFix:integer; //Erfolge
  iStp:integer; //Distanz zwischen Positionen
  B:integer;
begin
  if iDim<2 then exit; //nichts zu sortieren
  iStp:=round(iDim/2); //erster Vergleich = halbmaximale Distanz
  repeat
    iFix:=0; //Vorgabe
    for B:=iStp to pred(iDim) do
      if faDev[B]>faDev[B-iStp] then //große Werte nach vorne
      begin
        fTmp:=faDev[B-iStp];
        faDev[B-iStp]:=faDev[B];
        faDev[B]:=fTmp;
      end
      else inc(iFix);
      if iStp>1 then iStp:=round(iStp/2) //Distanz halbieren
  until iFix=pred(iDim); //alle Vergleiche richtig
end;

{ TODO: [Reduce.Median] könnte Masken suchen, deren Fehler sich ausschließen }

{ rMn bildet den Median aus allen übergebenen Kanälen. Dazu kopiert rMn alle
  Werte eines Pixels nach "fxDev", sortiert "fxDev" mit "QuickSort" und
  übernimmt den Wert in der Mitte der gültigen Einträge in "fxDev". rMn kopiert
  NoData Werte in den Bilddaten nicht nach "faDev" sondern reduziert mit "iDim"
  die gültigen Stellen in "faDev". }

function tReduce.Median(fxImg:tn3Sgl):tn2Sgl; //Vorbild: Median
const
  cDim = 'rMn: Less than three bands provided for median calculation';
var
  faDev:tnSgl=nil; //ein Pixel aus allen Kanälen
  iDim:integer; //Anzahl Kanäle
  B,X,Y: integer;
begin
  if length(fxImg)<3 then Tools.ErrorOut(cDim);
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  SetLength(faDev,length(fxImg)); //alle Kanäle
  for Y:=0 to high(fxImg[0]) do
  begin
    for X:=0 to high(fxImg[0,0]) do
    begin
      iDim:=0;
      for B:=0 to high(faDev) do
        if not isNan(fxImg[B,Y,X]) then
        begin
          faDev[iDim]:=fxImg[B,Y,X]; //Pixel-Stack
          inc(iDim)
        end;
      if iDim>2 then
      begin
        QuickSort(faDev,iDim); //ordnen
        Result[Y,X]:=faDev[trunc(iDim/2)] //median
      end;
    end;
    if Y and $FF=0 then write('.');
  end;
  write(#13)
end;

procedure tReduce.IndexSort(
  iaIdx:tnInt; //Indices der übergebenen Werte
  faVal:tnSgl); //Werte, unsortiert → sortiert
{ rIS sortiert das Array "faVal" absteigend. Dazu vertauscht rIS Werte und die
  mit dem Wert verknüpften Indices in "iaIdx" bis alle Vergliche passen. rIS
  verwendet zu Beginn große Abstände zwischen den Positionen im Array und
  reduziert sie schrittweise.
  ==> Werte statt Zeiger zu sortieren kann schneller sein, wenn die Werte klein
      und die Vorbereitung der Werte aufwändig ist.
  ==> vgl. Reduce.QuickSort }
var
  fVal:single; //Zwischenlager
  iFix:integer; //Erfolge
  iStp:integer; //Distanz zwischen Positionen
  iIdx:integer; //Zwischenlager
  B:integer;
begin
  //length(iaIdx)=length(faVal)?
  if length(iaIdx)<2 then exit; //nichts zu sortieren
  iStp:=round(length(iaIdx)/2); //erster Vergleich = halbmaximale Distanz
  repeat
    iFix:=0; //Vorgabe
    for B:=iStp to high(iaIdx) do
      if faVal[B]>faVal[B-iStp] then //große Werte nach vorne
      begin
        iIdx:=iaIdx[B-iStp];
        fVal:=faVal[B-iStp];
        iaIdx[B-iStp]:=iaIdx[B];
        faVal[B-iStp]:=faVal[B];
        iaIdx[B]:=iIdx;
        faVal[B]:=fVal;
      end
      else inc(iFix);
      if iStp>1 then iStp:=round(iStp/2) //Distanz halbieren
  until iFix=high(iaIdx); //alle Vergleiche richtig
end;

{ rV gibt den Near Infrared Vegetation Index als Kanal zurück. "iRed" und
  "iNir" müssen die Wellenländen von Rot und nahem Infrarot bezeichnen. }

function tReduce.Vegetation(
  fxImg:tn3Sgl; //Vorbild
  iNir,iRed:integer; //Parameter
  iTyp:integer): //Index-ID
  tn2Sgl; //Vorbild: Vegetationsindex
const
  cDim = 'rVn: Vegetation index calculation needs two bands!';
  cTyp = 'rVn: Undefined ID for vegetation index"';
var
  X,Y: integer;
begin
  if length(fxImg)<2 then Tools.ErrorOut(cDim);
  if (iTyp<0) or (iTyp>2) then Tools.ErrorOut(cTyp);
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
      if not IsNan(fxImg[0,Y,X]) then
        case iTyp of
          0: Result[Y,X]:=(fxImg[iNir,Y,X]-fxImg[iRed,Y,X])/(fxImg[iNir,Y,X]+
             fxImg[iRed,Y,X])*fxImg[iNir,Y,X]; //NIRv Vegetattionsindex
          1: Result[Y,X]:=(fxImg[iNir,Y,X]-fxImg[iRed,Y,X])/(fxImg[iNir,Y,X]+
             fxImg[iRed,Y,X]); //NDVI Vegetationsindex
          2: Result[Y,X]:=2.5*(fxImg[iNir,Y,X]-fxImg[iRed,Y,X])/
             (fxImg[iNir,Y,X]+2.4*fxImg[iRed,Y,X]+1.0); //EVI Vegetationsindex
        end;
end;

{ rID übersetzt einen Datums-String [YYYYMMDD] am Ende einer Dateinamens in
  Sekunden Systemzeit. Kann das Datum nict interpretiert werden, gibt rDI einen
  negativen Wert zurück. }

function tReduce.ImageDate(sImg:string):integer;
var
  iInt:integer; //für Format-Test
begin
  sImg:=RightStr(ChangeFileExt(sImg,''),8); //nur Datum [YYYYMMDD]
  if TryStrToInt(sImg,iInt) then
    Result:=trunc(EncodeDate(
      StrToInt(copy(sImg,1,4)),
      StrToInt(copy(sImg,5,2)),
      StrToInt(copy(sImg,7,2)))) //Integer(tDateTime)
  else Result:=-1; //Fehler gefunden
end;

{ rCD sucht in "slImg" nach Bildern mit gleichem Datum und verschiebt die
  Dateinamen in das Ergebnis. rCD gibt immer nur EIN Datum mit mehr als einem
  Bild zurück und kann widerholt aufgerufen werden bis alle Bilder von
  verschiedenen Tagen stammen. Dazu rCD sucht rCD nach Bildern die vom gleichen
  Tag stammen wie das erste und markiert sie durch eine Dummy-Adresse. Da mehr
  als zwei Bilder vom gleichen Tag stammen können, durchsucht lCD die gesamte
  Liste. }

function tReduce.CommonDate(
  slImg:tStringList): //WIRD REDUZIERT!
  tStringList; //passende Bilder ODER leer
var
  bSkp:boolean=False; //Suche beendet
  iTms:integer; //Datum Vorbild [Sekunden Systemzeit]
  I,K:integer;
begin
  Result:=tStringList.Create; //leere Liste
  if slImg.Count>1 then
  repeat
    for I:=pred(slImg.Count) downto 1 do //Referenz
    begin
      iTms:=ImageDate(slImg[I]);
      for K:=0 to pred(I) do //Vergleich, alle Kombinationen
        if ImageDate(slImg[K])=iTms then
        begin
          slImg.Objects[I]:=tObject($01); //Markierung setzten mit leerer Adresse
          slImg.Objects[K]:=tObject($01);
          bSkp:=True;
        end;
      if bSkp then break;
    end;
  until bSkp or (I=1);

  for I:=pred(slImg.Count) downto 0 do
    if slImg.Objects[I]=tObject($01) then
    begin
      Result.Add(slImg[I]); //Bilder mit gleichem Datum
      slImg.Delete(I) //markierte Bildnamen löschen
    end;
end;

{ TODO: [Reduce.BestOf] könnte auch dann die zwei Layer Regel anwenden, wenn
        einzelne Layer Löcher haben. Dazu müsste analog zu "faDev" ein "faQlt"
        Feld gefült werden, in das die QA-Indices ohne Lücken eingetragen
        werden. }

{ rBO übernimmt den "besten" Pixel aus einem beliebigen Stack. rBO kopiert alle
  definierten Werte eines Pixels nach "faDev". Sind mehr als 2 Werte definiert,
  sortiert rBO die Werte und übernimmt den Wert in der Mitte (Median). Bei zwei
  Werten bildet rBO den Mittelwert, wenn beide Bilder sehr wenig Fehler haben,
  andernfalls das "bessere" Bild. Ein Kanal wird unverändert übernommen. rBO
  füllt leere Bereiche mit NoData. }

function tReduce.BestOf(
  fxImg:tn3Sgl; //Vorbild
  sQap:string): //Qualitäts-Indices
  tn2Sgl; //Median
var
  bRnk:boolean=false; //
  fHig,fLow:single; //QA-Index für zweiten, ersten Layer
  faDev:tnSgl=nil; //ein Pixel aus allen Kanälen
  iDim:integer; //Anzahl Kanäle
  B,X,Y: integer;
begin
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  SetLength(faDev,length(fxImg)); //alle Kanäle

  if WordCount(sQap,[','])=2 then //Mittelwert oder Präfenz bei zwei Layern
  begin
    fHig:=StrToFloat(ExtractWord(2,sQap,[',']));
    fLow:=StrToFloat(ExtractWord(1,sQap,[',']));
    bRnk:=abs((fHig-fLow)/(fHig+fLow))>0.5;
  end;

  for Y:=0 to high(fxImg[0]) do
  begin
    for X:=0 to high(fxImg[0,0]) do
    begin
      iDim:=0;
      for B:=0 to high(faDev) do
        if not isNan(fxImg[B,Y,X]) then
        begin
          faDev[iDim]:=fxImg[B,Y,X]; //Pixel-Stack
          inc(iDim)
        end;
      if iDim>2 then
      begin
        QuickSort(faDev,iDim); //ordnen
        Result[Y,X]:=faDev[trunc(iDim/2)] //median
      end
      else if iDim>1 then
      begin
        if bRnk=False then
          Result[Y,X]:=(faDev[0]+faDev[1])/2 //Mittelwert
        else if fHig>fLow
          then Result[Y,X]:=faDev[1]
          else Result[Y,X]:=faDev[0]
      end
      else if iDim>0 then
        Result[Y,X]:=faDev[0] //erster Wert
      else Result[Y,X]:=NaN; //nicht definiert
    end;
  end;
end;

// bestimmt mittlere Qualität überlagerte Bilder

function tReduce.Quality(sQlt:string):single;
var
  I:integer;
begin
  Result:=0; //Vorgabe
  for I:=1 to WordCount(sQlt,[',']) do
    Result+=StrToFloat(ExtractWord(I,sQlt,[','])); //Summe aus Bildern
  if length(sQlt)>0
    then Result/=WordCount(sQlt,[',']) //mittlere Qualität
    else Result:=1; //Bilder notfalls verwenden
end;

{ rIS erweitert eine Zahl mit führenden Nullen auf "iSze" Stellen }

function tReduce.IntToStrSize(iInt,iSze:integer):string;
begin
  Result:=IntToStr(iInt);
  while length(Result)<iSze do
    Result:='0'+Result;
end;

{ rDI erzeugt aus der Liste mit Datums-Angaben in Header "tHdr.Dat" ein Array
  mit Zeitangaen in Sekunden Systemzeit. Bei multispektralen Bildern wiederholt
  rDI die Zeitangabe für jeden Kanal. Das Ergebnis hat ein Feld pro Kanal,
  unabhängig von der Zahl der Bilder. Wenn "tHdr.Dat" leer oder unvollständig
  ist gibt rDI ein Array aus fortlaufenden natürlichen Zahlen zurück. }

function tReduce.DateIndex(var rHdr:trHdr):tnInt;
const
  cSlc = 'rDI: At least two images must be selected!';
var
  bGap:boolean=False; //Lücken im Datum
  iPrd:integer; //
  iRes:integer; //Datum als Sekunden Systemzeit
  slImg:tStringList=nil;
  K,I:integer;
begin
  Result:=nil;
  iPrd:=max(rHdr.Prd,1); //Kanäle pro Bild
  try
    slImg:=tStringList.Create;
    slImg.AddCommaText(rHdr.Dat);
    Result:=Tools.InitInteger(slImg.Count*iPrd,0);
    for I:=0 to pred(slImg.Count) do
    begin
      iRes:=ImageDate(slImg[I]); //Datum als Systemzeit [s]
      if iRes<0 then bGap:=True; //Fehler!
      for K:=0 to pred(iPrd) do
        Result[I*iPrd+K]:=iRes; //gleiches Datum für Kanäle in einem Bild
    end;
    if bGap then
      for I:=0 to pred(slImg.Count) do
        slImg[I]:=IntToStr(succ(I)); //gleicher Abstand für alle Kanäle
  finally
    slImg.Free;
  end;
end;

{ rRg bestimmt die Regression aller Kanäle aus "fxImg" für einzelne Pixel und
  gibt sie als Bild zurück. rRg unterstellt, dass die Datei-Namen mit einem
  Datum enden. Ist das nicht der Fall, verwendet rRg gleiche Abstände zwischen
  allen Kanälen in der gegebenen Reihenfolge. rRg prüft jeden Kanal auf NoData,
  so dass auch lückige Bilder verarbeitet werden können. }
{ ==> Regression = (∑xy-∑x∑y/n) / (∑y²-(∑y)²/n); x=Zeit, y=Wert }

function tReduce.Regression(
  fxImg:tn3Sgl; //Vorbild
  var rHdr:trHdr): //Metadaten
  tn2Sgl; //Regression
var
  fDvs:double; //Dividend in Regressionsgleichung ← Nulldivision!
  fPrd:double; //Produkt aus Zeit und Wert (∑xy)
  fSqr:double; //Summe Werte-Quadrate (∑y²)
  fSum:double; //Summe Werte (∑y)
  fTms:double; //Summe Zeitachse (∑x)
  fVal:double; //aktueller Wert
  iaTms:tnInt=nil; //Datum in Sekunden Systemzeit
  iCnt:integer=0; //Anzahl gültiger Kanäle (n)
  B,X,Y: integer;
begin
  //mindestens 3 Kanäle?
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  iaTms:=DateIndex(rHdr); //Datum in Sekunden Systemzeit ← 31.536.000s/y
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
    begin
      fPrd:=0; fSqr:=0; fSum:=0; fTms:=0; fVal:=0; iCnt:=0;
      for B:=0 to high(fxImg) do
      begin
        fVal:=fxImg[B,Y,X];
        if IsNan(fVal) then continue;

        fTms+=iaTms[B]; //∑x
        fSum+=fVal; //∑y
        fPrd+=iaTms[B]*fVal; //∑xy
        fSqr+=sqr(fVal); //∑y²
        inc(iCnt) //Anzahl gültige Schritte
      end;
      if iCnt>0
        then fDvs:=fSqr-sqr(fSum)/iCnt
        else fDvs:=0;
      if fDvs>0
        then Result[Y,X]:=(fPrd-fTms*fSum/iCnt)/fDvs
        else Result[Y,X]:=NaN;
    end;
end;

{ rVc bestimmt die Varianz aller Layer in "fxImg" für einzelne Pixel und gibt
  sie als Bild zurück. rVc überprüft jeden Eingangs-Kanal auf NoData, so dass
  auch lückige Bilder verarbeitet werden können. }
{ Varianz = (∑x²-(∑x)²/n)/(n-1) }

function tReduce.Variance(fxImg:tn3Sgl):tn2Sgl; //Vorbild: Varianz
var
  fSqr:double; //Summe Werte-Quadrate (x²) ← maximale Genauigkeit
  fSum:double; //Summe Werte (∑x) ← maximale Genauigkeit
  iCnt:integer; //Anzahl gültiger Kanäle (n)
  B,X,Y: integer;
begin
  //mindestens 3 Kanäle?
  Result:=Tools.Init2Single(length(fxImg[0]),length(fxImg[0,0]),dWord(NaN)); //Vorgabe = NoData
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
    begin
      fSqr:=0; fSum:=0; iCnt:=0;
      for B:=0 to high(fxImg) do
      begin
        if IsNan(fxImg[B,Y,X]) then continue;
        fSum+=fxImg[B,Y,X];
        fSqr+=sqr(fxImg[B,Y,X]);
        inc(iCnt) //Anzahl gültige Schritte
      end;
      if iCnt>1
        then Result[Y,X]:=(fSqr-sqr(fSum)/iCnt)/pred(iCnt)
        else Result[Y,X]:=NaN;
    end;
end;

{ rEx reduziert ein Multikanal-Bild zu einem Kanal. Der Prozess wird durch die
  Konstante "sCmd" gewählt. Für die Vegetationsindices ist zusätzlich die ID
  des Kanals für ROT und NIR notwendig. "BestOf" benötigt die Anteile klarer
  Pixel im Bild aus dem Header. Für "Regression" müssen die Kanalnamen mit
  einem Datum enden und die Periode (Kanäle pro Bild ) im Header muss definiert
  sein. }

function tReduce.Execute(
  fxImg:tn3Sgl; //Vorbild, >1 Kanal
  iNir,iRed:integer; //Kanal-Indices NUR für Vegetationsindex
  sCmd:string; //Reduktions-Befehl (Konstante)
  var rHdr:trHdr): //Metadaten
  tn2Sgl; //Ergebnis
begin
  if sCmd=cfBst then Result:=BestOf(fxImg,rHdr.Qap) else //Median-Mean-Defined
  if sCmd=cfDff then Result:=Distance(fxImg) else //Euklidische Distanz
  if sCmd=cfLai then Result:=_LeafAreaIndex(fxImg,iNir,iRed) else //LAI-Näherung
  if sCmd=cfMdn then Result:=Median(fxImg) else //Median
  if sCmd=cfMea then Result:=MeanValue(fxImg) else //Mittelwert
  if sCmd=cfOvl then Result:=Overlay(fxImg) else //Überlagerung
  if sCmd=cfBrt then Result:=Brightness(fxImg) else //Hauptkomponente
  if sCmd=cfRgs then Result:=Regression(fxImg,rHdr) else //Regression
  if sCmd=cfNiv then Result:=Vegetation(fxImg,iNir,iRed,0) else //NirV Index
  if sCmd=cfNvi then Result:=Vegetation(fxImg,iNir,iRed,1) else //NDVI Index
  //if sCmd=cfEvi then Result:=_Vegetation(fxImg,iNir,iRed,2) else //EVI Index
  if sCmd=cfVrc then Result:=Variance(fxImg) else //Varianz
  begin end;
end;

{ rSc reduziert gestapelte multispektrale Bilder zu einem multispektralen Bild.
  Dabei reduziert rSc gleiche Kanäle aus verschiedenen Bildern mit dem Befehl
  "sCmd" zu jeweils einem Kanal und speichert die neuen Kanäle in der alten
  Reihenfolge unter dem Namen des Befehls. rSc mittelt das Datum in den Kanal-
  Namen. Alle Bilder im Stapel "sImg" müssen dieselben Kanäle haben. rSc liest
  und schreibt im ENVI-Format.
  ==> vgl. "xReduce" auf einen Kanal (Indices) }

procedure tReduce.xSplice(
  sCmd:string; //Prozess
  sImg:string; //Vorbild
  sTrg:string); //Ergebnis-Name ODER leer für Prozess-Name
const
  cFex = 'rSe: Image not found: ';
  cPrd = 'rSe: No period given for image splice: ';
var
  fxRes:tn2Sgl=nil; //Ergebnis-Kanal für aktuelle Gruppe
  fxStk:tn3Sgl=nil; //Kanäle aus Import mit gleicher Gruppen-Nr
  iRes:integer=-1; //aktueller Kanal, zu Beginn "-1" für neues Bild
  rHdr:trHdr; //Metadaten
  sBnd:string=''; //Kanal-Namen, durch LF getrennt
  B,I:integer;
begin
  if not FileExists(sImg) then Tools.ErrorOut(cFex+sImg);
  rHdr:=Header.Read(sImg);
  if rHdr.Prd<1 then Tools.ErrorOut(cPrd+sImg);
  if trim(sTrg)='' then sTrg:=eeHme+sCmd; //Vorgabe = Prozess-Name
  if rHdr.Prd<rHdr.Stk then //nur wenn mehr als ein Bild
  begin
    SetLength(fxStk,rHdr.Stk div rHdr.Prd,1,1); //Dummy, Ein Kanal für jedes Bild
    for B:=0 to pred(rHdr.Prd) do //alle Ergebnis-Kanäle
    begin
      for I:=0 to pred(rHdr.Stk div rHdr.Prd) do //alle Vorbilder
        fxStk[I]:=Image.ReadBand(I*rHdr.Prd+B,rHdr,sImg); //Kanal "B" aus Bild "I" laden
      fxRes:=Execute(fxStk,3,2,sCmd,rHdr); //multiplen Kanal reduzieren
      if B>0 then iRes:=B; //neues Bild (-1) oder neuer Kanal (I)
      Image.WriteBand(fxRes,iRes,sTrg); //Kanal schreiben
      sBnd+=ExtractWord(succ(B),rHdr.aBnd,[#10])+#10; //Kanal-Namen aus erstem Bild
      write(#13'Band '+IntToStr(succ(B))+' Image '+IntToStr(succ(I)));
    end;
    rHdr.Qap:=FloatToStrF(Quality(rHdr.Qap),ffFixed,7,3); //mittlere Qualität
    Header.WriteMulti(rHdr,sBnd,sTrg); //Kanal-Namen
  end
  else Tools.CopyEnvi(sImg,sTrg); //unverändert verwenden
  Header.Clear(rHdr);
  Tools.HintOut('Reduce.Splice: '+sCmd);
end;

{ TODO: [Reduce.xOverlay] könnte auch Bilder aus benachbarten Flugpfaden
        vereinigen, wenn die Aufnahmezeitpunkte nahe beieinander liegen }

{ rOy vereinigt Teilbilder, die am gleichen Tag aufgenommen wurden und löscht
  die Vorbilder. rOy prüft sukzessive ob die Liste "slImg" Bilder mit gleichem
  Datum enthält. Wenn ja, überlagert rOy die Teilbilder, speichert sie unter
  einem neuen Namen aus Sensor und Datum (ohne Kachel-ID) und löscht die
  Teilbilder. Gleichzeitig ersetzt rOy die Namen der Teilbilder in "slImg"
  durch das vereinigte Bild. Bilder mit gleichem Datum stammen aus einem
  Flugpfad. Sie sind identisch. }

procedure tReduce.xOverlay(slImg:tStringList); //WIRD REDUZIERT!
var
  slOvl:tStringList=nil; //Bilder mit gleichem Datum
  sTmp:string=''; //Zwischenlager
  I:integer;
begin
  if (slImg=nil) or (slImg.Count<1) then exit;
  repeat
    try
      slOvl:=CommonDate(slImg); //verschiebt Namen von "slImg" nach "slOvl"
      if slOvl.Count>0 then
      begin
        Image.StackImages(slOvl,eeHme+cfStk); //Kacheln in gemeinsamen Rahmen
        Reduce.xSplice(cfOvl,eeHme+cfStk,''); //gleiche Kanäle überlagern
        sTmp:=ExtractFilePath(slOvl[0])+LeftStr(ExtractFileName(slOvl[0]),5)+
          RightStr(ExtractFileName(slOvl[0]),8); //neuer Name
        Tools.EnviRename(eeHme+cfOvl,sTmp); //Sensor + Datum
        for I:=0 to pred(slOvl.Count) do
          Tools.EnviDelete(slOvl[I]); //Teilbilder löschen
        slImg.Add(sTmp); //Ergebnis übernehmen
      end
      else sTmp:=''; //Schalter
    finally
      FreeAndNil(slOvl);
    end;
  until sTmp='';
end;

{ rRe reduziert alle Kanäle in "sImg" auf einen Ergebnis-Kanal und speichert
  ihn unter dem Namen des Befehls "sCmd". "iNir" und "iRed" werden nur für den
  Vegetationsindex benötigt. }

procedure tReduce.xReduce(
  iNir,iRed:integer; //Kanäle für Vegetationsindex
  sCmd:string; //Befehl
  sImg:string; //Name des Vorbilds
  sTrg:string); //Name Ergebnis ODER leer
const
  cFex = 'rRe: Image not found: ';
var
  fxRes:tn2Sgl=nil; //Ergebnis der Reduktion
  fxStk:tn3Sgl=nil; //Stack zur Reduktion
  rHdr:trHdr; //Metadaten
begin
  if not FileExists(sImg) then Tools.ErrorOut(cFex+sImg);
  rHdr:=Header.Read(sImg);
  fxStk:=Image.Read(rHdr,sImg); //Import vollständig
  fxRes:=Execute(fxStk,iNir,iRed,sCmd,rHdr); //Befehl anwenden
  if trim(sTrg)='' then sTrg:=eeHme+sCmd; //Vorgane = Name des Befehls
  Image.WriteBand(fxRes,-1,sTrg); //neue Datei aus Ergebnis
  rHdr.Prd:=1; //nur ein Kanal
  rHdr.aBnd:=sCmd; //Kanal-Name = Prozess
  rHdr.Qap:=FloatToStrF(Quality(rHdr.Qap),ffFixed,7,3); //mittlere Qualität
  Header.WriteScalar(rHdr,sTrg); //Header für einen Kanal
  Tools.HintOut('Reduce.Execute :'+ExtractFileName(sTrg)); //Status
  Header.Clear(rHdr)
end;

{ mST klassifiziert die Probe "faSmp" mit dem Modell "fxMdl" und gibt die
  Klassen-ID zurück. mST klassifiziert mit (quadrierten) Distanzen im Merkmals-
  Raum. ST ignoriert
  Klassen aus dem Modell, wenn der Distanz-Radius überschritten wird. ST gibt
  die (quadrierte) Distanz zum Modell in "faSmp[0]" zurück. }

function tModel.SampleThema(
  faSmp:TnSgl; //Vorbild (Probe)
  fLmt:single; //Maxmum Distanz (quadriert)
  fxMdl:tn2Sgl): //spektrales Modell
  integer; //Klassen-ID
var
  fSed: single; //aktuelle Distanz (quadriert)
  pMdl: ^TnSgl; //Zeiger auf aktuelle Definition
  B,M: integer;
begin
  Result:=0; //Vorgabe
  for M:=1 to high(fxMdl) do //ohne Rückweisung
  begin
    pMdl:=@fxMdl[M]; //Verweis
    fSed:=0;
    for B:=1 to high(faSmp) do
      fSed+=sqr(pMdl^[B]-faSmp[B]); //Summe quadrierte Distanzen
    if fSed<fLmt then //beste Anpassung
    begin
      Result:=M;
      fLmt:=fSed;
    end;
  end;
end;

{ mFC klassifiziert die scalaren Attribute aller Zonen mit dem Modell "fxMdl"
  und gibt als Ergebnis ein Zonen-Attribut mit allen Klassen zurück. Das erste
  Attribut "fxMdl[?,0]" kann ein Gewicht oder ein Radius sein. Alle anderen
  sind "normale" Merkmale der Zonen. mFC unterstellt, dass die erste Klasse in
  "fxMdl" eine leere Rückweisung ist. }

function tModel.ZonesClassify(fxMdl:tn2Sgl):tnInt; //Klassen-Attribut
const
  cMdl = 'tMFC: no feature model given!';
var
  faSmp: TnSgl=nil; //Zellmerkmale als Array
  fxAtr: Tn2Sgl=nil; //Feature-Kombination der Zelle "Z"
  B,Z: integer;
begin
  Result:=nil;
  if fxMdl=nil then Tools.ErrorOut(cMdl);
  fxAtr:=Tools.BitRead(eeHme+cfAtr); //Attribut-Tabelle lesen
  Result:=Tools.InitInteger(length(fxAtr[0]),0); //alle Zonen incl. Null
  faSmp:=Tools.InitSingle(length(fxMdl[0]),0); //alle Attribute incl. Gewicht
  for Z:=1 to high(fxAtr[0]) do //alle Zonen
  begin
    for B:=1 to high(faSmp) do
      faSmp[B]:=fxAtr[pred(B),Z]; //Merkmale einer Zone
    Result[Z]:=SampleThema(faSmp,MaxSingle,fxMdl); //Klasse
  end; //for Z ..
  Tools.HintOut('Model.FeatureClassify: '+IntToStr(length(Result)));
end;

{ mAS gibt "iSmp" Stichproben aus der Attribut-Tabelle zurück, die zufällig
  über den Zonen-Index verteilt sind. Dazu wählt mAS einzelne Pixel im Index
  und gibt die Attribute und die Fläche der entsprechenden Zone zurück. Die
  Samples sind dabei geographisch gleichmäßig verteilt. Große Zonen können mehr
  als einmal getroffen sein. Das Ergebnis enthält im Index Null eine leere
  Rückweisungsklasse. Die Stichproben enthalten im Index 1..N die Attribute der
  Zonen, im Index Null die Fläche der Zone in Pixeln. }

function tModel.ZonesSamples(
  iSmp: integer): //Anzahl Stichproben
  tn2Sgl; //Stichproben[Probe][Merkmale]
const
  cSmp = 'tMAS: Amount of samples must be greater than 1!';
var
  fxAtr:Tn2Sgl=nil; //spektrale Attribute
  iaSze:tnInt=nil; //Zonen-Größe in Pixeln
  ixIdx:Tn2Int=nil; //Zellindex (Zeiger auf fxTmp[0])
  rHdr:trHdr; //Metadaten
  B,R,X,Y:integer;
begin
  Result:=nil;
  if iSmp<2 then Tools.ErrorOut(cSmp);
  rHdr:=Header.Read(eeHme+cfIdx); //Metadaten
  ixIdx:=tn2Int(Image.ReadBand(0,rHdr,eeHme+cfIdx)); //Zonen-IDs
  iaSze:=Tools.InitInteger(succ(rHdr.Cnt),0); //Vorgabe = leer
  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
      inc(iaSze[ixIdx[Y,X]]); //Pixel pro Zone

  fxAtr:=Tools.BitRead(eeHme+cfAtr); //Attribut-Tabelle lesen
  Result:=Tools.Init2Single(succ(iSmp),succ(length(fxAtr)),0); //leere Liste
  RandSeed:=cfRds; //Zufalls-Generator initialisieren
  for R:=1 to iSmp do //alle Beispiele, Null für Rückweisung
  begin
    repeat
      Y:=random(length(ixIdx));
      X:=random(length(ixIdx[0]))
    until (ixIdx[Y,X]>0); //nur definierte Orte
    for B:=1 to length(fxAtr) do
      Result[R,B]:=fxAtr[pred(B),ixIdx[Y,X]]; //Merkmale
    Result[R,0]:=iaSze[ixIdx[Y,X]]; //Zonen-Fläche in Pixeln
    iaSze[ixIdx[Y,X]]:=0; //Fläche nur einmal zählen
  end;
  Header.Clear(rHdr);
  Tools.HintOut('Model.AttributeSamples: '+IntToStr(iSmp));
end;

{ mMS wählt "iMap"+1 Proben aus der Stichproben-Liste "fxSmp" und gibt sie als
  Klassen-Vorläufer zurück. Die erste Klasse ist leer, das erste Merkmal die
  Fläche der Probe. }

function tModel.ModelSelect(
  fxSmp:tn2Sgl; //Stichproben-Liste
  iMap:integer): //Anzahl Klassen ohne Rückweisung
  tn2Sgl; //Klassen-Vorläufer
var
  iSlc:integer; //zufällige Auswahl
  F,M:integer;
begin
  Result:=Tools.Init2Single(succ(iMap),length(fxSmp[0]),0); //leer
  for M:=1 to iMap do
  begin
    iSlc:=Random(succ(high(fxSmp))); //zufällige Auswahl
    for F:=0 to high(fxSmp[0]) do
      Result[M,F]:=fxSmp[iSlc,F];
  end;
end;

{ mSC klassifiziert die Feature-Liste "fxSmp" mit den Klassen "fxMdl" und gibt
  das Ergebnis als Attribut für "fxSmp" zurück. mSC klassifiziert nach den
  kleinsten Distanzen im n-dimensionalen Merkmalsraum. }

function tModel.SampleClassify(
  fxMdl:tn2Sgl; //Klassen-Definitionen
  fxSmp:tn2Sgl): //Merkmals-Liste
  tnInt; //Klassen-IDs für "fsSmp"
var
  faSed:tnSgl=nil; //kleinste Distanz im Test
  fSed:single; //aktuelle quadrierte Distanz
  F,M,S:integer;
begin
  //high(fxMdl[0])=high(fxSmp[0])?
  Result:=Tools.InitInteger(length(fxSmp),0); //leer
  faSed:=Tools.InitSingle(length(fxSmp),dWord(single(MaxSingle)));
  for S:=1 to high(fxSmp) do //Rückweisung ignorieren
    for M:=1 to high(fxMdl) do //so
    begin
      fSed:=0;
      for F:=1 to high(fxMdl[0]) do //Fläche ignorieren
        fSed+=sqr(fxMdl[M,F]-fxSmp[S,F]); //quadrierte Distanz
      if fSed<faSed[S] then
      begin
        Result[S]:=M; //aktuelle Klasse
        faSed[S]:=fSed //neue Schwelle
      end;
    end;
end;

{ mCD zählt die Unterschiede zwischen den Arrays "iaBck" und "iaThm" }

function tModel.CountDiff(iaBck,iaThm:tnInt):integer;
var
  I:integer;
begin
  Result:=0;
  for I:=0 to high(iaBck) do
    if iaBck[I]<>iaThm[I] then inc(Result);
end;

{ nMA bestimmt neue Werte für die Klassen-Definitionen in "fxMdl". Dazu muss in
  "iaThm" eine Klassifikation von "fxSmp" übergeben werden. nMA summiert die
  Merkmale aller klassifizierten Proben aus "fxSmp" und gewichtet die Werte mit
  der Fläche der Proben. Die neuen Werte von "fxMdl" sind das gewchtete Mittel
  aller klassifizierten Proben. }

procedure tModel.ModelAdjust(
  fxMdl:tn2Sgl; //Klassen-Modell
  fxSmp:tn2Sgl; //Stichproben
  iaThm:tnInt); //Klassen-Attribut zu "fxSmp"
var
  pM:^tnSgl;
  F,M,S:integer;
begin
  for M:=0 to high(fxMdl) do
    FillDWord(fxMdl[M,0],length(fxMdl[0]),0); //leeren
  for S:=1 to high(fxSmp) do
  begin
    pM:=@fxMdl[iaThm[S]]; //aktuelle Klasse
    for F:=1 to high(fxMdl[0]) do
      pM^[F]+=fxSmp[S,F]*fxSmp[S,0]; //Merkmal*Fläche summieren
    pM^[0]+=fxSmp[S,0]; //Fläche summieren
  end;
  for M:=1 to high(fxMdl) do
    if fxMdl[M,0]>0 then
      for F:=1 to high(fxMdl[0]) do
        fxMdl[M,F]/=fxMdl[M,0]; //durch Fläche teilen
end;

{ mSM klassifiziert eine Liste mit Stichproben und gibt das Ergebnis als Matrix
  zurück. Das erste Element der Matrix ist eine leere Rückweisungs-Klasse. Das
  erste Merkmal aller Klassen ist die Fläche der Klasse in Pixeln.
    mSM nimmt "iMap" Proben aus der Liste "fxSmp", klassifiziert mit ihnen die
  Liste und bildet neue Klassen aus den Merkmalen der klassifizierten Proben.
  Die neuen Merkmale entsprechen dem Mittelwert aller Proben und ihrer Fläche.
  mSM wiederholt den Prozess bis die Klassifikation konstant ist. }

function tModel.SampleModel(
  fxSmp:tn2Sgl; //Stichproben
  iMap:integer; //Anzahl Klassen ohne Rückweisung
  sRes:string): //Dateiname für Modell
  tn2Sgl; //Klassen-Definition aus Stichproben
var
  iaBck:tnInt=nil; //Klassen-Attribut alte Version
  iaThm:tnInt=nil; //Klassen-Attribut
  iMdf:integer; //Veränderungen im Klassen-Attribut
begin
  Result:=ModelSelect(fxSmp,iMap); //Auswahl aus Stichproben
  SetLength(iaBck,length(fxSmp)); //Speicher
  SetLength(iaThm,length(fxSmp)); //so
  repeat
    move(iaThm[0],iaBck[0],length(iaThm)*SizeOf(integer)); //alter Stand
    iaThm:=SampleClassify(Result,fxSmp); //Klassen-Attribut
    iMdf:=CountDiff(iaBck,iaThm); //Veränderungen zählen
    ModelAdjust(Result,fxSmp,iaThm); //Klassen neu einstellen
    write(#13+IntToStr(iMdf));
  until iMdf<3;
  Tools.BitWrite(Result,eeHme+cfMdl); //als BIT-Tabelle speichern
  write(#13); //zurück
end;

procedure tModel.ThemaLayer(
  iMap:integer; //Anzahl Klassen ohne Rückweisung
  ixMap:tn2Byt;
  sImg:string);
var
  rHdr:trHdr; //Metadaten
begin
  //Rank.SortByte(iFtr,ixMap); //Klassen-ID nach Fläche
  Image.WriteThema(ixMap,eeHme+cfMap); //
  rHdr:=Header.Read(sImg); //Vorbild (nur Geometrie)
  Header.WriteThema(iMap,rHdr,'',eeHme+cfMap); //umwadeln und speichern
  Header.Clear(rHdr);
end;

{ mZM klassifiziert Zonen mit ihren Attributen und gibt das Ergebnis als
  Klassen-Layer zurück. Zonen, Attribute und Topologie müssen im Arbeits-
  Verzeichnis stehen.
    mZM nimmt "iSmp" Proben aus den aktuellen Zonen, analysiert die lokale
  Dichte der Proben im Merkmalsraum und fasst lokale Schwerpunkte zu Klassen
  zusammen. Der Einfluss einzelner Proben auf die Klassen entspricht ihrer
  Fläche. Mit diesen Klassen klassifiziert mZM alle Zonen und speichert das
  Ergebnis als Raster-Layer mit zufälligen Paletten-Farben. Bei Klassen und
  Proben ist das erste Element die Rückweisung, das erste Merkmal die Fläche
  der Zone bzw Klasse. }

procedure tModel.xZonesMap(
  iMap:integer; //Anzahl Klassen
  iSmp:integer; //Anzahl Stichproben
  sImg:string); //Vorbild (nur für Geometrie)
const
  cFex = 'mZM: Image not found: ';
  cMap = 'fFc: Number of fabric classes must exeed 2!';
  cSmp = 'fFc: Number of fabric samples must exeed 1000!';
var
  fxMdl:tn2Sgl=nil; //Klassen
  fxSmp:tn2Sgl=nil; //Stichproben → Klassen-Definition
  ixMap:tn2Byt=nil; //Klassen-Layer
  iaThm:tnInt=nil; //KLassen-Attribut
 begin
  if not FileExists(sImg) then Tools.ErrorOut(cFex+sImg);
  if iMap<2 then Tools.ErrorOut(cMap);
  if iSmp<1000 then Tools.ErrorOut(cSmp);
  Build.CheckZones('mZm: '); //Zonen vollständig?
  fxSmp:=ZonesSamples(iSmp); //Zonen-Stichproben
  fxMdl:=SampleModel(fxSmp,iMap,eeHme+cfMdl); //Klassen-Definitionen aus Proben
  iaThm:=Model.ZonesClassify(fxMdl); //Klassen-Attribut für alle Zonen
  ixMap:=Build.ThemaImage(iaThm); //Klassen-Layer
  ThemaLayer(iMap,ixMap,sImg); //Klassen-Layer
  Tools.HintOut('Model.ZonesMap: '+cfMap)
end;

{ mIS gibt "iSmp" Stichproben aus den Bilddaten zurück, die zufällig über die
  Bildfläche verteilt sind. Dazu wählt mIS mit einem Zufalls-Generator einzelne
  Pixel im Bild und gibt die Werte aller Kanäle des Pixels als Array zurück.
  Die Proben sind lineare Arrays. Array[0] nimmt die Fläche auf. }

function tModel.PixelSamples(
  iSmp: integer; //Anzahl Stichproben
  sImg: string): //Vorbild (ENVI-Format)
  Tn2Sgl; //Stichproben[Probe][Merkmale]
const
  cSmp = 'tMAS: Amount of samples must be greater than 1!';
var
  fxImg: tn3Sgl=nil; //Bilddaten, alle Kanäle
  rHdr: trHdr; //Metadaten
  B,S,X,Y: integer;
begin
  Result:=nil;
  if iSmp<2 then Tools.ErrorOut(cSmp);
  rHdr:=Header.Read(sImg); //Metadaten
  fxImg:=Image.Read(rHdr,sImg); //Bild mit allen Kanälen
  Result:=Tools.Init2Single(succ(iSmp),succ(length(fxImg)),0); //Merkmale-Liste
  RandSeed:=cfRds; //Reihe zurückstellen
  for S:=1 to high(Result) do //Proben ohne Rückweisung
  begin
    repeat
      Y:=random(rHdr.Lin);
      X:=random(rHdr.Scn)
    until not isNaN(fxImg[0,Y,X]); //nur definierte Orte
    for B:=0 to high(fxImg) do
      Result[S,succ(B)]:=fxImg[B,Y,X]; //Dichte-Kombination,
    Result[S,0]:=1; //Fläche = 1 Pixel
  end;
  Header.Clear(rHdr);
  Tools.HintOut('Model.Samples: '+IntToStr(iSmp));
end;

{ mIC klassifiziert die spektralen Attribute aller Pixel in "sImg" mit dem
  Modell "fxMdl" und gibt das Ergebnis als Byte-Matrix zurück. mIC
  klassifiziert nach dem Prinzip des "minimum distance" im Merkmalsraum. }

function tModel.PixelClassify(
  fxMdl:tn2Sgl; //Klassen-Vorbild
  sImg:string): //Vorbild (ENVI-Format)
  tn2Byt; //Klassifikation als Bild
const
  cMdl = 'tMIC: No density model given!';
var
  fSed:single; //quadrierte Distanz
  fxImg:Tn3Sgl=nil; //Vorbild mit allen Kanälen
  fxSed:tn2Sgl=nil; //Minimum Distanz
  rHdr:trHdr; //Metadaten
  B,M,X,Y:integer;
begin
  Result:=nil;
  if fxMdl=nil then Tools.ErrorOut(cMdl);
  rHdr:=Header.Read(sImg); //Metadaten
  fxImg:=Image.Read(rHdr,sImg); //Bild mit allen Kanälen
  Result:=Tools.Init2Byte(rHdr.Lin,rHdr.Scn); //Klassen-Ergebnis
  fxSed:=Tools.Init2Single(rHdr.Lin,rHdr.Scn,dWord(single(MaxSingle)));
  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
      if not IsNan(fxImg[0,Y,X]) then //nur definierte Pixel
        for M:=1 to high(fxMdl) do
        begin
          fSed:=0;
          for B:=0 to high(fxImg) do
            fSed+=sqr(fxImg[B,Y,X]-fxMdl[M,succ(B)]);
          if fSed<fxSed[Y,X] then
          begin
            Result[Y,X]:=M;
            fxSed[Y,X]:=fSed
          end;
        end;
  Header.Clear(rHdr);
  Tools.HintOut('Model.ImageClassify: '+IntToStr(length(fxMdl)));
end;

{ TODO: [Model.xImageMap] und "xZonesMap" sind fast identisch. }

{ mZM klassifiziert Pixel mit ihren Spektralkombinationen und gibt das Ergebnis
  als Klassen-Layer zurück.
    mZM nimmt "iSmp" Proben aus dem übergebeben Bild, analysiert die lokale
  Dichte der Proben im Merkmalsraum und fasst lokale Schwerpunkte zu Klassen
  zusammen. Der Einfluss einzelner Proben auf die Klassen entspricht ihrer
  Häufigkeit. Mit diesen Klassen klassifiziert mZM alle Pixel und speichert das
  Ergebnis als Raster-Layer mit zufälligen Paletten-Farben. Bei Klassen und
  Proben ist das erste Element die Rückweisung, das erste Merkmal die Fläche
  der Zone bzw Klasse. }

procedure tModel.xImageMap(
  iMap:integer; //Anzahl Klassen
  iSmp:integer; //Anzahl Stichproben
  sImg:string); //Vorbild (nur für Geometrie)
const
  cFex = 'mZM: Image not found: ';
  cMap = 'fFc: Number of fabric classes must exeed 2!';
  cSmp = 'fFc: Number of fabric samples must exeed 1000!';
var
  fxMdl:tn2Sgl=nil; //Klassen
  fxSmp:tn2Sgl=nil; //Stichproben → Klassen-Definition
  ixMap:tn2Byt=nil; //Klassen-Layer
begin
  if not FileExists(sImg) then Tools.ErrorOut(cFex+sImg);
  if iMap<2 then Tools.ErrorOut(cMap);
  if iSmp<1000 then Tools.ErrorOut(cSmp);
  Image.AlphaMask(sImg); //NoData-Maske auf alle Kanäle ausdehnen
  fxSmp:=PixelSamples(iSmp,sImg); //Stichproben aus Bilddaten
  fxMdl:=SampleModel(fxSmp,iMap,eeHme+cfMdl); //Klassen aus Stichproben
  ixMap:=PixelClassify(fxMdl,sImg); //Klassen-Matrix aus Bilddaten
  ThemaLayer(iMap,ixMap,sImg); //Klassen-Layer
  Tools.HintOut('Model.ZonesMap: '+cfMap)
end;

{ fDK gibt ein zweischichtiges Key-Array für die Zone "iIdx" zurück. Solche
  Key-Arrays enthalten neben den Kontakten der zentralen Zone auch alle
  Kontakte der Nachbarzonen. Durch die Zählweise sind die Kontakte der
  zentralen Zone vedoppelt. Die Summe aller Kontakte ist normalisiert. }

procedure tFabric.DoubleKey(
  iIdx:integer; //Zell-ID
  pSmp:tnSgl); //Zeiger auf Probe
var
  M,N:integer;
begin
  //pSmp^ muss leer sein
  for N:=iacDim[pred(iIdx)] to pred(iacDim[iIdx]) do
    for M:=iacDim[pred(iacNbr[N])] to pred(iacDim[iacNbr[N]]) do
      pSmp[0]+=iacPrm[M]; //Anzahl Kontakte incl. Nachbarn = "Gewicht"
  for N:=iacDim[pred(iIdx)] to pred(iacDim[iIdx]) do
    for M:=iacDim[pred(iacNbr[N])] to pred(iacDim[iacNbr[N]]) do
      pSmp[iacMap[iacNbr[M]]]+=iacPrm[M]/pSmp[0]; //normalisierte Kontakte incl. Nachbarn
end;

{ fSK gibt ein Array mit der Häufigkeit der Kontakte der Zone "iIdx" zurück.
  fSK zählt innere und äußere Kontakte ohne Unterschied. Die Werte sind auf
  Eins normalisiert. }

procedure tFabric.SingleKey(
  iIdx: integer; //Zell-ID
  pSmp: tnSgl); //Zeiger auf Probe
var
  N: integer;
begin
  //pSmp muss leer sein
  for N:=iacDim[pred(iIdx)] to pred(iacDim[iIdx]) do
    pSmp[0]+=iacPrm[N]; //Anzahl Kontakte = "Gewicht"
  for N:=iacDim[pred(iIdx)] to pred(iacDim[iIdx]) do
    pSmp[iacMap[iacNbr[N]]]+=iacPrm[N]/pSmp[0]; //normalisierte Kontakte
end;

{ fCK klassifiziert alle Zonen mit dem Modell "fxKey" und gibt das Ergebnis als
  Array mit Klassen-IDs zurück. fCK klassifiziert mit dem Anteil der Kontakte
  zwischen den Zonen. Mit "bDbl=True" verwendet fCK zweischichtige Kontakte. }

function tFabric.FabricClassify(
  bDbl:boolean; //extended Links
  fxKey:tn2Sgl): //Key-Modell
  TnInt; //Klassen-Attribut (Key-basiert)
const
  cTpl = 'tFFC: Cell topology required! (intern)';
var
  faSmp: TnSgl=nil; //Feature-Kombination für Zone "Z"
  Z: integer;
begin
  Result:=nil;
  if iacDim=nil then Tools.ErrorOut(cTpl);
  Result:=Tools.InitInteger(length(iacDim),0); //Klassen-Attribut
  faSmp:=Tools.InitSingle(length(fxKey[0]),0); //Vorgabe
  for Z:=1 to high(iacDim) do //Keys für alle Zonen
  begin
    FillDWord(faSmp[0],length(faSmp),0);
    if bDbl
      then DoubleKey(Z,faSmp) //große Umgebung
      else SingleKey(Z,faSmp);
    Result[Z]:=Model.SampleThema(faSmp,MaxSingle,fxKey); //Klasen
  end; //for Z ..
end;

{ fKS gibt "iSmp" Key-Samples zurück, die zufällig über das Bild verteilt sind.
  Dazu wählt fKS mit einem Zufalls-Generator einzelne Pixel im Bild und gibt
  die Kontakte der entsprechenden Zone zurück. Die Verteilung der Samples ist
  damit geographisch normal. "Result[?,0]" enthält die Anzahl der Kontakte. Die
  Topologie muss geladen sein! Große Zonen können mehr als einmal getroffen
  sein.
  ==> DIE GLOBALEN ZONEN-VARIABLEN MÜSSEN GELDEN SEIN }

function tFabric.FabricSamples(
  bDbl: boolean; //Double-Layer Models verwenden
  iMap: integer; //Anzahl Feature-Klassen
  iSmp: integer): //Anzahl Stichproben
  Tn2Sgl; //Stichproben
const
  cMap = 'fKS: Zonal classes must be defined!';
  cTpl = 'fKS: Zonal topology must exist!';
var
  ixIdx: Tn2Int=nil; //Zellindex
  rHdr: trHdr; //Metadaten
  R,X,Y: integer;
begin
  //iSmp,iMap sind überprüft
  Result:=nil;
  if (iacDim=nil) or (iacNbr=nil) or (iacPrm=nil) then Tools.ErrorOut(cTpl);
  if iacMap=nil then Tools.ErrorOut(cMap);
  Result:=Tools.Init2Single(succ(iSmp),succ(iMap),0); //Stichproben
  rHdr:=Header.Read(eeHme+cfIdx); //Zellindex-Metadaten
  ixIdx:=tn2Int(Image.ReadBand(0,rHdr,eeHme+cfIdx)); //Zellindex
  RandSeed:=cfRds; //neu initialisieren ==> gleiche Proben wie spekral
  for R:=1 to high(Result) do
  begin
    repeat
      Y:=random(rHdr.Lin);
      X:=random(rHdr.Scn)
    until ixIdx[Y,X]>0; //nur definierte Orte
    if bDbl
      then DoubleKey(ixIdx[Y,X],Result[R])
      else SingleKey(ixIdx[Y,X],Result[R]);
  end;
  Header.Clear(rHdr);
end;

{ fFM klassifiziert alle Zonen mit der Häufigkeit der Zonen-Kontakte und
  speichert das Ergebnis als Klassen-Layer "mapping". Die Zonen müssen im
  Arbeitsverzeichnis gespeichert sein.
    fFM erzeugt zunächst wie "Model.ZonesMap" ein Klassen-Attribut für alle
  Zonen. Im zweiten Schritt bestimmt fFM die Häufigkeit der Kontakte = Pixel-
  Grenzen zwischen den verschiedenen Klassen und klassifiziert diese Verteilung
  ein zweites Mal. fFM erfasst auch alle Kontakte innerhalb einer Zone, so dass
  große und/oder kompakte Zonen von den inneren Kontakten dominiert werden.
  Häufige räumliche Kombinationen bilden Muster-Klassen. }

procedure tFabric.xFabricMap(
  bDbl:boolean; //Extended Links
  iFbr:integer; //Anzahl Key-Klassen
  iSmp:integer); //Anzahl Stichproben
const
  cFbr = 'fFc: Number of fabric classes must exeed 2!';
  cSmp = 'fFc: Number of fabric samples must exeed 1000!';
var
  fxMdl:tn2Sgl=nil; //Klassen aus Zonen-Attributen
  fxSmp:tn2Sgl=nil; //Stichproben aus Zonen
  iaFbr:tnInt=nil; //Klassen-Attribut
  ixThm:tn2Byt=nil; //Cell-Objekt-Klassen als Bild
  rHdr:trHdr; //Metadaten aus Zellindex
begin
  if iFbr<2 then Tools.ErrorOut(cFbr);
  if iSmp<1000 then Tools.ErrorOut(cSmp);
  Build.CheckZones('fFM'); //Zonen vollständig?
  fxSmp:=Model.ZonesSamples(iSmp); //Zonen-Stichproben
  fxMdl:=Model.SampleModel(fxSmp,iFbr,eeHme+cfMdl); //Klassen-Definitionen aus Proben
  iacMap:=Model.ZonesClassify(fxMdl); //Klassen-Attribut für alle Zonen
  iacDim:=tnInt(Tools.BitExtract(0,eeHme+cfTpl));
  iacNbr:=tnInt(Tools.BitExtract(1,eeHme+cfTpl));
  iacPrm:=tnInt(Tools.BitExtract(2,eeHme+cfTpl));
  fxSmp:=FabricSamples(bDbl,iFbr,iSmp); //Key-Modell erzeugen
  fxMdl:=Model.SampleModel(fxSmp,iFbr,eeHme+cfKey); //Key-Definitionen aus Proben
  iaFbr:=FabricClassify(bDbl,fxMdl); //alle Zonen mit Keys klassifizieren
  ixThm:=Build.ThemaImage(iaFbr); //Bild aus Klassen-Attribut
  rHdr:=Header.Read(eeHme+cfIdx); //Geometrie aus Index
  Header.WriteThema(iFbr,rHdr,'',eeHme+cfMap); //Klassen-Header
  Image.WriteThema(ixThm,eeHme+cfMap); //Klassen als Bild
  SetLength(iacDim,0);
  SetLength(iacMap,0);
  SetLength(iacNbr,0);
  SetLength(iacPrm,0);
  Header.Clear(rHdr);
end;

{ lSZ vergibt einen negative ID an alle Zonen, die weniger als "iMin" innere
  Kontakte haben. Dazu verwendet lSZ ausschließlich die Topologie-Tabelle.
  lSZ gibt das Ergebnis in "iaFix" und die Zahl der markierten Zonen als
  Funktionswert zurück. "iaFix" muss mit allen aktuellen IDs incl. Null als
  fortlaufende Reihe initialisiert sein. }

function tLimits.SieveZones(
  iaFix:tnInt; //negatives Vorzeichen für Zonen mit zu wenig inneren Kontakten
  iMin:integer; //Minimum interne Kontakte
  ixTpl:tn2Int): //Zonen-Topologie
  integer; //Anzahl kleine Zonen
var
  iaDim:tnInt=nil; //Index auf "iacNbr, iacPrm"
  iaNbr:tnInt=nil; //Index der Nachbarzelle
  iaPrm:tnInt=nil; //Kontakte zur Nachbarzelle
  iLnk:integer; //innere Kontakte
  N,Z:integer;
begin
  Result:=0;
  iaDim:=ixTpl[0]; //Zeiger auf Startadressen
  iaNbr:=ixTpl[1]; //Zeiger auf IDs der Nachbarzellen
  iaPrm:=ixTpl[2]; //Zeiger auf Kontakte zu Nachbarzellen

  for Z:=1 to high(iaDim) do //alle Zonen
  begin
    iLnk:=0; //Vorgabe = keine inneren Grenzen
    for N:=iaDim[pred(Z)] to pred(iaDim[Z]) do //alle Kontakte (auch innere)
      if iaNbr[N]=Z then
        iLnk:=iaPrm[N];
    if iLnk<iMin then
    begin
      iaFix[Z]:=-iaFix[Z]; //kleine Zone = negativ
      inc(Result) //Veränderungen zählen
    end;
  end;
end;

{ lMZ sucht zu jeder Zone mit negativer ID eine Zone mit positiver ID und der
  höchsten Zahl an Kontakten. Findet lMZ eine solche Zone, übernimmt lMZ die
  ID der Nachbar-Zone auch für die aktuelle. lMZ verwendet dafür ausschließlich
  die Topologie-Tabelle. Die Suche muss nicht in jedem Fall Erfolg haben. Das
  Ergebnis kann negative IDs enthalten! }

procedure tLimits.MergeZones(
  ixTpl:tn2Int; //Zonen-Topologie
  iaFix:tnInt); //Zonen-IDs, negativ für kleine Zonen
var
  iaDim:tnInt=nil; //Index auf "iacNbr, iacPrm"
  iaNbr:tnInt=nil; //Index der Nachbarzelle
  iaPrm:tnInt=nil; //Kontakte zur Nachbarzelle
  iPrm:integer; //Anzahl Kontakte
  N,Z:integer;
begin
  iaDim:=ixTpl[0]; //Zeiger auf Startadressen
  iaNbr:=ixTpl[1]; //Zeiger auf IDs der Nachbarzellen
  iaPrm:=ixTpl[2]; //Zeiger auf Kontakte zu Nachbarzellen
  for Z:=1 to high(iaDim) do //alle Zellen
    if iaFix[Z]<0 then //nur kleine Zonen
    begin
      iPrm:=0;
      for N:=iaDim[pred(Z)] to pred(iaDim[Z]) do //alle Kontakte (auch innere)
        if (iaPrm[N]>iPrm) //längster Kontakt
        and (iaNbr[N]<>Z) //nicht innere Kontakte
        and (iaFix[iaNbr[N]]>0) then //stabile Zone
        begin
          iaFix[Z]:=iaNbr[N]; //neue ID ← nicht mit Array-Index identisch!
          iPrm:=iaPrm[N]; //längster Kontakt
        end;
    end;
end;

{ lRI trägt die Zonen-IDs aus "iaFix" in das Zonen-Bild "ixIdx" ein und gibt
  die neue Anzahl aller Zonen als Funktionswert zurück. "iaFix" kann negative
  IDs enthalten und die IDs können sich wiederholen. lRI zählt in "iaCnt" die
  Anzahl aller IDs, vergibt neue, fortlaufende IDs in "iaFix" und trägt sie in
  das Zonen-Bild "iaIdx" ein. }

function tLimits.RecodeIndex(
  iaFix:tnInt; //Transformations-Liste
  ixIdx:tn2Int): //Zonen-IDs WIRD VERÄNDERT!
  integer; //neue Anzahl Zonen
var
  iaCnt:tnInt=nil; //Pixel pro Zone
  X,Y,Z:integer;
begin
  Result:=0;
  iaCnt:=Tools.InitInteger(length(iaFix),0); //Zähler

  for Y:=0 to high(ixIdx) do
    for X:=0 to high(ixIdx[0]) do
    begin
      ixIdx[Y,X]:=abs(iaFix[ixIdx[Y,X]]); //neue Zonen-ID
      inc(iaCnt[ixIdx[Y,X]]) //Pixel pro Zone
    end;

  FillDWord(iaFix[0],length(iaFix),0); //leeren für neue IDs
  for Z:=1 to high(iaFix) do
    if iaCnt[Z]>0 then
    begin
      inc(Result); //neue fortlaufende Zonen-ID
      iaFix[Z]:=Result//neue ID an alter Position
    end;

  for Y:=0 to high(ixIdx) do
    for X:=0 to high(ixIdx[0]) do
      ixIdx[Y,X]:=iaFix[ixIdx[Y,X]]; //ID im Zonen-Bild ändern
end;

{ lSZ entfernt Zonen mit weniger als "iMin" inneren Kontakten und vereinigt sie
  mir der Zone, mit der sie die meisten Kontakte gemeinsam hat. Der Prozess
  kann eine Iteration erfordern. lSZ markiert entsprechende Zonen mit einer
  negativen ID, überträgt die ID der Nachbar-Zone mit der längsten gemeinsamen
  Grenze, vergibt fortlaufende IDs an alle Zonen und erneuert die Topologie-
  Tabelle. Nach der Transformation ersetzt lSZ den Raster-Index-Datei und
  bildet neue Grenzen. }

procedure tLimits.xSieveZones(iMin:integer); //Minimum innere Kontakte
var
  iaFix:tnInt=nil; //Transformations-Liste für neue Zonen-IDs
  iMdf:integer; //Kontrolle
  ixIdx:tn2Int=nil; //Zonen-IDs
  ixTpl:tn2Int=nil; //Zonen-Topologie
  rHdr:trHdr;
begin
  rHdr:=Header.Read(eeHme+cfIdx); //Metadaten Zellindex
  ixIdx:=tn2Int(Image.ReadBand(0,rHdr,eeHme+cfIdx)); //Zellindex-Bild
  repeat
    iaFix:=Tools.InitIndex(succ(rHdr.Cnt)); //fortlaufend
    ixTpl:=tn2Int(Tools.BitRead(eeHme+cfTpl)); //aktuelle Topologie
    iMdf:=SieveZones(iaFix,iMin,ixTpl); //negative Zonen-IDs in "iaFix" + Anzahl markierter Zonen
    if iMdf<1 then break;
    MergeZones(ixTpl,iaFix); //Nachbar-Zone mit häufigsten Kontakten
    rHdr.Cnt:=RecodeIndex(iaFix,ixIdx); //neue IDs eintragen + speichern
    Build._IndexTopology(rHdr.Cnt,ixIdx); //neue Topologie
  until iMdf<1;
  Image.WriteBand(tn2Sgl(ixIdx),-1,eeHme+cfIdx); //transformierte Zonen speichern
  Header.WriteIndex(rHdr.Cnt,rHdr,eeHme+cfIdx); //Metadaten speichern
  Gdal.ZonalBorders(eeHme+cfIdx); //neue Zellgrenzen
  Header.Clear(rHdr)
end;

{ mCV überträgt die Farben aus einer Klassen-Definition auf den Klassen-Layer.
  Die Klassen-Definition und Klassen-Layer müssen korrespondieren. mCV bestimmt
  für alle Kanäle die maximalen Werte aus der Klassen-Definition und scaliert
  damit die Farbdichten in der Palette auf 0..$FF. mCV verändert nur den Header
  des Klassen-Layers. }

procedure tModel.ClassValues(iRed,iGrn,iBlu:integer); //Kanäle [1..N]
const
  cCnt = 'mCV: Misfit between internal class layer and class definition!';
var
  fMax:single=0; //höchster Wert in Klassen-Defiition
  fxMdl:tn2Sgl=nil; //Klassen-Definition
  rHdr:trHdr; //Metadaten
  T:integer;
begin
  fxMdl:=Tools.BitRead(eeHme+cfMdl); //Klassen-Definition
  rHdr:=Header.Read(eeHme+cfMap); //Metadaten
  if rHdr.Cnt<>high(fxMdl) then Tools.ErrorOut(cCnt+cfMdl);

  for T:=1 to high(fxMdl) do
  begin
    fMax:=max(fxMdl[T,iRed],fMax);
    fMax:=max(fxMdl[T,iGrn],fMax);
    fMax:=max(fxMdl[T,iBlu],fMax);
  end;
  fMax:=$FF/fMax;
  fMax:=1.0;

  rHdr.Pal:=Tools.InitCardinal(succ(rHdr.Cnt)); //leere Palette
  for T:=1 to high(fxMdl) do
    rHdr.Pal[T]:=
      trunc(fxMdl[T,iRed]*fMax) +
      trunc(fxMdl[T,iGrn]*fMax) shl 8 +
      trunc(fxMdl[T,iBlu]*fMax) shl 16;
  rHdr.Pal[0]:=0;

  Header.WriteThema(rHdr.Cnt,rHdr,rHdr.Fld,eeHme+cfMap);
  Header.Clear(rHdr);
end;

{ rHy transformiert gestapelte multispektralen Bilder in einen Stack aus
  Graustufen-Layern mit der ersten Hauptkomponente aller Kanäle der Vorbilder.
  "xSplice" reduziert die Zeit und bewahrt die Kanäle, "xHistory" reduziert die
  Kanäle und bewahrt die Zeit. Der Vorbild-Stack muss einen erweiterten ENVI-
  Header haben. rHy erzeugt für jedes Bild zunächst einen Helligkeits-Layer und
  stapelt dann das Ergebnis. }

procedure tReduce.xHistory(sImg:string);
const
  cPrd = 'rCg: Bands per image seem to differ at: ';
var
  fNan:single=NaN; //NoData als Variable
  fSqr:double=0; //Summe quadrierte Differenzen
  fxRes:tn2Sgl=nil; //Ergebnis-Kanal = Hauptkomponente aus einem Bild
  fxTmp:tn3Sgl=nil; //quadrierte Differenzen
  iBnd:integer=-1; //Ergebnis für Bild "I" = Hauptkomponente
  rHdr:trHdr; //Metadata
  sBnd:string='t1'; //erste Zeiperiode
  B,I,X,Y:integer;
begin
  rHdr:=Header.Read(sImg);
  if rHdr.Stk mod rHdr.Prd>0 then Tools.ErrorOut(cPrd+sImg);
  fxRes:=Tools.Init2Single(rHdr.Lin,rHdr.Scn,dWord(fNan)); //Vorgabe = ungültig
  fxTmp:=Tools.Init3Single(rHdr.Prd,rHdr.Lin,rHdr.Scn,0); //Vorgabe = leer
  for I:=0 to pred(rHdr.Stk div rHdr.Prd) do //alle Bilder
  begin
    for B:=0 to pred(rHdr.Prd) do //alle Kanäle
      fxTmp[B]:=Image.ReadBand(I*rHdr.Prd+B,rHdr,sImg); //Kanal "B" aus Bild "I" laden
    for Y:=0 to pred(rHdr.Lin) do
      for X:=0 to pred(rHdr.Scn) do
      begin
        if isNan(fxTmp[0,Y,X]) then continue; //nicht definiert
        fSqr:=sqr(fxTmp[0,Y,X]);
        for B:=1 to high(fxTmp) do
          fSqr+=sqr(fxTmp[B,Y,X]);
        fxRes[Y,X]:=sqrt(fSqr)
      end;
    Image.WriteBand(fxRes,iBnd,eeHme+cfHry); //neues Bild für B=0, dann stapeln
    iBnd:=succ(I) //ab jetzt Kanäle stapeln
  end;
  for I:=2 to (rHdr.Stk div rHdr.Prd) do //Datum+Trenner
    sBnd+=#10't'+IntToStr(I); //laufende Nummer mit Zeilenwechsel
  rHdr.Prd:=1; //Zeitreihe!
  Header.WriteMulti(rHdr,sBnd,eeHme+cfHry);
  Header.Clear(rHdr);
end;

initialization

  Fabric:=tFabric.Create;
  Fabric.iacDim:=nil;
  Fabric.iacMap:=nil;
  Fabric.iacNbr:=nil;
  Fabric.iacPrm:=nil;

finalization

  SetLength(Fabric.iacDim,0);
  SetLength(Fabric.iacMap,0);
  SetLength(Fabric.iacNbr,0);
  SetLength(Fabric.iacPrm,0);
  Fabric.Free;

end.

{==============================================================================}

