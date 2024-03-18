unit mutual;

{ MUTUAL sammelt Wrapper, die von allen Routinen verwendet werden können und
  statistische Routinen, Kanäle, Referenzen, Attribute und Flächen miteinander
  vergleichen.

  ARCHIVE:  listet und extrahiert und komprimiert Dateien in Archiven
  GDAL:     sammelt und kapselt Aufrufe für GDAL Routinen aller Art
  RANK:     korreliert Verteilungen und verknüpft Referenzen mit Clustern
  SEPARATE: trennt unterschiedliche Merkmale mit Hauptkomponenten

  BEGRIFFE MIT SPEZIFISCHER ANWENDUNG:
  Gravity: Schwerpunkt einer Kachel oder Fläche }

{$mode objfpc}{$H+}

interface

uses
  Classes, Math, StrUtils, SysUtils, format;

type
  trPrd = record //Outlier in Zeitreihen
    Mea:double; //Mittelwert
    Vrz:double; //quadrierte Abweichung vom Mittelwert
    Low,Hig:integer; //Zeit-Intervall + Trenner als Indices [0..N]
  end;

  tr_Prd = record //Outlier in Zeitreihen
    Low,Hig:word; //Zeit-Intervall + Trenner als Indices [0..N]
    Prv:double; //Varianz/Mittelwert zum Vorgänger (previous)
    Nxt:double; //Varianz/Mittelwert zum Nachfolger (subsequent)
  end;
  tra_Prd = array of tr_Prd;
  tpr_Prd = ^tr_Prd;

  tArchive = class(tObject) //Archivierung (TAR)
    private
      function QueryPosition(fDst:single; rFrm:trFrm; sPnt:string):boolean;
      function QueryQuality(sArc,sFrm:string):single;
// vgl: Reduce._SentinelQuality_
      function TarContent(sArc:string; slMsk:tStringList):tStringList;
      procedure TarExtract(sArc:string; slNme:tStringList);
    public
      function Catalog(sMsk:string):tStringList;
      function ExtractFilter(sArc,sBnd:string):tStringList;
      function ImportBands(fFct,fOfs:single; sArc,sBnd,sFrm:string):string;
      function QueryDate(sDat,sPrd:string):boolean;
      function xSelect(fDst,fLmt:single; sFrm,sGrv,sPrd:string):tStringList;
      procedure xQuality(fLmt:single; sFrm:string; slArc:tStringList);
  end;

  tGdal = class(tObject) //GDAL-Befehle kapseln
    private
    public
      procedure ExportShape(iPrj:integer; sSrc,sTrg:string);
      procedure ExportTo(iBnd,iFmt:integer; sNme,sRes:string);
      procedure Hillshade(sDem:string);
      procedure Import(iSgl,iHig,iLow:integer; rFrm:trFrm; sImg:string);
      procedure ImportVect(iPrj:integer; sGeo:string);
      function ImageInfo(sImg:string):string;
      function OgrInfo(sVct:string):string;
      procedure Rasterize(iVal:integer; sAtr,sBnd,sVct:string);
      function SrsInfo(sImg:string):string;
      function Warp(iCrs,iPix:integer; sImg:string):string;
      procedure ZonalBorders(sIdx:string);
  end;

  tRank = class(tObject)
    private
      procedure AccuracyMask(sRfz,sThm:string);
      procedure ChainLine(faDns:tnSgl; iRds:integer);
      function Combination(sMap,sRfz:string):tn2Int;
      function Correlation(fxVal:tn2Sgl):tn2Sgl;
      function Distribution(sImg,sRfz:string):tn3Sgl;
      function MaxCover(ixCmb:tn2Int; lsSpc:tFPList):tnInt;
      procedure Median(faDns:tnSgl; iRds:integer);
      function Outlier(faDns:tnSgl):single;
      procedure Remap(iaLnk:tnInt; sMap:string);
      procedure ReportOut(lsSpc:tFPList);
      procedure _SortByte_(iMap:integer; ixMap:tn2Byt);
      procedure TableFormat(iFmt:integer; ixCnt:tn2Int; sRes:string);
    public
      procedure FieldToMap(iCrs:integer; sFld,sMap,sRfz:string);
      procedure xEqualize(iRds:integer; sImg:string);
      procedure xScalarFit(bAcy:boolean; sImg,sRfz:string);
      procedure xThemaFit(bAcy:boolean; sMap,sRfz:string);
  end;

  tSeparate = class(tObject)
    private
      fcPrd:double; //fxBnd*fxCmp product (∑xy)
      fcHrz:double; //fxBnd sum (∑x)
      fcVrt:double; //fxCnt sum (∑y)
      fcSqr:double; //fxCnt square (∑y²)
      icCnt:int64; //pixel > fNod
      rcHdr:trHdr; //Metadaten
      procedure Normalize(fFct:single; fxBnd:tn2Sgl);
      procedure Regression(fxBnd,fxCmp:Tn2Sgl);
      procedure Rotation(fxBnd,fxCmp:Tn2Sgl);
    public
      procedure xNormalize(fFct:single; sImg:string);
      procedure xPrincipal(iDim:integer; sImg:string);
  end;

const
  cuPrd: trPrd = (Mea:0; Vrz:0; Low:0; Hig:-1);

var
  Archive:tArchive;
  Gdal:tGdal;
  Rank:tRank;
  Separate:tSeparate;

implementation

uses
  raster, thema, vector;

{ sFloat transformiert einen String in das Single-Format und setzt bei Fehlern
  die Variable "bErr". "bErr" kann cumulativ verwendet werden }

function sFloat(var bErr:boolean; sLin:string):single;
begin
  if TryStrToFloat(copy(sLin,succ(rPos('=',sLin)),$FF),Result)=false then
    bErr:=True; //Flag setzen
end;

function SpcCount(p1,p2:Pointer):integer;
begin
  if tprRfz(p1)^.Cnt>tprRfz(p2)^.Cnt then Result:=-1 else //nach vorne
  if tprRfz(p1)^.Cnt<tprRfz(p2)^.Cnt then Result:=1 else Result:=0;
end;

function SpcValues(p1,p2:Pointer):integer;
begin
  if tprSpc(p1)^.Val>tprSpc(p2)^.Val then Result:=-1 else //nach vorne
  if tprSpc(p1)^.Val<tprSpc(p2)^.Val then Result:=1 else Result:=0;
end;

function SpcRfzMap(p1,p2:Pointer):integer;
begin
  if tprSpc(p1)^.Rfz<tprSpc(p2)^.Rfz then Result:=-1 else //nach vorne
  if tprSpc(p1)^.Rfz>tprSpc(p2)^.Rfz then Result:=1 else
    if tprSpc(p1)^.Map<tprSpc(p2)^.Map then Result:=-1 else //nach vorne
    if tprSpc(p1)^.Map>tprSpc(p2)^.Map then Result:=1 else Result:=0;
end;

{ rSB sortiert Klassen-IDs nach ihrer Häufigkeit im Bild. Häufige Klassen
  erhalten kleine IDs. rSB erzeugt eine sortierbare Liste "lsRfz" mit ID und
  Fläche der Klassen, sortiert die Liste und konvertiert die Klassen-IDs. Die
  Liste "iaRfz" macht die Transformation einfacher. }

procedure tRank._SortByte_(
  iMap:integer; //Anzahl Klassen
  ixMap:tn2Byt); //Klassen-Bild
var
  iaRfz:tnByt=nil;
  lsRfz:TFPList=nil; //Zeiger-Liste
  pRfz:tprRfz=nil; //Zeiger auf Klassen-Referenz
  I,X,Y:integer;
begin
  try
    lsRfz:=TFPList.Create;
    lsRfz.capacity:=iMap; //Platz für alle Klassen
    for I:=0 to iMap do
    begin
      new(pRfz);
      pRfz^.Cnt:=0; //Vorgabe
      pRfz^.Map:=I; //fortlaufend
      lsRfz.Add(pRfz);
    end;
    for Y:=0 to high(ixMap) do
      for X:=0 to high(ixMap[0]) do
        inc(tprRfz(lsRfz.Items[ixMap[Y,X]])^.Cnt); //Pixel pro Klasse
    lsRfz.Delete(0); //Rückweisung + leere Flächen löschen
    lsRfz.Sort(@SpcCount); //nach Fläche sortieren
    iaRfz:=Tools.InitByte(succ(iMap)); //Vorgabe, Null
    for I:=0 to pred(lsRfz.Count) do //alle gültigen Klassen
      iaRfz[tprRfz(lsRfz.Items[I])^.Map]:=succ(I); //neue Klassen-IDs
  finally
    for I:=0 to pred(lsRfz.Count) do
      dispose(TprRfz(lsRfz[I])); //Speicher freigeben
    lsRfz.Free;
  end;
  for Y:=0 to high(ixMap) do
    for X:=0 to high(ixMap[0]) do
      ixMap[Y,X]:=iaRfz[ixMap[Y,X]];
end;

procedure tRank.AccuracyMask(sRfz,sThm:string);
{ rAM löscht aus dem Klassen-Layer "sThm" alle Pixel, die nicht mit der
  Referenz "sRfz" identisch sind. }
var
  ixThm:tn2Byt=nil; //Klassen-Bild
  ixRfz:tn2Byt=nil; //Referenzen-Bild
  rHdr:trHdr; //Metadaten
  Y,X:integer;
begin
  rHdr:=Header.Read(sThm); //recodierte Cluster
  ixThm:=Image.ReadThema(rHdr,sThm);
  rHdr:=Header.Read(sRfz); //Referenz als Raster
  ixRfz:=Image.ReadThema(rHdr,sRfz);
  for Y:=0 to high(ixThm) do
    for X:=0 to high(ixThm[0]) do
      if ixThm[Y,X]<>ixRfz[Y,X] then
        ixThm[Y,X]:=0;
  Image.WriteThema(ixThm,eeHme+cfAcy);
  Header.WriteThema(rHdr.Cnt,rHdr,rHdr.Fld,eeHme+cfAcy);
  Header.Clear(rHdr)
end;

function tRank.Combination(
  sMap:string; //Clusterung
  sRfz:string): //Referenz
  tn2Int; //Pixel pro Cluster x Referenz
{ rCn zählt alle Referenz-Cluster-Kombinationen in den thematischen Bildern
  "sRfz" und "sMap" und gibt sie als Tabelle[Mapping][Reference] zurück. Die
  Bilder "sMap" und "sRfz" müssen deckungsgleich sein. rCn belegt die erste
  Spalte der Tabelle mit den Pixeln pro Referenz un die erste Zeile mit den
  Pixeln pro Cluster(Mapping). Result[0,0] gibt die Summe aller erfassten Pixel
  zurück. rCn speichert die Tabelle unverändert als tab-getrennten Text. }
const
  cHdr = 'rCn: Mapping and reference differ in size or format!';
var
  iMap:integer; //höchste Cluster-ID
  ixMap:tn2Byt=nil; //Clusterung als Bild
  ixRfz:tn2Byt=nil; //Referenzen als Bild
  rHdr:trHdr; //Metadaten
  M,R,X,Y:integer;
begin
  Result:=nil;
  rHdr:=Header.Read(sMap); //Clusterung
  if not Header.BandCompare(rHdr,sRfz) then Tools.ErrorOut(cHdr);
  //Projektion?
  ixMap:=Image.ReadThema(rHdr,sMap);
  iMap:=rHdr.Cnt; //höchste Cluster-ID
  rHdr:=Header.Read(sRfz); //Referenz
  ixRfz:=Image.ReadThema(rHdr,sRfz);
  Result:=Tools.Init2Integer(succ(iMap),succ(rHdr.Cnt),0);
  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
      if ixRfz[Y,X]>0 then
        inc(Result[ixMap[Y,X],ixRfz[Y,X]]); //Kombinationen
  for M:=1 to high(Result) do
    for R:=1 to high(Result[0]) do
    begin
      Result[M,0]+=Result[M,R]; //Pixel pro Cluster (Mapping)
      Result[0,R]+=Result[M,R]; //Pixel pro Referenz
      Result[0,0]+=Result[M,R]; //alle Pixel
    end;
  Header.Clear(rHdr);
end;

{ rDn bestimmt Mittelwert und Varianz aller Kanäle in den Bilddaten "sImg"
  bezogen auf die referenzierten Flächen in "sRfz" und gibt das Ergebnis als
  Tabelle zurück. }
{ rDn bildet Summe und Quadrat-Summe aller Werte in den verschiedenen Kanälen
  innerhalb der verschiedenen Referenzen und berechnet damit Mittelwert und
  Varianz für alle Referenz-Kanal Kombinationen. rDn gibt die Varianz als
  doppelte Abweichung zurück. Die Indices sind natürliche Zahlen ab Eins, die
  erste Zeile und erste Spalte ist nicht definiert! }
// Varianz = (∑x²-(∑x)²/n)/(n-1)

function tRank.Distribution(
  sImg:string; //Werte in scalarem Bild
  sRfz:string): //Klassen-Layer (Clusterung)
  tn3Sgl; //[Mittwelwert|Varianz][Referenzen][Kanäle]
const
  cNeg = 'rDn: Negative results for variance!';
var
  bNgv:boolean=False;
  fVrz:single; //Zwischenergebnis
  fxVal:tn2Sgl=nil; //Kanal aus Scalarem Bild
  fzVrz:tn2Sgl=nil; //Zeiger auf Varianz
  fzMdn:tn2Sgl=nil; //Zeiger auf Mittelwert
  iaCnt:tnInt=nil; //Pixel pro Cluster
  iCnt:integer; //Anzahl Cluster
  ixRfz:tn2Byt=nil; //Clusterung oder Klassen-Layer
  rHdr:trHdr; //Metadaten
  B,R,X,Y:integer;
begin
  //sMap = Klassen?
  //sVal = Scalar?
  //gleiche Größe?
  rHdr:=Header.Read(sRfz); //Metadaten Cluster
  ixRfz:=Image.ReadThema(rHdr,sRfz); //Cluster, Klassen
  iaCnt:=Tools.InitInteger(succ(rHdr.Cnt),0); //Pixel pro Cluster
  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
      inc(iaCnt[ixRfz[Y,X]]); //Pixel pro Referenz

  iCnt:=rHdr.Cnt; //höchte Cluster-ID
  rHdr:=Header.Read(sImg); //Metadaten Scalare
  Result:=Tools.Init3Single(2,succ(iCnt),succ(rHdr.Stk),0);
  fzMdn:=Result[0]; //Zeiger
  fzVrz:=Result[1];
  for B:=1 to rHdr.Stk do //alle Kanäle
  begin
    fxVal:=Image.ReadBand(pred(B),rHdr,sImg); //scalarer Kanal
    for Y:=0 to pred(rHdr.Lin) do
      for X:=0 to pred(rHdr.Scn) do
      begin
        fzVrz[ixRfz[Y,X],B]+=sqr(fxVal[Y,X]);
        fzMdn[ixRfz[Y,X],B]+=fxVal[Y,X];
      end;
  end;
  for R:=1 to iCnt do //alle Referenzen
    for B:=1 to rHdr.Stk do
    begin
      if iaCnt[R]>1
        then fVrz:=(fzVrz[R,B]-(sqr(fzMdn[R,B])/iaCnt[R]))/(pred(iaCnt[R]))
        else fVrz:=0;
      if fVrz>=0
        then fzVrz[R,B]:=sqrt(fVrz)*2 //Doppelte Abweichung
        else bNgv:=True; //Rundungsfehler!
      if iaCnt[R]>0 then
        fzMdn[R,B]:=fzMdn[R,B]/iaCnt[R];
    end;
  Header.Clear(rHdr);
  if bNgv then Tools.ErrorOut(cNeg+sRfz);
  Tools.HintOut('Rank.Distribution: memory');
end;

function tRank.MaxCover(
  ixCmb:tn2Int; //Cluster-Referenz-Kombinationen [Pixel]
  lsSpc:tFPList): //Kombinationen als Liste
  tnInt; //Klassen für Cluster aus Referenzen
{ rSy gibt ein Array mit den häufigsten Kombination zwischen Zeilen (Clustern)
  und Spalten (Referenzen) in "ixCmb" zurück. rSy erwartet in "ixCmb[0,0]" die
  Anzahl aller referenzierten Pixel. }
{ rSy erzeugt aus der Tabelle "ixCmb" eine Liste mit allen Cluster-Referenz-
  Kombinationen, sortiert sie nach der Fläche der Cluster in einer Referenz
  und sortiert sie nach der gemeinsamen Fläche "pSpc^.Prt". rSy gibt für jeden
  Cluster eine ID zurück, eine Referenz kann durch viele Cluster abgebildet
  werden. }
var
  pSpc:tprSpc=nil; //Zeiger auf Kombination
  I,M,R:integer;
begin
  Result:=Tools.InitInteger(length(ixCmb),0); //beste Referenz pro Cluster
  for M:=1 to high(ixCmb) do
    for R:=1 to high(ixCmb[0]) do
      if ixCmb[M,R]>0 then
      begin
        new(pSpc);
        pSpc^.Rfz:=R;
        pSpc^.Map:=M;
        pSpc^.Val:=ixCmb[M,R]/ixCmb[0,0]; //Anteil Cluster in Referenz
        lsSpc.Add(pSpc)
      end;
  lsSpc.Sort(@SpcValues); //nach Fläche sortieren
  for I:=0 to pred(lsSpc.Count) do
    with tprSpc(lsSpc[I])^ do
      if Result[Map]=0
        then Result[Map]:=Rfz //Cluster mit Referenz verknüpfen
        else Val:=-Val; //Fehler-Markierung
end;

procedure tRank.Remap(
  iaLnk:tnInt; //Klassen-ID aus Referenz
  sMap:string); //Clusterung
{ rRp ersetzt die Klassen in "sMap" mit der Transformation "iaLnk" durch neue
  Werte und speichert das Ergebnis als "thema" im Home-Verzeichnis. rRp liest
  und schreibt Bilder im ENVI-Byte-Format (Klassen). }
var
  ixMap:tn2Byt=nil; //Klassen-Bild
  rHdr:trHdr; //Metadaten
  sFld:string=''; //Feldnamen
  Y,X:integer;
begin
  rHdr:=Header.Read(sMap); //Clusterung
  ixMap:=Image.ReadThema(rHdr,sMap);
  for Y:=0 to high(ixMap) do
    for X:=0 to high(ixMap[0]) do
      ixMap[Y,X]:=iaLnk[ixMap[Y,X]];
  Image.WriteThema(ixMap,eeHme+cfThm);
  sFld:=Header.ReadLine('class names',eeHme+cfRfz);
  Header.WriteThema(MaxIntValue(iaLnk),rHdr,sFld,eeHme+cfThm);
  Header.Clear(rHdr)
end;

procedure tRank.ReportOut(
  lsSpc:tFPList); //Cluster-Referenz-Verteilung
{ rRO überträgt die Cluster-Referenz-Combination "lsSpc" in einen formatierten
  Text. Dazu fassr rRO alle Einträge mir gleicher Referenz-ID zu einer Zeile
  zusammen. Das Ergebnis enthält die Summe der richtig und falsch verknüpften
  Pixel und die IDs der beteiligten Cluster. rRO unterdrückt bei den ID's
  Cluster mit weniger als 0.1% Anteil, die Flächen-Summen sind vollständig. }
var
  fErr:single=0; //Anteil falsch
  fHit:single=0; //Anteil richtig
  sErr:string=''; //Cluster-IDs falsch
  sHit:string=''; //Cluster-IDs richtig

function lLineOut(iRfz:integer):string;
begin
  if length(sErr)>0 then delete(sErr,1,1); //führendes Komma
  if length(sHit)>0 then delete(sHit,1,1);
  Result:=IntToStr(iRfz)+#9+
    FloatToStrF(fHit*100,ffFixed,7,1)+#9+
    FloatToStrF(fErr*100,ffFixed,7,1)+#9+
    FloatToStrF((fHit+fErr)*100,ffFixed,7,1)+#9+
    '('+sHit+') – ('+sErr+')';
  fHit:=0; fErr:=0;
  sHit:=''; sErr:='';
end;

var
  fNgv:single=0; //Summe negative Anteile
  fPst:single=0; //Summe positive Anteile
  slRes:tStringList=nil; //Ergebnis als Text
  I:integer;
begin
  try
    slRes:=tStringList.Create;
    slRes.Add('Refz-ID'#9'Link %'#9'Error %'#9'Bilanz %'#9'Cluster-IDs');
    lsSpc.Sort(@SpcRfzMap); //Nach Referenz und Fläche sortieren
    for I:=0 to pred(lsSpc.Count) do
    with tprSpc(lsSpc[I])^ do
    begin
      if (I>0) and (tprSpc(lsSpc[pred(I)])^.Rfz<Rfz) then
        slRes.Add(lLineOut(tprSpc(lsSpc[pred(I)])^.Rfz));
      if Val>0
        then fHit+=Val
        else fErr+=Val; //Flächen-Anteile richtig / falsch
      if Val>1/1000 then sHit+=','+IntToStr(Map) else
      if Val<-1/1000 then sErr+=','+IntToStr(Map); //Cluster-ID richtig / falsch
      if Val>0
        then fPst+=Val
        else fNgv+=Val;
    end;
    slRes.Add(lLineOut(tprSpc(lsSpc.last)^.Rfz));
    slRes.Add('Sum'+
      #9+FloatToStrF(fPst*100,ffFixed,7,1)+
      #9+FloatToStrF(fNgv*100,ffFixed,7,1)+
      #9+FloatToStrF((fPst+fNgv)*100,ffFixed,7,1));
    slRes.SaveToFile(eeHme+cfSpc);
  finally
    slRes.Free;
  end
end;

procedure tRank.TableFormat(
  iFmt:integer; //0=unverändert, 1=Anteile Bild, 2=Anteile Cluster, negativ=Stellen als Float
  ixCnt:tn2Int; //Integer-Tabelle
  sRes:string); //Dateiname Ergebnis als Text
{ rTF schreibt eine Tabelle als tab-getrennten Text. rTF unterstellt, dass die
  erste Zeile und erste Spalte Hilfswerte enthalten und ersetzt sie durch die
  passenden Indices. }
{ Mit "iFmt<0" interpretiert rTF "ixCnt" als Single-Matrix und schreibt alle
  Werte mit abs(iFmt) Stellen. Mit "iFmt=0" schreibt rTF Integers. Mit "iFmt>0"
  normalisiert rTF die Werte auf die Summe der Zeilen, Spalten oder aller Werte.
  Dazu muss die erste Zeile bzw Spalte die Summen enthalten und die Summe aller
  Werte in "ixCnt[0,0]" stehen. In die Ausgabe ersetzt rTF in jedem Fall die
  erste Zeile und die erste Spalte durch die passenden Indices. }
var
  sLin:string; //aktuelle Textzeile
  slOut:tStringList=nil;
  C,R:integer;
begin
  try
    slOut:=tStringList.Create;
    sLin:='0'; //erste Zelle
    for C:=1 to high(ixCnt[0]) do
      sLin+=#9+IntToStr(C); //erste Zeile = Indices
    slOut.Add(sLin);
    for R:=1 to high(ixCnt) do //Zeilen
    begin
      sLin:=IntToStr(R); //erste Spalte = Index
      for C:=1 to high(ixCnt[0]) do //Werte in Spalten
        case iFmt of
          0:sLin+=#9+IntToStr(ixCnt[R,C]); //unverändert
          1:sLin+=#9+FloatToStrF(ixCnt[R,C]/ixCnt[0,0]*1000,ffFixed,7,0); //Anteil Gesamtfräche
          2:sLin+=#9+FloatToStrF(ixCnt[R,C]/ixCnt[0,C],ffFixed,7,0); //Anteil Spalte
          3:sLin+=#9+FloatToStrF(ixCnt[R,C]/ixCnt[R,0],ffFixed,7,0); //Anteil Zeile
          else sLin+=#9+FloatToStrF(tn2Sgl(ixCnt)[R,C],ffFixed,7,-iFmt); //Werte als Float, "iFmt" Stellen
        end;
      slOut.Add(sLin);
    end;
    slOut.SaveToFile(sRes)
  finally
    slOut.Free;
  end;
end;

{ pIV konvertiert ein bekanntes Vektor-Format in eine CSV-Datei und speichert
  das Ergebnis als "vector.csv" im WKT-Format. Mit "iPrj>0" projiziert pIV
  dabei nach "iPrj". "iPrj" muss als EPSG-Code übergeben werden. }
{ pIV kapselt (wrapper) den GDAL-Befehl "ogr2ogr" und überprüft den Erfolg.
  pIV leitet GDAL-Fehlermeldungen nach StdIO um. }

procedure tGdal.ImportVect(
  iPrj:integer; //Ziel-Projektion als EPSG, Null für unverändert
  sGeo:string); //Geometrie-Quelle
const
  cGdl = 'iGW: GDAL image warp not successful: ';
  cSrc = 'iGW: Vector source file not found: ';
var
  slCmd:tStringList=nil; //Parameter als Liste
begin
  if not FileExists(sGeo) then Tools.ErrorOut(cSrc+sGeo);
  DeleteFile(eeHme+cfVct);
  DeleteFile(eeHme+cfVct+'t');
  try
    slCmd:=TStringList.Create;
    slCmd.Add('-f'); //Output-File-Format
    slCmd.Add('CSV'); //als Comma Seperated Values
    slCmd.Add('-overwrite'); //neue Datei
    slCmd.Add('-lco'); //Layer Creation Option
    slCmd.Add('GEOMETRY=AS_WKT'); //Geometrie als WKT
    slCmd.Add('-lco');
    slCmd.Add('CREATE_CSVT=YES'); //Format der Attribute
    slCmd.Add('-t_srs'); //projizieren in Format
    slCmd.Add('EPSG:'+IntToStr(iPrj)); //als EPSG
    slCmd.Add(eeHme+cfVct); //Ziel = ".imalys/vector.csv"
    slCmd.Add(sGeo); //Quelle
    Tools.OsExecute(eeGdl+'ogr2ogr',slCmd);
    Tools.ErrorLog; //Exceptions speichern
  finally
    slCmd.Free;
    if not FileExists(eeHme+cfVct) then Tools.ErrorOut(cGdl+sGeo);
  end;
  Tools.HintOut('GDAL.Import: '+cfVct);
end;

{ gRz brennt Vektor-Polygone in das Vorbild "sBnd". Nur der erste Kanal wird
  verändert. Die Polygone müssen nicht dieselbe Projektion besitzen wie das
  Vorbild. }

procedure tGdal.Rasterize(
  iVal:integer; //eingebrannter Wert wenn "sAtr"=''
  sAtr:string; //Vektor-Attribut-Name + Schalter
  sBnd:string; //Vorbild, ein Kanal, wird verändert
  sVct:string); //Polygone
const
  //cGdl = 'tGI: GDAL image inport not successful: ';
  cSrc = 'tGI: Image source file not available: ';
var
  slCmd: tStringList=nil; //Befehls-Parameter für gdal
begin
  if not FileExists(sBnd) then Tools.ErrorOut(cSrc+sBnd);
  try
    slCmd:=TStringList.Create;
    if sAtr='' then
    begin
      slCmd.Add('-burn'); //ein Wert für alle Polygone
      slCmd.Add(IntToStr(iVal)); //Wert der Maske
    end
    else
    begin
      slCmd.Add('-a'); //Attribute wiedergeben
      slCmd.Add(sAtr) //Attribut Name
    end;
    {
    slCmd.Add('-of'); //Bildformat
    slCmd.Add('ENVI'); //ENVI
    slCmd.Add('-ot'); //Datenformat
    slCmd.Add('Byte'); //für Klassen
    }
    slCmd.Add(sVct); //Polygone
    slCmd.Add(sBnd); //Vorbild
    //slCmd.SaveToFile(eeHme+'gdal_translate.params'); //KONTROLLE
    Tools.OsExecute(eeGdl+'gdal_rasterize',slCmd);
    Tools.ErrorLog; //Fehler in Konsole umleiten
  finally
    slCmd.Free;
  end;
end;

{ rCe erzeugt ein Klassen-Bild "reference" aus der Vektor-Geometrie "sRfz" und
  dem Vektor-Attribut "sFld". Raster und Abdeckung sind identisch mit "sMap".
  rCe importiert das Vektor-Vorbild als CSV, klassifiziert das Feld "sFld",
  erweitert die Attribute in der CSV-Kopie um eine fortlaufende Klassen-ID und
  verwendet die ID als Wert für das Bild. rCe interpretiert die Werte in "sFld"
  als Strings und übernimmt sie als Klassen-Namen. rCe ignoriert Vektoren
  außerhalb von "sMap". }

procedure tRank.FieldToMap(
  iCrs:integer; //Projektion als EPSG
  sFld:string; //Feldname für Referenz-ID in Vektor-Tabelle
  sMap:string; //Klassifikation (Testobjekt)
  sRfz:string); //Klassen-Referenz (Vektoren)
var
  rHdr:trHdr; //Vorbild (Clusterung)
  slRfz:tStringList=nil; //Klassen-Namen aus Referenz
  sNme:string='NA'; //Klassen-Namen, kommagetrennt
  I:integer;
begin
  Gdal.ImportVect(iCrs,sRfz); //Referenz als "vector.csv speichern, Umprojektion!
  try
    slRfz:=Table.AddThema(sFld); //Namen der Referenz-Klassen, Klassen-IDs in "focus.csv"
    rHdr:=Header.Read(sMap); //Dimension Vorbild
    Image.WriteZero(rHdr.Scn,rHdr.Lin,eeHme+cfRfz); //leere Kopie erzeugen
    for I:=1 to pred(slRfz.Count) do
      sNme+=','+slRfz[I];
    Header.WriteThema(pred(slRfz.Count),rHdr,sNme,eeHme+cfRfz); //Kassen-Header dazu
  finally
    slRfz.Free;
  end;
  Gdal.Rasterize(0,sFld+'-ID',eeHme+cfRfz,eeHme+cfFcs); //Klassen-IDs einbrennen
  Header.Clear(rHdr)
end;

function tRank.Correlation(
  fxVal:tn2Sgl): //Mittelwerte[Referenz][Value]
  tn2Sgl; //Rang-Korrelation, alle Referenz-Kombinationen
{ rCn bestimmt die Rang-Korrelation nach Spearmann für alle Kombinationen aus
  zwei Zeilen in "fxVal" und gibt sie als Tabelle zurück. }
{ rCn erzeugt eine Rang-Matrix "ixRnk" für alle Zeilen in "fxVal". "ixRnk" hat
  dieselben Zeilen wie "fxVal". Die erste Spalte von "fxVal" ist unterdrückt.
  Als Vorgabe nummeriert rCn jede "ixRnk"-Zeile fortlaufend. rVL kopiert
  einzelne "fxVal"-Zeilen ohne die führende Null nach "faTmp" und sortiert sie
  zusammen mit derselben Zeile aus "ixRnk". rVL bestimmt für alle Kombinationen
  aus zwei Zeilen die Korrelation nach Spaermann und gibt sie als Tabelle
  [Referenz][Referenz] zurück. Die erste Zeile und die erste Spalte (Index=0)
  sind nicht definiert }
// Rangkorrelation = 1-6∑(x-y)²/n/(n²-1) (Spearmann) x,y=Rang n=Vergleiche
var
  faTmp:tnSgl=nil; //Zwischenlager
  fFct:single; //Spearmann-Faktor
  fRes:single; //Zwischenergebnis
  iDim:integer; //Anzahl Kanäle
  iSze:integer; //Byte pro Spektralkombination
  ixRnk:tn2Int=nil; //Werte-Rangfolge, alle Referenzen & Kanäle
  R,S,V:integer;
begin
  Result:=nil;
  SetLength(ixRnk,length(fxVal),high(fxVal[0]));
  for R:=1 to high(ixRnk) do //erste Zeile NICHT definiert!
    for S:=0 to high(ixRnk[0]) do //alle Spalten verwendet!
      ixRnk[R,S]:=succ(S); //fortlaufende Nummer (ab Eins)
  iSze:=high(fxVal[0])*SizeOf(single); //Byte pro "fxVal[?]
  iDim:=high(fxVal[0]); //Anzahl Kanäle
  faTmp:=Tools.InitSingle(iDim,0); //Zwischenlager
  for R:=1 to high(fxVal) do
  begin
    move(fxVal[R,1],faTmp[0],iSze); //Werte ohne erste Spalte
    Reduce.IndexSort(ixRnk[R],faTmp); //"iaRnk" und "faTmp" verändert
  end;
  Result:=Tools.Init2Single(length(fxVal),length(fxVal),0); //alle Referenz-Kombinationen
  fFct:=6/iDim/(sqr(iDim)-1); //Spearmann-Faktor
  for R:=2 to high(fxVal) do //alle Referenz-Referenz-Kombinationen
    for S:=1 to pred(R) do
    begin
      fRes:=0;
      for V:=0 to pred(high(fxVal[0])) do
        fRes+=sqr(ixRnk[R,V]-ixRnk[S,V]); //Summe quadrierte Rang-Differenzen
      Result[S,R]:=1-fFct*fRes; //Rang-Korrelation
    end;
end;

{ rSF bestimmt eine Rang-Korrelation zwischen allen Kanälen im Import und der
  Referenz "sRfz". rSF gibt Mittelwerte, Abweichung (2@) und Korrelation als
  Text-Tabellen zurück. }

procedure tRank.xScalarFit(
  bAcy:boolean; //Mittelwert und Abweichung als Tabelle
  sImg:string; //Vorbild
  sRfz:string); //Referenz als Raster-Bild
var
  fxDst:tn3Sgl=nil; //Mittelwert+Variank für alle Kombinationen
  fxRnk:tn2Sgl=nil; //Rang-Korrelation für alle Kombinationen
begin
  fxDst:=Rank.Distribution(sImg,sRfz); //Mittelwert, Varianz in Referenzen
  if bAcy then TableFormat(-3,tn2Int(fxDst[0]),eeHme+'meanvalues.tab');
  if bAcy then TableFormat(-3,tn2Int(fxDst[1]),eeHme+'deviation.tab');
  fxRnk:=Correlation(fxDst[0]); //Korrelation für alle Referenzen
  TableFormat(-2,tn2Int(fxRnk),eeHme+'correlation.tab');
end;

procedure tRank.xThemaFit(
  bAcy:boolean; //Accuracy-Kontrollen erzeugen
  sMap,sRfz:string); //Cluster, Referenz als thematisches Bild
{ rTF überträgt Klassen-IDs der Referenz "sRfz" auf die Clusterung "sMap" und
  speichert das Ergebnis als "thema". Die Referenzen müssen als Raster-Layer
  verfügbar sein. }
{ rTF zählt die Cluster-Referenz-Kombinationen aller referenzierten Pixel in
  "ixCmb", erzeugt eine Lister "lsSpc" der C/R-Kombinationen, sortiert sie nach
  der Fläche der Cluster in den Referenzen und vergibt für alle Cluster die ID
  der Referenz mit der größten Fläche. Mit "bAcy=true" speichert rTF "ixCmb"
  als "combination", eine Zusammenfassung der Liste "lsSpc" als "specificity"
  und einen Klassen-Layer "accuracy", in dem nur korrekt abgebildete Referenzen
  sichtbar sind. }
var
  iaLnk:tnInt=nil; //referenzierte Klassen-IDs
  ixCmb:tn2Int=nil; //Anzahl Cluster-Referenz-Kombinationen
  lsSpc:tFPList=nil; //Kombinationen nach Häufigkeit
  I:integer;
begin
  //Projektion?
  try
    ixCmb:=Combination(sMap,sRfz); //Cluster-Referenz-Kombinationen + Summen
    lsSpc:=tFPList.Create; //Cluster-Klassen-Kombinationen
    iaLnk:=MaxCover(ixCmb,lsSpc); //Cluster-IDs aus Referenz
    Remap(iaLnk,sMap); //Cluster-IDs durch Referenz ersetzen
    if bAcy then
    begin
      ReportOut(lsSpc); //Kombinationen als Text
      TableFormat(0,ixCmb,eeHme+cfCbn); //als Text-Tabelle
      AccuracyMask(sRfz,eeHme+cfThm) //Filter für Cluster=Referenz
    end;
  finally
    for I:=0 to pred(lsSpc.Count) do
      dispose(tprSpc(lsSpc[I])); //Speicher freigeben
    lsSpc.Free;
  end;
end;

{ ToDo: [Gdal.ExportShape] "ogr2ogr" kann mit der Feldnamen-Zeile am Beginn des
        CSV Blocks nichts anfangen. qGis fragt die Feldnamen explizit ab.
        Feldnamen separat definieren? }

{ gES transformiert eine Vektor-Datei und ihre Attribute in das Shape-Format.
  Ist die Vorlage eine CSV-Datei, wird die übergebene Projektion auf In- und
  Output angewendet. Sind beide Dateien projiziert, nimmt fES mit "sPrj" eine
  Umprojektion vor. fEG kapselt (wrapper) die GDAL-Funktion "ogr2ogr" }

procedure tGdal.ExportShape(
  iPrj:integer; //Projektion der Vorlage
  sSrc:string; //Vorbild Geometrie (CSV)
  sTrg:string); //Ergebnis Geometrie mit Attributen
const
  cGdl = 'gEG: GDAL vector transformation not successful: ';
  cSrc = 'gEG: CSV file not found: ';
var
  slCmd:tStringList=nil; //Parameter als Liste
begin
  if not FileExists(sSrc) then Tools.ErrorOut(cSrc+sSrc);
  try
    slCmd:=TStringList.Create;
    slCmd.Add('-f'); //Output-File-Format
    slCmd.Add('ESRI Shapefile'); //als Comma Seperated Values
    slCmd.Add('-a_srs'); //Projektion der Vorlage ← für csv-Dateien
    slCmd.Add('EPSG:'+IntToStr(iPrj)); //EPSG-Code
    slCmd.Add('-nlt'); //Geometrie-Typ
    slCmd.Add('MULTIPOLYGON');
    //slCmd.Add('-preserve_fid'); //Feldnamen bewahren
    slCmd.Add(sTrg); //Ziel: formatierte Geometrie
    slCmd.Add(sSrc); //Vorlage: erweiterte CSV-Datei
    Tools.OsExecute(eeGdl+'ogr2ogr',slCmd);
    Tools.ErrorLog; //Exceptions speichern
  finally
    slCmd.Free;
    if not FileExists(sTrg) then Tools.ErrorOut(cGdl+sTrg);
  end;
  Tools.HintOut('GDAL.Export: '+ExtractFileName(sTrg));
end;

function tGdal.ImageInfo(sImg:string):string;
{ I extrahiert Metadaten aus dem Bild "sImg" und aktualisiert bei Bedarf die
    Statistik. Zur Statistik gehören Grauwert-Histogramme für alle Kanäle. Das
    Ergebnis ist formatierter Text. }
const
  cGdl = 'iGI: GDAL image information not successful: ';
  cImg = 'iGI: Image source file not found: ';
var
  slPrm: tStringList=nil; //Parameter-Liste
begin
  Result:='';
  if not FileExists(sImg) then Tools.ErrorOut(cImg+sImg);
  try
    slPrm:=TStringList.Create;
    //slPrm.Add('-stats'); //bei Bedarf Statistik erzeugen
    //slPrm.Add('-hist'); //Histogramm-Werte anzeigen
    slPrm.Add('-proj4'); //Projektion als "proj4"-String
    slPrm.Add(sImg); //Quell-Datei
    Tools.OsExecute(eeGdl+'gdalinfo',slPrm); //modal ausführen
    Result:=Tools.GetOutput(Tools.prSys); //GDAL Image Information (Text)
    Tools.ErrorLog; //Exceptions speichern
    if length(Result)=0 then Tools.ErrorOut(cGdl);
  finally
    slPrm.Free;
  end;
end;

procedure tGdal.ZonalBorders(sIdx:string);
const
  cRes = 'gZB: Zonal polygonization not successful: ';
  cShp = '.shp';
var
  slCmd: tStringList=nil;
begin
  Tools.ShapeDelete(sIdx); //"gdal_polygonize.py" überschreibt nicht
  sIdx:=ChangeFileExt(sIdx,''); //ohne Extension
  try
    slCmd:=tStringList.Create;
    slCmd.Add(sIdx); //Bildquelle
    //slCmd.Add('-b');
    //slCmd.Add('1'); //ein Kanal
    //slCmd.Add('-f');
    //slCmd.Add('SHP'); //Vektorformat
    slCmd.Add(sIdx+cShp); //Ziel
    //slCmd.Add('cell'); //Feldname
    //slCmd.Add('DN'); //Feldwert
    Tools.OsExecute(eeGdl+'gdal_polygonize.py',slCmd);
    Tools.ErrorLog; //Exceptions speichern
  finally
    slCmd.Free;
  end;
  if FileExists(sIdx+cShp)=False then Tools.ErrorOut(cRes+sIdx+cShp);
  Tools.HintOut('gdal.ZoneBorders: '+ExtractFileName(sIdx));
end;

{ TODO: [Gdal.ExportTo] Export mit Palette ermöglichen. Das Attribut -expand
        kann Paletten verfügbar machen }

{ tGET kapselt den Befehl GDAL_Translate. tGET speichert das Bild "sNme" als
  "sRes", die Extension steuert das Format. Für Exporte im IDL-Format muss der
  Header übergeben werden. "iFmt" steuert Bit pro Pixel. Mit iFmt=1 übernimmt
  tGET das bestehende Pixelformat, mit iFmt>1 exportiert tGET im gewählten
  Format. }

procedure tGdal.ExportTo(
  iBnd: integer; //Kanal im Vorbild ODER Null für alle
  iFmt: integer; //1=unmodified 2=Byte 3=Small 4:Integer 5:Single
  sNme: string; //Vorbild (Zwischenergebnis)
  sRes: string); //neuer Dateiname, Extension steuert Format
const
  caFmt: array[1..5] of string = ('','Byte','Int16','Int32','Float32');
  cFmt = 'rGE runtime error: Image transformation format not defined: ';
  cRes = 'rGE runtime error: Image export not successful: ';
var
  slCmd: TStringList=nil; //Parameter
begin
  if (iFmt<1) or (iFmt>5) then Tools.ErrorOut(cFmt+IntToStr(iFmt));
  try
    slCmd:=TStringList.Create;
    if iFmt>1 then slCmd.Add('-ot'); //Pixelformat erwarten
    if iFmt>1 then slCmd.Add(caFmt[iFmt]); //Format-Bezeichner
    if ExtractFileExt(sRes)='' then //ENVI-Format verwenden
    begin
      slCmd.Add('-of');
      slCmd.Add('ENVI');
      sRes:=ChangeFileExt(sRes,'') //Bilddaten ohne Extension!
    end;
    if iBnd>0 then slCmd.Add('-b'); //bestimmten Kanal verwenden
    if iBnd>0 then slCmd.Add(IntToStr(iBnd)); //Kanal-Nummer
    slCmd.Add(sNme); //Vorbild
    slCmd.Add(sRes); //Ergebnis
    Tools.OsExecute(eeGdl+'gdal_translate',slCmd);
    Tools.ErrorLog; //bei Exceptions anhalten
  finally
    slCmd.Free;
  end;
  if FileExists(sRes)=False then Tools.ErrorOut(cRes+sRes);
  Tools.HintOut('GDAL.Export: '+ExtractFileName(sRes));
end;

function tGdal.Warp(
  iCrs:integer; //EPSG-Code für Ergebnis
  iPix:integer; //Pixelgröße in Metern
  sImg:string): //Vorbild
  string; //Ergebnis-Name
{ gWp transformiert das Bild "sImg" in die Projektion "iCrs" und die Pixelgröße
  "iPix" und speichert das Ergebnis im ENVI-Format als "warp". Die Pixel sind
  quadratisch. Ihre Position folgt den Ziel-Koordinaten. Die Pixel-Werte sind
  bicubisch interpoliert. Leere Bereiche sind auf NoData gesetzt. }
const
  cGdl = 'iGW: GDAL image warp not successful: ';
  cSrc = 'iGW: Image source file not found: ';
var
  slCmd: tStringList=nil; //Parameter-Liste für "prSys"
begin
  Result:=eeHme+cfWrp;
  if not FileExists(sImg) then Tools.ErrorOut(cSrc+sImg);
  try
    slCmd:=TStringList.Create;
    slCmd.Add('-t_srs'); //target-CRS
    slCmd.Add('EPSG:'+IntToStr(iCrs)); //gewähltes CRS
    slCmd.Add('-tr'); //target-Pixelgröße
    slCmd.Add(IntToStr(iPix)); //gewählte Pixelgröße horizontal
    slCmd.Add(IntToStr(iPix)); //gewählte Pixelgröße vertikal
    slCmd.Add('-ot'); //Datenformat
    slCmd.Add('Float32'); //Single = Standard
    slCmd.Add('-r'); //Resampling
    slCmd.Add('cubic'); //Quadratisch = Standard
    slCmd.Add('-dstnodata');
    slCmd.Add(FloatToStr(NaN));
    slCmd.Add('-tap'); //Target Alligned Pixels
    slCmd.Add('-of'); //Bildformat
    slCmd.Add('ENVI'); //ENVI
    slCmd.Add(sImg); //Vorbild
    //slCmd.Add('-overwrite'); //Ergebnis ersetzen
    slCmd.Add(Result); //Ergebnis
    Tools.OsExecute(eeGdl+'gdalwarp',slCmd);
    Tools.ErrorLog; //Bei Exceptions anhalten
  finally
    slCmd.Free;
    if not FileExists(Result) then
      Tools.ErrorOut(cGdl+Result);
  end;
  Tools.HintOut('GDAL.Warp: '+ExtractFileName(sImg));
end;

procedure tSeparate.Regression(
  fxBnd: Tn2Sgl; //Basis-Kanal
  fxCmp: Tn2Sgl); //Vergleichs-Kanal
{ sRn bestimmt Zwischenergebnisse für die Regression der Pixel-Dichte zwischen
  den Kanälen "fxBnd" und "fxCmp". sRn ignoriert maskierte NoData-Pixel. }
// Regression = (∑xy-∑x∑y/n) / (∑y²-(∑y)²/n) >> dX/dY
var
  X,Y: integer; //Pixel
begin
  fcPrd:=0; fcSqr:=0; fcHrz:=0; fcVrt:=0; icCnt:=0; //Vorgabe
  for Y:=0 to pred(rcHdr.Lin) do
    for X:=0 to pred(rcHdr.Scn) do
    begin
      if isNan(fxBnd[Y,X])
      or isNan(fxCmp[Y,X]) then continue; //X:
      fcPrd+=fxBnd[Y,X]*fxCmp[Y,X];
      fcHrz+=fxBnd[Y,X];
      fcVrt+=fxCmp[Y,X];
      fcSqr+=sqr(fxCmp[Y,X]);
      inc(icCnt); //Pixel ohne NoData
    end; //for X ..
end;

procedure tSeparate.Rotation(
  fxBnd: Tn2Sgl; //Basis-Kanal
  fxCmp: Tn2Sgl); //Vergleichs-Kanal
{ sRn rotiert die Dichte-Matrix für die Kanäle "fxBnd" und "fxCmp" so, dass die
  maximale Ausdehnung in der X-Achse liegt. sRn bestimmt den Rotations-Winkel
  aus der Regression der Kanäle "fxCmp" und "fxBnd". Als Rotations-Zentrum
  verwendet sRn den Schwerpunkt aller Dichte-Kombinationen. Die X-Achse "fxBnd"
  sammelt die Hauptkomponente, die Y-Achse "fxCmp" die Rest-Werte. }
var
  fDst:double; //Distanz Schwerpunkt-Dichte
  fGam:double; //Winkel nach Rotation
  fOmg:double; //Regression als Winkel (omega)
  fRgs:double; //Regression dX/dY
  X,Y:integer; //Pixel
begin
  if fcSqr=sqr(fcVrt)/icCnt then exit; //Maske ohne Differenzierung
  fRgs:=(fcPrd-fcVrt/icCnt*fcHrz) / (fcSqr-sqr(fcVrt)/icCnt); //Regression dX/dY
  fOmg:=Pi/2 - Tools.ArcTanQ(fRgs,1); //Drehung auf Y=0 aus Regression
  fcHrz/=icCnt; //Schwerpunkt aus Summen
  fcVrt/=icCnt;
  for Y:=0 to pred(rcHdr.Lin) do
    for X:=0 to pred(rcHdr.Scn) do
    begin
      if isNan(fxBnd[Y,X])
      or isNan(fxCmp[Y,X]) then continue; //X:
      fDst:=sqrt(sqr(fxBnd[Y,X]-fcHrz) + sqr(fxCmp[Y,X]-fcVrt));  //Distanz Schwerpunkt-Dichte
      fGam:=Tools.ArcTanQ(fxBnd[Y,X]-fcHrz,fxCmp[Y,X]-fcVrt) + fOmg; //Winkel nach Rotation
      fxBnd[Y,X]:=sin(fGam)*fDst + fcHrz; //neue Koordinaten
      fxCmp[Y,X]:=cos(fGam)*fDst + fcVrt;
    end; //for X ..
end;

{ sPl gibt eine vollständige Hauptkomponenten-Transformation zurück. Die Zahl
  der Komponenten kann mit "iDim" reduziert werden. "Reduce.Principal" gibt mit
  einem schnelleren Algorithmus die erste Hauptkomponente alleine zurück. }
{ sPl verwendet zwei geschachtelte Schleifen. In der Inneren bestimmt
  "Regression" die mittlere Richtung aller Dichte-Vektoren für die ersten zwei
  Kanäle und "Rotation" rotiert die Vektoren so, dass die mittlere (gemeinsame)
  Dichte genau in die X-Richtung zeigt. sPl speichert die Dichte in X-Richtung
  im ersten und die Dichte in Y-Richtung im zweiten Ergebnis-Kanal. }
{ Diesen Prozess wiederholt sPl mit allen übrigen Kanälen als zweiten Kanal bis
  im ersten Kanal eine gemeinsame Hauptrichtung (Helligkeit) und in allen
  anderen Kanälen die verschiedenen Abweichungen übrig sind. In der äußeren
  Schleife verwendet sPl die Abweichungen vom letzten Schritt als neues Bild
  und wiederholt den Prozess ohne das bisherige Ergebnis zu erändern. Da jedes
  neue Bild einen Kanal weniger hat als der Vorgänger hat das ergebnis dieselbe
  Anzahl an Kanälen wie das Vorbild. }
{ Durch die Rotation können negative Werte entstehen. sPl transformiert alle
  Werte linear zu positiven Werten. }

procedure tSeparate.xPrincipal(
  iDim: integer; //Maximum Dimensionen
  sImg: string); //Pfadname Vorbild
const
  //cDim = '[Maximum Dimension] input must be larger than 0!';
  cFex = 'sPl: Image not found: ';
  cStk = 'Given image needs at least two image bands';
var
  fxBnd:Tn2Sgl=nil; //Basis-Kanal für erste Hauptkomponente
  fxCmp:Tn2Sgl=nil; //Vergleichs-Kanal
  sBnd:string=''; //Kanal-Namen, kommagetrennt
  B,C:integer;
begin
  if not FileExists(sImg) then Tools.ErrorOut(cFex+sImg);
  //if iDim<1 then Tools.ErrorOut(cDim);
  iDim:=max(iDim,1); //mindestens erste Hauptkomponente
  rcHdr:=Header.Read(sImg); //Header wird verändert!
  if rcHdr.Stk<2 then Tools.ErrorOut(cStk);
  iDim:=min(iDim,rcHdr.Stk); //maximum Komponenten
  Image.WriteBand(Tools.Init2Single(rcHdr.Lin,rcHdr.Scn,0),-1,eeHme+cfPca); //leere Kachel für 1. Kanal

  for C:=0 to pred(iDim) do
  begin
    fxBnd:=Image.ReadBand(C,rcHdr,sImg); //Basis-Kanal
    for B:=succ(C) to pred(rcHdr.Stk) do //alle anderen Kanäle
    begin
      fxCmp:=Image.ReadBand(B,rcHdr,sImg); //Vergleichs-Kanal
      Regression(fxBnd,fxCmp); //Regression für Kanäle C/B
      Rotation(fxBnd,fxCmp); //maximale Ausdehnung für "fxBnd"
      Filter.ValueMove(-Tools.MinBand(fxBnd),fxCmp); //alle Werte positiv machen
      Image.WriteBand(fxCmp,B,eeHme+cfPca); //Ergebnis als Zwischenlager für "Reste"
      write('.') //Fortschritt
    end;
    write(#13);
    Filter.ValueMove(-Tools.MinBand(fxBnd),fxBnd); //alle Werte positiv machen
    Image.WriteBand(fxBnd,C,eeHme+cfPca); //Ergebnis "C" dauerhaft speichern
    sImg:=eeHme+cfPca; //ab jetzt "Reste"-Kanäle als Vorbild
    Tools.HintOut('Separate.Principal: '+IntToStr(succ(C))+'/'+IntToStr(iDim)+
      ': '+cfPca);
  end;
  for C:=1 to iDim do
    sBnd+='PC-'+IntToStr(C)+#10; //Kanal-Bezeichner
  Header.WriteMulti(rcHdr,sBnd,sImg);
  Header.Clear(rcHdr);
end;

{ fOI extrahiert die Metadaten aus "sVct" und gibt sie als Text zurück. fOI
  leitet Fehlermeldungen von "ogrinfo" in den "exception"-Prozess um. }

function tGdal.OgrInfo(sVct:string):string; //Quelle: Ergebnis
const
  cGdl = 'iGW: GDAL geometry info not successful: ';
  cSrc = 'iGW: Vector source file not found: ';
var
  slCmd:tStringList=nil; //Parameter als Liste
begin
  if not FileExists(sVct) then Tools.ErrorOut(cSrc+sVct);
  try
    slCmd:=TStringList.Create;
    slCmd.Add('-al'); //alle Layer anzeigen ← für Vergleich mit CSV-Version
    slCmd.Add('-so'); //nur Zusammenfassung
    slCmd.Add(sVct); //Quelle
    Tools.OsExecute(eeGdl+'ogrinfo',slCmd);
    Result:=Tools.GetOutput(Tools.prSys); //GDAL Image Information (Text)
    Tools.ErrorLog; //Exception speichern
    if length(Result)=0 then Tools.ErrorOut(cGdl);
  finally
    slCmd.Free;
  end;
end;

{ gIt konvertiert das Bild "sImg" in das ENVI-Format und speichert das Ergebnis
  als "import". Mit "iSgl=0" übernimmt gIt das Format des Originals, in allen
  anderen Fällen speichert gIt das Bilder als 32-Bit Float. gIt aktualisiert
  die Bildstatistik. Mit "iHig >= iLow > Null" werden nur die Kanäle zwischen
  "iLow" und "iHig" übernommen. Mit "rFrm.Lft < rFrm.Rgt" beschneidet gIt das
  Bild auf den übergebenen Rahmen. Die Koordinaten müssen zm Bild-CRS passen.
  Der Rahmen darf größer sein als das Bild. }

procedure tGdal.Import(
  iSgl:integer; //Ergebnis im Single-Format [0,1]
  iHig,iLow:integer; //letzter, erster Kanal beginnend mit Eins; iHig<iLow für alle
  rFrm:trFrm; //Auswahl-Rahmen im Koordinaten-System der Bilder
  sImg:string); //Vorbild-Dateiname
const
  cGdl = 'tGI: GDAL image inport not successful: ';
  cHme = 'tGI: Imalys needs a working directory. Try to run initialization!';
  cSrc = 'tGI: Image source file not available: ';
var
  slCmd: tStringList=nil; //Befehls-Parameter für gdal
  B: integer;
begin
  //if not FileExists(eeHme) then Tools.ErrorOut(cHme);
  if not DirectoryExists(eeHme) then Tools.ErrorOut(cHme);
  if not FileExists(sImg) then Tools.ErrorOut(cSrc+sImg);

  try
    slCmd:=TStringList.Create;
    slCmd.Add('-of'); //Bildformat
    slCmd.Add('ENVI'); //ENVI
    if iSgl>0 then
    begin
      slCmd.Add('-ot'); //Datenformat
      slCmd.Add('Float32')
    end;
    slCmd.Add('-stats'); //Statistik neu rechnen
    if iHig>=iLow then //Kanäle selektiert (ab Eins)!
      for B:=iLow to iHig do
      begin
        slCmd.Add('-b');
        slCmd.Add(IntToStr(B))
      end;
    if rFrm.Lft<rFrm.Rgt then //nicht Vorgabe
    begin
      slCmd.Add('-projwin');
      slCmd.Add(FloatToStr(rFrm.Lft));
      slCmd.Add(FloatToStr(rFrm.Top));
      slCmd.Add(FloatToStr(rFrm.Rgt));
      slCmd.Add(FloatToStr(rFrm.Btm));
    end;
    if ExtractFileExt(sImg)=cfHdr
      then slCmd.Add(ChangeFileExt(sImg,'')) //Vorbild im IDL-Format
      else slCmd.Add(sImg); //Vorbild in anderem Format
    slCmd.Add(eeHme+cfImp); //Ergebnis Dateiname
    //slCmd.SaveToFile(eeHme+'gdal_translate.params'); //KONTROLLE
    Tools.OsExecute(eeGdl+'gdal_translate',slCmd);
    Tools.ErrorLog; //Fehler speichern
  finally
    slCmd.Free;
  end;
  if not FileExists(eeHme+cfImp) then Tools.ErrorOut(cGdl+sImg);
end;

{ gSI ruft "gdalsrsinfo" mit dem Parameter "-e" für den EPSG-Code auf und gibt
  das Ergebnis als String zurück. Der String enthält Zeilenende-Marken. }

function tGdal.SrsInfo(sImg:string):string;
const
  cGdl = 'gSI: GDAL image information not successful: ';
  cImg = 'gSI: Image source file not found: ';
var
  slPrm: tStringList=nil; //Parameter-Liste
begin
  Result:='';
  if not FileExists(sImg) then Tools.ErrorOut(cImg+sImg);
  try
    slPrm:=TStringList.Create;
    slPrm.Add('-e'); //EPSG-Code zurückgeben
    slPrm.Add(sImg); //Quell-Datei
    Tools.OsExecute(eeGdl+'gdalsrsinfo',slPrm); //modal ausführen
    Result:=Tools.GetOutput(Tools.prSys); //GDAL Image Information (Text)
    Tools.ErrorLog; //Exception wenn Fehler-Meldungen
    if length(Result)=0 then Tools.ErrorOut(cGdl);
  finally
    slPrm.Free;
  end;
end;

procedure tGdal.Hillshade(sDem:string); //Vorbild-Dateiname
{ gIt konvertiert das Bild "sImg" in das ENVI-Format und speichert das Ergebnis
  als "import". Mit "iSgl=0" übernimmt gIt das Format des Originals, in allen
  anderen Fällen speichert gIt das Bilder als 32-Bit Float. gIt aktualisiert
  die Bildstatistik. Mit "iHig >= iLow > Null" werden nur die Kanäle zwischen
  "iLow" und "iHig" übernommen. Mit "rFrm.Lft < rFrm.Rgt" beschneidet gIt das
  Bild auf den übergebenen Rahmen. Die Koordinaten müssen zm Bild-CRS passen.
  Der Rahmen darf größer sein als das Bild. }
// gdaldem input output options
const
  cHme = 'tGI: Imalys needs a working directory. Try to run initialization!';
  cRes = 'tGI: GDAL hillshade not successful: ';
  cSrc = 'tGI: Image source file not available: ';
var
  slCmd: tStringList=nil; //Befehls-Parameter für gdal
begin
  if not FileExists(eeHme) then Tools.ErrorOut(cHme);
  if not FileExists(sDem) then Tools.ErrorOut(cSrc+sDem);
  try
    slCmd:=TStringList.Create;
    slCmd.Add('hillshade'); //Modus
    slCmd.Add(sDem); //Vorbild
    slCmd.Add(eeHme+cfHse); //Ergebnis
    slCmd.Add('-of'); //Bildformat
    slCmd.Add('ENVI'); //ENVI
    Tools.OsExecute(eeGdl+'gdaldem',slCmd);
    Tools.ErrorLog; //Fehler in Konsole umleiten
  finally
    slCmd.Free;
  end;
  if not FileExists(eeHme+cfHse) then Tools.ErrorOut(cRes+eeHme+cfHse);
end;

procedure tSeparate.Normalize(
  fFct:single; //Abweichnung scalieren
  fxBnd:tn2Sgl); //Datenblock (Bild, Array)
{ sNz normalisiert alle Werte im Kanal "fxBnd" auf den Bereich 0.5±S*fFct. "S"
  ist die Standardabweichung. Varianz = (∑x²-(∑x)²/n)/(n-1) }
{ "fFct" MUSS POSITIV SEIN }
var
  fDev:double; //Abweichung (Standard)
  fOfs:double; //Offset für Ergebnis
  fScl:double; //Scalierung für Ergebnis
  fVal:double; //Mittelwert
  X,Y: integer; //Pixel
begin
  fcPrd:=0; fcSqr:=0; fcHrz:=0; fcVrt:=0; icCnt:=0; //Vorgabe
  for Y:=0 to high(fxBnd) do
    for X:=0 to high(fxBnd[0]) do
    begin
      if isNan(fxBnd[Y,X]) then continue;
      fcHrz+=fxBnd[Y,X]; //Summe Werte
      fcSqr+=sqr(fxBnd[Y,X]); //Summe Quadrate
      inc(icCnt); //Summe gültige Pixel
    end; //for X ..
  fVal:=fcHrz/icCnt; //Mittelwert
  fDev:=sqrt((fcSqr-sqr(fcHrz)/icCnt)/pred(icCnt));
  fScl:=1/(fDev*2*fFct); //Abweichung nach oben und unten
  fOfs:=fVal-fDev*fFct; //Mittelwert ohne Abweichung
  for Y:=0 to high(fxBnd) do
    for X:=0 to high(fxBnd[0]) do
      if not isNan(fxBnd[Y,X]) then
        fxBnd[Y,X]:=(fxBnd[Y,X]-fOfs)*fScl;
end;

{ sNe normalisiert alle Kanäle aus "sImg" auf den Wertebereich 0.5±S*fFct. "S"
  ist die Standardabweichung aller Werte sNe erzeugt keine neue Datei sondern
  verändert die Werte direkt. }

procedure tSeparate.xNormalize(
  fFct:single; //Anzahl Standardabweichungen
  sImg:string); //Vorbild
const
  cFct = 'sNe: Provided normalization range must be positive: ';
  cFex = 'sNe: Imag not found: ';
var
  fxRes:tn2Sgl=nil; //Kanal, wird normalisiert
  rHdr:trHdr; //Metadaten
  B:integer;
begin
  if fFct<=0 then Tools.ErrorOut(cFct+FloatToStr(fFct));
  if not FileExists(sImg) then Tools.ErrorOut(cFex+sImg);
  rHdr:=Header.Read(sImg);
  for B:=0 to pred(rHdr.Stk) do
  begin
    fxRes:=Image.ReadBand(B,rHdr,sImg); //Kanal lesen
    Normalize(fFct,fxRes); //auf [0..1] normalisieren
    Image.WriteBand(fxRes,B,sImg); //Kanäle überschreiben
  end;
  Header.Clear(rHdr); //Aufräumen
  Tools.HintOut('Separate.Normalize: '+ExtractFileName(sImg));
end;

{ aTC gibt eine Liste aller Dateinamen zurück, die im Archiv "sArc" gespeichert
  sind. Mit "slMsk<>nil" reduziert aTC die Liste auf Namen, die mindestens
  einen der Filter-Strings aus "slMsk" enthalten.
==> DAS ERGEBNIS KANN EINE LEERE LISTE SEIN }

function tArchive.TarContent(
  sArc:string; //Archiv-Name
  slMsk:tStringList): //Filter für benötigte Namen
  tStringList; //gefilterte Namen im Archiv
const
  cArc = 'Archive not available: ';
  cCmd = 'tar';
var
  bHit:boolean; //Suchmaske gefunden
  slPrm:tStringList=nil; //Parameter für Tar-Befehl
  sRes:string=''; //tar-Output
  B,R:integer;
begin
  Result:=nil;
  if not FileExists(sArc) then Tools.ErrorOut(cArc+sArc);
  try
    slPrm:=tStringList.Create;
    slPrm.Add('-t'); //liste erzeugen
    slPrm.Add('-f'); //Archiv-Name
    slPrm.Add(sArc); //Archiv-Name
    Tools.OsExecute(cCmd,slPrm); //Liste in StdIO
    sRes:=Tools.GetOutput(Tools.prSys); //Inhaltsverzeichnis im StdOut
    Tools.ErrorLog; //Error-Log ergänzen
  finally
    slPrm.Free;
  end;

  if length(sRes)>0 then
  begin
    Result:=tStringList.Create;
    Result.Text:=sRes; //Output als Liste
    if slMsk<>nil then //Suchmaske übergeben
      for R:=pred(Result.Count) downto 0 do
      begin
        bHit:=False; //Vorgabe
        for B:=0 to pred(slMsk.Count) do
          bHit:=bHit or (pos(slMsk[B],Result[R])>0); //Ausdruck kommt vor
        if not bHit then Result.Delete(R); //nicht benötigte Namen löschen
      end
  end
end;

{ aTE extrahiert die Dateien "slNme" aus dem Archiv "sArc" mit dem OS-Befehl
  "tar". Die extrahierten Dateien werden von "tar" im Stammverzeichnis (?)
  im "x_Imalys"-Verzeichnis (?) gespeichert. }
{ ES GIBT "CPIO" FÜR ARCHIVIERTE DATEIEN }

procedure tArchive.TarExtract(
  sArc:string; //Archiv-Name
  slNme:tStringList); //gewählte Namen im Archiv
const
  cCmd = 'tar';
var
  slPrm:tStringList=nil; //Parameter für "tar"-Befehl
begin
  if (slNme<>nil) and (slNme.Count>0) then
  try
    slPrm:=tStringList.Create;
    slPrm.Add('-x'); //liste erzeugen
    slPrm.Add('-f'); //Archiv-Name
    slPrm.Add(sArc); //Archiv-Name
    slPrm.AddStrings(slNme); //gefilterte Namen
    Tools.OsExecute(cCmd,slPrm); //gefilterte Namen extrahieren
    Tools.ErrorLog; //tar-Fehlermeldungen
  finally
    slPrm.Free;
  end;
end;

{ pEF liest das Inhaltsverzeichnis des Archivs "sArc", reduziert es auf
  Einträge die "sBnd" enthalten und extrahiert die gefilterten Namen. Der
  Befehl "tar" extrahiert in das Stamm-Verzeichnis wenn keine Pfade gesetzt
  sind, unter gdb in das Verzeichnis des aufrufenden Programms. "sBnd" kann
  eine kommagetrennte Liste sein. Jeder Eintrag wird getrennt gefiltert. }

function tArchive.ExtractFilter(
  sArc:string; //Archiv-Name (TAR)
  sBnd:string): //Filter für Kanal-Namen als CSV
  tStringList; //extrahierte Kanäle ODER nil
const
  cArc = 'aEF: Archive not defined or content missing: ';
var
  sDir:string; //Verzeichnis der ausführbaren Datei = Ziel der Extraktion
  slMsk:tStringList=nil; //Kanal-Namen-Suchmasken als Liste
  I:integer;
begin
  Result:=nil;
  try
    slMsk:=tStringList.Create;
    slMsk.Text:=Tools.CommaToLine(sBnd); //Liste aus CSV
    Result:=TarContent(sArc,slMsk); //Dateinamen im Archiv lesen und filtern
    if (Result<>nil) and (Result.Count>0) then
    begin
      TarExtract(sArc,Result); //Namen in "Result" extrahieren
      sDir:=Tools.OsCommand('pwd','')+DirectorySeparator;
      //writeln('pwd = '+sDir);
      {if FileExists(ExtractFilePath(eeExc)+Result[0])=False
        then sDir:=Tools.SetDirectory('/home/'+Tools.OsCommand('whoami','')) //Stammverzeichnis
        else sDir:=ExtractFilePath(eeExc); //Verzeichnis der ausführbaren Datei}
      for I:=pred(Result.Count) downto 0 do
        if FileExists(sDir+Result[I]) //Extraktion erfolgreich
          then Result[I]:=sDir+Result[I] //vollständiger Pfadname
          else Result.Delete(I); //kein Ergebnis
    end
    else Tools.WarningLog(cArc+sArc);
  finally
    slMsk.Free;
  end;
  if (Result<>nil) and (Result.Count>0)
    then Tools.HintOut('Archive.ExtractF: '+sBnd)
    else FreeAndNil(Result); //nil zurückgeben
end;

{ TODO: [Archive.ImportBands] bestimmt den EPSG-Code für jedes Archiv.
        "Parse.Import" fragt ihn für Warp ein zweites mal ab. Eine globale
        Variable könnte vermitteln }

{ TODO: [Archive.ImportBands] erzeugt für jedes Archiv einen ROI-Rahmen im CRS
        der Rohdaten. Das CRS wechselt wahrscheinlich selten, der projizierte
        ROI könnte wiederholt verwendet werden. Eine "Konstante" könnte helfen }

{ aIB extrahiert die Kanäle "sBnd" aus dem Archiv "sArc", beschneidet das Bild
  auf den Ausschnitt "sFrm", kalibriert die Werte mit "fFct" und "fOfs" und
  speichert alle extrahierten Kanäle als Stack im Arbeitsverzeichnis. Der Name
  enthält die Kachel-ID und das Datum. aIB schreibt im ENVI-Format. Dazu
  extrahiert aIB ganze Kanäle in das Stamm-Verzeichnis, speichert kalibrierte
  Ausschnitte im Arbeitsverzeichnis und bildet am Ende den Stack. aIB löscht
  alle Zwischenprodukte. }

function tArchive.ImportBands(
  fFct,fOfs:single; //Faktor + Offset für Kalibrierung
  sArc:string; //Archiv-Name
  sBnd:string; //Kanal-Filter, kommagetrennt
  sFrm:string): //Bounding-Box des ROI
  string; //Dateiname nach Import
var
  iEpg:integer; //Projektion der Rohdaten
  rFrm:trFrm; //ROI in der Projektion der Rohdaten
  slBnd:tStringList=nil; //Kanäle im Archiv
  B:integer;
begin
  Result:='';
  try
    slBnd:=ExtractFilter(sArc,sBnd); //Layer extrahieren
    if slBnd=nil then exit; //kein passender Kanal
    Result:=eeHme+
      Tools.LinePart(1,slBnd[0])+'_'+
      Tools.LinePart(3,slBnd[0])+'_'+
      Tools.LinePart(4,slBnd[0]); //Sensor, Kachel und Datum
    iEpg:=Cover.CrsInfo(slBnd[0]); //EPSG-Code der ersten Kachel
    rFrm:=Cover.VectorCrsFrame(iEpg,sFrm); //Bounding-Box in Projektion der Rohdaten
    for B:=0 to pred(slBnd.Count) do
    begin
      Gdal.Import(1,0,1,rFrm,slBnd[B]); //Float-Format, manueller Ausschnitt, als "import"
      DeleteFile(slBnd[B]); //Zwischenlager löschen
      Filter.Calibrate(fFct,fOfs,0,nil,eeHme+cfImp); //NoData-Maske, Slope, Offset, "import" verändern
      slBnd[B]:=Result+'_'+Tools.LinePart(9,slBnd[B]); //Datei-Name für Kanal im Imalys-Verzeichnis
      Tools.EnviRename(eeHme+cfImp,slBnd[B]); //Zwischenlager, getrennte Kanäle
    end;
    Image.StackBands(slBnd); //Kanäle als Stack
    Tools.EnviRename(eeHme+cfStk,Result); //Name für ROI-Ausschnitt
    for B:=0 to pred(slBnd.Count) do
      Tools.EnviDelete(slBnd[B]); //aufräumen
  finally
    slBnd.Free;
  end;
  Tools.HintOut('Archive.Import: '+ExtractFileName(Result));
end;

{ aCg erzeugt einen Archive-Katalog als Punkt-Geometrie im WKT-Format. Das
  Ergebnis enthält Mittelpunkt, Radius und Dateiname der Kachel. Das CRS ist
  geographisch. Mit "sMsk" kann die Suche auf Archive beschränkt werden, die
  "sMsk" im Namen haben. aCg extrahiert aus jedem Archiv die Metadaten und
  übernimmt aus den Bildecken Mittelpunkt und Kachelradius. Länge und Breite
  werden getrennt verarbeitet. }

function tArchive.Catalog(
  sMsk:string): //Verzeichnis+Datei-Maske für Archive
  tStringList; //Distanz < Schwelle
var
  bErr:boolean=False; //Fehler bei Zahlenkonvertierung
  fLft,fTop,fRgt,fBtm:single; //Koordinaten
  slArc:tStringList=nil; //Archiv-Namen nach Filterung
  slBnd:tStringList=nil; //Dateinamen im Archiv
  slMtl:tStringList=nil; //Text in MTL-Datei
  I,K:integer;
begin
  Result:=tStringList.Create; //nei
  try
    slMtl:=tStringList.Create; //Metadaten als text
    slArc:=Tools.FileFilter(ChangeFileExt(sMsk,'.tar')); //Archiv-Namen
    Result.Add('WKT,id,width,height,filename');
    for I:=0 to pred(slArc.Count) do
    begin
      slBnd:=ExtractFilter(slArc[I],'_MTL.txt'); //MTL-Text extrahieren
      if FileExists(slBnd[0]) then
      begin
        slMtl.LoadFromFile(slBnd[0]); //MTL-Text lesen
        bErr:=False;
        for K:=0 to pred(slMtl.Count) do
          if slMtl[K]='  GROUP = PROJECTION_ATTRIBUTES' then
          begin
            fLft:=(sFloat(bErr,slMtl[K+13])+sFloat(bErr,slMtl[K+17]))/2;
            fTop:=(sFloat(bErr,slMtl[K+12])+sFloat(bErr,slMtl[K+14]))/2;
            fRgt:=(sFloat(bErr,slMtl[K+15])+sFloat(bErr,slMtl[K+19]))/2;
            fBtm:=(sFloat(bErr,slMtl[K+16])+sFloat(bErr,slMtl[K+18]))/2;
            break; //fertig
          end;
        DeleteFile(slBnd[0]); //aufräumen
        if bErr then continue; //Zahlen nicht gefunden oder nicht lesbar
        Result.Add('"POINT ('+
          FloatToStr((fLft+fRgt)/2)+#32+ //Mittelpunkt horizontal
          FloatToStr((fTop+fBtm)/2)+')",'+ //Mittelpunkt vertikal
          IntToStr(Result.Count)+','+ //ID fortlaufend
          FloatToStr((fRgt-fLft)/2)+','+ //Radius horizontal
          FloatToStr((fTop-fBtm)/2)+','+ //Radius vertikal
          slArc[I]); //Dateiname
      end;
      FreeAndNil(slBnd); //Speicher freigeben
    end;
  finally
    slArc.Free;
    slMtl.Free;
  end;
  Tools.HintOut('Archive.Catalog: '+ChangeFileExt(sMsk,'.tar'));
end;

{ aQQ extrahiert den Landsat-QA-Kanal aus dem Archiv "sArc" und bestimmt den
  Anteil ungestörter Pixel innerhalb der Bilddaten und "sFrm". Das Ergebnis ist
  Null, wenn "sFrm" die Bilddaten nicht berührt. aQQ filtert den QA-Kanal mit
  binären Filtern für sichere opake Wolken, Wolken-Schatten, Cirren und Bild-
  Fehler. Für die Bildqualität verwendet aQQ das Verhältnis aus klaren und
  gestörten Pixeln innerhalb der Bilddaten "iPix/iCnt". aQQ ignoriert leere
  Pixel innerhalb und außerhalb der Szene. }

function tArchive.QueryQuality(
  sArc:string; //Archiv-Name
  sFrm:string): //Bounding-Box des ROI, leer für ganze Szene
  single; //Anteil klare Pixel
const
  cCld = $300; //2⁸+2⁹ = Clouds
  cSdw = $C00; //2¹⁰+2¹¹ = Shadow
  cIce = $3000; //2¹²+2¹³ = Ice, Snow
  cCir = $C000; //2¹⁴+2¹⁵ = Cirrus
var
  iCnt:integer=0; //Pixel innerhalb der Kachel, einschließlich leere Pixel am rand
  iEpg:integer=0; //EPSG-Code
  iPix:integer=0; //Pixel ohne Störung
  ixBin:tn2Wrd=nil; //Landsat-QA-Layer
  rFrm:trFrm; //Bounding-Box des ROI, CRS wie Bild! ← intern umwandeln?
  rHdr:trHdr; //Metadaten
  slBnd:tStringList=nil; //Dateien im Archiv, ausgewählte Kanäle
  X,Y:integer;
begin
  Result:=0; //Vorgabe
  try
    slBnd:=ExtractFilter(sArc,'_QA_PIXEL'); //QA-Layer extrahieren
    iEpg:=Cover.CrsInfo(slBnd[0]); //EPSG-Code des QA-Layers
    rFrm:=Cover.VectorCrsFrame(iEpg,sFrm); //Bounding-Box in Projektion der Rohdaten
    Gdal.Import(0,0,1,rFrm,slBnd[0]); //Ausschnitt "rFrm, als "import"
    DeleteFile(slBnd[0]); //Extrakt löschen
    DeleteFile(slBnd[0]+cfExt); //Extrakt löschen
    rHdr:=Header.Read(eeHme+cfImp);
    ixBin:=Image.ReadWord(rHdr,eeHme+cfImp); //QA-Layer
    for Y:=0 to pred(rHdr.Lin) do
      for X:=0 to pred(rHdr.Scn) do
        if ixBin[Y,X]>1 then //Bildpixel innerhalb der Szene
        begin
          inc(iCnt); //Summe definierte Pixel
          if (ixBin[Y,X] and cCld=cCld) //binäre Marker für Wolken und Schatten
          or (ixBin[Y,X] and cSdw=cSdw)
          or (ixBin[Y,X] and cCir=cCir) then continue;
          inc(iPix); //Summe klare Pixel
        end;
    if iCnt>0 then Result:=iPix/iCnt; //Anteil ungestörte Pixel [%]
    Header.Clear(rHdr);
  finally
    slBnd.Free;
  end;
end;

{ aQD vergleicht das Datum "sDat" mit der Zeitperiode "sPrd". aQD ist wahr,
  wenn Jahr, Monat und Tag aus "sDat" zu den Grenzen in "sPrd" passen. Alle
  Datumsangaben müssen als YYYYMMDD formatiert sein. }

function tArchive.QueryDate(
  sDat:string; //Datum im Vorbild YYYYMMDD
  sPrd:string): //Periode als YYYYMMDD-YYYYMMDD
  boolean; //Übereinstimmung
var
  iDat,iHig,iLow:integer; //Datum als Zahl
begin
  Result:=False;
  if (TryStrToInt(sDat,iDat)=False)
  or (TryStrToInt(LeftStr(sPrd,8),iLow)=False)
  or (TryStrToInt(RightStr(sPrd,8),iHig)=False) then exit;
  Result:=(iDat>=iLow) and (iDat<=iHig);
end;

{ TODO: [Archive.Frame] Der ROI ist für alle Abfragen gleich. Bestimmen und
        übergeben! }

{ aQy reduziert die Liste "slArc" um alle Archive, die innerhalb von "sFrm"
  weniger als "fLmt" klare Pixel haben. Dabei trägt aQy die Qualität als Zahl
  in den Zeiger der String-Liste ein. Eins wird als 0.999 geschrieben. }

procedure tArchive.xQuality(
  fLmt:single; //Minimum Anteil klarer Pixel
  sFrm:string; //Ausschnitt
  slArc:tStringList); //Liste wird reduziert!
var
  fPrt:single=0; //Anteil klarer Pixel
  I:integer;
begin
  for I:=pred(slArc.Count) downto 0 do
  begin
    fPrt:=QueryQuality(slArc[I],sFrm); //Anteil ungestörte Pixel im Bild + Frame
    if fPrt>=fLmt then
      slArc.Objects[I]:=tObject(pointer(round(fPrt*1000))) //Qualität als Zeiger
    else slArc.Delete(I); //Name aus Liste löschen
  end;
end;

{ aQP bestimmt die Distanz zwischen dem Mittelpunkt der Bildkachel in "sPnt"
  und dem Mittelpunkt des ROI "rGeo". aQP ist wahr, wenn die horizontale und
  vertikale Distanz kleiner ist als die Schwelle "Kachelradius * "fDst". aQP
  vergleicht Länge und Breite der Kachel getrennt . }

// ROI als Box einlesen

function tArchive.QueryPosition(
  fDst:single; //maximale relative Distanz der Mittelpunkte
  rFrm:trFrm; //Bounding-Box des ROI
  sPnt:string): //Punkt im WKT-Format
  boolean; //Distanz < Schwelle
var
  fHrz,fVrt:single; //Distanz zwischen Mittelpunkten in Grad
  iHig,iLow:integer; //Position der Klammern in WKT-Zeile
  rPnt:trGeo; //Kachel-Mittelpunkt
  sGeo:string; //Koordinaten Horz-Vert als String
begin
  Result:=False; //Vorgabe = passt nicht!
  iLow:=succ(pos('(',sPnt)); //Punkt-Koordinaten zwischen Klammern
  iHig:=pred(pos(')',sPnt));
  sGeo:=copy(sPnt,iLow,succ(iHig-iLow)); //nur Koordinaten, getrennt durch blank
  rPnt.Lat:=StrToFloat(copy(sGeo,succ(pos(' ',sGeo)),$FF)); //Koordinaten als Zahl
  rPnt.Lon:=StrToFloat(copy(sGeo,1,pred(pos(' ',sGeo))));
  fHrz:=max((rFrm.Rgt-rFrm.Lft)/2,StrToFloat(ExtractWord(3,sPnt,[',']))); //norm horizontal
  fVrt:=max((rFrm.Top-rFrm.Btm)/2,StrToFloat(ExtractWord(4,sPnt,[',']))); //norm vertikal
  Result:=(abs(rPnt.Lon-(rFrm.Rgt+rFrm.Lft)/2)<fDst*fHrz) and
          (abs(rPnt.Lat-(rFrm.Top+rFrm.Btm)/2)<fDst*fVrt);
end;

{ aSt prüft Position und Qualität aller Kacheln in der Archiv-Liste "sGrv" und
  gibt die Dateinamen zurück, die im gewählten Zeitraum "sPrd" aufgenommen
  wurden, nahe genug (fDst) am ROI liegen und mindestens "fLmt" der ROI-Fläche
  ohne Bildfehler abdecken.
    Die Abstands-Berechnung basiert auf Mittelpunkten. aSt erwartet in "sFrm"
  eine Vektor-Geometrie und bestimmt ihren Mittelpunkt aus der Bounding-Box von
  "sFrm". Bei Bedarf transformiert aSt die Projektion nach EPSG:4326. Die
  Mittelpunkte der Szenen sind in "sGrv" abgelegt, die Projektion ist immer
  geographisch. "fDst" ist ein Faktor für die maximale Distanz der Mittelpunte.
  aSt bestimmt die Radien des ROI und der Kacheln und setzt den größeren Radius
  auf Eins. "fDst" wirkt als Faktor auf diesen Radius. Mit "fDst=1" werden alle
  Kacheln gewählt, die entweder zur Hälfte in den ROI ragen oder den ROI zur
  Häfte abdecken. aSt verwendet getrennte Radien für horizontale und vertikale
  Distanzen.
    aSt bestimmt aus den Metadaten der Provider den Anteil ungestörter Pixel
  innerhalb der Schnittfläche von Kachel und ROI. Da aSt nur Dateinamen zurück
  gibt, codiert aSt den Flächenanteil als Zeiger in der Ergebnis-Liste.
  "Parse.Import" überträgt die Werte in den Header.

  ==> Die Liste "sGrv" muss mit →Catalog erstellt worden sein. }

function tArchive.xSelect(
  fDst:single; //Maximum relative Distanz der Mittelpunkte
  fLmt:single; //Minimum definierte Pixel als Anteil
  sFrm:string; //ROI-Geometrie
  sGrv:string; //WKT-Datei mit Kachel-Schwerpunkten + Dateinamen
  sPrd:string): //Zeitraum (YYYYMMDD-YYYYMMDD)
  tStringList; //Liste akzeptierte Dateinamen
const
  cDat = 'aSt: Given period must be formatted as »YYYYMMDD-YYYYMMDD«';
  cGrv = 'aSt: Archive register not available: ';
  cSlc = 'aSt: A frame or a date must be given: ';
var
  fPrt:single; //Anteil ungestörte Bildpixel
  rFrm:trFrm; //Boundin-Box des ROI
  sArc:string=''; //Archiv-Dateiname
  sDat:string=''; //Datum aus Dateinamen
  slGrv:tStringList=nil; //Kachel-Mittelpunkte der Archive
  I:integer;
begin
  Result:=nil;
  if not FileExists(sGrv) then Tools.ErrorOut(cGrv+sGrv);
  if (sPrd='') and (sFrm='') then Tools.ErrorOut(cSlc+sGrv);
  if length(sPrd)<>17 then Tools.ErrorOut(cDat+sPrd);
  if length(sFrm)>0
    then rFrm:=Cover.VectorCrsFrame(4326,sFrm) //Bounding-Box des ROI, geographisch
    else rFrm:=crFrm; //nicht definiert

  Result:=tStringList.Create;
  try
    slGrv:=tStringList.Create;
    slGrv.LoadFromFile(sGrv); //Kachel-Schwerpunkte als WKT-Zeilen
    for I:=1 to pred(slGrv.Count) do
    begin
      fPrt:=0; //Vorgabe wg. Abfrage
      sArc:=ExtractWord(5,slGrv[I],[',']); //nur Dateiname
      sDat:=copy(ExtractFileName(sArc),18,8); //Datum im Dateinamen
      if QueryDate(sDat,sPrd) and //übergebenen Zeitraum filtern
         QueryPosition(fDst,rFrm,slGrv[I]) //Distanz der Mittelpunkte
      then fPrt:=QueryQuality(sArc,sFrm); //Anteil ungestörte Pixel im Bild + Frame
      if fPrt>=fLmt then
        Result.AddObject(sArc,tObject(pointer(round(fPrt*1000)))); //Name+Qualität übernehmen
    end;
  finally
    slGrv.Free;
  end;
end;

{ rOl gibt für jeden Bildpixel in einem Stack (Zeitreihe) den Quotient zwischen
  Abweichung und Mittelwert zurück. Ausreißer und Veränderungen werden mit
  hohen Werten abgebildet. }

function tRank.Outlier(
  faDns:tnSgl): //Werte-Reihe
  single; //Abweichung/Helligkeit
// Varianz = (∑x²-(∑x)²/n)/(n-1)
var
  fSum:double=0;
  fSqr:double=0;
  fVrz:double=0;
  I:integer;
begin
  for I:=0 to high(faDns) do
  begin
    fSqr+=sqr(faDns[I]);
    fSum+=faDns[I];
  end;
  fVrz:=(fSqr-sqr(fSum)/length(faDns))/high(faDns); //Varianz ACHTUNG Rundung!
  Result:=sqrt(max(fVrz,0))/fSum*length(faDns); //Relativ zur Helligkeit
end;

{ rCL dämpft die Zeitreihe "faDns" mit einem gewichteten Mittelwert in einem
  beweglichen Fenster. Das Fenster ist "iRds"*2+1 Punkte lang, am Anfang und
  Ende der Zeitreihe kürzer. Der Mittelpunkt im Fenster hat das höchste
  Gewicht, Nachbarn sind mit dem Quadrat der Distanz reduziert. }

procedure tRank.ChainLine(
  faDns:tnSgl; //Zeitreihe
  iRds:integer); //Fang-Radius
const
  cTms = sqrt(2);
var
  faTmp:tnSgl=nil; //Zwischenlager
  fDst:single; //Distanz Wert und Zeit
  fVal:single; //Summe gewichtete Werte
  fWgt:single; //Summe gewichtete Distanzen
  I,R:integer;
begin
  SetLength(faTmp,length(faDns));
  move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Backup
  for I:=0 to high(faDns) do
  begin
    fVal:=faDns[I]; //Vorgabe
    fWgt:=1; //Vorgabe
    for R:=I-iRds to I+iRds do
    begin
      if (R<0) or (R=I) or (R>high(faDns)) then continue;
      fDst:=power(cTms,abs(I-R)); //Distanz-Faktor
      fWgt+=1/fDst; //Summe Gewichte
      fVal+=faTmp[R]/fDst //Summe gewichtete Werte
    end;
    if fWgt>0 then
      faDns[I]:=fVal/fWgt;
  end;
end;

{ rMn bildet den Median aus allen übergebenen Kanälen. Dazu kopiert rMn alle
  Werte eines Pixels nach "fxDev", sortiert "fxDev" mit "QuickSort" und
  übernimmt den Wert in der Mitte der gültigen Einträge in "fxDev". rMn kopiert
  NoData Werte in den Bilddaten nicht nach "faDev" sondern reduziert mit "iDim"
  die gültigen Stellen in "faDev". }

procedure tRank.Median(
  faDns:tnSgl; //Zeitreihe, wird verändert!
  iRds:integer);
var
  faPrt:tnSgl=nil; //Zeitreihe-Fenster
  faTmp:tnSgl=nil; //Puffer für "faDns"
  iCnt:integer; //gültige Zeitpunkte
  I,R: integer;
begin
  SetLength(faTmp,length(faDns));
  move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Backup
  SetLength(faPrt,succ(iRds*2));
  for I:=0 to high(faDns) do
  begin
    iCnt:=0;
    for R:=I-iRds to I+iRds do
    begin
      if (R<0) or (R>high(faDns)) then continue;
      faPrt[iCnt]:=faTmp[R];
      inc(iCnt);
    end;
    Reduce.QuickSort(faPrt,iCnt); //ordnen
    faDns[I]:=faPrt[trunc(iCnt/2)] //median
  end;
end;

// Zeitverlauf stark dämpfen
// NoData von Kanal 1 muss für alle Kanäle gelten
// Outlier erzeugt Suchbild = Abweichung / Helligkeit
// Median entfernt Ausreißer

procedure tRank.xEqualize(
  iRds:integer; //Fang-Radius
  sImg:string); //Vorbild
const
  cStk = 'rSg: The time course must contain at least tree layers: ';
var
  fNan:single=NaN; //NoData
  faDns:tnSgl=nil; //Werte für einen Pixel
  fxOtl:tn2Sgl=nil; //Kontroll-Bild
  fxStk:tn3Sgl=nil; //Stack aus Zeitpunkten
  rHdr:trHdr; //Metadata
  S,X,Y:integer;
begin
  rHdr:=Header.Read(sImg);
  if rHdr.Stk<3 then Tools.ErrorOut(cStk+sImg);
  faDns:=Tools.InitSingle(rHdr.Stk,0); //ein Pixel, alle Zeitpunkte
  fxStk:=Image.Read(rHdr,sImg); //Stack aus Zeitpunkten
  fxOtl:=Tools.Init2Single(rHdr.Lin,rHdr.Scn,dWord(fNan));

  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
    begin
      if isNan(fxStk[0,Y,X]) then continue;
      for S:=0 to pred(rHdr.Stk) do
        faDns[S]:=fxStk[S,Y,X]; //Zeit-Array aus einem Pixel
      fxOtl[Y,X]:=Outlier(faDns); //normalisierte Abweichung
      Median(faDns,iRds); //outlier entfernen
      //ChainLine(faDns,iRds); //LowPass
      for S:=0 to pred(rHdr.Stk) do
        fxStk[S,Y,X]:=faDns[S]; //Ausgleich als Bild
    end;
{ TODO: RECENT:
   → "Outlier" findet übersichtlich Ereignisse und Störungen
   → Schwellen für Ausreißer scheinen grundsätzlich nicht brauchbar
   → ChainLine dämpft sehr stark, reagiert aber auf Ausreißer
   → Median hat mit RGB gut funktioniert }
  Image.WriteMulti(fxStk,eeHme+'equalize');
  Header.WriteMulti(rHdr,rHdr.aBnd,eeHme+'equalize');
  Image.WriteBand(fxOtl,-1,eeHme+'outlier');
  Header.WriteScalar(rHdr,eeHme+'outlier');
  Header.Clear(rHdr);
end;

initialization

  Separate:=tSeparate.Create;
  Separate.fcPrd:=0;
  Separate.fcHrz:=0;
  Separate.fcVrt:=0;
  Separate.fcSqr:=0;
  Separate.icCnt:=0;

finalization

  Separate.Free;

end.

{==============================================================================}

// Reihe ausgleichen
// Endpunkte bleiben bestehen
// neue Werte im Schwerpunkt der besehenden
// Abstand wirkt quadratisch

function tRank._Equalize(faDns:tnSgl):tnSgl;
var
  fLow,fHig:single; //Distanz-Faktoren
  S:integer;
begin
  SetLength(Result,length(faDns));
  move(faDns[0],Result[0],length(faDns)*SizeOf(single)); //Kopie als Vorlage
  for S:=1 to length(faDns)-2 do
  begin
//------------------------------------------------------------------------------
    {fxStk[S,Y,X]:=faDns[pred(S)]/4 + faDns[S]/2 + faDns[succ(S)]/4;}
//------------------------------------------------------------------------------
    fLow:=sqr(faDns[pred(S)]-faDns[S]); //sqr<>abs
    fHig:=sqr(faDns[S]-faDns[succ(S)]); //sqr<>abs
    Result[S]:=(faDns[pred(S)]*fHig/(fLow+fHig)+faDns[S]+
      faDns[succ(S)]*fLow/(fLow+fHig))/2;
//------------------------------------------------------------------------------
  end;
end;

// Werte-Reihe ausgleichen
// Basis: arithmetisches Mittel
// Intervall frei wählbar
// Am Rand kürzeres Intervall

procedure tRank._Equalize(
  faDns:tnSgl; //Werte-Reihe
  iRds:integer); //Fangradius
var
  faTmp:tnSgl=nil; //Arbeitskopie von "faDns"
  iCnt:integer; //gültige Punkte in Periode
  R,S,T:integer;
begin
  SetLength(faTmp,length(faDns));
  for R:=1 to iRds do
  begin
    move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Vorlage
    FillDWord(faDns[0],length(faDns),0); //Vorgabe
    for S:=0 to high(faDns) do
    begin
      iCnt:=0;
      for T:=S-iRds to S+iRds do
      begin
        if (T<0) or (T>high(faDns)) then continue;
        faDns[S]+=faTmp[T];
        inc(iCnt)
      end;
      if iCnt>0 then
        faDns[S]/=iCnt;
    end;
  end;
end;

// Werte-Reihe ausgleichen
// immer drei Punkte
// Endpunkte bleiben bestehen
// Basis: gewichteter Mittelwert
// Gewicht: Distanz wirkt invers quadratisch
// Wiederholungen möglich

procedure tRank._Equalize_Sqr(
  faDns:tnSgl;
  iRpt:integer);
var
  faTmp:tnSgl=nil; //Arbeitskopie von "faDns"
  fLow,fHig:single; //Distanz-Faktoren
  R,S:integer;
begin
  SetLength(faTmp,length(faDns));
  for R:=1 to iRpt do
  begin
    move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Vorlage
    for S:=1 to length(faDns)-2 do
    begin
      fLow:=sqr(faTmp[pred(S)]-faTmp[S]); //sqr<>abs
      fHig:=sqr(faTmp[S]-faTmp[succ(S)]); //sqr<>abs
      if (fLow=0) and (fHig=0) then continue;
      faDns[S]:=(faTmp[pred(S)]*fHig/(fLow+fHig)+faTmp[S]+
        faTmp[succ(S)]*fLow/(fLow+fHig))/2
    end;
  end;
end;

// Zeitverlauf stark dämpfen
// NoData von Kanal 1 muss für alle Kanäle gelten

procedure tRank._xEqualize(sImg,sOut:string); //Vorbild
const
  cStk = 'rSg: The time course must contain at least tree layers: ';
var
  fLow,fHig:single; //Distanz-Faktoren
  faDns:tnSgl=nil; //Werte für einen Pixel
  fxStk:tn3Sgl=nil; //Stack aus Zeitpunkten
  rHdr:trHdr; //Metadata
  S,X,Y:integer;
begin
  rHdr:=Header.Read(sImg);
  if rHdr.Stk<3 then Tools.ErrorOut(cStk+sImg);
  faDns:=Tools.InitSingle(rHdr.Stk,0); //ein Pixel, alle Zeitpunkte
  fxStk:=Image.Read(rHdr,sImg); //Stack aus Zeitpunkten
  //iHig:=pred(rHdr.Stk); //für Ausgleich

  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
    begin
      //Zeitreihe für einen Pixel kopieren
      if isNan(fxStk[0,Y,X]) then continue;
      for S:=0 to pred(rHdr.Stk) do
        faDns[S]:=fxStk[S,Y,X];

      //Zeitreihe dämpfen
      {fxStk[0,Y,X]:=faDns[0]/2 + faDns[1]/2; //Mittelwert}
      for S:=1 to rHdr.Stk-2 do
      begin
//------------------------------------------------------------------------------
        {fxStk[S,Y,X]:=faDns[pred(S)]/4 + faDns[S]/2 + faDns[succ(S)]/4;}
//------------------------------------------------------------------------------
        fLow:=sqr(faDns[pred(S)]-faDns[S]); //sqr<>abs
        fHig:=sqr(faDns[S]-faDns[succ(S)]); //sqr<>abs
        fxStk[S,Y,X]:=(faDns[pred(S)]*fHig/(fLow+fHig)+faDns[S]+
          faDns[succ(S)]*fLow/(fLow+fHig))/2;
//------------------------------------------------------------------------------
      end;
      {fxStk[iHig,Y,X]:=faDns[pred(iHig)]/2 + faDns[iHig]/2; //Mittelwert}
    end;
  Image.WriteMulti(fxStk,sOut);
  Header.WriteMulti(rHdr,rHdr.aBnd,sOut);
  Header.Clear(rHdr);
end;

// Zeitverlauf stark dämpfen
// NoData von Kanal 1 muss für alle Kanäle gelten

procedure tRank.__xEqualize(
  iRpt:integer; //wiederholungen
  sImg:string; //Vorbild
  sOut:string); //Ergebns
const
  cStk = 'rSg: The time course must contain at least tree layers: ';
var
  faDns:tnSgl=nil; //Werte für einen Pixel
  fxStk:tn3Sgl=nil; //Stack aus Zeitpunkten
  rHdr:trHdr; //Metadata
  S,X,Y:integer;
begin
  rHdr:=Header.Read(sImg);
  if rHdr.Stk<3 then Tools.ErrorOut(cStk+sImg);
  faDns:=Tools.InitSingle(rHdr.Stk,0); //ein Pixel, alle Zeitpunkte
  fxStk:=Image.Read(rHdr,sImg); //Stack aus Zeitpunkten
  //iHig:=pred(rHdr.Stk); //für Ausgleich

  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
    begin
      //Zeitreihe für einen Pixel kopieren
      if isNan(fxStk[0,Y,X]) then continue;
      for S:=0 to pred(rHdr.Stk) do
        faDns[S]:=fxStk[S,Y,X];
      _Equalize(faDns,iRpt); //glätten mit "iRpt" Wiederholungen
      for S:=0 to pred(rHdr.Stk) do
        fxStk[S,Y,X]:=faDns[S];
    end;
  Image.WriteMulti(fxStk,sOut);
  Header.WriteMulti(rHdr,rHdr.aBnd,sOut);
  Header.Clear(rHdr);
end;

{ rOl gibt die größte Differenz zwischen einem Messpunkt und dem Mittelwert
  zurück. rOl unterstelt, dass alle übergebenen Layer eine Zeitreihe bilden.
  rOl bestimmt für jeden Bildpixel Mittelwert und Abweichung und übernimmt die
  größte Differenz zum Mittwelwert als Ergebnis }
{ ==> Outlier könnten entfernt werden
  ==> Outlier könnten als Differenz aufeinander folgender Differenzen schärfer werden
  ==> die Suche könnte Wiederholungen benötigen
  ==> hohe CoVarianz müsste lineare Trends anzeigen
  ==> kleine Varianz müsste konstante Perioden anzeigen
  ==> Sprünge könnten mit den Differenzen zwischen zwei Werten gesucht werden,
      wenn die Outlier entfernt sind. Für Sprünge sollten die Differenzen aller
      Kanäle getrennt erfasst werden um Farbänderungen zu finden. }

procedure tRank.xOutlier(sImg:string);
var
  fDvt,fMea:double; //Statistik
  fNan:single=NaN; //NoData als Variable
  fSqr,fSum:double; //Zwischenlager: Quadrat, Summe
  fxRes:tn2Sgl=nil; //Ergebnis-Kanal = Hauptkomponente aus einem Bild
  fxStk:tn3Sgl=nil; //Vorbild = Stack, multispektral
  iCnt:integer; //Zähler Zeitpunkte
  pVal:^single; //ausgewählter Pixel
  rHdr:trHdr; //Metadata
  I,X,Y:integer;
begin
  rHdr:=Header.Read(sImg);
  fxRes:=Tools.Init2Single(rHdr.Lin,rHdr.Scn,dWord(fNan)); //Vorgabe = ungültig
  fxStk:=Image.Read(rHdr,sImg); //Bild mit 1 Kanal pro Zeitpunkt

  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
    begin
      fSqr:=0; fSum:=0; iCnt:=0; //Vorgaben
      for I:=0 to high(fxStk) do
      begin
        pVal:=@fxStk[I,Y,X]; //Vorbild-Pixel
        if isNan(pVal^) then continue;
        fSqr+=sqr(pVal^); //Zwischenlager
        fSum+=pVal^;
        inc(iCnt) //Zähler
      end;
      if iCnt<2 then continue;

      fDvt:=sqrt((fSqr-sqr(fSum)/iCnt)/pred(iCnt)); //Abweichung
      fMea:=fSum/iCnt; //Mittelwert
      pVal:=@fxRes[Y,X]; //Ergebnis-Pixel
      if fDvt>0 then
      begin
        pVal^:=fxStk[0,Y,X]; //Vorgabe wg. NoData
        for I:=1 to high(fxStk) do
          pVal^:=max(abs(fxStk[I,Y,X]-fMea)/fDvt,pVal^) //höchste Abweichung
      end;
      fxRes[Y,X]:=pVal^;
    end;
  Image.WriteBand(fxRes,-1,eeHme+'outlier');
  Header.WriteScalar(rHdr,eeHme+'outlier');
  Header.Clear(rHdr);
end;

{ rSg sucht nach konstanten Perioden in der Zeitreihe. Zu Beginn teilt rSg die
  Zeitreihe in gleich große Perioden auf und bestimmt die gemeinsame Varianz
  von jeweils zwei Nachbar-Perioden. Dabei bilden sich lokale Minima. rSg
  vereinigt die Nachbar-Perioden an lokalen Minima und wiederholt den Prozess.
  Die Perioden wachsen bis eine Schwelle erreicht wird. rSg gibt die Anzahl der
  gebildeten Perioden zurück. }
{ rSg unterstellt, dass die übergebenen Bilddaten "sImg" eine fortlaufende und
  homogene Zeitreihe bilden. Als Schwelle für Perioden verwendet rSg
  Varianz der gesamten Zeitreihe mit einem wählbaren Faktor. }
{ in "raPrd.Prv|Nxt" ist die Varianz der aktuellen und der vorherigen|nächsten
  Periode gespeichert. "raPrd.Low|Hig" enthalten die Grenzen der aktuellen
  Periode. }

{ ==> Varianz als Schwelle scheint wenig geeignet. Das Ergebns gibt keine
      Landschafts-Strukturen wieder. Die Varianz ist nicht von der Zeit
      abhängig.
  ==> CoVarianz und konstante Schwelle verwenden. Längste Periode zurückgeben.
      RGB für drei längste Perioden? Bit-Code für periodische Abschnitte? }

procedure tRank._x1Segments_(
  fFct:single; //Faktor für Varianz
  sImg:string); //Vorbild
var
  fLmt:single; //Maximum Varianz für Vereinigung
  fNan:single=NaN; //NoData
  faDns:tnSgl=nil; //Werte für einen Pixel
  fxStk:tn3Sgl=nil; //Stack aus Zeitpunkten
  fxVrz:tn2Sgl=nil; //Varianz aller Layer
  iDrp:integer; //Zwischenlager für nPrd
  fxPrd:tn2Sgl=nil; //Anzahl Perioden
  nPrd:integer; //Anzahl Perioden
  raPrd:tra_Prd=nil; //stabile Perioden im Zeitverlauf
  rHdr:trHdr; //Metadata
  S,T,X,Y:integer;
begin
  rHdr:=Header.Read(sImg);
  fxStk:=Image.Read(rHdr,sImg); //Stack aus Zeitpunkten
  SetLength(raPrd,rHdr.Stk); //alle Zeitpunkte als Periode
  fxPrd:=Tools.Init2Single(rHdr.Lin,rHdr.Scn,dWord(fNan)); //KONTROLLE: Anzahl Perioden
  fxVrz:=Reduce.Variance(fxStk); //Varianz aller Kanäle

  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
    begin
      //Zeitreihe für einen Pixel, alle Kanäle
      faDns:=Tools.InitSingle(rHdr.Stk,dWord(fNan)); //ein Pixel, alle Zeitpunkte
      for S:=0 to pred(rHdr.Stk) do
        faDns[S]:=fxStk[S,Y,X]; //Werte für einen Pixel
      fLmt:=fxVrz[Y,X]*fFct; //Maximum Abwechung (als Varianz)

      //Vorbereitung: Intervall, keine Richtung
      for S:=0 to pred(rHdr.Stk) do
      begin
        raPrd[S].Low:=S;
        raPrd[S].Hig:=S;
        raPrd[S].Prv:=MaxSingle;
        raPrd[S].Nxt:=MaxSingle;
      end;
      for S:=1 to pred(rHdr.Stk) do
        SectVariance(faDns,@raPrd[pred(S)],@raPrd[S]); //Paare bewerten

      //lokale Minima ausdehnen
      nPrd:=rHdr.Stk;
      repeat
        iDrp:=nPrd; //Perioden vor der Prüfung
        for S:=pred(nPrd) downto 1 do
          if (raPrd[pred(S)].Prv>raPrd[pred(S)].Nxt) and
             (raPrd[S].Prv<raPrd[S].Nxt) and //lokales Minimum
             (raPrd[S].Prv<=fLmt) then //Schwelle eingehalten
          begin
            raPrd[pred(S)].Hig:=raPrd[S].Hig; //Periode erweitern
            for T:=S to nPrd-2 do //restliche Perioden ..
              raPrd[T]:=raPrd[succ(T)]; //.. verschieben
            dec(nPrd);

            //neue Kontakte vorbelegen
            if S>1 then raPrd[S-2].Nxt:=MaxSingle;
            raPrd[pred(S)].Prv:=MaxSingle;
            raPrd[pred(S)].Nxt:=MaxSingle;
            if S<nPrd then raPrd[S].Prv:=MaxSingle;

            //Varianz neu bestimmen
            if S>1 then SectVariance(faDns,@raPrd[S-2],@raPrd[pred(S)]); //Intervall bewerten
            if S<nPrd then SectVariance(faDns,@raPrd[pred(S)],@raPrd[S]); //Intervall bewerten
          end;
      until nPrd=iDrp; //keine Veränderung

      //längstes Intervall NUR KONTROLLE
      iDrp:=raPrd[0].Hig-raPrd[0].Low;
      for S:=1 to pred(nPrd) do
        iDrp:=max(raPrd[S].Hig-raPrd[S].Low,iDrp);
      fxPrd[Y,X]:=succ(iDrp); //längstes Intervall NUR KONTROLLE
    end;
  Image.WriteBand(fxPrd,-1,eeHme+'segments');
  Header.WriteScalar(rHdr,eeHme+'segments');
  Header.Clear(rHdr);
end;

{ rSg sucht nach konstanten Perioden in der Zeitreihe. Zu Beginn teilt rSg die
  Zeitreihe in gleich große Perioden auf und bestimmt die gemeinsame CoVarianz
  von jeweils zwei Nachbar-Perioden. Dabei bilden die sich lokale Maxima der
  Beträge. rSg vereinigt die Nachbar-Perioden an lokalen Maxima und wiederholt
  den Prozess. Die Perioden wachsen bis eine Schwelle erreicht wird. rSg gibt
  die längste Periode als Wert zurück. }
{ rSg unterstellt, dass die übergebenen Bilddaten "sImg" eine fortlaufende und
  homogene Zeitreihe bilden. }
{ in "raPrd.Prv|Nxt" ist die CoVarianz der aktuellen mit der jeweils vorherigen
  bzw. nächsten Periode gespeichert. "raPrd.Low|Hig" enthält die Grenzen der
  aktuellen Periode. }

{ ==> Bit-Code für periodische Abschnitte? }

procedure tRank._x2Segments_(
  fLmt:single; //Faktor für Varianz
  sImg:string); //Vorbild
var
  fNan:single=NaN; //NoData
  faDns:tnSgl=nil; //Werte für einen Pixel
  fxStk:tn3Sgl=nil; //Stack aus Zeitpunkten
  iDrp:integer; //Zwischenlager für nPrd
  fxPrd:tn2Sgl=nil; //Anzahl Perioden
  nPrd:integer; //Anzahl Perioden
  raPrd:tra_Prd=nil; //stabile Perioden im Zeitverlauf
  rHdr:trHdr; //Metadata
  S,T,X,Y:integer;
begin
  rHdr:=Header.Read(sImg);
  fxStk:=Image.Read(rHdr,sImg); //Stack aus Zeitpunkten
  SetLength(raPrd,rHdr.Stk); //alle Zeitpunkte als Periode
  fxPrd:=Tools.Init2Single(rHdr.Lin,rHdr.Scn,dWord(fNan)); //KONTROLLE: Anzahl Perioden

  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
    begin
      //Zeitreihe für einen Pixel, alle Kanäle
      faDns:=Tools.InitSingle(rHdr.Stk,dWord(fNan)); //ein Pixel, alle Zeitpunkte
      for S:=0 to pred(rHdr.Stk) do
        faDns[S]:=fxStk[S,Y,X]; //Werte für einen Pixel

      //Vorbereitung: Intervall, keine Richtung
      for S:=0 to pred(rHdr.Stk) do
      begin
        raPrd[S].Low:=S;
        raPrd[S].Hig:=S;
        raPrd[S].Prv:=0;
        raPrd[S].Nxt:=0;
      end;
      for S:=1 to pred(rHdr.Stk) do
        _SgCoVariance(faDns,@raPrd[pred(S)],@raPrd[S]); //Paare bewerten

      //lokale Minima ausdehnen
      nPrd:=rHdr.Stk;
      repeat
        iDrp:=nPrd; //Perioden vor der Prüfung
        for S:=pred(nPrd) downto 1 do
          if (abs(raPrd[pred(S)].Prv)<abs(raPrd[pred(S)].Nxt)) and
             (abs(raPrd[S].Prv)>abs(raPrd[S].Nxt)) and //lokales Minimum
             (abs(raPrd[S].Prv)>=fLmt) then //Schwelle eingehalten
          begin
            raPrd[pred(S)].Hig:=raPrd[S].Hig; //Periode erweitern
            for T:=S to nPrd-2 do //restliche Perioden ..
              raPrd[T]:=raPrd[succ(T)]; //.. verschieben
            dec(nPrd);

            //neue Kontakte vorbelegen
            if S>1 then raPrd[S-2].Nxt:=0;
            raPrd[pred(S)].Prv:=0;
            raPrd[pred(S)].Nxt:=0;
            if S<nPrd then raPrd[S].Prv:=0;

            //Varianz neu bestimmen
            if S>1 then _SgCoVariance(faDns,@raPrd[S-2],@raPrd[pred(S)]); //Intervall bewerten
            if S<nPrd then _SgCoVariance(faDns,@raPrd[pred(S)],@raPrd[S]); //Intervall bewerten
          end;
      until nPrd=iDrp; //keine Veränderung

      //längstes Intervall NUR KONTROLLE
      {iDrp:=raPrd[0].Hig-raPrd[0].Low;
      for S:=1 to pred(nPrd) do
        iDrp:=max(raPrd[S].Hig-raPrd[S].Low,iDrp);
      fxPrd[Y,X]:=succ(iDrp); //längstes Intervall NUR KONTROLLE}

      //Dichte der Intervalle
      fxPrd[Y,X]:=nPrd/rHdr.Stk; //Intervall-Dichte NUR KONTROLLE
    end;
  Image.WriteBand(fxPrd,-1,eeHme+'segments');
  Header.WriteScalar(rHdr,eeHme+'segments');
  Header.Clear(rHdr);
end;

{ rSg sucht nach konstanten Perioden in der Zeitreihe. Zu Beginn teilt rSg die
  Zeitreihe in gleich große Perioden auf und bestimmt die gemeinsame CoVarianz
  von jeweils zwei Nachbar-Perioden. Dabei bilden die sich lokale Maxima der
  Beträge. rSg vereinigt die Nachbar-Perioden an lokalen Maxima und wiederholt
  den Prozess. Die Perioden wachsen bis eine Schwelle erreicht wird. rSg gibt
  die längste Periode als Wert zurück. }
{ rSg unterstellt, dass die übergebenen Bilddaten "sImg" eine fortlaufende und
  homogene Zeitreihe bilden. }
{ in "raPrd.Prv|Nxt" ist die CoVarianz der aktuellen mit der jeweils vorherigen
  bzw. nächsten Periode gespeichert. "raPrd.Low|Hig" enthält die Grenzen der
  aktuellen Periode. }

{ ==> CoVarianz für 3-Punkt-Intervalle verwenden
       → jedes Intervall getrennt rechnen
       → die Intervalle überlappen sich!
       → Schwelle anwenden
       → wenn bei zwei aufeinander folgenden Intervallen die Richtung stimmt,
         dann Intervalle vereinigen
       → Werte auf mittlere Helligkeit normalisieren
  ==> Bit-Code für periodische Abschnitte?

  ==> Daten sind zu stark verrauscht
  ==> Zeitreihen stark dämpfen (Kettenlinie)
  ==> Ausreißer dann leicht erkennbar
  ==> Umkehrpunkte als Perioden-Trenner?}

procedure tRank._x3Segments_(
  fLmt:single; //Faktor für Varianz
  sImg:string); //Vorbild
const
  cStk = 'rSg: The time course must contain at least tree layers: ';
var
  fNan:single=NaN; //NoData
  faCov:tnSgl=nil; //CoVarianz ür 3-Punkt-Intervalle
  faDns:tnSgl=nil; //Werte für einen Pixel
  faMed:tnSgl=nil; //Mittelwert ür 3-Punkt-Intervalle
  fxPrd:tn2Sgl=nil; //Anzahl Perioden
  fxStk:tn3Sgl=nil; //Stack aus Zeitpunkten
  iaPrd:tnInt=nil; //Perioden-IDs als Array
  rHdr:trHdr; //Metadata
  S,X,Y:integer;
begin
  rHdr:=Header.Read(sImg);
  if rHdr.Stk<3 then Tools.ErrorOut(cStk+sImg);
  faCov:=Tools.InitSingle(rHdr.Stk,0); //CoVarianz für 3-Punkt-Intervalle
  faMed:=Tools.InitSingle(rHdr.Stk,0); //Mittelwert für 3-Punkt-Intervalle
  fxPrd:=Tools.Init2Single(rHdr.Lin,rHdr.Scn,dWord(fNan)); //Anzahl Perioden KONTROLLE
  fxStk:=Image.Read(rHdr,sImg); //Stack aus Zeitpunkten
  iaPrd:=Tools.InitInteger(rHdr.Stk,0); //Perioden-IDs

  for Y:=0 to pred(rHdr.Lin) do
    for X:=0 to pred(rHdr.Scn) do
    begin
      //Zeitreihe für einen Pixel, alle Kanäle
      faDns:=Tools.InitSingle(rHdr.Stk,dWord(fNan)); //ein Pixel, alle Zeitpunkte
      for S:=0 to pred(rHdr.Stk) do
        faDns[S]:=fxStk[S,Y,X]; //Werte für einen Pixel

      //CoVarianz für 3-Punkte-Intervall
      for S:=1 to rHdr.Stk-2 do
      begin
        faCov[S]:=_CovPeriod(faDns,pred(S),succ(S)); //Paare bewerten
        faMed[S]:=(faDns[pred(S)]+faDns[S]+faDns[succ(S)])/3; //Mittelwert
      end;

      //Perioden suchen
      iaPrd[1]:=1; //erstes Intervall
      for S:=2 to rHdr.Stk-2 do
        if abs(faCov[pred(S)]/faMed[pred(S)]+faCov[S]/faMed[S])>fLmt //Schwelle?
          then iaPrd[S]:=iaPrd[pred(S)] //gleiches Intervall
          else iaPrd[S]:=succ(iaPrd[pred(S)]); //neues Intervall

      fxPrd[Y,X]:=iaPrd[S]; //Anzahl Intervalle NUR KONTROLLE
    end;
  Image.WriteBand(fxPrd,-1,eeHme+'segments');
  Header.WriteScalar(rHdr,eeHme+'segments');
  Header.Clear(rHdr);
end;

{ rTT erzeugt ein multispektrales Bild der Textur in der Zeit. Dazu läd rTT
  immer denselben Kanal aus allen übergebenen Bildern (Zeitreihe) und bestimmt
  die erste Hauptkomponente aller Pixel in der Zeit. rTT ignoriert NoData Pixel
  in allen Kanälen und Zeiten. }

procedure tRank._xTime_Texture_(sImg:string);
const
  cPrd = 'rTT: Bands per image seem to differ at: ';
var
  fNan:single=NaN; //NoData als Variable
  fSed:single; //Summe quadrierte Differenzen
  fxRes:tn2Sgl=nil; //Ergebnis-Kanal
  fxStk:tn3Sgl=nil; //Zeitreihe für einen Kanal
  iBnd:integer=-1; //neues Bild bei erstem Kanal
  iCnt:integer; //Anzahl gültige Bilder
  rHdr:trHdr; //Metadata
  sBnd:string=''; //Kanal-Namen
  B,I,X,Y:integer;
begin
  rHdr:=Header.Read(sImg);
  if rHdr.Stk mod rHdr.Prd>0 then Tools.ErrorOut(cPrd+sImg);
  SetLength(fxStk,rHdr.Stk div rHdr.Prd,1,1); //Dummy, Ein Kanal für jedes Bild
  for B:=0 to pred(rHdr.Prd) do //alle Ergebnis-Kanäle
  begin
    sBnd+=ExtractWord(succ(B),rHdr.aBnd,[#10])+#10;
    for I:=0 to pred(rHdr.Stk div rHdr.Prd) do //alle Vorbilder
      fxStk[I]:=Image.ReadBand(I*rHdr.Prd+B,rHdr,sImg); //Kanal "B" aus Bild "I" laden
    fxRes:=Tools.Init2Single(rHdr.Lin,rHdr.Scn,dWord(fNan)); //Vorgabe = ungültig
    for Y:=0 to pred(rHdr.Lin) do
      for X:=0 to pred(rHdr.Scn) do
      begin
        fSed:=0; iCnt:=0;
        for I:=1 to high(fxStk) do
        begin
          if isNan(fxStk[pred(I),Y,X])
          or IsNan(fxStk[I,Y,X]) then continue;
          fSed+=sqr(fxStk[pred(I),Y,X]-fxStk[I,Y,X]);
          inc(iCnt)
        end;
        if iCnt>0 then
          fxRes[Y,X]:=sqrt(fSed/iCnt);
          //fxRes[Y,X]:=sqrt(fSed)/iCnt;
      end;
    Image.WriteBand(fxRes,iBnd,eeHme+'timetexture'); //neues Bild für B=0, dann stapeln
    iBnd:=B;
  end;
  Header.WriteMulti(rHdr,sBnd,eeHme+'timetexture');
  Header.Clear(rHdr);
end;

// Werte-Reihe ausgleichen
// immer drei Punkte
// Endpunkte bleiben bestehen
// Basis: gewichteter Mittelwert
// Gewicht: Distanz wirkt invers quadratisch
// Wiederholungen möglich

procedure tRank.___Chain_Line(
  faDns:tnSgl;
  iRpt:integer);
var
  faTmp:tnSgl=nil; //Arbeitskopie von "faDns"
  fLow,fHig:single; //Distanz-Faktoren
  R,S:integer;
begin
  SetLength(faTmp,length(faDns));
  for R:=1 to iRpt do
  begin
    move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Vorlage
    for S:=1 to length(faDns)-2 do
    begin
      fLow:=abs(faTmp[pred(S)]-faTmp[S])/(faTmp[pred(S)]+faTmp[S]);
      fHig:=abs(faTmp[S]-faTmp[succ(S)])/(faTmp[S]+faTmp[succ(S)]);
      if (fLow=0) and (fHig=0) then continue;
      faDns[S]:=(faTmp[pred(S)]*fHig/(fLow+fHig)+faTmp[S]+
        faTmp[succ(S)]*fLow/(fLow+fHig))/2
    end;
  end;
end;

{ rLP bestimmt für jede Periode in "raDns" die multispektrale Varianz aller
  Pixel zusammen mit einer der Nachbar-Perioden. rLP übergibt die ID der
  besser passenden Nachbar-Periode in "raPrd.Lnk". }

function tRank._Cov_Period(
  faDns:tnSgl; //Zeitverlauf Helligkeit
  iLow,iHig:integer): //erster, letzter Zeitpunkt in "faDns"
  single;
var
  fPrd:double=0; //Summe Werteprodukt
  fSum:double=0; //Summe Werte
  fTms:double=0; //Summe Zeitstempel
  iCnt:integer=0; //Anzahl gültige Abschnitte
  S:integer;
begin
  Result:=0; //Vorgabe = keine Korrelation
  for S:=iLow to iHig do //Intervall
    if not isNan(faDns[S]) then
    begin
      fPrd+=faDns[S]*S;
      fSum+=faDns[S];
      fTms+=S;
      inc(iCnt)
    end;
  if iCnt>1 then
    Result:=(fPrd-fSum*fTms/iCnt)/pred(iCnt)
end;

// Standardabweichung relativ zur Dichte
// mit faDns[0]<>NaN müssen alle Werte gültig sein ← Lücken vorher interpolieren

function tRank.__D_eviation(
  faDns:tnSgl; //Werte-Reihe
  var fMwt:single): //Mittelwert
  single; //Abweichung
// Varianz = (∑x²-(∑x)²/n)/(n-1)
var
  fSum:double=0;
  fSqr:double=0;
  fVrz:double=0;
  I:integer;
begin
  for I:=0 to high(faDns) do
  begin
    fSqr+=sqr(faDns[I]);
    fSum+=faDns[I];
  end;
  fVrz:=(fSqr-sqr(fSum)/length(faDns))/high(faDns); //Varianz ACHTUNG Rundung!
  Result:=sqrt(max(fVrz,0)); //Abweichung (Rundungsfehler!)
  fMwt:=fSum/length(faDns); //Mittelwert
end;

// Werte-Reihe ausgleichen
// Basis: arihmetisches Mittel
// immer genau drei Punkte
// am Rand nur zwei Punkte
// Wiederholungen möglich

procedure tRank._E_qualize(
  faDns:tnSgl; //Werte-Reihe
  iRpt:integer); //Wiederholungen
var
  faTmp:tnSgl=nil; //Arbeitskopie von "faDns"
  iHig:integer; //höchster Index
  R,S:integer;
begin
  SetLength(faTmp,length(faDns));
  iHig:=high(faDns);
  for R:=1 to iRpt do
  begin
    move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Vorlage
    faDns[0]:=(faTmp[0]+faTmp[1])/2;
    for S:=1 to length(faDns)-2 do
      faDns[S]:=(faTmp[pred(S)]+faTmp[S]+faTmp[succ(S)])/3;
    faDns[iHig]:=(faTmp[pred(iHig)]+faDns[iHig])/2;
  end;
end;

// Ausnahmen: ein Extremwerte neben zwei normalen
//

procedure tRank._Fill_Exception(
  faDns:tnSgl; //Zeitreihe
  fLmt:single); //Schwelle = Abweichung / Mittelwert * Faktor
var
  faTmp:tnSgl=nil; //Puffer für Zeitreihe
  iHig:integer; //höchster Index
  I:integer;
begin
  // mindestens drei Punkte!
  SetLength(faTmp,length(faDns));
  move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Backup
  if abs(faTmp[0]*2-(faTmp[1]+faTmp[2]))>fLmt then
    faDns[0]:=faTmp[1]*2-faTmp[1]; //extrapolieren
  for I:=1 to length(faTmp)-2 do
    if abs(faTmp[I]*2-(faTmp[pred(I)]+faTmp[succ(I)]))>fLmt then //NULLDIVISION?
      faDns[I]:=(faTmp[pred(I)]+faTmp[succ(I)])/2; //interpolieren
  iHig:=high(faDns);
  if abs(faTmp[iHig]*2-(faTmp[pred(iHig)]+faTmp[iHig-2]))>fLmt then //
    faDns[iHig]:=faTmp[pred(iHig)]*2-faTmp[iHig-2]; //extrapolieren
end;

procedure tRank._O_utlier(
  faDns:tnSgl; //Werte-Reihe
  fLmt:single); //Minimum Abweichung = sqrt(Varianz)/Mittelwert
// Varianz = (∑x²-(∑x)²/n)/(n-1)
var
  faTmp:tnSgl=nil; //Buffer
  fDvt,fSum,fSqr:single;
  I,K:integer;
begin
  SetLength(faTmp,length(faDns));
  move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Backup

  for I:=1 to length(faDns)-2 do
  begin
    fSum:=0; fSqr:=0;
    for K:=pred(I) to succ(I) do
    begin
      fSqr+=sqr(faTmp[K]);
      fSum+=faTmp[K];
    end;

    fDvt:=sqrt((fSqr-sqr(fSum)/3)/2);

    if abs(faTmp[I]-fSum/3)>fDvt*fLmt then
      faDns[I]:=(faDns[pred(I)]+faDns[succ(I)])/2; //Extremwert ersetzen

    if I=0 then
      if abs(faTmp[0]-fSum/3)>fDvt*fLmt then
        faDns[0]:=(faDns[I]+faDns[succ(I)])/2; //Extremwert ersetzen

    if I=pred(high(faDns)) then
      if abs(faTmp[high(faDns)]-fSum/3)>fDvt*fLmt then
        faDns[high(faDns)]:=(faDns[pred(I)]+faDns[I])/2; //Extremwert ersetzen
  end;
end;

procedure tRank.__O_utlier(
  faDns:tnSgl; //Zeitreihe
  fLmt:single); //minimale Abweichung
var
  fMax:single=0; //größte Abweichung
  iHig,iLow:integer; //Zeitpunkte vor/nach aktuellem Punkt
  iOtl:integer=-1; //Zeitpunkt der größten Abweichung
  I:integer;
begin
  for I:=0 to high(faDns) do
  begin
    if I=0 then iLow:=2 else iLow:=pred(I);
    if I=high(faDns) then iHig:=length(faDns)-3 else iHig:=succ(I);
    if faDns[I]/(faDns[iLow]+faDns[iHig])*2>fMax then
    begin
      iOtl:=I;
      fMax:=faDns[I]/(faDns[iLow]+faDns[iHig])*2
    end;
  end;

  if fMax>=fLmt then
  begin
    if iOtl=0 then iLow:=2 else iLow:=pred(iOtl);
    if iOtl=high(faDns) then iHig:=length(faDns)-3 else iHig:=succ(iOtl);
    faDns[iOtl]:=(faDns[iLow]+faDns[iHig])/2
  end;
end;

// Kontrastausgleich
// Punkte gewichten ← Gewicht = Distanz in Zeit + Wert
// Varianz = (∑x²-(∑x)²/n)/(n-1)

procedure tRank.___O_utlier(
  faDns:tnSgl; //Zeitreihe
  fFct:single;
  iRds:integer);
var
  faTmp:tnSgl=nil; //Zwischenlager
  fSum:single; //Summe Werte in Umgebung
  iCnt:integer; //Anzahl gültige Punkte
  I,R:integer;
begin
  SetLength(faTmp,length(faDns));
  move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Backup
  for I:=0 to high(faDns) do
  begin
    fSum:=0; iCnt:=0;
    for R:=I-iRds to I+iRds do
    begin
      if (R<0) or (R=I) or (R>high(faDns)) then continue; //Intervall beschneiden
      fSum+=faTmp[R];
      inc(iCnt)
    end;
    if (iCnt>0) and (abs(faTmp[I]/fSum*iCnt)>fFct) then
      faDns[I]:=fSum/iCnt;
  end;
end;

{ rLP bestimmt für jede Periode in "raDns" die multispektrale Varianz aller
  Pixel zusammen mit einer der Nachbar-Perioden. rLP übergibt die ID der
  besser passenden Nachbar-Periode in "raPrd.Lnk". }

{ ==> nur Helligkeit verwenden
  ==> alternativ mit CoVarianz }

procedure tRank.S_ectVariance(
  faDns:tnSgl; //Zeitverlauf Helligkeit
  pSml,pLrg:tpr_Prd); //erste, zweite Periode (small ID, large ID)
var
  fSqr:double=0; //Summe quadrierte Werte
  fSum:double=0; //Summe Werte
  fVrz:double=0; //Varianz aller Abschnitte
  iCnt:integer=0; //Anzahl gültige Abschnitte
  S:integer;
begin
  //Zwischenergebnisse
  for S:=pSml^.Low to pLrg^.Hig do //gemeinsames Intervall
  begin
    if isNan(faDns[S]) then continue;
    fSqr+=sqr(faDns[S]);
    fSum+=faDns[S];
    inc(iCnt)
  end;

  //Varianz der vereinigten Perioden
  if iCnt>1 then
  begin
    fVrz+=(fSqr-sqr(fSum)/iCnt)/pred(iCnt); //Varianzen, gemeinsames Intervall
    pSml^.Nxt:=min(fVrz,pSml^.Nxt); //Varianzen eintragen
    pLrg^.Prv:=min(fVrz,pLrg^.Prv);
  end;
end;

{ rLP bestimmt für jede Periode in "raDns" die multispektrale Varianz aller
  Pixel zusammen mit einer der Nachbar-Perioden. rLP übergibt die ID der
  besser passenden Nachbar-Periode in "raPrd.Lnk". }

procedure tRank._S_gCoVariance(
  faDns:tnSgl; //Zeitverlauf Helligkeit
  pSml,pLrg:tpr_Prd); //erste, zweite Periode (small ID, large ID)
var
  fPrd:double=0; //Summe Werteprodukt
  fSum:double=0; //Summe Werte
  fTms:double=0; //Summe Zeitstempel
  fVrz:double=0; //CoVarianz aller Abschnitte
  iCnt:integer=0; //Anzahl gültige Abschnitte
  S:integer;
begin
  //Zwischenergebnisse
  for S:=pSml^.Low to pLrg^.Hig do //gemeinsames Intervall
  begin
    if isNan(faDns[S]) then continue;
    fPrd+=faDns[S]*S;
    fSum+=faDns[S];
    fTms+=S;
    inc(iCnt)
  end;

  //CoVarianz der vereinigten Perioden (∑xy - ∑x∑y/n)/(n-1)
  if iCnt>1 then
  begin
    fVrz+=(fPrd-fSum*fTms/iCnt)/pred(iCnt); //Varianzen, gemeinsames Intervall
    if abs(fVrz)>abs(pSml^.Nxt) then pSml^.Nxt:=fVrz; //Varianzen eintragen
    if abs(fVrz)>abs(pLrg^.Prv) then pLrg^.Prv:=fVrz;
  end;
end;

procedure tRank._Chain_Line(faDns:tnSgl);
var
  faTmp:tnSgl=nil; //Zwischenlager
  fDns:single; //Zwischenlager
  fFct:single; //Distanz-Faktor
  fWgt:single; //Gewichts-Anteile
  iRds:integer; //Umgebung
  I,R:integer;
begin
  SetLength(faTmp,length(faDns));
  move(faDns[0],faTmp[0],length(faDns)*SizeOf(single)); //Kopie als Backup
  iRds:=3;
  for I:=0 to high(faDns) do
  begin
    fDns:=0; fWgt:=0;
    for R:=I-iRds to I+iRds do
    begin
      if (R<0) or (R>high(faDns)) then continue;
      fFct:=1/power(1.2,abs(I-R));
      fWgt+=fFct;
      fDns+=faTmp[R]*fFct;
    end;
    if fWgt>0 then
      faDns[I]:=fDns/fWgt;
  end;
end;

