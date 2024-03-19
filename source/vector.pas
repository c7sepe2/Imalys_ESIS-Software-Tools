unit vector; //+miscellanous

{ VECTOR sammelt Routinen um Vektoren zu transformieren und zu attributieren.
  Dazu werden alle Vektor-Dateien als "vector.csv" importiert, zeilenweise
  bearbeitet, die ergebnis-Zeilen als "focus.csv" und "focus.csvt" gespeichert
  und zum Schluss in einem wählbaren Vektor-Format exportiert. In- und Export
  erledigt "gdal.ogr2ogr".
  ==> https://gdal.org/drivers/vector/csv.html beschreibt das CSV-Frmat
  ==> https://gdal.org/ dokumentiert

  COVER:  transformiert und vereinigt Koordinaten und Rahmen
  POINTS: erzeugt, transformiert und attributiert Vektor-Punkte
  LINES:  erzeugt Abfluss Diagramme als Linien-Vektoren
  TABLE:  liest und schreibt Werte in einer CSV-Tabelle

  BEGRIFFE:}

{$mode objfpc}{$H+}

interface

uses
  Classes, Math, StrUtils, SysUtils, format;

type
  tCover = class(tObject)
    private
      function _EnviFrame_(sImg:string):trCvr;
      function _FrameFit_(arRoi:tarGeo; sMsk:string):tStringList;
      function _LandsatFrame_(sArc:string):tarGeo;
      function _PointInside_(rPnt:trGeo; rPly:tarGeo):boolean;
      function RasterFrame(sImg:string):trCvr;
    public
      procedure ClipToFrame(sFrm,sImg:string);
      function CrsInfo(sImg:string):integer;
      function CutFrame(rFrm:trFrm; sImg:string):trFrm;
      function _LargeFrame_(iEpg:integer):trFrm;
      function MergeFrames(slImg:tStringList):trFrm;
      function VectorCrsFrame(iEpg:integer; sVct:string):trFrm;
      function VectorFrame(sFrm:string):trFrm;
  end;

  tLines = class(tObject) //Bilddaten verändern
    private
      function _BoundingBox_(raLnk:tarFrm):trFrm;
      function _Coordinates(iaNxt,iaPix:tnInt; var rHdr:trHdr):tarFrm;
    public
      procedure _RunOff_(iCrs:integer; sGml:string);
      procedure _LinesOut(iPrj:integer; sImg:string);
  end;

  tPoints = class(tObject) //Punkt-Vektor Anwendungen <== tTable?
    private
      function AttribValues(sFtr:string):tn2Sgl;
      procedure DefaultFormat(iFtr:integer);
      procedure FieldTypes(sVct:string);
      procedure FormatAppend(iFtr:integer);
      function GetIndex(var rHdr:trHdr):tnInt;
      procedure PixMask(iaPix:tnInt; sTmp:string);
      function PointAttributes(iaPix:tnInt; var rHdr:trHdr; sBnd:string):tnSgl;
      procedure _RandomPoints_(iCnt:integer; sImg:string);
      procedure PointAppend(fxVal:tn2Sgl; sFtr:string);
      procedure ValueAppend(fxVal:tn2Sgl; sFtr:string);
    public
      procedure xPointAttrib(iCrs:integer; sFtr,sPnt:string);
      procedure xPolyAttrib;
  end;

  tTable = class(tObject)
    private
      procedure AddFormat(sFmt:string);
      procedure AddInteger(iaVal:tnInt; sFtr:string);
      function FieldValues(sFld:string):tStringList;
    public
      function AddThema(sFld:string):tStringList;
  end;

var
  Cover:tCover;
  Lines:tLines;
  Points:tPoints;
  Table:tTable;

implementation

uses
  mutual, raster;

{ fPA gibt die Werte einzelner Pixel aus dem Kanal "sBnd" zurück. Die Position
  der Pixel muss als Pixel-Index in "iaPix" übergeben werden. }

function tPoints.PointAttributes(
  iaPix:tnInt; //Indices ausgewählter Pixel
  var rHdr:trHdr; //Metadaten
  sBnd:string): //Bild-Name
  tnSgl; //Werte der ausgewählten Pixel
const
  cPix = 'fPA: List of pixel indices must be provided!';
var
  fxBnd:tn2Sgl=nil; //aktueller Kanal
  iCnt:integer; //Anzahl Pixel
  I:integer;
begin
  if iaPix=nil then Tools.ErrorOut(cPix);
  Result:=Tools.InitSingle(length(iaPix),dWord(Nan)); //Vorgabe
  iCnt:=rHdr.Scn*rHdr.Lin; //Anzahl Pixel
  fxBnd:=Image.ReadBand(0,rHdr,sBnd); //Bildkanal
  for I:=0 to high(iaPix) do
    if (iaPix[I]>=0) and (iaPix[I]<iCnt) then
      with rHdr do
        Result[I]:=fxBnd[iaPix[I] div Scn,iaPix[I] mod Scn];
  Tools.HintOut('Points.Attributes: menory');
end;

function tLines._Coordinates(
  iaNxt:tnInt; //Zellindex der verknüpften Zelle
  iaPix:tnInt; //Pixelindex des Minimums jeder Zelle
  var rHdr:trHdr): //Metadaten
  tarFrm; //Koordinaten für zwei Punkte = [Lft,Top] – [Rgt,Btm]
{ lC konvertiert Pixel-Koordinaten in geographische Koordinaten und gibt sie
  als "tBox" zurück. lC übernimmt die Projektion aus dem ENVI-Header in "rHdr".
  Die Koordinaten im ENVI-Header beziehen sich auf die linke untere Ecke des
  Bilds. lC korrigiert auf Pixelmitte. lC ist auf Linien aus zwei Punkten
  spezialisiert. }
var
  fLat,fLon:single; //Kordinaten-ursprung für Pixelmitte
  Z:integer;
begin
  SetLength(Result,length(iaPix));
  fLon:=rHdr.Lon+0.5*rHdr.Pix; //Ursprung auf Pixelmitte
  fLat:=rHdr.Lat-0.5*rHdr.Pix;
  for Z:=1 to high(iaPix) do
    if iaNxt[Z]>0 then
    begin
      Result[Z].Lft:=fLon+(iaPix[Z] mod rHdr.Scn)*rHdr.Pix; //Geo-Koordinaten aus Pixelkoordinaten
      Result[Z].Top:=fLat-(iaPix[Z] div rHdr.Scn)*rHdr.Pix;
      Result[Z].Rgt:=fLon+(iaPix[iaNxt[Z]] mod rHdr.Scn)*rHdr.Pix;
      Result[Z].Btm:=fLat-(iaPix[iaNxt[Z]] div rHdr.Scn)*rHdr.Pix;
    end
    else Result[Z]:=crFrm; //Vorgabe
end;

function tLines._BoundingBox_(raLnk:tarFrm):trFrm;
{ lBB bestimmt ein einschließendes Rechteck aus allen Koordinaten in "raLnk" }
const
  cMax:single=MaxInt;
var
  Z:integer;
begin
  Result:=crFrm; //Vorgabe, nicht definiert
  for Z:=1 to high(raLnk) do
    if raLnk[Z].Lft<cMax then
    begin
      Result.Lft:=min(raLnk[Z].Lft,Result.Lft);
      Result.Top:=max(raLnk[Z].Top,Result.Top);
      Result.Rgt:=max(raLnk[Z].Rgt,Result.Rgt);
      Result.Btm:=min(raLnk[Z].Btm,Result.Btm);
    end;
end;

procedure tLines._RunOff_( //==> mit "resistance" = RST verknüpft
  iCrs:integer; //EPSG-Code
  sGml:string); //Dateiname
{ lRO überträgt Abfluss-Attribute aus "index.bit" in Linien-Polygone aus
  jeweils zwei Punkten. Attribute sind eine fortlaufende ID und der Abfluss.
  lRO bietet keine Format-Altenativen. }
const
  cGml = 'Impossible to create file ';
var
  dGml: TextFile; //Initialisierung
  faWgt:tnSgl=nil; //scalares Attribut
  iaNxt:tnInt=nil; //Pixelindex der verknüpften Zelle
  iaPix:tnInt=nil; //Pixelindex der Zelle
  raLnk:tarFrm=nil; //Punkt-Verknüpfungen
  iFtr:integer=0; //fortlaufende Nummer
  rFrm:trFrm; //Bounding-Box
  rHdr:trHdr; //Metadaten Zellindex
  sCrs:string=''; //EPSG-Code ausgeschrieben
  Z:integer;
begin
  iaPix:=tnInt(Tools.BitExtract(0,eeHme+cfIdx)); //Quelle-Pixelindex
  iaNxt:=tnInt(Tools.BitExtract(1,eeHme+cfIdx)); //Senke-Zellindex
  faWgt:=Tools.BitExtract(4,eeHme+cfIdx); //Attribut
  rHdr:=Header.Read(eeHme+cfIdx); //Pixelgröße, Koordinaten
  sCrs:='"EPSG:'+IntToStr(iCrs)+'"'; //ausgeschrieben
  sGml:=ExtractFileName(ChangeFileExt(sGml,'')); //ohne Pfad, ohne Extension
  raLnk:=_Coordinates(iaNxt,iaPix,rHdr); //Geo-Koordinaten aus Pixelindices
  rFrm:=_BoundingBox_(raLnk); //Bounding-Box
  try
    AssignFile(dGml,eeHme+sGml+cfGml);
    {$i-} Rewrite(dGml); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cGml+sGml);
    writeln(dGml,'<?xml version="1.0" encoding="utf-8" ?>');
    writeln(dGml,'<ogr:FeatureCollection');
    writeln(dGml,'     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
    writeln(dGml,'     xsi:schemaLocation="http://ogr.maptools.org/ gml_test.xsd"');
    writeln(dGml,'     xmlns:ogr="http://ogr.maptools.org/"');
    writeln(dGml,'     xmlns:gml="http://www.opengis.net/gml">');
    writeln(dGml,'  <gml:boundedBy>');
    writeln(dGml,'    <gml:Box>');
    writeln(dGml,'      <gml:coord><gml:X>'+FloatToStr(rFrm.Lft)+'</gml:X>'+
      '<gml:Y>'+FloatToStr(rFrm.Top)+'</gml:Y></gml:coord>');
    writeln(dGml,'      <gml:coord><gml:X>'+FloatToStr(rFrm.Rgt)+'</gml:X>'+
      '<gml:Y>'+FloatToStr(rFrm.Btm)+'</gml:Y></gml:coord>');
    writeln(dGml,'    </gml:Box>');
    writeln(dGml,'  </gml:boundedBy>');
    for Z:=1 to high(iaPix) do
      if iaNxt[Z]>0 then
      begin
        writeln(dGml,'  <gml:featureMember>');
        writeln(dGml,'    <ogr:'+sGml+' fid="'+sGml+'.'+IntToStr(iFtr)+'">');
        writeln(dGml,'      <ogr:geometryProperty>'+'<gml:MultiLineString '+
          'srsName='+sCrs+'><gml:lineStringMember><gml:LineString>'+
          '<gml:coordinates>'+
          FloatToStr(raLnk[Z].Lft)+','+FloatToStr(raLnk[Z].Top)+#32+
          FloatToStr(raLnk[Z].Rgt)+','+FloatToStr(raLnk[Z].Btm)+
          '</gml:coordinates></gml:LineString></gml:lineStringMember>',
          '</gml:MultiLineString></ogr:geometryProperty>');
        writeln(dGml,'      <ogr:id>'+IntToStr(succ(iFtr))+'</ogr:id>');
        writeln(dGml,'      <ogr:flow>'+FloatToStr(faWgt[Z])+'</ogr:flow>');
        writeln(dGml,'    </ogr:'+sGml+'>');
        writeln(dGml,'  </gml:featureMember>');
        inc(iFtr); //fortlaufend zählen
      end;
    writeln(dGml,'</ogr:FeatureCollection>');
  finally
    Flush(dGml);
    CloseFile(dGml);
  end; //of try ..
  Header.Clear(rHdr);
end;

function _PointAttributes(
  iaPix:tnInt; //Indices ausgewählter Pixel
  var rHdr:trHdr; //Metadaten
  sBnd:string): //Bild-Name
  tnSgl; //Werte der ausgewählten Pixel
{ fPA gibt die Werte einzelner Pixel aus dem Kanal "sBnd" zurück. Die Position
  der Pixel wird als Pixel-Indices in "iaPix" übergeben. }
var
  fxBnd:tn2Sgl=nil; //Kanal
  I:integer;
begin
  fxBnd:=Image.ReadBand(0,rHdr,sBnd); //Bildkanal
  Result:=Tools.InitSingle(length(iaPix),dWord(Nan)); //Vorgabe
  for I:=0 to high(iaPix) do
    with rHdr do
      Result[I]:=fxBnd[iaPix[I] div Scn,iaPix[I] mod Scn];
end;

{ TODO: [Poits.GetIndex] "ExtractWord" prüft nicht, ob die Klammern in der
        richtigen Reihenfolge verwendet werden, Doppelhochkomma werden nicht
        verifiziert }

{ fGI liest projizierte Koordinaten von Vektor-Punkten im WKT-Format aus einer
  CSV Datei und transformiert sie in Pixel-Indices. Für Punkte außerhalb der
  Bildfläche gibt fGI (-1) zurück. Der Pixel-Ursprung ist links oben. }

function tPoints.GetIndex(
  var rHdr:trHdr): //Metadaten Vorbild
  tnInt; //Pixel-Indices[Vektor-Punkt]
const
  cCsv = 'Impossible to read file: ';
  cPnt = 'Not a WKT point format: ';
  cWkt = 'Geometry must be WKT formatted: ';
var
  dCsv:TextFile; //Datei
  fLat,fLon:single; //aktuelle Koordinaten (Ursprung links unten)
  iHrz,iVrt:integer; //Pixel-Koordinaten (Ursprung links oben)
  nRes:integer=0; //Dimension Pixelindices
  sLin:string; //aktuelle Zeile
begin
  SetLength(Result,$FF); //nicht definiert
  try
    AssignFile(dCsv,eeHme+cfVct);
    {$i-} Reset(dCsv); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cCsv+eeHme+cfVct);
    readln(dCsv,sLin); //Zeile mit Feldnamen
    if ExtractDelimited(1,sLin,[','])<>'WKT' then
      Tools.ErrorOut(cCsv+eeHme+cWkt);
    repeat
      readln(dCsv,sLin); //Zeile mit Koordinaten (und Attributen)
      sLin:=ExtractDelimited(1,sLin,[',']); //WKT-Geometrie
      if (pos('POINT Z',sLin)>0) or (pos('POINT',sLin)>0) then //nur Punkte
      begin
        sLin:=ExtractDelimited(2,sLin,['(',')']); //Substring in Klammern
        fLon:=StrToFloat(ExtractDelimited(1,sLin,[#32])); //1. Substring in Blankes
        fLat:=StrToFloat(ExtractDelimited(2,sLin,[#32])); //2. Substring in Blankes
        iHrz:=trunc((fLon-rHdr.Lon)/rHdr.Pix); //Pixel-Koordinaten
        iVrt:=trunc((rHdr.Lat-fLat)/rHdr.Pix);
        if (iHrz<0) or (iHrz>pred(rHdr.Scn))
        or (iVrt<0) or (iVrt>pred(rHdr.Lin))
          then Result[nRes]:=-1 //Pixel außerhhalb der Bildfläche
          else Result[nRes]:=iVrt*rHdr.Scn+iHrz; //Pixel-Index
        inc(nRes); //fortlaufend zählen
        if nRes>=length(Result) then
          SetLength(Result,nRes*2);
      end
      else Tools.ErrorOut(cPnt+eeHme+cfVct);
    until eof(dCsv);
    SetLength(Result,nRes);
  finally
    CloseFile(dCsv);
  end; //of try ..
  Tools.HintOut('Points.GetIndex: memory');
end;

procedure tPoints.PixMask(
  iaPix:tnInt; //Pixelindices als Array
  sTmp:string); //Vorbild für Geometrie
{ fPM erzeugt eine Maske aus Pixelindices und gibt sie als Klassen-Bild zurück }
var
  iCnt:integer; //Anzahl Pixel
  ixMsk:tn2Byt=nil; //Raster-Maske Testpunkte
  rHdr:trHdr;
  I:integer;
begin
  rHdr:=Header.Read(sTmp);
  ixMsk:=Tools.Init2Byte(rHdr.Lin,rHdr.Scn);
  iCnt:=rHdr.Lin*rHdr.Scn; //Anzahl Pixel
  for I:=0 to high(iaPix) do
    if (iaPix[I]>=0) and (iaPix[I]<iCnt) then //nur innerhalb der Bildfläche
      ixMsk[iaPix[I] div rHdr.Scn,iaPix[I] mod rHdr.Scn]:=1;
  Header.WriteThema(1,rHdr,'',eeHme+cfMsk);
  Image.WriteThema(ixMsk,eeHme+cfMsk);
  Header.Clear(rHdr);
end;

procedure tPoints.FieldTypes(sVct:string); //Geometrie im CSV-Format
{ pFT erzeugt eine CSVT-Datei mit Formatangaben für die Attribute der Vektor-
  Datei "sVct". pFT übernimmt aus der CSV-Datei die Feldnamen (erste Zeile) des
  Originals und verknüpft sie mit den Format-Angaben aus dem "ogrinfo"-Prozess
  des Originals. }
const
  cWkt = 'CSV vector geometry must use WKT format! ';
var
  iBrk:integer; //Grenze Feldname-Dimension
  iFld:integer; //Anzahl felder ohne "WKT"
  slIfo:tStringList=nil; //Container für OgrInfo
  sFld:string; //Feldname mit Dimension
  sTyp:string=''; //Format-String
  I:integer;
begin
  sFld:=Tools.LineRead(eeHme+cfVct); //erste Zeile der CSV-Version
  if LeftStr(sFld,3)<>'WKT' then Tools.ErrorOut(cWkt+eeHme+cfVct);
  iFld:=pred(WordCount(sFld,[','])); //Anzahl Felder ohne "WKT"
  try
    slIfo:=tStringList.Create;
    slIfo.AddText(Gdal.OgrInfo(sVct)); //Info als Stream
    for I:=pred(slIfo.Count) downto slIfo.Count-iFld do //nur Feldnamen
    begin
      iBrk:=pos(': ',slIfo[I])+2; //Grenze Name: Format
      if iBrk>2
        then sFld:=copy(slIfo[I],iBrk,$FF) //nur Format
        else sFld:=''; //Vorgabe = String
      sTyp:=','+sFld+sTyp;
    end;
  finally
    slIfo.Free;
  end;
end;

procedure tPoints._RandomPoints_(
  iCnt:integer; //Anzahl zufälliger Punkte
  sImg:string); //Bilddaten für Bounding Box
{ pRP erzeugt "iCnt" Vektor-Punkte im CSV-Format, die zufällig über die
  Bounding-Box des Bilds "sImg" verteilt sind. Die Koordinaten werden im WKT-
  Format gespeichert, einziges Attribut ist eine fortlaufende ID. }
const
  cCrt = 'pRP: Error while creating: ';
  cFmt = 'WKT,Integer(12)';
var
  dVct:TextFile; //Vektor-Punkte im CSV-Format
  fLat,fLon:double; //zufällige Koordinaten
  iHrz,iVrt:integer; //Bildgröße in Metern
  rHdr:trHdr; //Metadaten
  I:integer;
begin
  rHdr:=Header.Read(sImg);
  iHrz:=trunc(rHdr.Scn*rHdr.Pix); //Bildbreite in Metern
  iVrt:=trunc(rHdr.Lin*rHdr.Pix); //Bildhöhe in Metern
  try
    AssignFile(dVct,eeHme+cfVct); //Punkte mit ergänzten Attributen
    {$i-} Rewrite(dVct); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cCrt+eeHme+cfVct);
    writeln(dVct,'WKT,ID'); //Feldnamen
    Randomize;
    for I:=1 to iCnt do
    begin
      fLat:=rHdr.Lat-random(iVrt);
      fLon:=rHdr.Lon+random(iHrz);
      writeln(dVct,'"POINT ('+FloatToStr(fLon)+#32+FloatToStr(fLat)+')",'+
        IntToStr(I));
    end;
  finally
    Flush(dVct);
    CloseFile(dVct);
  end; //of try ..
  Header.Clear(rHdr);
  Tools.TextOut(eeHme+ChangeFileExt(cfVct,'.csvt'),cFmt) //Format der Felder
end;

function tPoints.AttribValues(sFtr:string):tn2Sgl; {lokale Bilder: Attribut-Tabelle}
{ pAV erzeugt eine Tabelle mit dem Wert der Bildpixel am Ort der Punkt-Vektoren
  "vector.csv". Die Bilddaten aus der Liste "sFtr" müssen im Imalys-Verzeichnis
  stehen. Die Punkt-Vektoren müssen im WKT-Format in "vector.csv" stehen. Bild-
  und Vektordaten müssen dieselbe Projektion haben. Die Geometrie der Bilddaten
  muss identisch sein. }
{ pAV konvertiert die Koordinaten aus "vector.csv" in einen Pixelindex. Der
  Index basiert auf der Bounding-Box des ersten Bilds in "sFtr". pAV ignoriert
  Vektor-Punkte außerhalb der Bounding-Box. }
var
  iaPix:tnInt=nil; //Pixelindices
  rHdr:trHdr; //Metadaten
  slFtr:tStringList=nil; //Dateinamen-Liste
  I:integer;
begin
// gleiches CRS bei allen Bildern und cfVct? ← EPSG überprüfen
  try
    slFtr:=tStringList.Create;
    slFtr.AddText(Tools.CommaToLine(sFtr)); //ausgewählte lokale Bilder
    rHdr:=Header.Read(eeHme+slFtr[0]); //Metadaten aus erstem Bild
    iaPix:=GetIndex(rHdr); //Pixelindices aus Vektor-Punkten
    //PixMask(iaPix,slFtr[0]); //NUR KONTROLLE DER LAGE
    SetLength(Result,slFtr.Count,1); //leere Attribut-Liste
    for I:=0 to pred(slFtr.Count) do //alle gewählten Prozesse
      Result[I]:=PointAttributes(iaPix,rHdr,eeHme+slFtr[I]); //Werte am Ort der Punkte
  finally
    slFtr.Free;
  end;
  Header.Clear(rHdr);
end;

{ fVA liest die Vorlage "vector.csv", ergänzt Attribute und speichert das
  Ergebnis als "focus.csv". fVA liest und schreibt einzelne Zeilen im Text-
  Format. fVA übernimmt die Feldnamen aus "sFtr" und die Werte der Tabelle aus
  "fxVal". Feldnamen und Werte müssen korresponieren. fVA schreibt alle Werte
  im Float-Format und markiert nicht definierte Werte als "NA". }

procedure tPoints.PointAppend(
  fxVal:tn2Sgl; //Werte[Kanal,Punkt] (aus Vorbild)
  sFtr:string); //Feldnamen = Prozess-Namen als CSV
const
  cCsv = 'fVA: File not available: ';
  cFcs = 'fVA: File creation failed: ';
  cFld = 'fVA: Number of field names differ from field values!';
  cRcd = 'fVA: Number of vector records differ from extraced values!';
var
  dCsv:TextFile; //Vektor-Import im CSV-Format
  dFcs:TextFile; //ergänzte Attribute im CSV-Format
  iRcd:integer=0; //Anzahl Punkte=Zeilen
  sLin:string; //Zeilen-Puffer
  I:integer;
begin
  if WordCount(sFtr,[','])<>length(fxVal) then
    Tools.ErrorOut(cFld);
  //length(slPrc)=length(fxVal)?
  //Anzahl Zeilen <> Länge Attribut-Arrays
  try
    AssignFile(dCsv,eeHme+cfVct); //Test-Punkte als CSV
    {$i-} Reset(dCsv); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cCsv+eeHme+cfVct);

    AssignFile(dFcs,eeHme+cfFcs); //Punkte mit ergänzten Attributen
    {$i-} Rewrite(dFcs); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cFcs+eeHme+cfFcs);

    readln(dCsv,sLin); //bestehene Feldnamen
    writeln(dFcs,sLin+','+DelSpace(sFtr)); //neuer Header
    repeat
      readln(dCsv,sLin); //bestehene Werte
      for I:=0 to high(fxVal) do //alle neuen Felder
        if not IsNan(fxVal[I,iRcd])
          then sLin+=','+FloatToStr(fxVal[I,iRcd])
          else sLin+=',NA';
      inc(iRcd); //neue Zeile
      writeln(dFcs,sLin); //Zeile speichern
    until eof(dCsv);
    if length(fxVal[0])<>iRcd then Tools.ErrorOut(cRcd);
  finally
    CloseFile(dCsv);
    Flush(dFcs);
    CloseFile(dFcs);
  end; //of try ..
end;

procedure tPoints.FormatAppend(iFtr:integer);
{ pFA erweitert die CSVT-Datei "vector.csvt" um "iFtr" neue Felder im Float-
  Format und speichert das Ergebnis als "focus.csvt". }
const
  cFlt = ',Real(24.15)';
var
  sFmt:string;
  I:integer;
begin
  sFmt:=Tools.LineRead(eeHme+ChangeFileExt(cfVct,'.csvt'));
  for I:=0 to pred(iFtr) do
    sFmt+=cFlt; //Single-Format-Code anhängen
  Tools.TextOut(ChangeFileExt(eeHme+cfFcs,'.csvt'),sFmt);
end;

{ pAt überträgt Werte von Bildpixeln in die Attribut-Tabelle von Punkt-
  Vektoren. Dazu importiert pAt die Punkte als "vector.csv", transformiert sie
  in die Projektion "iCrs", ergänzt die Werte der Attribute für alle Records,
  speichert das Ergebnis als "focus.csv" und transformiert die CSV-Datei in das
  Shape-Formet. "sFtr" muss gültige Dateinamen aus dem Imalys-Verzeichnis
  enthalten. "Raster- und CSV-Vektoren müssen dieselbe Projektion haben. }

procedure tPoints.xPointAttrib(
  iCrs:integer; //Projektion der Bilddaten
  sFtr:string; //Merkmale = Dateinamen in kommagetrennter Liste
  sPnt:string); //Vorlage Punkt-Vektoren
const
  cGeo = 'fE: Observation points file (vector) not available! ';
var
  fxVal:tn2Sgl=nil; //Attribute[Kanal][Punkt]
begin
  //alle feature-Dateien gleich groß?
  Gdal.ImportVect(iCrs,sPnt); //Punkt-Vektoren als "vector.csv"
  FieldTypes(sPnt); //CSVT-Datei mit Feldtypen aus gdal-Info
  if not FileExists(eeHme+cfVct) then
    Tools.ErrorOut(cGeo+eeHme+cfVct);
  fxVal:=AttribValues(sFtr); //Attribute an gewählten Punkten
  PointAppend(fxVal,sFtr); //Feldnamen + Attribute im CSV erweitern
  FormatAppend(high(fxVal)); //Formatangaben als CSVT erweitern
  //Gdal.ExportShape(False,iCrs,eeHme+cfFcs+'.csv',sTrg); //als ESRI-Shape speichern
  Gdal.ExportShape(iCrs,eeHme+cfFcs,ChangeFileExt(eeHme+cfFcs,'.shp')); //als ESRI-Shape speichern
  Tools.HintOut('Points.Attributes: '+cfFcs)
end;

procedure tLines._LinesOut(
  iPrj:integer; //EPSG-Code
  sImg:string); //Vorbild Dateiname
const
  cCsv = 'lLO: Unable to create: ';
var
  dCsv: TextFile; //Initialisierung
  faVal:tnSgl=nil; //Abfluss als Attribut
  iaNxt:tnInt=nil; //Verknüpfung der lokalen Minima
  iaPix:tnInt=nil; //Pixelindices zu allen lokalen Minima
  iVid:integer=0; //Vektor-ID
  raLnk:tarFrm=nil; //Linien zwische zwei Punkten (Left-Top → Right-Bottom)
  rHdr:trHdr; //Metadaten (Geometrie!) aus Vorbild
  sLin:string; //NUR TEST
  sOut:string; //Ergebnis-Dateiname (Vector)
  Z:integer;
begin
  //length(iaPix)=length(faFlw)=length(iaNxt)…
  iaPix:=tnInt(Tools.BitExtract(0,eeHme+cfIdx)); //Quelle-Pixelindex
  iaNxt:=tnInt(Tools.BitExtract(1,eeHme+cfIdx)); //Verknüpfung der Indices
  faVal:=Tools.BitExtract(4,eeHme+cfIdx); //Abfluss als Attribut
  rHdr:=Header.Read(sImg); //Metadaten aus erstem Prozess
  raLnk:=_Coordinates(iaNxt,iaPix,rHdr); //Verknüpfung als Koordinaten (LT→RB)
  try
    AssignFile(dCsv,eeHme+cfVct);
    {$i-} Rewrite(dCsv); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cCsv+cfVct);
    writeln(dCsv,'WKT,id,index,link,flow');
    for Z:=0 to high(iaNxt) do
      if iaNxt[Z]>0 then
        with raLnk[Z] do
        begin
          inc(iVid); //Linien zählen
          sLin:='"MULTILINESTRING (('+
            FloatToStr(Lft)+#32+FloatToStr(Top)+','+ //Quelle
            FloatToStr(Rgt)+#32+FloatToStr(Btm)+'))"'+ //Senke
            ','+IntToStr(iVid)+ //ID (mit Anführungszeichen)
            ','+IntToStr(Z)+ //Verknüpfung (mit Anführungszeichen)
            ','+IntToStr(iaNxt[Z])+ //Verknüpfung (mit Anführungszeichen)
            ','+FloatToStr(faVal[Z]); //Abfluss (ohne Anführungszeichen)
          writeln(dCsv,sLin);
        end;
  finally
    Flush(dCsv);
    CloseFile(dCsv);
  end; //of try ..
  sOut:=eeHme+'FLW_'+ExtractFileName(sImg);
  Gdal.ExportShape(iPrj,eeHme+cfVct,sOut);
  Header.Clear(rHdr);
end;

{ pVA liest die Vorlage "vector.csv", ergänzt numerische Attribute und
  speichert das Ergebnis als "focus.csv". pVA liest und schreibt einzelne
  Zeilen im Textformat. pVA übernimmt die Feldnamen aus "sFtr" und die Werte
  der Tabelle aus "fxVal". Feldnamen und Werte müssen korresponieren. pVA
  schreibt alle Werte im Float-Format und markiert nicht definierte Werte als
  "NA". }

procedure tPoints.ValueAppend(
  fxVal:tn2Sgl; //Werte[Kanal,Punkt] (aus Vorbild)
  sFtr:string); //Feldnamen = Prozess-Namen als CSV
const
  cAtr = 'pVA: Geometry import must contain only a WKT and a DN field!';
  cCsv = 'pVA: File not available: ';
  cFcs = 'pVA: File creation failed: ';
  cRcd = 'pVA: Record-ID not provided by index attributes: ';
var
  dCsv:TextFile; //Vektor-Import im CSV-Format
  dFcs:TextFile; //ergänzte Attribute im CSV-Format
  iRcd:integer; //Anzahl Punkte=Zeilen
  sLin:string; //Zeilen-Puffer
  I:integer;
begin
  try
    AssignFile(dCsv,eeHme+cfVct); //bestehende Geometrie als CSV
    {$i-} Reset(dCsv); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cCsv+eeHme+cfVct);

    AssignFile(dFcs,eeHme+cfFcs); //Geometrie mit Attributen
    {$i-} Rewrite(dFcs); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cFcs+eeHme+cfFcs);

    readln(dCsv,sLin); //bestehene Feldnamen
    if sLin<>'WKT,DN' then Tools.ErrorOut(cAtr);
    writeln(dFcs,'WKT,DN,'+DelSpace(sFtr)); //erweiterte Feldnamen
    repeat
      readln(dCsv,sLin); //bestehene Werte
      iRcd:=rPos(',',sLin); //letztes Komma
      iRcd:=StrToInt(copy(sLin,iRcd+2,length(sLin)-iRcd-2)); //Record-ID
      if iRcd>high(fxVal[0]) then Tools.ErrorOut(cRcd+IntToStr(iRcd));
      for I:=0 to high(fxVal) do //alle Attribute
        if not IsNan(fxVal[I,iRcd])
          then sLin+=','+FloatToStr(fxVal[I,iRcd])
          else sLin+=',NA';
      writeln(dFcs,sLin); //Zeile speichern
    until eof(dCsv);
  finally
    CloseFile(dCsv);
    Flush(dFcs);
    CloseFile(dFcs);
  end; //of try ..
end;

procedure tPoints.DefaultFormat(iFtr:integer);
{ pDF erzeugt eine CSVT-Datei für eine WKT-Geometrie mit Attributen. Die "DN"
  für die Datensätze ist "integer", alle Attribute sind "real". pDF speichert
  das Ergebnis als "focus.csvt". }
const
  cFlt = ',Real(24.15)';
  cInt = ',Integer(9.0)';
var
  sFmt:string;
  I:integer;
begin
  sFmt:='WKT'+cInt; //Geometrie und "DN"
  for I:=0 to pred(iFtr) do
    sFmt+=cFlt; //Single-Format für alle Attribute
  Tools.TextOut(ChangeFileExt(eeHme+cfFcs,'.csvt'),sFmt);
end;

{ pPA überträgt die Attribut-Tabelle "index.bit" auf die Geometrie "vector.csv"
  und speichert das Ergebnis als "focus.csv". "vector.csv" muss existieren und
  darf keine Attribute enthalten. pPn läd die Polygone einzeln als Textzeile,
  ergänzt alle Werte aus der Attribut-Tabelle und schreibt die erweiterten
  Zeilen nach "focus.csv". Zum Schluss erzeugt pPn eine angepasste "focus.csvt"
  Datei. qGis kann "focus.csv" direkt lesen. }

procedure tPoints.xPolyAttrib;
const
  cVal = 'pPA: Number of fields at index table differs from field names!';
  cVct = 'pPA: Geometry file not found: ';
var
  fxVal:tn2Sgl=nil; //Zell-Attribute als Maxtrix
  sFtr:string=''; //Liste mit Feldnamen aus Index-Header
begin
  if not FileExists(eeHme+cfVct) then Tools.ErrorOut(cVct+eeHme+cfVct);
  sFtr:=Header.ReadLine('field names =',eeHme+cfIdx); //Liste mit Feldnamen (CSV)
  fxVal:=Tools.BitRead(eeHme+cfIdx); //aktuelle Zellindex-Attribute als Matrix
  if WordCount(sFtr,[','])<>length(fxVal) then Tools.ErrorOut(cVal);
  ValueAppend(fxVal,sFtr); //"vector.csv" mit Attributen als "focus.csv" speichern
  DefaultFormat(length(fxVal)); //CSVT-Datei für Attribute
  Tools.HintOut('Points.Attributes: '+cfFcs);
end;

function tTable.FieldValues(sFld:string):tStringList;
{ tFV gibt alle Werte aus dem Feld "sFld" in der Tabelle von "vector.csv" als
  String-Liste zurück. tFV unterstellt, dass "vector.csv" Polygone im WKT-
  Format enthält. }
const
  cCsv = 'Impossible to read file: ';
  cFld = 'Field name not provided: ';
  cWkt = 'Geometry must be WKT formatted: ';
var
  dCsv:TextFile; //Datei
  iCol:integer=0; //Spalte für gesuchtes Feld
  iWkt:integer; //Ende Polygon-Teil
  sLin:string; //aktuelle Zeile
  I:integer;
begin
  Result:=tStringList.Create;
  try
    AssignFile(dCsv,eeHme+cfVct);
    {$i-} Reset(dCsv); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cCsv+eeHme+cfVct);
    readln(dCsv,sLin); //Zeile mit Feldnamen
    if ExtractDelimited(1,sLin,[','])<>'WKT' then
      Tools.ErrorOut(cCsv+eeHme+cWkt);
    for I:=2 to WordCount(sLin,[',']) do
      if ExtractDelimited(I,sLin,[','])=sFld then iCol:=pred(I); //Spalte mit Feldnamen ohne "WKT"
    if iCol<1 then Tools.ErrorOut(cFld+sFld);
    repeat
      readln(dCsv,sLin); //ab zweite Zeile = Inhalte
      iWkt:=PosEx('"',sLin,2); //Position zweites Doppelhochkomma
      Delete(sLin,1,succ(iWkt)); //Polygon-Teil + Komma entfernen
      Result.Add(trim(ExtractDelimited(iCol,sLin,[',']))); //Bezeichner ohne Leerzeichen
    until eof(dCsv);
  finally
    CloseFile(dCsv);
  end;
end;

{ TODO: [Table.AddInteger] zusammenfassen:
        → "AppendField" mit ALLEN 32-Bit-Zahlen
          → evt verschiedene Namen für verschiedene Formate
        → analog AppemdTable
        → AppendString? nötig }

{ tAI erweitert die Tabelle aus "vector.csv" um das Integer-Feld "sFtr"-ID.
  Dazu muss die Tabelle als "focus.csv" neu geschrieben werden. tAI unterstellt
  dass "vector.csv" Polygone im WKT-Format enthält. }

procedure tTable.AddInteger(
  iaVal:tnInt; //Werte (Liste) Index wie Vektoren
  sFtr:string); //neue Feldnamen, kommagetrennt
const
  cAtr = 'pVA: Geometry import must contain a WKT field!';
  cCsv = 'pVA: File not available: ';
  cFcs = 'pVA: File creation failed: ';
var
  dCsv:TextFile; //Vektor-Import im CSV-Format
  dFcs:TextFile; //ergänzte Attribute im CSV-Format
  iCnt:integer=0; //Zeilen-ID (ab Null)
  sLin:string; //Zeilen-Puffer
begin
  try
    AssignFile(dCsv,eeHme+cfVct); //bestehende Geometrie als CSV
    {$i-} Reset(dCsv); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cCsv+eeHme+cfVct);

    AssignFile(dFcs,eeHme+cfFcs); //Geometrie mit Attributen
    {$i-} Rewrite(dFcs); {$i+}
    if IOResult<>0 then Tools.ErrorOut(cFcs+eeHme+cfFcs);

    readln(dCsv,sLin); //bestehene Feldnamen
    if LeftStr(sLin,3)<>'WKT' then Tools.ErrorOut(cAtr);
    if sFtr[1]<>',' then sFtr:=','+sFtr; //führendes Komma
    writeln(dFcs,sLin+DelSpace(sFtr)); //erweiterte Feldnamen
    repeat
      readln(dCsv,sLin); //bestehene Werte
      //if not IsNan(fxVal[I,iRcd]) .. sLin+='NA'
      sLin+=','+FloatToStr(iaVal[iCnt]); //Wert ergänzen
      writeln(dFcs,sLin); //Zeile speichern
      inc(iCnt) //Zeilen-Index
    until eof(dCsv);
  finally
    CloseFile(dCsv);
    Flush(dFcs);
    CloseFile(dFcs);
  end; //of try ..
  Tools.HintOut('Table.AddInteger: '+cfFcs);
end;

procedure tTable.AddFormat(sFmt:string);
{ tAF erweitert die CSVT-Tabelle um den Eintrag "sFmt". "vector.csvt" muss
  existieren. tAF schreibt nach "focus.csvt". }
const
  cVct = 'Vector format definition vector.CSVT needed!';
begin
  if not FileExists(ChangeFileExt(eeHme+cfVct,'.csvt')) then
    Tools.ErrorOut(cVct+ChangeFileExt(eeHme+cfVct,'.csvt'));
  if sFmt[1]<>',' then sFmt:=','+sFmt;
  sFmt:=Tools.LineRead(ChangeFileExt(eeHme+cfVct,'.csvt'))+sFmt;
  Tools.TextOut(ChangeFileExt(eeHme+cfFcs,'.csvt'),sFmt);
end;

function tTable.AddThema(sFld:string):tStringList;
{ tAT erzeugt aus dem Feld "sFld" in "vector.csv" ein Array mit Klassen-IDs für
  die Inhalte von "sFld", ergänzt damit die Tabelle und speichert das Ergebnis
  als "focus.csv". }
{ tAT betrachtet die Inhalte von "sFld" als Strings und vergibt für jedes
  Muster eine Klassen-ID. Dazu kopiert tAT die ursprüngliche Liste, sortiert
  sie und reduziert gleiche Einträge bis von jedem Muster nur noch ein Beispiel
  übrig bleibt. tAT verwendet den Index der reduzierten Liste als Klassen-ID,
  trägt die IDs in ein neues Integer-Array ein und ergänzt das Array als neues
  Feld für "focus.csv". tAT erweitert auch die CSVT-Datei und übernimmt die
  PRJ-Datei aus "vector.prj" }
var
  iaMap:tnInt=nil; //Klassen-IDs
  slFld:tStringList=nil; //Klassen-Bezeichner, alle Polygone
  I:integer;
begin
  Result:=tStringList.Create; //klassifizierte Bezeichner
  try
    slFld:=FieldValues(sFld); //Klassen-Bezeichner, alle Polygone
    Result.AddStrings(slFld); //Liste kopieren
    Result.Add(#32); //leere Klasse für Rückweisung, ID=0
    Result.Sort; //alphabetisch
    for I:=pred(Result.Count) downto 1 do
      if Result[I]=Result[pred(I)] then Result.Delete(I); //nur verschiedene Bezeichner
    iaMap:=Tools.InitInteger(slFld.Count,0); //Klassen-IDs als Array
    for I:=0 to pred(slFld.Count) do
      iaMap[I]:=Result.IndexOf(slFld[I]); //Index des Bezeichners = Klassen-ID
    Table.AddInteger(iaMap,sFld+'-ID'); //Werte an Tabelle anhängen
    Table.AddFormat('Integer(10)'); //Feld-Format an CSVT anhängen
    Tools.CopyFile(ChangeFileExt(eeHme+cfVct,'.prj'),
      ChangeFileExt(eeHme+cfFcs,'.prj')); //Projektion als WKS
    //Result.Count darf $FF nicht überschreiten
  finally
    slFld.Free;
  end;
end;

{ cRF extrahiert die Projektion, Ursprung, Rahmen und Pixelgröße der Bilddaten
  "sImg" aus dem "gdalinfo"-Text und gibt sie als "trCvr" zurück. Der Ursprung
  bezeichnet die linke obere Ecke des Bildes. Der Rahmen kann leere Bildflächen
  enthalten. }

function tCover.RasterFrame(sImg:string):trCvr; //Bildname: Abdeckung

{ lSB überträgt die vier Eckpunkte der Bilddaten aus "gdalinfo" in einen
  einschließenden Rahmen. Der Ursprung ist die linke obere Bildecke. }

procedure lSetBonds(sPnt:string);
var
  fLat,fLon:single; //Koordinaten
begin
  fLat:=StrToFloat(ExtractDelimited(2,sPnt,[',']));
  fLon:=StrToFloat(ExtractDelimited(1,sPnt,[',']));
  Result.Lft:=min(fLon,Result.Lft);
  Result.Top:=max(fLat,Result.Top);
  Result.Rgt:=max(fLon,Result.Rgt);
  Result.Btm:=min(fLat,Result.Btm);
end;

const
  cCrs = 'cRF: Insufficient coordinate system information: ';
  cSqr = 'Reprojection necessary to get square pixels: ';
var
  fXip:single; //Pixel height
  sLin:string; //Zeilen-Puffer
  slInf:tStringList=nil; //GDAL ImageInfo
  I:integer;
begin
  Result:=crCvr; //Vorgabe = unmöglich
  try
    slInf:=TStringList.Create;
    slInf.AddText(Gdal.ImageInfo(sImg)); //GDAL-Info übernehmen
    for I:=0 to pred(slInf.Count) do
    begin
      if LeftStr(slInf[I],13)='    ID["EPSG"' then
        Result.Epg:=StrToInt(copy(slInf[I],15,length(slInf[I])-16)) else
      if LeftStr(slInf[I],4)='    ' then continue; //nur linksbündige Einträge

      if LeftStr(slInf[I],7)='Size is' then
      begin
        sLin:=copy(slInf[I],pos('Size is',slInf[I])+7,$FF);
        Result.Wdt:=StrToInt(ExtractDelimited(1,sLin,[',']));
        Result.Hgt:=StrToInt(ExtractDelimited(2,sLin,[',']));
      end else
      if (LeftStr(slInf[I],7)='PROJCRS')
      or (LeftStr(slInf[I],7)='GEOGCRS') then
        Result.Crs:=ExtractWord(2,slInf[I],['"']) else
      if LeftStr(slInf[I],12)='Pixel Size =' then
      begin
        sLin:=ExtractDelimited(2,slInf[I],['(',')']); //Ausdruck in Klammern
        Result.Pix:=abs(StrToFloat(ExtractDelimited(1,sLin,[','])));
        fXip:=abs(StrToFloat(ExtractDelimited(2,sLin,[','])));
        if (fXip-Result.Pix)/(fXip+Result.Pix)>0.0001 then
          Tools.ErrorOut(cSqr+sImg);
      end else
      if LeftStr(slInf[I],16)='PROJ.4 string is' then
        //Result.Pro:=trim(slInf[succ(I)]) else //PROJ.4-String
        Result.Pro:=copy(slInf[succ(I)],2,length(slInf[succ(I)])-2) else
      if (LeftStr(slInf[I],10)='Upper Left') //Bildecken
      or (LeftStr(slInf[I],10)='Lower Left')
      or (LeftStr(slInf[I],11)='Upper Right')
      or (LeftStr(slInf[I],11)='Lower Right') then
        lSetBonds(ExtractDelimited(2,slInf[I],['(',')']));
    end;
  finally
    slInf.Free;
  end;
  if Result.Epg=0 then Result.Epg:=CrsInfo(sImg); //EPSG-Code

  if (Result.Pix=0) or (Result.Hgt=0) or (Result.Wdt=0) then
    Tools.ErrorOut(cCrs+sImg);
end;

{ cVF gibt das Auswahl-Rechnteck und die Projektion einer Vektor-Datei zurück.
  cVF ruft dazu ogrinfo auf, sucht die passenden Stichworte und konvertiert den
  Inhalt. Die Koordinaten beziehen sich auf das CRS der Vektoren. }

function tCover.VectorFrame(sFrm:string):trFrm; //Dateiname: Auswahlrahmen
const
  cFrm = 'cVF: Unable to open bounding geometry: ';
var
  sLin:string; //Zwischenlager
  slInf:tStringList=nil; //Vektor-Info
  I:integer;
begin
  Result:=crFrm; //Vorgabe = unmöglich
  //if length(sFrm)<1 then exit; //kein Aufruf
  if FileExists(sFrm)=False then Tools.ErrorOut(cFrm+sFrm);
  try
    slInf:=tStringList.Create;
    slInf.AddText(Gdal.OgrInfo(sFrm)); //Info-Text
    for I:=0 to pred(slInf.Count) do
    begin
      if LeftStr(slInf[I],13)='    ID["EPSG"' then
        Result.Epg:=StrToInt(copy(slInf[I],15,length(slInf[I])-16)) else
      if LeftStr(slInf[I],4)='    ' then continue; //nur linksbündige Einträge

      if LeftStr(slInf[I],7)='Extent:' then
      begin
        sLin:=ExtractDelimited(2,SlInf[I],['(',')']);
        Result.Lft:=StrToFloat(ExtractDelimited(1,sLin,[',']));
        Result.Btm:=StrToFloat(ExtractDelimited(2,sLin,[',']));
        sLin:=ExtractDelimited(4,SlInf[I],['(',')']);
        Result.Rgt:=StrToFloat(ExtractDelimited(1,sLin,[',']));
        Result.Top:=StrToFloat(ExtractDelimited(2,sLin,[',']));
      end else
      if (LeftStr(slInf[I],7)='PROJCRS')
      or (LeftStr(slInf[I],7)='GEOGCRS') then
        Result.Crs:=ExtractWord(2,slInf[I],['"']) else
    end;
  finally
    slInf.Free;
  end;
end;

{ cVCF gibt die Bounding-Box von Vektoren zurück. Mit "iEpg<>0" projiziert cVCF
  die Vektoren in das angegebene CRS und gibt den Rahmen im neuen CRS zurück. }

function tCover.VectorCrsFrame(
  iEpg:integer; //Ziel-CRS (EPSG-Code) oder Null für unverändert
  sVct:string): //Vektordaten für Bounding-Box
  trFrm; //Boundin-Box der Vektor-Daten
const
  cCrs = 'cVCF: Coordinate sytem not defined: ';
begin
  Result:=VectorFrame(sVct); //Bounding-Box aus OgrInfo
  if Result.Epg=0 then Tools.ErrorOut(cCrs+sVct);
  if (iEpg<>0) and (iEpg<>Result.Epg) then //Projektion anpassen?
  begin
    Gdal.ImportVect(iEpg,sVct); //Rahmen umprojizieren
    Result:=VectorFrame(eeHme+cfVct); //neuer Vektor-Rahmen
  end;
end;

function tCover._LargeFrame_(iEpg:integer):trFrm; //sehr großer Ramen
{ cLF gibt einen sehr großen Rahmen zurück. cLF übernimmt Koordinatensystem und
  EPSG-Code direkt aus der Eingabe }
const
  crDfl: trFrm = (Crs:''; Epg:0; Lft:1-MaxInt; Top:MaxInt; Rgt:MaxInt;
         Btm:1-MaxInt); //"endlos" groß
begin
  Result:=crDfl;
  Result.Epg:=iEpg;
end;

function tCover._EnviFrame_(sImg:string):trCvr; //Bildname: Abdeckung
//==> Frame aus Header, EPSG-Code aus gdalsrsinfo, PROJ.4 aus gdalsrsinfo
{ cRF extrahiert die Projektion, Ursprung, Rahmen und Pixelgröße der Bilddaten
  "sImg" aus dem "gdalinfo"-Text und gibt sie als "trCvr" zurück. Der Ursprung
  bezeichnet die linke obere Ecke des Bildes. Der Rahmen kann leere Bildflächen
  enthalten. }
const
  cCrs = 'cEF: Insufficient coordinate system information: ';
var
  rHdr:trHdr; //Metadaten
  slInf:tStringList=nil; //GDAL ImageInfo
  I:integer;
begin
  Result:=crCvr; //Vorgabe = unmöglich
  try
    slInf:=TStringList.Create;
    slInf.AddText(Gdal.SrsInfo(sImg)); //GDAL-Info übernehmen
    for I:=0 to pred(slInf.Count) do
    begin
      if LeftStr(slInf[I],4)='    ' then continue; //nur linksbündige Einträge
      if LeftStr(slInf[I],4)='EPSG' then
        Result.Epg:=StrToInt(copy(slInf[I],6,length(slInf[I])-5)) else
      if LeftStr(slInf[I],6)='PROJ.4' then
        Result.Pro:=trim(copy(slInf[I],9,$FF)) else
      if (LeftStr(slInf[I],7)='PROJCRS')
      or (LeftStr(slInf[I],7)='GEOGCRS') then
        Result.Crs:=ExtractWord(2,slInf[I],['"']) else
    end;
  finally
    slInf.Free;
  end;

  rHdr:=Header.Read(sImg);
  Result.Wdt:=rHdr.Scn; //Bildbreite in Pixeln
  Result.Hgt:=rHdr.Lin; //Bildhöhe in Pixeln
  Result.Lft:=rHdr.Lon; //linke obere Bildecke
  Result.Top:=rHdr.Lat;
  Result.Rgt:=rHdr.Lon+rHdr.Scn*rHdr.Pix; //rechte untere Bildecke
  Result.Btm:=rHdr.Lat-rHdr.Lin*rHdr.Pix;
  Result.Pix:=rHdr.Pix; //Pixelgröße
  Header.Clear(rHdr);

  if (Result.Pix=0) or (Result.Hgt=0) or (Result.Wdt=0) then
    Tools.ErrorOut(cCrs+sImg);
end;

function tCover.CrsInfo(sImg:string):integer; //Bildname: EPSG-Code
{ cCI extrahiert den EPSG-Code aus dem Text von "gdalsrsinfo" }
var
  slInf:tStringList=nil;
  I:integer;
begin
  Result:=0; //Vorgabe = undefiniert
  try
    slInf:=TStringList.Create;
    slInf.AddText(Gdal.SrsInfo(sImg)); //GDAL-Info übernehmen
    for I:=0 to pred(slInf.Count) do
      if LeftStr(slInf[I],4)='EPSG' then
      begin
        Result:=StrToInt(copy(slInf[I],6,length(slInf[I])-5));
        break
      end;
  finally
    slInf.Free;
  end;
end;

function tCover.CutFrame(
  rFrm:trFrm; //Auswahl-Rahmen
  sImg:string): //Vorbild
  trFrm; //gemeinsamer Rahmen
{ cCF gibt die Schnittmenge der gemeinsam abgedeckten Fläche für dem Rahmen
  "rFrm" und dem Header "sImg" zurück.
  ==> Das CRS muss gleich sein }
const
  cEpg = 'cCF: Coordinate systems must be equal!';
  cFrm = 'cCF: No overlap between selected frame an image!';
var
  rCvr:trCvr; //Rahmen für Bilder
begin
  rCvr:=RasterFrame(sImg); //Bildrahmen
  if rCvr.Epg<>rFrm.Epg then Tools.ErrorOut(cEpg);
  Result.Crs:=rCvr.Crs;
  Result.Epg:=rCvr.Epg;
  Result.Lft:=max(rFrm.Lft,rCvr.Lft); //gemeinsame Abdeckung
  Result.Top:=min(rFrm.Top,rCvr.Top);
  Result.Rgt:=min(rFrm.Rgt,rCvr.Rgt);
  Result.Btm:=max(rFrm.Btm,rCvr.Btm);
  with Result do if (Lft>Rgt) or (Top<Btm) then
  begin
    Result.Epg:=0; //Fehler-Flag
    Tools.ErrorOut(cFrm);
  end;
end;

function tCover.MergeFrames(
  slImg:tStringList): //Bildnamen
  trFrm; //Rechteck + Projektion
{ cMF gibt einen Rahmen zurück, der alle Bilder in "slImg" aufnimmt. cMF
  verwendet dazu die Header-Information der einzelnen Kanäle.
  ==> Das Koordinatensystem aller Bilder muss gleich sein. }
const
  cCrs = 'cMF: Inport images must share coordinate system!';
  cPix = 'cMF: Image merge needs identical pixel size!';
var
  I:integer;
  rHdr:trHdr; //Metadaten Bilder
  sCrs:string=''; //Bezeichner des Koordinatensystems aus Header
begin
  Result:=crFrm; //Vorgabe
  for I:=0 to pred(slImg.Count) do
  begin
    rHdr:=Header.Read(slImg[I]);
    if I=0 then
      sCrs:=ExtractWord(2,rHdr.Cys,['"']) //CRS-Zusammenfassung
    else if ExtractWord(2,rHdr.Cys,['"'])<>sCrs then
      Tools.ErrorOut(cCrs);
    with Result do
    begin
      Lft:=min(rHdr.Lon,Lft);
      Top:=max(rHdr.Lat,Top);
      Rgt:=max(rHdr.Lon+rHdr.Scn*rHdr.Pix,Rgt);
      Btm:=min(rHdr.Lat-rHdr.Lin*rHdr.Pix,Btm);
    end;
  end;
  Header.Clear(rHdr)
end;

{ cPI gibt True zurück, wenn der Punkt "pPnt" im Polygon "pPly" liegt. Dazu
  bestimmt cPI die Position der Schnittpunkte zwischen der horizontalen und
  vertikalen Koordinate des Fixpunkts mit allen Kanten eines Polygons. cPI
  zählt das Vorzeichen von horizontalen und vertikalen Differenzen. Ist das
  Ergebnis ungerade, liegt der Punkt außerhalb des Polygons. }

function tCover._PointInside_(
  rPnt:trGeo; //Punkt, unabhängig von "rPly"
  rPly:tarGeo): //geschlossenes Polygon
  boolean;
var
  fHrz,fVrt:double; //Schnittpunkt Lat/Lon
  fLft,fTop,fRgt,fBtm:double;
  iHrz:integer=0; //pos/neg Distanzen zu Schnittpunkt
  iVrt:integer=0; //pos/neg Distanzen zu Schnittpunkt
  p:integer;
begin
  //rPly[0].Lat=rPly[high(rPly)].Lat? //Polygon geschlossen?
  //rPly[0].Lon=rPly[high(rPly)].Lon?
  Result:=false;
  for P:=1 to high(rPly) do //alle Linien zwischen zwei Polygon-Punkten
  begin
    fBtm:=rPly[pred(P)].Lat; //Zeiger für Übersicht
    fTop:=rPly[P].Lat;
    fLft:=rPly[pred(P)].Lon;
    fRgt:=rPly[P].Lon;

    if (fTop<rPnt.Lat) and (fBtm>rPnt.Lat) //horizontal suchen
    or (fTop>rPnt.Lat) and (fBtm<rPnt.Lat) then
    begin
      fHrz:=fLft+(rPnt.Lat-fBtm)/(fTop-fBtm)*(fRgt-fLft);
      if fHrz>=rPnt.Lon
        then inc(iHrz)
        else dec(iHrz);
    end;

    if (fLft<rPnt.Lon) and (fRgt>rPnt.Lon) //vertikal suchen
    or (fLft>rPnt.Lon) and (fRgt<rPnt.Lon) then
    begin
      fVrt:=fBtm+(rPnt.Lon-fLft)/(fRgt-fLft)*(fTop-fBtm);
      if fVrt>=rPnt.Lat
        then inc(iVrt)
        else dec(iVrt);
    end;
  end;

  Result:=(odd(iHrz)=False) and (odd(iVrt)=False)
end;

{ cLF übernimmt die vier Bildecken aus den Landsat Metadaten und gibt sie als
  geschlossenes Polygon in UTM, WGS84 (geographisch) zurück }

function tCover._LandsatFrame_(sArc:string):tarGeo; //Archiv-Name: Eckpunkte ODER leer
const
  cArc = 'cLF: Archives must formatted as level 2 tier 1!';
  cGeo = 'cLF: Coordinates not found in "MTL" file!';
var
  bHit:boolean=False; //Koordinaten gefunden
  slInf:tStringList=nil;
  I:integer;
begin
  if RightStr(sArc,14)<>'_02_T1_MTL.txt' then Tools.ErrorOut(cArc);
  SetLength(Result,5); //geschlossenes Polygon
  try
    slInf:=tStringList.Create;
    slInf:=Archive.ExtractFilter(sArc,'_MTL'); //aus Archiv extrahieren
    slInf.LoadFromFile(slInf[0]); //MTL vollständig lesen
    for I:=0 to pred(slInf.Count) do
      if slInf[I]='  GROUP = PROJECTION_ATTRIBUTES' then
      begin
        if not (slInf[I+12]='    CORNER_UL_LAT_PRODUCT') then
          Tools.ErrorOut(cGeo);
        Result[0].Lat:=StrToFloat(copy(slInf[I+12],29,8));
        Result[0].Lon:=StrToFloat(copy(slInf[I+13],29,8));
        Result[1].Lat:=StrToFloat(copy(slInf[I+14],29,8));
        Result[1].Lon:=StrToFloat(copy(slInf[I+15],29,8));
        Result[3].Lat:=StrToFloat(copy(slInf[I+16],29,8));
        Result[3].Lon:=StrToFloat(copy(slInf[I+17],29,8));
        Result[2].Lat:=StrToFloat(copy(slInf[I+18],29,8));
        Result[2].Lon:=StrToFloat(copy(slInf[I+19],29,8));
        Result[4].Lat:=Result[0].Lat; //Polygon schließen
        Result[4].Lon:=Result[0].Lon;
        bHit:=True;
        break; //Aufgabe abgeschlossen
      end;
  finally
    slInf.Free;
  end;
  if not bHit then SetLength(Result,0); //nil zurückgeben
end;

{ cFF prüft, ob Landsat-Pfade (Flugstreifen) das Polygon "arRoi" abdecken und
  gibt die Namen für alle passenden Kacheln zurück. Dazu erzeugt cFF eine Liste
  "slArc" mit allen Archiven die zur Text-Maske "sMsk" passen. Im ersten Block
  löscht cFF alle Arcive aus "slArc", die keinen Punkt aus dem Polygon "arRoi"
  enthalten. Im zweiten Block zählt cFF die Treffer (Polygon-Eckpunkte) pro
  Landsat-Pfad und löscht alle Kacheln mit zu wenig Treffern in ihrem Pfad.
==> cFF unterstellt, dass der ROI kleiner ist als die Kachel. Ist das nicht der
    Fall, müssen Mittelpunkt + gleichmäßig verteilte Flächen-Punkte im ROI
    ergänzt werden um alle Kacheln innerhalb eines Polygons zu erfassen. }

function tCover._FrameFit_(
  arRoi:tarGeo; //Polygon für Region of Interest
  sMsk:string): //Maske für Landsat-Archiv Dateinamen
  tStringList; //Archiv-Namen
var
  arFrm:tarGeo=nil; //Polygon mit Bildkachel-Eckpunkten
  iaPth:tnInt=nil; //Kacheln pro Flugpfad
  iHit:integer; //ROI-Eckpunkte pro Kachel
  iLmt:integer; //Minimum Treffer (Eckpunkte) pro Flugpfad
  iPth:integer; //Landsat-PathNr
  slArc:tStringList=nil; //Namen der archivierten Kacheln
  I,P:integer;
begin
  Result:=nil;
  try
    slArc:=Tools.FileFilter(sMsk);
    iaPth:=Tools.InitInteger(255,0); //Treffer pro Pfad (233)

    for I:=pred(slArc.Count) downto 0 do
    begin
      arFrm:=_LandsatFrame_(slArc[I]); //Eckpunkte ODER leer
      if arFrm<>nil then
      begin
        iHit:=0; //Vorgabe
        for P:=1 to high(arRoi) do
          if _PointInside_(arRoi[P],arFrm) then
          begin
            inc(iHit); //Roi-Punkte pro Kachel
            iPth:=StrToInt(copy(slArc[I],11,3)); //Pfadnummer
            inc(iaPth[iPth]) //Punkte pro Pfad
          end;
        if iHit<1 then slArc.Delete(I); //kein Treffer
      end
      else slArc.Delete(I); //keine Eckpunkte gefunden
    end;

    Result:=tStringList.Create;
    iLmt:=high(arRoi); //Vorgabe = alle Eckpunkte
    repeat
      iPth:=StrToInt(copy(slArc[0],11,3)); //Pfadnummer für Null
      for I:=pred(slArc.Count) downto 0 do
      begin
        if StrToInt(copy(slArc[I],11,3))=iPth then //gleicher Pfad wie Null
          if iaPth[iPth]>=iLmt then Result.Add(slArc[I]); //Kachel kopieren
        slArc.Delete(I) //Kachel immer löschen
      end;
    until slArc.Count=0;
  finally
    slArc.Free
  end;
end;

{ cCF setzt in "sImg" alle Bildpixel außerhalb des Polygons "sFrm" auf NoData.
  cCF projiziert den Rahmen "sFrm" auf das CRS von "sImg", erzeugt eine Pixel-
  Maske [0,1] mit dem Rahmen und setzt alle Pixel in allen Layern auf NoData
  die außerhalb des Rahmens liegen. }

procedure tCover.ClipToFrame(
  sFrm:string; //Geometrie (ROI)
  sImg:string); //Vorbild WIRD VERÄNDERT!
var
  fxImg:tn3Sgl=nil; //Vorbild (multiband)
  fxMsk:Tn2Sgl=nil; //Maske für ROI
  iEpg:integer; //EPSG-Code Vorbild
  rHdr:trHdr; //Metadaten
  B,X,Y:integer;
begin
  iEpg:=Cover.CrsInfo(sImg); //Projektion der Bilddaten
  Gdal.ImportVect(iEpg,sFrm); //Rahmen projizieren + als CSV speichern
  rHdr:=Header.Read(sImg); //Bounding Box des Vorbilds
  fxMsk:=Tools.Init2Single(rHdr.Lin,rHdr.Scn,0); //Maske mit Vorgabe = Null
  Image.WriteBand(fxMsk,-1,eeHme+cfMsk); //als "mask" für GDAL speichern
  Header.WriteScalar(rHdr,eeHme+cfMsk);
  Gdal.Rasterize(1,'',eeHme+cfMsk,eeHme+cfVct); //ROI als (1) einbrennen

  fxMsk:=Image.ReadBand(0,rHdr,eeHme+cfMsk); //Maske [0,1]
  rHdr:=Header.Read(sImg); //Maske hat Header verändert
  fxImg:=Image.Read(rHdr,sImg); //Maske [0,1]
  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
      if fxMsk[Y,X]<1 then //Pixel innerhalb des ROI
        for B:=0 to pred(rHdr.Stk) do
          fxImg[B,Y,X]:=NaN;
  Image.WriteMulti(fxImg,sImg); //Header bleibt gleich
  Header.Clear(rHdr);
end;

end.

{==============================================================================}

