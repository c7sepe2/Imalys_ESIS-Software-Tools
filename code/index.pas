unit index;

{ INDEX sammelt Routinen zur Zellbildung. "Zellen" sind zusammenhängende Teile
  des Bilds, deren Pixel mehr Merkmale gemeinsam haben als Pxel außerhalb der
  Zelle. "Zellen" werden durch eine Iteration gebildet. In jedem Schritt werden
  spektral maximal ähnliche Pixel oder Teilflächen zusammenfasst.

  BUILD:  sammelt vom Zellindex abhängige Routinen
  DRAIN:  bestimmt Catchments und verknüpft sie entsprechend der Topographie
  UNION:  vereinigt Pixel zu Zonen basierend auf Varianz

  BEGRIFFE:
  Attribut: Wert, der einer Zelle zugeordnet ist, meistens der Mittelwert aller
            Pixel. Aus Form und Größe der Zonen abgeleitete Werte können ebenso
            Attribute sein.
  Basin:    Gebiet mit einem gemeinsamen Abfluss
  Drain:    Abfluss mit Richtung entlang eines Gradienten, auch übertragen auf
            große, miteinander verknüpfte primäre Catchments
  Flow:     Abfluss mit Mengenangabe?
  Link:     Verknüpfung primärer Catchmenrs ohne Richtung
  Index:    Bereich eines Bildes mit gleicher ID in "index" → Zelle
  Kontakt:  Grenze zwischen zwei Pixeln vor allem im Zusammenhang mit Grenzen
            zwischen Zellen
  Zone:     Pixel mit gleichem Wert im Zellindex "index". Pixel einer Zone
            sind immer mit mindestens einer Kante verknüpft. Die Zell-ID ist
            eindeutig.
  }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, format;

type
  tBuild = class(tObject) //Aufruf geprüft 22-11-17
    private
      function Attributes(rHdr,rIdx:trHdr; sImg:string):tn2Sgl;
      function BandNames(var rHdr:trHdr):string;
      function CellWeight(var rHdr:trHdr):tnSgl;
      function Dendrites:tnSgl;
      function Deviation(fxImg:tn3Sgl; iCnt:integer; ixIdx:tn2Int):tnSgl;
      function Diffusion(faVal:tnSgl; iGen:integer):tnSgl;
      function Diversity(sImg:string):tnSgl;
      function InterFlow:tnSgl;
      function NormalZ(fxImg:tn3Sgl; iCnt:integer; ixIdx:tn2Int):tnSgl;
      function Proportion:tnSgl;
      function Relations:tnSgl;
    public
      function CheckZones(sSrc:string):boolean;
      procedure _IndexTopology(iCnt:integer; ixIdx:tn2Int);
      function SizeFit(sIdx,sStk:string):boolean;
      function ThemaImage(iaThm:tnInt):tn2Byt;
      procedure xAttributes(sImg:string);
      procedure xFeatures(iGen:integer; sImg:string; slCmd:tStringList);
      procedure xKernels(slCmd:tStringList; sImg:string);
  end;

  tDrain = class(tObject) //Aufruf geprüft 22-11-17
    const
      fcNan: single=0-MaxInt; //Wert für NoData
    private
      ixcIdx: tn2Int; //Zellindex (Bilddaten)
      racLnk: traLnk; //Verknüpfungen als Pixelindex
      rcHdr: trHdr; //gemeinsame Metadaten
      procedure Attributes(fxVal:tn2Sgl; iaNxt,iaPix:tnInt);
      procedure BasinIndex(fxVal:tn2Sgl);
      function BasinLink(fxVal:tn2Sgl; iImp:integer):tnInt;
      function CellMerge(iaLnk:tnInt; ixIdx:tn2Int):integer;
      function FlowConnect:tnInt;
      procedure Index_Control(iaNxt:tnInt);
      function MinimaIndex(fxVal:tn2Sgl):tnInt;
      procedure PixelDrain(fxVal:tn2Sgl);
    public
      procedure _DrainOut_(sImg:string);
  end;

  tUnion = class(tObject)
    private
      iacChn:tnInt; //Pixel-Indices auf Suchpfad NUR FÜR "xBorders"
      ixcIdx:tn2Int; //Zonen-IDs NUR FÜR "xBorders"
      ixcMap:tn2Byt; //Klassen-Layer NUR FÜR "xBorders"
      procedure _CheckDiversity_(apEtp:tapEtp; ixIdx:tn2Int; var rHdr:trHdr);
      function NewIndex(fxImg:tn3Sgl; var iCnt:integer):tn2Int;
      function IndexMerge(apEtp:tapEtp; iaLnk:tnInt; ixIdx:tn2Int):tapEtp;
      function LinksMerge(apEtp:tapEtp; ixIdx:tn2Int):tnInt;
      function NewEntropy(fxImg:tn3Sgl; iCnt:integer; ixIdx:tn2Int):tapEtp;
      procedure MinEntropy(apEtp:tapEtp; iGrw:integer; ixIdx:tn2Int);
      procedure PatchGrow(iLat,iLon,iVrt,iHrz:integer);
    public
      procedure xBorders(sImg:string);
      procedure xZones(iGrw,iSze:integer; sImg:string);
  end;

var
  Build: tBuild;
  Drain: tDrain;
  Union: tUnion;

implementation

uses
  Mutual, Raster, Thema, Vector;

{ fDI erzeugt ein Bild mit den Diversitäts-Werten der einzelen Zonen. }

procedure tUnion._CheckDiversity_(
  apEtp:tapEtp; //Entropie-Liste
  ixIdx:tn2Int; //Zonen-Index
  var rHdr:trHdr); //Header dazu
var
  fxDvs:tn2Sgl=nil;
  X,Y:integer;
begin
  fxDvs:=Tools.Init2Single(length(ixIdx),length(ixIdx[0]),0); //Diversity-Kanal
  for Y:=0 to high(fxDvs) do
    for X:=0 to high(fxDvs[0]) do
      if ixIdx[Y,X]>0 then
        fxDvs[Y,X]:=apEtp[ixIdx[Y,X]]^.Min;
  Image.WriteBand(fxDvs,-1,eeHme+'diversity');
  Header.WriteScalar(rHdr,eeHme+'diversity');
end;

{ tCTI transformiert ein Klassen-Attribut in einen Klassen-Layer. }

function tBuild.ThemaImage(iaThm:tnInt):tn2Byt;
var
  ixIdx: tn2Int=nil; //Zellindex-Bild
  rHdr: trHdr; //Zellindex-Metadaten
  X,Y: integer;
begin
  Result:=nil;
  rHdr:=Header.Read(eeHme+cfIdx); //Metadaten Zellindex
  Result:=Tools.Init2Byte(rHdr.Lin,rHdr.Scn); //
  ixIdx:=tn2Int(Image.ReadBand(0,rHdr,eeHme+cfIdx)); //Zellindex-Bild
  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
      Result[Y,X]:=iaThm[ixIdx[Y,X]];
  Header.Clear(rHdr)
end;

procedure tDrain.PixelDrain(fxVal:tn2Sgl); //Bilddaten mit Höhe, Distanz …
{ tDPD bestimmt für jeden Pixel den Nachbarpixel mit dem niedrigsten Wert und
  gibt den Pixelindex dieses Nachbarn in "ixcIdx" zurück. Lokale Minima
  behalten den Wert Null. tDPD ignoriert NoData Bereiche in "fxcVal". Auch sie
  behalten den Wert Null. }

procedure lNext(
  var fMin:single; //höchster Wert
  const iLat,iLon:integer; //Koordinaten
  var iPix:integer); //Pixelindex
begin
  if fxVal[iLat,iLon]<=fcNan then exit;
  if fxVal[iLat,iLon]<fMin then
  begin
    iPix:=iLat*rcHdr.Scn+iLon; //Pixelindex höchster Nachbar
    fMin:=fxVal[iLat,iLon] //neues Maximum
  end;
end;

var
{ ixcIdx: tn2Int; //Pixelindex
  racLnk: traLnk; //Verknüpfungen als Pixelindices
  rcHdr: trHdr; //gemeinsame Metadaten }
  fMin: single; //kleinster Wert eines Nachbarpixels
  iPix: integer; //Pixelindex höchster Nachbarpixel
  X,Y: integer;
begin
  for Y:=0 to high(fxVal) do
    for X:=0 to high(fxVal[0]) do
      if fxVal[Y,X]>fcNan then
      begin
        fMin:=fxVal[Y,X]; //Vorgabe
        if X>0 then lNext(fMin,Y,pred(X),iPix);
        if Y>0 then lNext(fMin,pred(Y),X,iPix);
        if X<pred(rcHdr.Scn) then lNext(fMin,Y,succ(X),iPix);
        if Y<pred(rcHdr.Lin) then lNext(fMin,succ(Y),X,iPix);
        if fMin<fxVal[Y,X] then
          ixcIdx[Y,X]:=iPix; //Pixelindex des Nachbar-Pixels
      end;
end;

function tDrain.MinimaIndex(
  fxVal:tn2Sgl): //Bilddaten
  tnInt; //Position der lokalen Minima als Pixelindex
{ tPMI zählt die lokalen Minima und trägt ihre ID als NEGATIVE Zahl in den Zell-
  Index ein. Die Zell-IDs sind negativ um sie von den Verweisen auf den
  niedrigesten Nachbarpixel (Pixel-Indices) zu unterscheiden. Gleichzeitig gibt
  tDMI die Position der lokalen Minima als Pixelindex zurück. }
var
{ ixcIdx: tn2Int; //Pixelindex
  racLnk: traLnk; //Verknüpfungen als Pixelindices
  rcHdr: trHdr; //gemeinsame Metadaten }
  X,Y:integer;
begin
  Result:=Tools.InitInteger($FF,0);
  for Y:=0 to high(ixcIdx) do
    for X:=0 to high(ixcIdx[0]) do
      if (ixcIdx[Y,X]=0) //kein Verweis auf Nachbar mit kleinerem Wert
      and (fxVal[Y,X]>fcNan) then //gültiger Wert im Bild (kein NoData)
      begin
        inc(rcHdr.Cnt);
        ixcIdx[Y,X]:=0-rcHdr.Cnt;
        if rcHdr.Cnt>=length(Result) then
          SetLength(Result,rcHdr.Cnt*2);
        Result[rcHdr.Cnt]:=Y*rcHdr.Scn+X; //Pixelindex
      end;
  SetLength(Result,succ(rcHdr.Cnt));
end;

procedure tDrain.BasinIndex(fxVal:tn2Sgl); //Bilddaten mit Höhen, Distanzen …
{ tPBI ersetzt die Verweise in "ixcIdx" durch die ID des lokalen Minimas. tPBF
  ignoriert NoData-Bereiche. Um Ketten effektiv zu verfolgen, iteriert tPBF
  abwechselnd von links oben und rechts unten. tPBF zählt bei jedem Scan die
  Pixel ohne markierten Nachbarn und wiederholt den Prozess bis er lückenlos
  ist. }
var
{ ixcIdx: tn2Int; //Pixelindex
  racLnk: traLnk; //Verknüpfungen als Pixelindices
  rcHdr: trHdr; //gemeinsame Metadaten }
  iSkp: integer; //Pixel ohne Basin-ID
  X,Y:integer;

procedure lGrow;
{ lG weist dem Pixel [Y,X] eine Zell-ID zu, wenn der Verweis (positive Zahl) in
  "ixcIdx" auf eine registrierte Zelle (negative Zahl) zeigt. lG zählt mit
  "iSkp" Pixel, die noch nicht registriert wurden. }
var
  iLat,iLon: integer; //Koordinaten
begin
  iLat:=ixcIdx[Y,X] div rcHdr.Scn;
  iLon:=ixcIdx[Y,X] mod rcHdr.Scn;
  if ixcIdx[iLat,iLon]<0
    then ixcIdx[Y,X]:=ixcIdx[iLat,iLon]
    else inc(iSkp);
end;

begin
  repeat
    iSkp:=0;
    for Y:=0 to high(fxVal) do
      for X:=0 to high(fxVal[0]) do
        if ixcIdx[Y,X]>0 then lGrow; //nur Pixelindices
    if iSkp=0 then break;

    iSkp:=0;
    for Y:=high(fxVal) downto 0 do
      for X:=high(fxVal[0]) downto 0 do
        if ixcIdx[Y,X]>0 then lGrow; //nur Pixelindices
  until iSkp=0;

  for Y:=0 to high(fxVal) do
    for X:=0 to high(fxVal[0]) do
      ixcIdx[Y,X]:=0-ixcIdx[Y,X]; //Vorzeichen ändern, Null bleibt unverändert
end;

function tDrain.BasinLink(
  fxVal:tn2Sgl; //Vorbild (scalar)
  iImp:integer): //ierarchie-Stufe (impact)
  tnInt; //Verknüpfungen als Zell-IDs
{ dBL sucht für jede Zelle nach dem niedrigsten Punkt am Rand der Zelle und
  gibt die ID der Nachbarzelle als Funktionswert zurück. Gleichzeitig gibt dBL
  die Indices beider Pixel am Ort der Verknüpfung in der globalen Variable
  "racLnk" zurück. Die Verknüpfungen können Linien und Kreise bilden, eine
  Zelle kann das Ziel vieler Zellen sein.
    Am Bildrand und an der Grenze zu NoData-Bereichen verknüpft dBL mit der
  Zelle Null. Der Bildrand wird durch den Pixel "ixcIdx[0,0] vertreten. Dazu
  muss "fxVal[0,0]" stark negativ und "ixcIdx[0,0]=0" gesetzt sein. dBL prüft
  horizontale und vertikale Kontakte getrennt um die Abfragen zu minimieren.
    dBL wird wiederholt aufgerufen um lokale Catchments aus verknüpfungen
  Zellen iterativ weiter zu vereinigen bis alle einen Abfluss nach NoData
  besitzen. Das Funktionsergebnis bezieht sich nur auf den aktuellen Zellindex,
  "racLnk" wird bei jedem Aufruf erweitert. Da "racLnk" Pixelindices speichert,
  können die ursprünglichen Zell-IDs aus der Position des Kontakts abgeleitet
  werden. dBL speichert die Generation des Aufrufs in "racLnk.Imp". }
{ FX-VAL MUSS IN NO-DATA BEREICHEN EINEN STARK NEGATIVEN WERT HABEN }
var
{ ixcIdx: tn2Int; //Pixelindex
  racLnk: traLnk; //Verknüpfungen als Pixelindices
  rcHdr: trHdr; //gemeinsame Metadaten }
  faFlw: tnSgl=nil; //Wert am Kontakt (Minimum am Rand der Zelle)
  iaHig: tnInt=nil; //Pixelindices Übergabe-Punkt am Rand der Zelle
  iaLow: tnInt=nil; //Pixelindices Empfangs-Punkt am Rand der Nachbarzelle

procedure lCheckLink(
  const iHrz,iVrt:integer; //Koordinaten am Rand der aktuellen Zelle
  const iLon,iLat:integer); //Koordinaten Nachbarpixel in der Nachbarzelle
{ lCL registriert einen Kontakt als Wert (Höhe) in "faFlw", als Index in "Result}
var
  iBsn:integer; //Catchment-ID
begin
  iBsn:=ixcIdx[iVrt,iHrz]; //aktuelles Catchment
  if iBsn>0 then //keine Abfragen von NoData aus
    if max(fxVal[iVrt,iHrz],fxVal[iLat,iLon])<faFlw[iBsn] then //niedrigster Punkt am Rand des Catchments
    begin
      faFlw[iBsn]:=max(fxVal[iVrt,iHrz],fxVal[iLat,iLon]); //neues Minimum
      iaHig[iBsn]:=iVrt*rcHdr.Scn+iHrz; //Pixelindex am Rand der Zelle
      iaLow[iBsn]:=iLat*rcHdr.Scn+iLon; //Pixelindex am Rand der Nachbarzelle
      Result[iBsn]:=ixcIdx[iLat,iLon]; //Index der Nachbar-Zelle
    end;
end;

procedure lHorizontal;
{ lH sucht nach dem niedrigsten horizontalen Kontakt zwischen zwei Zellen. lH
  trägt die Zell-IDs der Verknüpfungen in "Result" ein, die Position der Pixel
  am Kontakt in "iaHig" und "iaLow". Dazu scannt lH alle Zeilen und registriert
  neue Minima. Die erste und letzte Spalte werden separat abgefragt. }
var
  iRgt: integer; //höchste Spalten-ID
  X,Y: integer;
begin
  iRgt:=high(ixcIdx[0]); //höchster Pixel-Index horizontal
  for Y:=0 to high(ixcIdx) do //alle Zeilen
  begin
    lCheckLink(0,Y,0,0); //nach NoData
    for X:=1 to high(ixcIdx[0]) do
      if ixcIdx[Y,pred(X)]<>ixcIdx[Y,X] then //nur verschiedene Zellen
      begin
        lCheckLink(pred(X),Y,X,Y); //von links
        lCheckLink(X,Y,pred(X),Y); //von rechts
      end;
    lCheckLink(iRgt,Y,0,0); //nach NoData
  end;
end;

procedure lVertical; //so
var
  iBtm: integer; //höchste Zeilen-ID
  X,Y: integer;
begin
  iBtm:=high(ixcIdx); //höchster Pixel-Index vertikal
  for X:=0 to high(ixcIdx[0]) do //alle Spalten
  begin
    lCheckLink(X,0,0,0);
    for Y:=1 to high(ixcIdx) do
      if ixcIdx[pred(Y),X]<>ixcIdx[Y,X] then
      begin
        lCheckLink(X,pred(Y),X,Y);
        lCheckLink(X,Y,X,pred(Y));
      end;
    lCheckLink(X,iBtm,0,0);
  end;
end;

procedure lLinkRegister;
{ lLR überträgt die lokalen Variablen "iaHig,iaLow" auf die Liste "racLnk". Mit
  der sukzessiven Vergrößerung der Catchments kann eine Zelle mehr als eine
  Verknüpfung bekommen. Der Index von "racLnk" ist deshalb größer als die Zahl
  der primären Zellen (Catchments). Das Ziel (racLnk.Low) kann Null sein. }
var
  iDim: integer=0; //Anzahl Verknüpfungen
  Z: integer;
begin
  //succ(rcHdr.Cnt)=length(iaHig)=length(iaLow)?
  iDim:=length(racLnk); //Anzahl bestehende Kontakte
    SetLength(racLnk,iDim+rcHdr.Cnt); //erweitern auf Maximum
  for Z:=1 to pred(rcHdr.Cnt) do
  begin
    racLnk[iDim].Hig:=iaHig[Z];
    racLnk[iDim].Low:=iaLow[Z];
    racLnk[iDim].Imp:=iImp; //Iterations-Stufe
    inc(iDim)
  end;
  SetLength(racLnk,iDim); //passend zuschneiden
end;

const
  cMax:single=Maxint; //Vorgabe für Suche nach Minimum
begin
  Result:=Tools.InitIndex(succ(rcHdr.Cnt)); //Nachbarzelle: Vorgabe = Sebstbezug
  faFlw:=Tools.InitSingle(succ(rcHdr.Cnt),dWord(cMax)); //Wert am Kontakt (Minimum am Rand der Zelle)
  ixcIdx[0,0]:=0; //Zelle Null wird durch den Pixel [0,0] vertreten
  fxVal[0,0]:=fcNan; //als NoData eintragen
  iaHig:=Tools.InitInteger(succ(rcHdr.Cnt),dWord(-1)); //Vorgabe = undefiniert
  iaLow:=Tools.InitInteger(succ(rcHdr.Cnt),dWord(-1));
  lHorizontal; //horizontale Kontakte registrieren
  lVertical; //vertikale Kontakte registrieren
  lLinkRegister; //Kontakte als Pixel-Koordinaten
end;

procedure tDrain.Index_Control(iaNxt:tnInt); //Verknüpfungen als Zell-IDs
{ tDIC schreibt alle in "iaNxt" registrierten Verknüpfungen als als Text. }
var
{ ixcIdx: tn2Int; //Pixelindex
  racLnk: traLnk; //Verknüpfungen als Pixelindices
  rcHdr: trHdr; //gemeinsame Metadaten }
  slLnk:tStringList=nil;
  I:integer;
begin
  try
    slLnk:=tStringList.Create;
    for I:=0 to high(iaNxt) do
      slLnk.Add(IntToStr(I)+' → '+IntToStr(iaNxt[I]));
    slLnk.SaveToFile(eeHme+'Indexlink.txt');
  finally
    slLnk.Free;
  end;
end;

function tDrain.FlowConnect:tnInt; //Zell-IDs
{ tDFC konvertiert die Verknüpfungen in "racLnk" in genau eine Verknüpfung für
  jede Zelle. Das Ziel kann ein anderes Minimum, der Bildrand oder Nodata sein.
    Verknüfungen in "racLnk" (Links) enthalten in der ersten Generation in sich
  geschlossene Inseln mit einem Ringschluss als gemeinsames Ziel und ab der
  zweiten Generation Links zwischen diesen Inseln. tDFC übernimmt die primären
  Links und ergänzt anschließend höhere Gernerationen. Um keinen Link zu
  verlieren ändert tDFC die Richtung bestehender Links bis zum nächsten
  Ringschluss.}
var
  iaMsk:tnInt=nil; //Maske aktuelle veränderte Verknüpfungen
  iBck,iIdx,iNxt:integer; //aufeinander folgende Zell-IDs
  I:integer;
begin
  Result:=Tools.InitInteger(succ(rcHdr.Cnt),0); //Verknüpfungen
  iaMsk:=Tools.InitInteger(succ(rcHdr.Cnt),0); //Maske besuchte Minima

  for I:=0 to high(racLnk) do //Zell-ID statt Position
    with racLnk[I],rcHdr do
    begin
      Hig:=ixcIdx[Hig div Scn,Hig mod Scn]; //primäre Catchment-ID
      Low:=ixcIdx[Low div Scn,Low mod Scn];
    end;

  for I:=0 to high(racLnk) do
    with racLnk[I] do
      if Imp>1 then //sekundäre Verknüpfungen
      begin
        if Low=0 then continue; //Abfluss unverändert
        iBck:=Low; //neue Verknüpfung
        iIdx:=Hig; //aktuelle Zelle
        iNxt:=Result[iIdx]; //alte Verknüpfung
        repeat
          Result[iIdx]:=iBck; //Verknüpfung ändern
          iaMsk[iIdx]:=1; //Zelle markieren
          iBck:=iIdx; //Block verschieben
          iIdx:=iNxt; //so
          iNxt:=Result[iNxt]; //so
        until (iaMsk[iNxt]>0)
           or (iIdx=0);
        repeat
          iaMsk[iNxt]:=0; //Markierung löschen
          iNxt:=Result[iNxt] //Kette verfolgen
        until iaMsk[iNxt]=0;
      end
      else Result[Hig]:=Low; //Link unverändert übernehmen
end;

procedure tDrain.Attributes(
  fxVal:tn2Sgl; //Bilddaten (Vorbild, evt. invertiert)
  iaNxt:tnInt; //Verknüpfung der primären Zellen
  iaPix:tnInt); //Pixelindex der Zell-Minima
{ dA erzeugt die Attribut-Tabelle zum Abfluss. dA registriert in "iaSze" die
  Pixel pro Zelle und in "faWgt" die Summe aller Werte in der Zelle. "faMin"
  enthält den kleinsten Wert im lokalen Minimum und "faLnk" den Wert an der
  Übergabe. Die Übergabe besteht aus zwei benachbarten Pixeln aus den zwei
  verknüpften Zellen. dA übernimmt den größeren von beiden (Widerstand!). }
var
  faMin:tnSgl=nil; //Höhe des Zell-Minimums
  faWgt:tnSgl=nil; //mittlere Höhe der Zelle
  iaSze:tnInt=nil; //Zellgröße in Pixeln
  X,Y,Z:integer;
begin
  faMin:=Tools.InitSingle(succ(rcHdr.Cnt),0);
  faWgt:=Tools.InitSingle(succ(rcHdr.Cnt),0);
  iaSze:=Tools.InitInteger(succ(rcHdr.Cnt),0);

  for Z:=1 to high(iaPix) do
    faMin[Z]:=fxVal[iaPix[Z] div rcHdr.Scn,iaPix[Z] mod rcHdr.Scn]; //Wert an der Quelle]
  for Y:=0 to pred(rcHdr.Lin) do
    for X:=0 to pred(rcHdr.Scn) do
    begin
      faWgt[ixcIdx[Y,X]]+=fxVal[Y,X]; //Werte-Summe pro Zelle
      inc(iaSze[ixcIdx[Y,X]]); //Pixel pro Zelle
    end;
  faWgt[0]:=0; iaSze[0]:=0; //Logik

  DeleteFile(eeHme+cfIdx+cfBit); //nur gleiche Dimension wird überschrieben
  Tools.BitInsert(tnSgl(iaPix),0,eeHme+cfIdx+cfBit); //Pixelindex des Minimums
  Tools.BitInsert(tnSgl(iaNxt),1,eeHme+cfIdx+cfBit); //Verknüpfung als Zell-ID
  Tools.BitInsert(tnSgl(iaSze),2,eeHme+cfIdx+cfBit); //Pixel pro Zelle
  Tools.BitInsert(faMin,3,eeHme+cfIdx+cfBit); //Wert des Minimums
  Tools.BitInsert(faWgt,4,eeHme+cfIdx+cfBit); //Werte-Summe der Zelle
end;

function tDrain.CellMerge(
  iaLnk:tnInt; //ID der verknüpften Zelle
  ixIdx:tn2Int): //Zellindex
  integer; //Anzahl Zellen
{ fCM vereinigt verknüpfte Zellen unter einer gemeinsamen ID als Zellindex. Die
  ID ist fortlaufend und beginnt mit Eins. NoData Bereiche im Vorbild haben den
  Index Null. }
{ fCM verfolgt eine Kette von Verknüpfungen bis sie sich schließt. Dazu
  markiert fCM jede Suche in "fxNxt" mit (-1). Findet fCM am Ende der Kette
  eine bestehende Zelle, übernimmt fCM die ID und trägt sie in den Suchpfad
  ein. Trifft der Suchpfad auf sich selbt, verwendet fCM eine neue Zell-ID. }
var
  iaNxt:tnInt=nil; //neue Verknüpfung
  iIdx:integer=0; //alte Zell-ID
  iTmp:integer; //aktuelle ID
  X,Y,Z:integer;
begin
  Result:=0;
  iaNxt:=Tools.InitInteger(length(iaLnk),0);
  for Z:=1 to high(iaLnk) do
  begin
    if iaNxt[Z]>0 then continue; //erledigt

    iIdx:=Z; //Zell-ID
    repeat
      iaNxt[iIdx]:=-1; //Marke
      iIdx:=iaLnk[iIdx]; //ähnlichste Zelle
    until iaNxt[iIdx]<>0; //Schleife oder Zelle

    if iaNxt[iIdx]<0 then //Schleife → neue Zelle
    begin
      inc(Result); //neue ID
      iTmp:=Result; //ID verwenden
    end
    else iTmp:=iaNxt[iIdx];

    iIdx:=Z; //Zell-ID
    repeat
      iaNxt[iIdx]:=iTmp; //Marke
      iIdx:=iaLnk[iIdx] //ähnlichste Zelle
    until iaNxt[iIdx]=iTmp; //Zelle gefunden
  end;

  iaNxt[0]:=0;
  for Y:=0 to high(ixIdx) do
    for X:=0 to high(ixIdx[0]) do
      ixIdx[Y,X]:=iaNxt[ixIdx[Y,X]];
end;

procedure tDrain._DrainOut_(sImg:string); //Höhenmodell
{ tPDO erzeugt eine Liste von Verknüpfungen, die lokale Minima in "sImg" zu
  einem natürlichen Abfluss-System verbindet. tPDO verwendet nur den ersten
  Kanal von "sImg". Der Abfluss ist so gestaltet, dass jedes lokale Minimum am
  niedrigsten Punkt seiner Grenze ausläuft und nur in Gebiete mit kleinerem
  Minimum abfließt. Der Bildrand ist "unendlich" tief.
    tPDO bestimmt für jeden Pixel den niedrigsten Nachbarpixel. Dabei bleiben
  lokale Minima übrig. tPDO zählt sie fortlaufend. tPDO registriert in "faMin"
  den Wert und in iaDrn die Position der lokalen Minima. Aus diesen Listen und
  der Flussrichtung auf Pixelebene ergibt sich ein Bild mit einer fortlaufenden
  ID für alle primären Gebiete (Catchments).
    tPDO vereinigt iterativ Catchments mit gemeinsamem Abfluss bis die Gebiete
  stabil sind. Dazu sucht tPDO auf jeder Stufe neue Orte, an denen vereinigte
  Gebiete in ein tieferes ausfließen. Wie zu Beginn ist der Abfluss der tiefste
  Ort am Rand des vereinigten Gebiets.
    Während der iterativen Vereinigung protokolliert tPDO in "iaHig" und
  "iaLow" den Abfluss- und den Aufnahme-Ort als Pixelindex. Zusammen mit den
  lokalen Minima "iaDrn" ergibt sich daraus ein Netz von Verknüpfungen, dass
  jedem lokalen Minimum genau ein anderes zuordnet, in das es abfließt. tPDO
  gibt dieses Netz als Liste geographischer Koordinaten zurück, die jeweils
  zwei lokale Minima verknüpfen. }
var
{ ixcIdx: tn2Int; //Pixelindex
  racLnk: traLnk; //Verknüpfungen als Pixelindices
  rcHdr: trHdr; //gemeinsame Metadaten }
  fxVal:tn2Sgl=nil; //Vorbild mit Höhen, Distanzen …
  iaNxt:tnInt=nil; //Liste mit Verknüpfungen zwischen Zellen
  iaPix:tnInt=nil; //Pixelindices der lokalen Minima
  iCnt:integer=0; //Anzahl Zellen (Zwischenrgebnis)
  iStp:integer=0; //Stufen bei der Catchment-Vereinigung
begin
{ "import", "mapping" und "model" definiert? }
  rcHdr:=Header.Read(sImg); //gemeinsame Metadaten
  fxVal:=Image.ReadBand(0,rcHdr,sImg); //Vorbild
  Image.ValueInvert(fxVal); //Werte invertierten
  Filter.ValueMove(0-Tools.MinBand(fxVal),fxVal); //nur positive Werte
  Filter.ReplaceNan(fcNan,fxVal); //NoData auf Zahl legen
  ixcIdx:=Tools.Init2Integer(rcHdr.Lin,rcHdr.Scn,0); //leerer Zellindex
  PixelDrain(fxVal); //Flussrichtung als Pixelindex in "ixcIdx"
  iaPix:=MinimaIndex(fxVal); //Position als Pixelindex + negative Zell-IDs im Bild
  BasinIndex(fxVal); //Mikro-Catchment-Index
  Image.WriteBand(tn2Sgl(ixcIdx),-1,eeHme+cfIdx); //primäre Catchments speichern
  Header.WriteIndex(rcHdr.Cnt,rcHdr,eeHme+cfIdx); //Index Metadaten speichern
  repeat
    inc(iStp); //Merge-Stufen zählen
    iCnt:=rcHdr.Cnt;
    iaNxt:=BasinLink(fxVal,iStp); //Index-Verknüpfungen
    rcHdr.Cnt:=CellMerge(iaNxt,ixcIdx);
  until rcHdr.Cnt=iCnt;
  Image.WriteBand(tn2Sgl(ixcIdx),-1,eeHme+cfCtm); //finale Catchments speichern
  Header.WriteIndex(rcHdr.Cnt,rcHdr,eeHme+cfCtm); //Metadaten dazu
  Gdal.ZonalBorders(eeHme+cfCtm); //Catchments als Polygone
  rcHdr:=Header.Read(eeHme+cfIdx);
  ixcIdx:=tn2Int(Image.ReadBand(0,rcHdr,eeHme+cfIdx)); //primäre Catchments neu laden
  iaNxt:=FlowConnect; //Verknüpfung der Minima für Abfluss
  Index_Control(iaNxt); //Verknüpfungen der Zell-IDs NUR ZUR KONTROLLE
  Attributes(fxVal,iaNxt,iaPix); //Attribute als BIT-Tabelle
  SetLength(ixcIdx,0); //aufräumen ..
  SetLength(racLnk,0);
  Header.Clear(rcHdr);
  Tools.HintOut('Drain.Execute: '+cfIdx);
end;

{ bIF gibt die Intensität aller Verknüpfungen aus der Drain-Analyse zurück. }

function tBuild.InterFlow:tnSgl;
var
  faWgt:tnSgl=nil; //Summe der Werte pro Zelle
  iaNxt:tnInt=nil; //Verknüpfung der Zelle
  Z:integer;
begin
  // Drain-Index geladen?
  iaNxt:=tnInt(Tools.BitExtract(1,eeHme+cfAtr)); //Verknüpfung, aus Selbstbezug
  faWgt:=Tools.BitExtract(3,eeHme+cfAtr); //Summe aller Werte der Zelle
  Result:=Tools.InitSingle(length(iaNxt),0);
  for Z:=1 to high(iaNxt) do
    Result[Z]:=min(faWgt[Z],faWgt[iaNxt[Z]]);
end;

function tBuild.Dendrites:tnSgl; //Attribut "Kompaktheit"
{ bDd erzeugt ein Attribut mit der Kompaktheit der Zellen. Dazu bildet bDd das
  normalisierte Verhältnis zwischen äußeren und inneren Kontakten aller Pixel
  einer Zelle und gibt es als Array zurück. }
var
  iaDim:tnInt=nil; //Index auf "iacNbr, iacPrm"
  iaNbr:tnInt=nil; //Index der Nachbarzelle
  iaPrm:tnInt=nil; //Kontakte zur Nachbarzelle
  iExt,iInt:integer; //externe, interne Kontakte einer Zelle
  ixTpl:tn2Int=nil; //Zell-Topologie
  N,Z:integer;
begin
  //Topology defined?
  ixTpl:=tn2Int(Tools.BitRead(eeHme+cfTpl));
  iaDim:=ixTpl[0]; //Zeiger auf Startadressen
  iaNbr:=ixTpl[1]; //Zeiger auf IDs der Nachbarzellen
  iaPrm:=ixTpl[2]; //Zeiger auf Kontakte zu Nachbarzellen
  Result:=Tools.InitSingle(length(iaDim),0); //Umfang als Attribut
  for Z:=1 to high(iaDim) do //alle Zellen
  begin
    iExt:=0; iInt:=0; //Vorgabe
    for N:=iaDim[pred(Z)] to pred(iaDim[Z]) do //alle Kontakte (auch innere)
      if iaNbr[N]=Z //innere Kontakte
        then iInt+=iaPrm[N]
        else iExt+=iaPrm[N];
    if iExt>0
      then Result[Z]:=iExt/(iInt+iExt) //Verhältnis innere/äußere Kontakte
      else Result[Z]:=0;
  end;
end;

{ bRt gibt das Verhältnis zwischen Anzahl der Nachbarzonen und dem Umfang der
  zentralen Zone als Attribut zurück. Index und Topologie müssen existieren.
  Das Ergebnis sollte von der Größe der zentralen Zone unabhängig sein. }

function tBuild.Relations:tnSgl;
var
  iaDim:tnInt=nil; //Index auf "iacNbr, iacPrm"
  iaNbr:tnInt=nil; //Index der Nachbarzelle
  iaPrm:tnInt=nil; //Kontakte zur Nachbarzelle
  iPrm,iRes:integer; //Umfang der Zelle, Anzahl Kontakte
  ixTpl:tn2Int=nil; //Zell-Topologie (heterogen)
  N,Z:integer;
begin
  ixTpl:=tn2Int(Tools.BitRead(eeHme+cfTpl));
  iaDim:=ixTpl[0]; //Zeiger auf Startadressen
  iaNbr:=ixTpl[1]; //Zeiger auf IDs der Nachbarzellen
  iaPrm:=ixTpl[2]; //Zeiger auf Kontakte zu Nachbarzellen
  Result:=Tools.InitSingle(length(iaDim),0); //Verknüpfungen als Attribut
  for Z:=1 to high(iaDim) do //alle Zellen
  begin
    iPrm:=0; iRes:=0; //Vorgaben
    for N:=iaDim[pred(Z)] to pred(iaDim[Z]) do //alle Kontakte
      if iaNbr[N]<>Z then //äußere Kontakte
      begin
        iPrm+=iaPrm[N]; //Umfang
        inc(iRes) //Anzahl Kontakte
      end;
    if iPrm>0 then
      Result[Z]:=iRes/iPrm; //Verhältnis innere/äußere Kontakte}
  end;
end;

{ bDn erzeugt einen Werte-Ausgleich zwischen Attributen. }
{ bLM bestiimt für jede Zelle den Mittelwert das Attributs "faVal" für die
  zentrale Zelle und alle Nachbarzellen. Die Werte sind mit der Länge der
  gemensamen Grenze gewichtet. bLM iteriert den Vorgang "iGen" mal. }

function tBuild.Diffusion(
  faVal:tnSgl; //Attribut
  iGen:integer): //Nachbar-Generationen
  tnSgl; //Attribut nach Vereinigung
const
  cGen = 'Error(bLM): Iterations must be positive!';
  cVal = 'Error(bLM): Attribute not defined!';
var
  fRes:single; //Zwischenlager für Mittelwert
  iaDim: tnInt=nil; //Index auf "iacNbr, iacPrm"
  iaNbr: tnInt=nil; //Index der Nachbarzelle
  iaPrm: tnInt=nil; //Kontakte zur Nachbarzelle
  iCnt: integer; //Summe Kontakte
  ixTpl: tn2Int=nil; //Zell-Topologie
  I,N,Z:integer;
begin
  if faVal=nil then Tools.ErrorOut(cVal);
  if iGen<1 then Tools.ErrorOut(cGen);
  Result:=Tools.InitSingle(length(faVal),0);
  ixTpl:=tn2Int(Tools.BitRead(eeHme+cfTpl));
  iaDim:=ixTpl[0]; //Zeiger auf Startadressen
  iaNbr:=ixTpl[1]; //Zeiger auf Nachbar-IDs
  iaPrm:=ixTpl[2]; //Länge der Grenzen
  for I:=1 to iGen do
  begin
    for Z:=1 to high(iaDim) do
    begin
      fRes:=0; iCnt:=0;
      for N:=iaDim[pred(Z)] to pred(iaDim[Z]) do //alle Kontakte (auch innere)
      begin
        fRes+=faVal[iaNbr[N]]*iaPrm[N]; //gewichteter Mittelwert
        iCnt+=iaPrm[N]; //Kontakte zählen
      end;
      if iCnt>0 then Result[Z]:=fRes/iCnt;
    end;
    faVal:=copy(Result,0,length(faVal)); //identische Kopie
  end;
end;

{ bBN überträgt die Kanal-Namen in getrennten Zeilen aus "rHdr.aBnd" in eine
  kommagetrennte Liste oder erzeugt eine neue }

function tBuild.BandNames(var rHdr:trHdr):string;
var
  iCnt:integer=0; //Anzahl Zeilentrenner
  I:integer;
begin
  Result:=copy(rHdr.aBnd,1,length(rHdr.aBnd)); //Kopie
  for I:=1 to length(Result) do
    if Result[I]=#10 then
    begin
      Result[I]:=',';
      inc(iCnt)
    end;
  if Result[length(Result)]=','
    then delete(Result,length(Result),1)
    else inc(iCnt); //erster Eintrag
  while rHdr.Stk>iCnt do
    Result+=',b'+IntToStr(iCnt); //folgende
end;

function tBuild.CheckZones(sSrc:string):boolean;
const
  cAtr = 'Zonal classification needs a zonas attribute table "index.bit"';
  cIdx = 'Zonal classification needs a zones definition image "index"';
  cTpl = 'Zonal classification needs a zonas topology "topology.bit"';
begin
  Result:=
    FileExists(eeHme+cfIdx) and
    FileExists(eeHme+cfAtr) and
    FileExists(eeHme+cfTpl);
  if not Result then
  begin
    if not FileExists(eeHme+cfIdx) then Tools.ErrorOut(sSrc+cIdx);
    if not FileExists(eeHme+cfAtr) then Tools.ErrorOut(sSrc+cAtr);
    if not FileExists(eeHme+cfTpl) then Tools.ErrorOut(sSrc+cTpl);
  end;
end;

{ bDy leitet eine spektrale Diversität direkt aus den Zonen-Attributen ab und
  gibt sie als neues Attribut zurück. Dazu benötigt bDy den Index, die Anzahl
  der scalaren Attribute und die Topologie. bDy bestimmt für jede benachbarte
  Zelle die spektrale Differenz aus der Hauptkomponente aller Kanäle und
  summiert die Differenzen entsprechend der Länge der gemeinsamen Grenze. bDy
  behandelt innere Kontakte (Fläche) genauso wie alle Nachbarzonen. Große Zonen
  haben dadurch eine geringere Diversität. bDy trägt den Prozess-Namen als
  Feldname in den Zonen-Header ein. }

function tBuild.Diversity(
  sImg:string): //Dateiname Bilddaten
  tnSgl; //Diversität
const
  cImg = 'bDy: Input image not available: ';
var
  fDst:single; //Summe gewichtete Distanzen
  fRes:single; //Zwischenlager
  fxVal:tn2Sgl=nil; //Zell-Attribute
  iaDim:tnInt=nil; //Index auf "iacNbr, iacPrm"
  iaNbr:tnInt=nil; //Index der Nachbarzelle
  iaPrm:tnInt=nil; //Kontakte zur Nachbarzelle
  iCnt:integer; //Summe Kontakte
  iSpc:integer=0; //spektrale Attribute
  ixTpl:tn2Int=nil; //Zell-Topologie
  B,N,Z:integer;
begin
  if length(sImg)<1 then Tools.ErrorOut(cImg+sImg);
  SetLength(Result,0); //leeren
  ixTpl:=tn2Int(Tools.BitRead(eeHme+cfTpl));
  iaDim:=ixTpl[0]; //Zeiger auf Startadressen
  iaNbr:=ixTpl[1]; //Zeiger auf IDs der Nachbarzellen
  iaPrm:=ixTpl[2]; //Zeiger auf Kontakte zu Nachbarzellen
  fxVal:=Tools.BitRead(eeHme+cfAtr); //Zell-Attribute
  Result:=Tools.InitSingle(length(iaDim),0); //Entropie-Attribut
  iSpc:=StrToInt(Header.ReadLine('bands',sImg));
  for Z:=1 to high(iaDim) do
  begin
    fRes:=0; iCnt:=0; //Vorgaben
    for N:=iaDim[pred(Z)] to pred(iaDim[Z]) do //alle Kontakte (auch innere)
    begin
      fDst:=0; //Vorgabe
      for B:=0 to pred(iSpc) do //nur Spektralkanäle
        fDst+=sqr(fxVal[B,iaNbr[N]]-fxVal[B,Z]); //quadrierte Distanz
      fRes+=sqrt(fDst)*iaPrm[N]; //Distanz * Anzahl Kontakte
      iCnt+=iaPrm[N]; //Kontakte zählen
    end;
    if iCnt>0 then
      Result[Z]:=fRes/iCnt; //mittlere Distanz
  end;
end;

{ fNI erzeugt einen neuen Zonen-Index. In der Vorgabe bilden alle definierten
  Pixel eine Zone. }

function tUnion.NewIndex(
  fxImg:tn3Sgl; //Vorbild
  var iCnt:integer): //definierte Pixel
  tn2Int; //Zonen-IDs
var
  X,Y:integer;
begin
  Result:=Tools.Init2Integer(length(fxImg[0]),length(fxImg[0,0]),0); //Zonen-IDs
  for Y:=0 to high(fxImg[0]) do
    for X:=0 to high(fxImg[0,0]) do
    begin
      if isNan(fxImg[0,Y,X]) then continue; //Bild nicht definiert
      inc(iCnt); //fortlaufende Zonen-ID
      Result[Y,X]:=iCnt; //Pixel = Zone
    end;
end;

{ fNR erzeugt ein neues "Entropy"-Array mit einem "tapEtp" Record pro Zone. Die
  Records bestehen aus einem konstanten teil für Minimum, Größe und Verknüpfung
  und einem dynamischen Teil für Summe und Quadrat-Summe aller Pixel in allen
  Kanälen. Summen verwenden die niedrigere Hälfte der Indices, Quadrate die
  hohen Indices. Wenn später Flächen vereinigt werden, müssen nur die Record-
  Inhalte addiert werden. }

function tUnion.NewEntropy(
  fxImg:tn3Sgl; //Vorbild
  iCnt:integer; //definierte Pixel
  ixIdx:tn2Int): //Zonen-Index
  tapEtp; //Varianz, Size, Link, Sum, Square
var
  pBnd:^TnSgl=nil; //Zeiger auf Summen + Quadrate
  pEtp:tpEtp; //Zeiger auf Zonen-Merkmale
  iBnd:integer=0; //Anzahl Kanäle
  B,X,Y,Z:integer;
begin
  Result:=nil;
  SetLength(Result,succ(iCnt));
  iBnd:=length(fxImg); //Anzahl Kanäle
  for Z:=1 to iCnt do
  begin
    new(pEtp); //neue Zone
    pEtp^:=crEtp; //Vorgabe
    SetLength(pEtp^.aBnd,iBnd*2);
    FillDWord(pEtp^.aBnd[0],iBnd*2,0);
    Result[Z]:=pEtp;
  end;
  Result[0]:=nil;

  for Y:=0 to high(ixIdx) do
    for X:=0 to high(ixIdx[0]) do
    begin
      if ixIdx[Y,X]=0 then continue;
      pBnd:=@Result[ixIdx[Y,X]]^.aBnd; //Zeiger
      for B:=0 to high(fxImg) do //alle Kanäle
      begin
        pBnd^[B]+=fxImg[B,Y,X]; //Summe aller Werte pro Kanal
        pBnd^[iBnd+B]+=sqr(fxImg[B,Y,X]); //Quadrate aller Werte pro Kanal
      end;
      inc(Result[ixIdx[Y,X]]^.Sze); //Pixel pro Zone
    end;
end;

{ uME prüft alle Grenzen zwischen zwei Zonen ob ihre gemeinsame Entropie ein
  lokales Minimum ergeben würde und gibt die Verknüpfung mit der kleinsten
  Entropie als tapEtp^.Lnk zurück. uME verwendet als Maß für die "Entropie" die
  Gauß'sche Varianz aller Pixel einer Zone. }
{ lGL bestimmt die Entropie der vereinigten Zonen "iIdx" und "iNxt" und
  vergleicht sie mit bereits getesteten Alternativen. lGL registriert die ID
  der Zone mit der niedrigsten gemeinsamen Entropie. Um jede Kombination nur
  einmal zu berechnen, registriert lGL alle getesteten Kombinationen in
  "ixLnk". "ixLnk[Zone,0]" enthält die Zahl der Vergleiche. }

procedure tUnion.MinEntropy(
  apEtp:tapEtp; //Varianz, Size, Link, Summen, Quadrate
  iGrw:integer; //Zonen Wachstum eingeschränkt
  ixIdx:tn2Int); //Zonen-Index als Bild
const
  cLmt = MaxInt; //"unendliche" Varianz
var
  iBnd:integer; //Anzahl Kanäle
  ixLnk:tn2Int=nil; //getestete Verknüpfungen

procedure lGetLink(const iIdx,iNxt:integer); //Zonen-IDs
//Varianz = (∑x²-(∑x)²/n)/(n-1)
var
  fRes,fSqr,fSum:single; //Zwischenlager für Varianz
  pIdx,pNxt:tpEtp; //Zeiger auf trEtp-Eintrag
  iSze:integer; //gemeinsame Fläche
  B,I:integer;
begin
  if (iNxt=iIdx) //gleiche Zone
  or (iNxt=0) or (iIdx=0) then exit; //keine Definition
  for I:=1 to ixLnk[iIdx,0] do
    if ixLnk[iIdx,I]=iNxt then exit; //Vergleich existiert
  for I:=1 to ixLnk[iNxt,0] do
    if ixLnk[iNxt,I]=iIdx then exit;

  pIdx:=apEtp[iIdx];
  pNxt:=apEtp[iNxt];
  iSze:=pIdx^.Sze+pNxt^.Sze; //gemeinsame Fläche
  fRes:=0;
  for B:=0 to pred(iBnd) do
  begin
    fSum:=pIdx^.aBnd[B]+pNxt^.aBnd[B]; //Summe Dichte
    fSqr:=pIdx^.aBnd[iBnd+B]+pNxt^.aBnd[iBnd+B]; //Summe Dichte-Quadrate
    fRes+=(fSqr-sqr(fSum)/iSze)/pred(iSze); //Varianzen aller Kanäle
  end;
  case iGrw of
    0:; //keine Bindung
    1: fRes*=ln(iSze); //mäßige Anpassung
    2: fRes*=iSze; //starke Anpassung
  end;

  if fRes<pIdx^.Min then //neues Minimum
  begin
    pIdx^.Min:=fRes;
    pIdx^.Lnk:=iNxt;
    inc(ixLnk[iIdx,0]); //neuer Vergleich
    if length(ixLnk[iIdx])<=ixLnk[iIdx,0] then
      SetLength(ixLnk[iIdx],length(ixLnk[iIdx])*2); //Array erweitern
    ixLnk[iIdx,ixLnk[iIdx,0]]:=iNxt; //Verknüpfung
  end;

  if fRes<pNxt^.Min then //neues Minimum
  begin
    pNxt^.Min:=fRes;
    pNxt^.Lnk:=iIdx;
    inc(ixLnk[iNxt,0]); //neuer Vergleich
    if length(ixLnk[iNxt])<=ixLnk[iNxt,0] then
      SetLength(ixLnk[iNxt],length(ixLnk[iNxt])*2); //Array erweitern
    ixLnk[iNxt,ixLnk[iNxt,0]]:=iIdx; //Verknüpfung
  end;
end;

var
  X,Y,Z:integer;
begin
  iBnd:=length(apEtp[1]^.aBnd) div 2; //Anzahl Kanäle
  ixLnk:=Tools.Init2Integer(length(apEtp),4,0); //Verknüpfungen, Dimensuion=Vorgabe
  for Z:=1 to high(apEtp) do
  begin
    apEtp[Z]^.Min:=cLmt; //Vorgabe Varianz
    apEtp[Z]^.Lnk:=0; //Vorgabe = keine Verknüpfung
  end;
  for Y:=0 to high(ixIdx) do
    for X:=1 to high(ixIdx[0]) do
      lGetLink(ixIdx[Y,pred(X)],ixIdx[Y,X]);
  for Y:=1 to high(ixIdx) do
    for X:=0 to high(ixIdx[0]) do
      lGetLink(ixIdx[pred(Y),X],ixIdx[Y,X]);
end;

{ fIM gibt eine Transformations-Liste für neue, vereinigte Zonen-IDs zurück.
  Dazu erzeugt fIM zuerst eine Liste der bestehenden IDs und sucht nach
  rückbezüglichen Verweisen. fIM vergibt für jeden Treffer eine neue ID und
  markiert sie als negative Zahl. Wenn alle rückbezüglichen Verweise erfasst
  sind, vergibt fIM neue, fortlaufende IDs an alle anderen Zonen. fIM übergibt
  die höchste Zonen.ID als Result[0]. }

function tUnion.LinksMerge(
  apEtp:tapEtp; //bestehende Statistik
  ixIdx:tn2Int): //Zonen-Index
  tnInt; //neue Zonen-IDs
var
  iMrg:integer=0; //neue IDs
  Z:integer;
begin
  SetLength(Result,length(apEtp));
  for Z:=1 to high(apEtp) do
    Result[Z]:=apEtp[Z]^.Lnk; //bestehende Verknüpfungen
  Result[0]:=0;

  for Z:=1 to high(apEtp) do
    if (Result[Z]>0) //Verknüpfung ist registriert
    and (Result[Result[Z]]=Z) then //Rückbezug
    begin
      inc(iMrg); //neue Zone
      Result[Result[Z]]:=-iMrg; //markieren
      Result[Z]:=-iMrg
    end;

  for Z:=1 to high(Result) do
    if Result[Z]>=0 then //nicht verknüpfte Zone
    begin
      inc(iMrg); //neu zählen
      Result[Z]:=iMrg
    end
    else Result[Z]:=-Result[Z]; //Vorzeichen löschen

  Result[0]:=iMrg; //höchste ID
end;

{ fIM transformiert den Zonen-Index "iaIdx" und die Zonen-Attribute "apEtp"
  mit der Liste "iaLnk". Der Index erhält einfach andere Werte. fIM vereinigt
  zuerst Entropy-Records die zur gleichen neuen Zone gehören und verschiebt
  anschließend unveränderte Records in die neue Entropy-Liste. Dabei entfernt
  fIM Variable und konstante Komponenten der nicht mehr benötigten Records.
  fIM gibt die verkürzte Entropy-Liste zurück. }

function tUnion.IndexMerge(
  apEtp:tapEtp; //bestehende Statistik
  iaLnk:tnInt; //transformations-Liste
  ixIdx:tn2Int): //Zonen-Index
  tapEtp; //neue Statistik
var
  iBnd:integer; //Anzahl Kanäle
  pEtp,pRes:tpEtp; //Zeiger auf Zonen-Statistik
  B,X,Y,Z:integer;
begin
  SetLength(Result,succ(iaLnk[0]));
  FillDWord(Result[0],length(Result)*2,0);
  iaLnk[0]:=0;

  for Y:=0 to high(ixIdx) do
    for X:=0 to high(ixIdx[0]) do
      ixIdx[Y,X]:=iaLnk[ixIdx[Y,X]];

  iBnd:=length(apEtp[1]^.aBnd) div 2; //Anzahl Kanäle
  for Z:=1 to high(iaLnk) do //alle alten Zonen
    if Result[iaLnk[Z]]<>nil then
    begin
      pRes:=Result[iaLnk[Z]]; //Zeiger
      pEtp:=apEtp[Z]; //verknüpftes Element
      pRes^.Sze+=pEtp^.Sze; //Pixel pro Zone
      for B:=0 to pred(iBnd) do
        pRes^.aBnd[B]+=pEtp^.aBnd[B]; //Summe Dichte
      for B:=iBnd to pred(iBnd*2) do
        pRes^.aBnd[B]+=pEtp^.aBnd[B]; //QuadratSumme Dichte
      SetLength(pEtp^.aBnd,0); //altes Array frei geben
      dispose(pEtp); //alten Record frei geben
    end
    else Result[iaLnk[Z]]:=apEtp[Z]; //Zeiger kopieren
  Result[0]:=nil;
  SetLength(apEtp,0); //alte Liste frei geben
end;

{ TODO: [Union.xZones] Grenzen könnten geglättet werden:
   → Knoten registrieren (Rasterbild, 1-Pixel-Rahmen rund um Original)
   → Linien aus Grenzen
   → Punkte auf geraden Stecken löschen
   → Punkte in Richtung der zwei Nachbarn bewegen
   → Strecke abhängig von der Entfernung
   → Punkte löschen wenn Distenz < Schwelle }

{ fZs erzeugt einen neuen Zonen-Index als Bild und ein ESRI-Shape mit allen
  Grenzen zwischen zwei Zonen. fZs bestimmt die Varianz aller Kombinationen
  zwischen zwei Nachbar-Zonen und vereinigt lokale Minima. Der Prozess iteriert
  bis die mittlere Fläche (Pixel) der Zonen "iSze" überschreitet. Mit "iGrw>1"
  wird die Varianz großer Zonen vergrößert. }

procedure tUnion.xZones(
  iGrw:integer; //Zonen-Wachstum einschränken [0,1,2]
  iSze:integer; //Pixel/Zone
  sImg:string); //Name Bilddaten
var
  apEtp:tapEtp=nil; //Varianzen als Liste
  fxImg:tn3Sgl=nil; //Vorbild, alle Kanäle
  iCnt:integer=0; //Anzahl Zonen
  iDef:integer=0; //Definierte Pixel im Index
  iaLnk:tnInt=nil; //Verknüpfungs-Liste
  ixIdx:tn2Int=nil; //Zonen-IDs
  rHdr:trHdr; //gemeinsamer Header
begin
  rHdr:=Header.Read(sImg); //Vorbild
  fxImg:=Image.Read(Header.Read(sImg),sImg); //Vorbild mit allen Kanälen
  ixIdx:=NewIndex(fxImg,iDef); //Index einrichten, 0=nicht definiert
  apEtp:=NewEntropy(fxImg,iDef,ixIdx); //Entropie-Record für alle Pixel
  repeat
    iCnt:=length(apEtp);
    MinEntropy(apEtp,iGrw,ixIdx); //Summen, Quadrate, Varianzen
    iaLnk:=LinksMerge(apEtp,ixIdx); //Verknüpfungen
    apEtp:=IndexMerge(apEtp,iaLnk,ixIdx); //neuer Index, Statistik
    write(#13+IntToStr(iCnt));
  until (iDef/length(apEtp)>iSze) //mittlere Flächengröße
     or ((iCnt-length(apEtp))/(iCnt+length(apEtp))<0.0001); //leerlauf
  iCnt:=length(apEtp);
  Tools.HintOut(#13'Force.Zones: '+IntToStr(iCnt)); //mit Wagenrücklauf
  Image.WriteBand(tn2Sgl(ixIdx),-1,eeHme+cfIdx); //Bilddaten schreiben
  Header.WriteIndex(iCnt,rHdr,eeHme+cfIdx); //Index-Header dazu
  Build._IndexTopology(iCnt,ixIdx); //Topologie-Tabelle
  Gdal.ZonalBorders(eeHme+cfIdx); //Zellgrenzen als Shape
  Header.Clear(rHdr);
end;

{ bDn bestimmt die Standardaweichung zwischen allen Pixeln einer Zone und gibt
  das Ergebnis als Array für alle Zonen zurück. bDn bestimmt zunächst die
  Abweichung in jedem einzelnen Kanal und bildet dann aus den Ergebnissen der
  Kanäle die Hauptkomponente. Auf diese Weise werden auch Farbkontraste bei
  konstanter Helligkeit erfasst.
  → Die Varianz relativ zur Helligkeit ist als Kommentar notiert
  → Varianz = (∑x²-(∑x)²/n)/(n-1) }

function tBuild.Deviation(
  fxImg:tn3Sgl; //Vorbild
  iCnt:integer; //Anzahl Zonen
  ixIdx:tn2Int): //Zonen-IDs
  tnSgl; //Gauß'sche Abweichung pro Zone
var
  //faBrt:tnSgl=nil; //Zwischenlager für Helligkeit
  faSqr:tnSgl=nil; //Zwischenlager für Varianz
  faSum:tnSgl=nil;
  iaSze:tnInt=nil; //definierte Pixel pro Zone
  pBnd:^tn2Sgl=nil;
  B,X,Y,Z:integer;
begin
  Result:=Tools.InitSingle(succ(iCnt),0);
  //faBrt:=Tools.InitSingle(succ(iCnt),0);
  iaSze:=Tools.InitInteger(succ(iCnt),0);
  SetLength(faSqr,succ(iCnt));
  SetLength(faSum,succ(iCnt));

  for B:=0 to high(fxImg) do
  begin
    FillDWord(faSqr[0],succ(iCnt),0);
    FillDWord(faSum[0],succ(iCnt),0);
    pBnd:=@fxImg[B]; //Zeiger
    for Y:=0 to high(ixIdx) do
      for X:=0 to high(ixIdx[0]) do
        if ixIdx[Y,X]>0 then //NoData-Pixel ignorieren
        begin
          faSqr[ixIdx[Y,X]]+=sqr(pBnd^[Y,X]); //für Varianz
          faSum[ixIdx[Y,X]]+=pBnd^[Y,X];
          if B=0 then inc(iaSze[ixIdx[Y,X]]); //definierte Pixel pro Zone
        end;
    for Z:=1 to iCnt do
      if iaSze[Z]>1 then
      begin
        Result[Z]+=(faSqr[Z]-sqr(faSum[Z])/iaSze[Z])/pred(iaSze[Z]);
        //faBrt[Z]+=sqr(faSum[Z]/iaSze[Z]); //für Hauptkomponente Helligkeit
      end;
  end;
  for Z:=1 to iCnt do
    Result[Z]:=sqrt(Result[Z]); //erste Hauptkomponente
    //if faBrt[Z]>0 then
      //Result[Z]:=sqrt(Result[Z])/sqrt(faBrt[Z]); //erste Hauptkomponente
  Result[0]:=0;
end;

{ bSF prüft ob Zonen-Raster und Vorbilder genau gleich groß sind. }

function tBuild.SizeFit(sIdx,sStk:string):boolean; //Bildnamen
const
  cSze = 'bSF: Image size and zones size differ! ';
var
  rIdx,rStk:trHdr; //Metadaten
begin
  rStk:=Header.Read(sStk); //Metadaten Vorbild
  rIdx:=Header.Read(eeHme+cfIdx); //Metadaten Zonen
  Result:=(round(rIdx.Lat/rIdx.Pix)=round(rStk.Lat/rStk.Pix)) //linke obere Ecke
      and (round(rIdx.Lon/rIdx.Pix)=round(rStk.Lon/rStk.Pix))
      and (rIdx.Lin=rStk.Lin) and (rIdx.Scn=rStk.Scn) //Höhe, Breite
      and ((rIdx.Pix-rStk.Pix)/(rIdx.Pix+rStk.Pix)<1e-5); //Pixelgröße
  Header.Clear(rStk);
  Header.Clear(rIdx);
  if not Result then Tools.ErrorOut(cSze);
end;

{ uAs erzeugt eine Zonen-Attribut-Tabelle für alle Kanäle von "fxImg" und gibt
  sie als Matrix zurück. Die Attribute sind der Mittelwert aller Pixel der
  einzelnen Zone. }

function tBuild.Attributes(
  rHdr,rIdx:trHdr; //Metadaten: Vorbild, Zonen
  sImg:string): //Name Vorbild
  tn2Sgl; //spektrale Merkmale aller Zellen
var
  fxImg:tn3Sgl=nil; //Vorbild, NoData-Pixel müssen zum Index passen!
  iaSze:tnInt=nil; //Pixel pro Zelle
  iIdx:integer; //aktuelle Zell-ID
  ixIdx:tn2Int; //Zellindex
  pMsk:^tn2Sgl=nil; //Zeiger auf ersten Kanal
  B,X,Y,Z:integer;
begin
  Result:=Tools.Init2Single(rHdr.Stk,succ(rIdx.Cnt),0); //leere Tabelle
  fxImg:=Image.Read(rHdr,sImg); //Stack für Attribute aus Bilddaten
  ixIdx:=tn2Int(Image.ReadBand(0,rIdx,eeHme+cfIdx)); //Zonen Raster
  iaSze:=Tools.InitInteger(succ(rIdx.Cnt),0);
  pMsk:=@fxImg[0]; //Zeiger auf ersten Kanal
  for Y:=0 to high(ixIdx) do
    for X:=0 to high(ixIdx[0]) do
    begin
      if isNan(pMsk^[Y,X]) then continue; //nicht definiert
      iIdx:=ixIdx[Y,X]; //aktuelle Zelle
      for B:=0 to high(fxImg) do
        Result[B,iIdx]+=fxImg[B,Y,X]; //Merkmale summieren
      inc(iaSze[iIdx]) //Pixel dazu zählen
    end;
  for Z:=1 to rIdx.Cnt do
    if iaSze[Z]>0 then
      for B:=0 to high(fxImg) do
        Result[B,Z]/=iaSze[Z];
  for B:=0 to high(fxImg) do
    Result[B,0]:=0; //Null ist nicht definiert
end;

{ bAs ersetzt die Tabelle "index.bit" durch die Bilddaten in "sImg". Zonen und
  Topologie müssen existieren. bAs bestimmt den Mittelwert der Pixel für jede
  Zone und schreibt das Ergebnis nach Kanälen getrennt in die Tabelle. bAs
  überträgt die Kanal-Namen aus "sImg" als Feldnamen in den Zonen-Header. }

procedure tBuild.xAttributes(sImg:string); //Vorbild für Attribute
var
  fxAtr:tn2Sgl=nil; //scalare Attribute
  rStk,rIdx:trHdr; //Vorbild (Layer-Stack)
  sFld:string=''; //Kanal-Namen als kommagetrennte Liste
  I:integer;
begin
  // fileexists(sImg)?
  rStk:=Header.Read(sImg); //Metadaten Import
  sFld:=BandNames(rStk); //Kanal-Namen aus Bilddaten als kommagetrennte Liste
  rIdx:=Header.Read(eeHme+cfIdx); //Zonen Metadatem
  fxAtr:=Attributes(rStk,rIdx,sImg); //Attribute aus Bilddaten
  if FileExists(eeHme+cfAtr) //Attribute vorhanden (Sicherheit)
    then rIdx.Fld:=rIdx.Fld+','+sFld //Feldnamen aus Bilddaten ergänzen
    else rIdx.Fld:=sFld; //Feldnamen ersetzen
  for I:=0 to high(fxAtr) do
    Tools.BitInsert(fxAtr[I],$FFF,eeHme+cfAtr); //Attribute erzeugen oder erweitern
  Header.Write(rIdx,'Imalys Cell Index',eeHme+cfIdx); //Header mit Feldnamen
  Header.Clear(rIdx);
  Header.Clear(rStk);
  Tools.HintOut('Build.Attributes: '+cfAtr);
end;

{ bNZ bestimmt die normalisierte Textur mit Zonen als Kernel und gibt das
  Ergebnis als Array (Zonen-Attribut) zurück. bNZ scannt das gesamte Bild
  horizontal und vertikal und registriert dabei jedes Pixel-Paar das in der
  gleichen Zone liegt. bNZ bestimmt die mittlere Differenz dieser Paare für
  jeden Kanal getrennt. Das Ergebnis ist dann die Hauptkomponente aller Werte
  der einzelnen Kanäle. (Mit bNrm=true) normalisiert bNZ die Differenz mit der
  Helligkeit beider Pixel. }
{ lD bestimmt die (normalisierte) Differenz zwischen zwei Pixeln. lD prüft ob
  beide Pixel zur gleichen Zelle gehören (iIdx,iNxt), bestimmt das Ergebnis
  und zählt die berechneten Differenzen (iCnt). }

function tBuild.NormalZ(
  fxImg:tn3Sgl; //Vorbild
  iCnt:integer; //Anzahl Zonen
  ixIdx:tn2Int): //Zonen-IDs
  tnSgl; //normalisierte Textur pro Zone

function lDiff(
  const fHig,fLow:single;
  const iIdx,iNxt:integer;
  var iCmp:integer):single;
begin
  Result:=0; //Vorgabe
  if (iIdx<1) or (iNxt<>iIdx) then exit;
  if fHig+fLow=0 then exit;
  Result:=abs(fHig-fLow)/(fHig+fLow); //normalisierte Differenz
  inc(iCmp); //Anzahl Vergleiche
end;

var
  faRes:tnSgl=nil; //Ergebnis für einen Kanal
  iaCmp:tnInt=nil; //Anzahl Vergleiche Nachbarpixel
  pBnd:^tn2Sgl=nil; //Zeiger auf aktuellen Kanal
  B,X,Y,Z:integer;
begin
  Result:=Tools.InitSingle(succ(iCnt),0);
  iaCmp:=Tools.InitInteger(succ(iCnt),0); //Anzahl Vergleiche
  SetLength(faRes,succ(iCnt)); //Zwischenlager
  for B:=0 to high(fxImg) do
  begin
    pBnd:=@fxImg[B]; //Zeiger
    FillDWord(faRes[0],succ(iCnt),0); //für jeden Kanal leeren
    for Y:=0 to high(ixIdx) do
      for X:=1 to high(ixIdx[0]) do
        faRes[ixIdx[Y,X]]+=lDiff(pBnd^[Y,pred(X)],pBnd^[Y,X],
          ixIdx[Y,pred(X)],ixIdx[Y,X],iaCmp[ixIdx[Y,X]]);
    for X:=0 to high(ixIdx[0]) do
      for Y:=1 to high(ixIdx) do
        faRes[ixIdx[Y,X]]+=lDiff(pBnd^[pred(Y),X],pBnd^[Y,X],
          ixIdx[pred(Y),X],ixIdx[Y,X],iaCmp[ixIdx[Y,X]]);
    for Z:=1 to iCnt do
      if iaCmp[Z]>1 then
        Result[Z]+=sqr(faRes[Z]/iaCmp[Z]); //für Hauptkomponente
  end;
  for Z:=1 to iCnt do
    Result[Z]:=sqrt(Result[Z]); //erste Hauptkomponente
  Result[0]:=0;
end;

{ TODO: [Build.CellWeight] Zonen am Ende der Liste sind definiert aber leer }

{ bCW bestimmt die Größe der Zonen direkt aus dem Zellindex und gibt sie als
  Attribut zurück. Das Attribut enthält die Fläche in [ha]. }

function tBuild.CellWeight(var rHdr:trHdr):tnSgl;
var
  fSze:single; //Faktor Pixel → Hektar
  ixIdx:tn2Int=nil; //Zellindex-Bild
  X,Y,Z:integer;
begin
  Result:=Tools.InitSingle(succ(rHdr.Cnt),0); //Vorgabe = leer
  ixIdx:=tn2Int(Image.ReadBand(0,rHdr,eeHme+cfIdx)); //Zellindex-Bild
  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
      Result[ixIdx[Y,X]]+=1; //Pixel pro Zone
  fSze:=sqr(rHdr.Pix)/10000; //Hektar pro Pixel
  for Z:=1 to rHdr.Cnt do
    Result[Z]*=fSze; //Fläche in [ha]
  Result[0]:=0;
end;

{ bPt bestimmt die "Textur" der Zonengröße als Attribut. Das Ergebnis ist der
  Mittelwert aller Flächen-Differenzen zu allen Nachbarzellen. Das Ergebnis
  kann negativ sein! bPt verwendet die Summe der inneren Kontakte als Fläche. }

function tBuild.Proportion:tnSgl;
var
  faSze:tnSgl=nil; //Zellgröße aus internen Kontakten
  iaDim:tnInt=nil; //Index auf "iacNbr, iacPrm"
  iaNbr:tnInt=nil; //Index der Nachbarzelle
  iaPrm:tnInt=nil; //Kontakte zur Nachbarzelle
  iNbr:integer; //Anzahl Nachbarzellen + Zentrum
  ixTpl:tn2Int=nil; //Zell-Topologie (heterogen)
  N,Z:integer;
begin
  ixTpl:=tn2Int(Tools.BitRead(eeHme+cfTpl));
  iaDim:=ixTpl[0]; //Zeiger auf Startadressen
  iaNbr:=ixTpl[1]; //Zeiger auf IDs der Nachbarzellen
  iaPrm:=ixTpl[2]; //Zeiger auf Kontakte zu Nachbarzellen
  Result:=Tools.InitSingle(length(iaDim),0); //Verknüpfungen als Attribut
  faSze:=Tools.InitSingle(length(iaDim),0); //Zellgröße aus internen Kontakten

  for Z:=1 to high(iaDim) do //alle Zellen
    for N:=iaDim[pred(Z)] to pred(iaDim[Z]) do //alle Kontakte
      if iaNbr[N]=Z then //innere Kontakte
        //faSze[Z]:=iaPrm[N]; //Logarithmus innere Kontakte als Zellgröße
        faSze[Z]:=ln(succ(iaPrm[N])); //Logarithmus innere Kontakte als Zellgröße

  for Z:=1 to high(iaDim) do //alle Zellen
  begin
    iNbr:=0; //Vorgabe
    for N:=iaDim[pred(Z)] to pred(iaDim[Z]) do //alle Kontakte, auch innere
      if iaNbr[N]<>Z then
      begin
        Result[Z]+=faSze[iaNbr[N]]; //Flächen (logarithmen) summieren
        inc(iNbr) //zählen
      end;
    if Result[Z]>0
      then Result[Z]:=faSze[Z]/Result[Z]*iNbr //Verhältnis zum Mittelwert
      else Result[Z]:=0;
  end;
end;

{ bFs erweitert die Attribut-Tabelle "index.bit" mit Attributen aus der
  Geometrie und den spektralen Attributen ganzer Zonen. Wenn "index.bit" nicht
  existiert, erzeugt bFs eine neue. Zellindex und Topologie müssen existieren.
  Mit "iGen>0" werden die Attribute lokal mit einer Diffusion gemittelt. bFs
  trägt die Prozess-Namen aus "slCmd" als Feldnamen in den Index-Header ein. }

procedure tBuild.xFeatures(
  iGen:integer; //Iterationen für Mittelwert
  sImg:string; //Name Bilddaten ODER leer
  slCmd:tStringList); //Prozesse + Ergebnis-Namen
const
  cCmd = 'Error(bA): Command not appropriate to run "attributes": ';
var
  faVal:tnSgl=nil; //gewähltes Attribut
  rHdr:trHdr; //gemeinsame Metadaten
  I:integer;
begin
  if slCmd.Count<1 then exit; //kein Aufruf
  rHdr:=Header.Read(eeHme+cfIdx); //Zellindex
  if FileExists(eeHme+cfAtr) //Attribute vorhanden
    then rHdr.Fld:=rHdr.Fld+','+slCmd.CommaText //Feldnamen aus Bilddaten ergänzen
    else rHdr.Fld:=slCmd.CommaText; //Feldnamen ersetzen
  for I:=0 to pred(slCmd.Count) do
  begin
    if slCmd[I]=cfDdr then faVal:=Dendrites else
    if slCmd[I]=cfDvs then faVal:=Diversity(sImg) else
    if slCmd[I]=cfItf then faVal:=Interflow else
    if slCmd[I]=cfPrp then faVal:=Proportion else
    if slCmd[I]=cfRlt then faVal:=Relations else
    if slCmd[I]=cfSze then faVal:=CellWeight(rHdr) else
      Tools.ErrorOut(cCmd+slCmd[I]); //nicht definierter Befehl
    if iGen>0 then faVal:=Diffusion(faVal,iGen); //Attribut lokal mitteln
    Tools.BitInsert(faVal,$FFF,eeHme+cfAtr); //bestehende Attribute erzeugen oder erweitern
  end;
  Header.Write(rHdr,'Imalys zonal index',eeHme+cfIdx); //speichern
  Header.Clear(rHdr); //aufräumen
  Tools.HintOut('Build.Features: '+cfAtr);
end;

{ IT erzeugt eine heterogene Tabelle "topology.bit". Die Tabelle enthält in
  der ersten Spalte den Index "iaDim" mit der Zahl der Einträge pro Zone, in
  der zweiten Spalte "iaNbr" für jede Zelle die IDs aller Nachbarzellen und in
  der dritten Spalte "iaPrm" die Anzahl der Kontakte. IT enthält auch innere
  Kontakte. IT ignoriert NoData-Pixel.
    IT erzeugt znächst ein Zwischenprodukt "ixNbr" und "ixPrm" die für jede
  Zone ein eigenes Array besitzen. Die Anzahl der gültigen Einträge steht in
  "iaNbr[?,0]". IT passt die Länge der Arrays dynamisch an den Bedarf an. IT
  scannt den Zellindex getrennt vollständig horizontal und vertikal. Am Ende
  übersetzt IT die Zwischenprodukte in die Tabelle und speichert sie als BIT-
  Datei. }

procedure tBuild._IndexTopology(
  iCnt:integer; //Anzahl Zonen (höchste ID)
  ixIdx:tn2Int); //Zonen-Raster
var
  ixNbr: Tn2Int=nil; //Nachbar-Zell-IDs
  ixPrm: Tn2Int=nil; //Kontakte zu Nachbar-Zellen

procedure lLink(const iLow,iHig:integer);
var
  N: integer;
begin
  if (iLow<1) or (iHig<1) then exit; //NoData ignorieren

  for N:=1 to ixNbr[iLow,0] do
    if ixNbr[iLow,N]=iHig then
    begin
      inc(ixPrm[iLow,N]);
      exit;
    end; //if iaNbr[iLow,N]=iHig

  inc(ixNbr[iLow,0]);
  if ixNbr[iLow,0]>high(ixNbr[iLow]) then
  begin
    SetLength(ixNbr[iLow],ixNbr[iLow,0]*2);
    SetLength(ixPrm[iLow],ixNbr[iLow,0]*2);
  end; //if ixNbr[iLow,0] ..
  ixNbr[iLow,ixNbr[iLow,0]]:=iHig;
  ixPrm[iLow,ixNbr[iLow,0]]:=1;
end; //lLink.

procedure lLinksIndex(ixIdx:tn2Int);
var
  X,Y,Z: integer;
begin
  for Z:=1 to iCnt do
  begin
    ixNbr[Z]:=Tools.InitInteger(7,0);
    ixPrm[Z]:=Tools.InitInteger(7,0);
  end; //if ixFtr[1,Z]<iMin

  for Y:=1 to high(ixIdx) do
    for X:=0 to high(ixIdx[0]) do
    begin
      lLink(ixIdx[pred(Y),X],ixIdx[Y,X]);
      lLink(ixIdx[Y,X],ixIdx[pred(Y),X]);
    end; //for X ..

  for Y:=0 to high(ixIdx) do
    for X:=1 to high(ixIdx[0]) do
    begin
      lLink(ixIdx[Y,pred(X)],ixIdx[Y,X]);
      lLink(ixIdx[Y,X],ixIdx[Y,pred(X)]);
    end; //for X ..
end; //lLinksIndex.

procedure lInternal;
var
  N,Z: integer;
begin
  for Z:=1 to iCnt do
    for N:=1 to ixNbr[Z,0] do
      if ixNbr[Z,N]=Z then
        ixPrm[Z,N]:=ixPrm[Z,N] div 2;
end; //lInternal.

procedure lIndexSave;
var
  iaDim: TnInt=nil; //Abschnitte in "iaNbr"
  iaNbr: TnInt=nil; //Zell-ID Kontakt
  iaPrm: TnInt=nil; //Anzahl Kontakte
var
  iDim: integer; //Topologie-Dimension bis zur Zelle "Z"
  Z: integer;
begin
  iaDim:=Tools.InitInteger(succ(iCnt),0);
  iaNbr:=Tools.InitInteger(succ(iCnt),0);
  iaPrm:=Tools.InitInteger(succ(iCnt),0);
  for Z:=1 to iCnt do
  begin
    iDim:=iaDim[pred(Z)]+ixNbr[Z,0]; //neue Dimension
    if iDim>high(iaNbr) then
    begin
      SetLength(iaNbr,round(iDim*sqrt(2)));
      SetLength(iaPrm,length(iaNbr));
    end; //if iaDim[pred(Z)] ..
    move(ixNbr[Z,1],iaNbr[iaDim[pred(Z)]],ixNbr[Z,0]*SizeOf(integer));
    move(ixPrm[Z,1],iaPrm[iaDim[pred(Z)]],ixNbr[Z,0]*SizeOf(integer));
    iaDim[Z]:=iDim;
    SetLength(ixNbr[Z],0); //Speicher freigeben
    SetLength(ixPrm[Z],0);
  end; //for Z ..
  SetLength(iaNbr,iaDim[iCnt]); //Speicher reduzieren
  SetLength(iaPrm,iaDim[iCnt]);
  DeleteFile(eeHme+cfTpl);
  Tools.BitInsert(tnSgl(iaDim),0,eeHme+cfTpl);
  Tools.BitInsert(tnSgl(iaNbr),1,eeHme+cfTpl);
  Tools.BitInsert(tnSgl(iaPrm),2,eeHme+cfTpl);
end; //lIndexSave.

const
  cIdx = 'iPIT: Cell index file not provided: ';
begin
  if not FileExists(eeHme+cfIdx) then Tools.ErrorOut(cIdx+eeHme+cfIdx);
  ixNbr:=Tools.Init2Integer(succ(iCnt),1,0); //Container
  ixPrm:=Tools.Init2Integer(succ(iCnt),1,0);
  lLinksIndex(ixIdx); //Pixel-Kontakte indizieren (Y*2)
  lInternal; //interne Grenzen einfach zählen
  lIndexSave; //Topologie indizieren und speichern (Z)
  Tools.HintOut('Union.IndexTopology: '+cfTpl)
end;

{ fZK bestimmt Kernel-Attribute mit Zonen als Kernel und speichert das Ergebnis
  in der Attribut-Tabelle "index.bit". fZK ergänzt die Prozess-Namen im Index-
  Header als Feldnamen. }

procedure tBuild.xKernels(
  slCmd:tStringList;//Prozess-Namen
  sImg:string); //Dateiname Vorbild
const
  cCmd = 'bZK: Command not defined in this context: ';
  cFex = 'bZK: Image not found: ';
var
  faDvs:tnSgl=nil; //Werte (Diversity) pro Zone
  fxImg:tn3Sgl=nil; //Vorbild, alle Kanäle
  ixIdx:tn2Int=nil; //Zonen-IDs
  rHdr,rIdx:trHdr; //Metadaten
  C:integer;
begin
  if slCmd=nil then exit; //keine Befehle
  if not FileExists(sImg) then Tools.ErrorOut(cFex+sImg);
  // slCmd muss gefiltert sein ← "Parse.KernelCmd"
  // iBnd>0?

  rIdx:=Header.Read(eeHme+cfIdx); //Metadaten Zonenindex
  ixIdx:=tn2Int(Image.ReadBand(0,rIdx,eeHme+cfIdx)); //Zonen-Bild
  if FileExists(eeHme+cfAtr) //Attribute vorhanden
    then rIdx.Fld:=rIdx.Fld+','+slCmd.CommaText //Feldnamen aus Bilddaten ergänzen
    else rIdx.Fld:=slCmd.CommaText; //Feldnamen ersetzen
  Header.Write(rIdx,'Imalys Cell Index',eeHme+cfIdx); //Header mit Feldnamen
  rHdr:=Header.Read(sImg); //Metadaten Vorbild
  fxImg:=Image.Read(rHdr,sImg); //Stack für Attribute aus Bilddaten
  for C:=0 to pred(slCmd.Count) do //alle Befehle
  begin
    if slCmd[C]=cfEtp then faDvs:=Deviation(fxImg,rIdx.Cnt,ixIdx) else //Abweichung
    if slCmd[C]=cfNrm then faDvs:=NormalZ(fxImg,rIdx.Cnt,ixIdx) else //normalisierte Textur
        Tools.ErrorOut(cCmd+slCmd[C]); //nicht definierter Befehl
    Tools.BitInsert(faDvs,$FFF,eeHme+cfAtr); //Attribute erzeugen oder erweitern
  end;
  Header.Clear(rHdr);
  Header.Clear(rIdx);
  Tools.HintOut('Build.ZonesKernel: '+slCmd.CommaText);
end;

{ uPG prüft ob der Pixel [iLat,iLon] zur gleichen Klasse gehört wie [iVrt,iHrz]
  und markiert akzeptierte Pixel mit der Zonen-ID des Vorbilds. uPG trägt neu
  registrierte Pixel in den Suchpfad "iacChn" ein. "xBorders" übergibt diese
  Pixel syystematisch an uPG bis alle Pixel geprüft sind. }

procedure tUnion.PatchGrow(
  iLat,iLon:integer; //neuer Pixel
  iVrt,iHrz:integer); //alter Pixel
{ iacCnt:tnInt; //Pixel-Indices auf Suchpfad NUR FÜR "xBorders"
  ixcIdx:tn2Int; //Zonen-IDs NUR FÜR "xBorders"
  ixcMap:tn2Byt; //Klassen-Layer NUR FÜR "xBorders"}
begin
  if (ixcMap[iLat,iLon]=ixcMap[iVrt,iHrz]) and //gleiche Klasse
     (ixcIdx[iLat,iLon]=0) then //Pixel nicht geprüft
  begin
    inc(iacChn[0]); //neuer Test
    if length(iacChn)<=iacChn[0] then
      SetLength(iacChn,length(iacChn)*2); //neuer Speicher
    iacChn[iacChn[0]]:=iLat*length(ixcMap)+iLon; //Pixelindex
    ixcIdx[iLat,iLon]:=ixcIdx[iVrt,iHrz] //ID übernehmen
  end
end;

{ uBs erzeugt Zonen aus einem Klassen-Layer. uBs bildet alle Klassen-Grenzen
  als Zonen-Grenzen ab. uBs akzeptiert als Vorbild nur einzelne Layer im Byte-
  Format. uBs interpretiert Null im Vorbild als nicht definierte Bereiche.
    uBs füllt die klassifizierten Flächen mit einem Flood-Algorithmus. Dazu
  prüft uBs systemetisch die Umgebung von jeden Pixel auf identische Nachbar-
  Pixel und erweitert den Index entsprechend. Zusammenhängende Flächen müssen
  durch mindestens eine Pixel-Kante miteinander verbunden sein. Das Vorbild
  "ixcMap", der Zonen-Index "ixcIdx" und der Suchpfad "iacChn" sind in der
  Klasse definiert um das Interface klein zu halten. }

procedure tUnion.xBorders(sImg:string); //Vorbild (Klassen)
{ iacCnt:tnInt; //Pixel-Indices auf Suchpfad NUR FÜR "xBorders"
  ixcIdx:tn2Int; //Zonen-IDs NUR FÜR "xBorders"
  ixcMap:tn2Byt; //Klassen-Layer NUR FÜR "xBorders" }
var
  iChn:integer=0; //Position aktueller Pixel in "iaxChn"
  iRes:integer=0; //Zonen-ID → Anzahl Zonen
  iHrz,iVrt:integer; //Pixel-Position
  rHdr:trHdr; //gemeinsamer Header
  X,Y:integer;
begin
  rHdr:=Header.Read(sImg); //Vorbild
  //if rHdr.Fmt<>1 then
  ixcMap:=Image.ReadThema(rHdr,sImg); //Klassen-Layer lesen
  ixcIdx:=Tools.Init2Integer(rHdr.Lin,rHdr.Scn,0); //Zonen-IDs, leer
  iacChn:=Tools.InitInteger($100,0); //Pixelindices geprüfte Pixel, leer
  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
    begin
      if ixcMap[Y,X]=0 then continue; //Bild nicht definiert
      if ixcIdx[Y,X]>0 then continue; //Zonen-ID vergeben
      inc(iRes); //neue Zone
      iacChn[0]:=1; //ein gültiger Eintrag
      iacChn[1]:=Y*rHdr.Lin+X; //erster Pixelindex
      iChn:=1; //Position der Prüfung
      ixcIdx[Y,X]:=iRes; //Wert vergeben
      repeat
        iVrt:=iacChn[iChn] div rHdr.Lin;
        iHrz:=iacChn[iChn] mod rHdr.Lin;
        if iVrt>0 then PatchGrow(pred(iVrt),iHrz,iVrt,iHrz);
        if iHrz>0 then PatchGrow(iVrt,pred(iHrz),iVrt,iHrz);
        if iVrt<high(ixcMap) then PatchGrow(succ(iVrt),iHrz,iVrt,iHrz);
        if iHrz<high(ixcMap[0]) then PatchGrow(iVrt,succ(iHrz),iVrt,iHrz);
        inc(iChn) //nächster Pixel
      until iChn>iacChn[0];
    end;
  Tools.HintOut('Union.Borders: '+IntToStr(iRes));
  Image.WriteBand(tn2Sgl(ixcIdx),-1,eeHme+cfIdx); //Bilddaten schreiben
  Header.WriteIndex(iRes,rHdr,eeHme+cfIdx); //Index-Header dazu
  Build._IndexTopology(iRes,ixcIdx); //Topologie-Tabelle
  Gdal.ZonalBorders(eeHme+cfIdx); //Zellgrenzen als Shape
  SetLength(ixcIdx,0);
  SetLength(ixcMap,0);
  SetLength(iacChn,0);
  Header.Clear(rHdr);
end;

initialization

  Drain:=tDrain.Create;
  Drain.ixcIdx:=nil;
  Drain.racLnk:=nil;
  Union:=tUnion.Create;
  Union.ixcIdx:=nil;
  Union.ixcMap:=nil;
  Union.iacChn:=nil;

finalization

  SetLength(Union.ixcIdx,0);
  SetLength(Union.ixcMap,0);
  SetLength(Union.iacChn,0);
  Union.Free;
  SetLength(Drain.ixcIdx,0);
  SetLength(Drain.racLnk,0);
  Drain.Free;

end.

{==============================================================================}

{ fZK bestimmt Kernel-Attribute mit Zonen als Kernel und speichert das Ergebnis
  in der Attribut-Tabelle "index.bit". fZK ergänzt die Prozess-Namen im Index-
  Header als Feldnamen. }

procedure tBuild._xZonesKernel_(
  slCmd:tStringList;//Prozess-Namen
  sImg:string); //Dateiname Vorbild
const
  cCmd = 'bZK: Command not defined in this context: ';
  cFex = 'bZK: Image not found: ';
var
  faDvs:tnSgl=nil; //Werte (Diversity) pro Zone
  fxImg:tn3Sgl=nil; //Vorbild, alle Kanäle
  ixIdx:tn2Int=nil; //Zonen-IDs
  rHdr,rIdx:trHdr; //Metadaten
  C:integer;
begin
  if slCmd=nil then exit; //keine Befehle
  if not FileExists(sImg) then Tools.ErrorOut(cFex+sImg);
  // slCmd muss gefiltert sein ← "Parse.KernelCmd"

  rIdx:=Header.Read(eeHme+cfIdx); //Metadaten Zonenindex
  ixIdx:=tn2Int(Image.ReadBand(0,rIdx,eeHme+cfIdx)); //Zonen-Bild
  if FileExists(eeHme+cfAtr) //Attribute vorhanden
    then rIdx.Fld:=rIdx.Fld+','+slCmd.CommaText //Feldnamen aus Bilddaten ergänzen
    else rIdx.Fld:=slCmd.CommaText; //Feldnamen ersetzen
  Header.Write(rIdx,'Imalys Cell Index',eeHme+cfIdx); //Header mit Feldnamen
  rHdr:=Header.Read(sImg); //Metadaten Vorbild
  fxImg:=Image.Read(rHdr,sImg); //Stack für Attribute aus Bilddaten
  for C:=0 to pred(slCmd.Count) do //alle Befehle
  begin
    if slCmd[C]=cfDvn then faDvs:=Deviation(fxImg,rIdx.Cnt,ixIdx) else //Abweichung
    if slCmd[C]=cfNrm then faDvs:=NormalZ(fxImg,rIdx.Cnt,ixIdx) else //normalisierte Textur
        Tools.ErrorOut(cCmd+slCmd[C]); //nicht definierter Befehl
    Tools.BitInsert(faDvs,$FFF,eeHme+cfAtr); //Attribute erzeugen oder erweitern
  end;
  Header.Clear(rHdr);
  Header.Clear(rIdx);
  Tools.HintOut('Build.ZonesKernel: '+slCmd.CommaText);
end;

{ IT erzeugt eine heterogene Tabelle "topology.bit". Die Tabelle enthält in
  der ersten Spalte den Index "iaDim" mit der Zahl der Einträge pro Zelle, in
  der zweiten Spalte "iaNbr" für jede Zelle die IDs aller Nachbarzellen und in
  der dritten Spalte "iaPrm" die Anzahl der Kontakte. IT enthält auch innere
  Kontakte. IT ignoriert NoData-Pixel.
    IT erzeugt znächst ein Zwischenprodukt "ixNbr" und "ixPrm" die für jede
  Zelle ein eigenes Array besitzen. Die Anzahl der gültigen Einträge steht in
  "iaNbr[?,0]". IT passt die Länge der Arrays dynamisch an den Bedarf an. IT
  scannt den Zellindex getrennt vollständig horizontal und vertikal. Am Ende
  übersetzt IT die Zwischenprodukte in die Tabelle und speichert sie als BIT-
  Datei. }

procedure tBuild._Index_Topology_(ixIdx:tn2Int; var r_Hdr:trHdr);
var
  ixNbr: Tn2Int=nil; //Nachbar-Zell-IDs
  ixPrm: Tn2Int=nil; //Kontakte zu Nachbar-Zellen

procedure lLink(const iLow,iHig:integer);
var
  N: integer;
begin
  if (iLow<1) or (iHig<1) then exit; //NoData ignorieren

  for N:=1 to ixNbr[iLow,0] do
    if ixNbr[iLow,N]=iHig then
    begin
      inc(ixPrm[iLow,N]);
      exit;
    end; //if iaNbr[iLow,N]=iHig

  inc(ixNbr[iLow,0]);
  if ixNbr[iLow,0]>high(ixNbr[iLow]) then
  begin
    SetLength(ixNbr[iLow],ixNbr[iLow,0]*2);
    SetLength(ixPrm[iLow],ixNbr[iLow,0]*2);
  end; //if ixNbr[iLow,0] ..
  ixNbr[iLow,ixNbr[iLow,0]]:=iHig;
  ixPrm[iLow,ixNbr[iLow,0]]:=1;
end; //lLink.

procedure lLinksIndex(ixIdx:tn2Int);
var
  X,Y,Z: integer;
begin
  for Z:=1 to r_Hdr.Cnt do
  begin
    ixNbr[Z]:=Tools.InitInteger(7,0);
    ixPrm[Z]:=Tools.InitInteger(7,0);
  end; //if ixFtr[1,Z]<iMin

  for Y:=1 to pred(r_Hdr.Lin) do
    for X:=0 to pred(r_Hdr.Scn) do
    begin
      lLink(ixIdx[pred(Y),X],ixIdx[Y,X]);
      lLink(ixIdx[Y,X],ixIdx[pred(Y),X]);
    end; //for X ..

  for Y:=0 to pred(r_Hdr.Lin) do
    for X:=1 to pred(r_Hdr.Scn) do
    begin
      lLink(ixIdx[Y,pred(X)],ixIdx[Y,X]);
      lLink(ixIdx[Y,X],ixIdx[Y,pred(X)]);
    end; //for X ..
end; //lLinksIndex.

procedure lInternal;
var
  N,Z: integer;
begin
  for Z:=1 to r_Hdr.Cnt do
    for N:=1 to ixNbr[Z,0] do
      if ixNbr[Z,N]=Z then
        ixPrm[Z,N]:=ixPrm[Z,N] div 2;
end; //lInternal.

procedure lIndexSave;
var
  iaDim: TnInt=nil; //Abschnitte in "iaNbr"
  iaNbr: TnInt=nil; //Zell-ID Kontakt
  iaPrm: TnInt=nil; //Anzahl Kontakte
var
  iDim: integer; //Topologie-Dimension bis zur Zelle "Z"
  Z: integer;
begin
  iaDim:=Tools.InitInteger(succ(r_Hdr.Cnt),0);
  iaNbr:=Tools.InitInteger(succ(r_Hdr.Cnt),0);
  iaPrm:=Tools.InitInteger(succ(r_Hdr.Cnt),0);
  for Z:=1 to r_Hdr.Cnt do
  begin
    iDim:=iaDim[pred(Z)]+ixNbr[Z,0]; //neue Dimension
    if iDim>high(iaNbr) then
    begin
      SetLength(iaNbr,round(iDim*sqrt(2)));
      SetLength(iaPrm,length(iaNbr));
    end; //if iaDim[pred(Z)] ..
    move(ixNbr[Z,1],iaNbr[iaDim[pred(Z)]],ixNbr[Z,0]*SizeOf(integer));
    move(ixPrm[Z,1],iaPrm[iaDim[pred(Z)]],ixNbr[Z,0]*SizeOf(integer));
    iaDim[Z]:=iDim;
    SetLength(ixNbr[Z],0); //Speicher freigeben
    SetLength(ixPrm[Z],0);
  end; //for Z ..
  SetLength(iaNbr,iaDim[r_Hdr.Cnt]); //Speicher reduzieren
  SetLength(iaPrm,iaDim[r_Hdr.Cnt]);
  DeleteFile(eeHme+cfTpl);
  Tools.BitInsert(tnSgl(iaDim),0,eeHme+cfTpl);
  Tools.BitInsert(tnSgl(iaNbr),1,eeHme+cfTpl);
  Tools.BitInsert(tnSgl(iaPrm),2,eeHme+cfTpl);
end; //lIndexSave.

const
  cIdx = 'iPIT: Cell index file not provided: ';
begin
  if not FileExists(eeHme+cfIdx) then Tools.ErrorOut(cIdx+eeHme+cfIdx);
  ixNbr:=Tools.Init2Integer(succ(r_Hdr.Cnt),1,0); //Container
  ixPrm:=Tools.Init2Integer(succ(r_Hdr.Cnt),1,0);
  lLinksIndex(ixIdx); //Pixel-Kontakte indizieren (Y*2)
  lInternal; //interne Grenzen einfach zählen
  lIndexSave; //Topologie indizieren und speichern (Z)
  Tools.HintOut('Union.IndexTopology: '+cfTpl)
end;

