unit Loop;

{ WARNUNG: Loop-Hooks dürfem keinen "replace" Befehl enthalten }

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Format;

type
  tChange = class(tObject)
    private
    public
      procedure LoopParams_(sCmd,sTbl:string);
      procedure _LoopImalys(sCmd,sTbl:string);
      procedure _VarExchange(slPrc,slVar:tStringList);

  end;

var
  Change: tChange;

implementation

//erste Zeile der Tabelle = $1 tab $2 tab $3 ..

procedure tChange.LoopParams_(sCmd,sTbl:string);
var
  iPst:integer; //Position "$" in Hook-Zeile
  iVid:integer; //Variablen-ID = Ziffer nach "$"
  sHnt:string=''; //Loop-Zähler
  sIdx:string=''; //erste Zeile aus variablen-Liste
  sOut:string=''; //Letzte Output-Zeile im Loop-Prozess
  slAls:tStringList=nil; //Variablen im aktuellen Prozess
  slCmd:tStringList=nil; //aktuelle Befehle und Parameter
  slLst:tStringList=nil; //Liste mit Variablen für konsekutive Prozesse
  slPrm:tStringList=nil; //Parameter-Filename als Liste
  A,P,T:integer;
begin
  try
    slAls:=tStringList.Create;
    slCmd:=tStringList.Create;
    slLst:=tStringList.Create;
    slPrm:=tStringList.Create;
    slLst.LoadFromFile(sTbl);
    sIdx:=Tools.LineRead(sTbl); //erste Zeile der Tabelle = Indices
    for A:=1 to WordCount(sIdx,[#9]) do
      slAls.Add(ExtractWord(A,sIdx,[#9])); //Variable anlegen
    slPrm.Add(eeHme+'commands'); //aktuelle Befehle

    for T:=0 to pred(slLst.Count) do
    begin
      if trim(slLst[T])='' then continue; //Leerzeichen ignorieren
      for A:=1 to slAls.Count do
        slAls[pred(A)]:=trim(ExtractWord(A,slLst[T],[#9])); //aktuelle Variable
      slCmd.LoadFromFile(sCmd); //Vorbild Befehle (mit Variablen)
      for P:=1 to pred(slCmd.Count) do
      begin
        if trim(slCmd[P])='' then continue; //Leerzeile

        iPst:=pos('$',slCmd[P]); //Variable suchen
        while iPst>0 do
        begin
          iVid:=StrToInt(slCmd[P][succ(iPst)]); //Variablen-ID als Zahl
          slCmd[P]:=copy(slCmd[P],1,pred(iPst))+slAls[pred(iVid)]+
            copy(slCmd[P],iPst+2,$FF); //Variable eingesetzt
          iPst:=pos('$',slCmd[P]); //beliebig viele Variable sind zulässig
        end;
      end;
      slCmd.SaveToFile(eeHme+'commands');
      Tools.OsExecute(eeExc,slPrm);

      sOut:=Tools.GetOutput(Tools.prSys); //Prozess-Output
      iPst:=pos('ImalysError',sOut); //Abbruch-Meldung?
      sHnt:='imalys-chain ['+TimeToStr(Time)+'] '+IntToStr(T)+': '; //Prozess-ID
      for A:=1 to pred(slAls.Count) do
        sHnt+=slAls[A]+', '; //Prozess-Variable
      if iPst>1 then sHnt+=copy(sOut,iPst,$FF); //Abbruch-Indikator
      writeln(sHnt);
      Tools.TextAppend(ExtractFilePath(sTbl)+'process.log',sHnt+#10); //als Text speichern
    end;
  finally
    slAls.Free;
    slCmd.Free;
    slLst.Free;
    slPrm.Free;
  end;
end;

procedure tChange._VarExchange(
  slPrc:tStringList; //Prozesskette
  slVar:tStringList); //Variable
var
  iPst:integer; //Position des "$" Zeichens ODER Null
  iVid:integer; //ID der Variable als Zahl
  P:integer;
begin
  for P:=1 to pred(slPrc.Count) do
  begin
    if trim(slPrc[P])='' then continue; //Leerzeile
    iPst:=pos('$',slPrc[P]); //Variable suchen
    while iPst>0 do
    begin
      iVid:=StrToInt(slPrc[P][succ(iPst)]); //Variablen-ID als Zahl
      slPrc[P]:=copy(slPrc[P],1,pred(iPst))+slVar[iVid]+
        copy(slPrc[P],iPst+2,$FF); //Variable eingesetzt
      iPst:=pos('$',slPrc[P]); //beliebig viele Variable sind zulässig
    end;
  end;
end;

{ cLI ersetzt Variable in einem Imalys-Hook durch Variable in einer mit Tabs
  getrennten Text-Tabelle. cLI läd die Befehlskette, ersetzt die nummerierten
  Variablen in der Reihenfolge der Spalten und speichert das Ergebnis. Ist die
  Anzahl der Variablen größer als die Spalten der Tabelle, verändert cLI nur
  Variable die einer Spalte entsprechen. Jede Zeile erzeugt eine modifizuerte
  Prozess-Kette und ruft damit "x_Imalys" auf. }

procedure tChange._LoopImalys(
  sCmd:string; //Prozesskette
  sTbl:string); //Variable
var
  iCls:integer=0; //Spalten in Tabelle "sTbl"
  iPst:integer=0; //Position "$" Zeichen (Variable)
  iRpl:integer=0; //Zeile mit "replace" Befehl
  iVid:integer=0; //ID der Variable [1..9]
  slCmd:tStringList=nil; //Prozesskette
  slTbl:tStringList=nil; //Tabelle mit Variablen
  sHnt:string=''; //Prozess-Kontrollstring
  sVar:string=''; //aktuelle Variable
  C,T:integer;
  qV:string;
begin
  try
    slCmd:=tStringList.Create; //Liste mit Befehlen
    slTbl:=tStringList.Create; //Tabelle mit Variablen
    slTbl.LoadFromFile(sTbl);
    iCls:=WordCount(slTbl[0],[#9]); //Tab-getrennte Worte
    slCmd.LoadFromFile(sCmd); //
    for C:=1 to pred(slCmd.Count) do
      if pos('replace',slCmd[C])>0 then //Beginn Abschnitt suchen
      begin
        iRpl:=succ(C);
        break
      end;

    for T:=0 to pred(slTbl.Count) do //alle Zeilen der Tabelle
    begin
      sHnt:=''; //Parameter als Zeile
      if T>0 then slCmd.LoadFromFile(sCmd); //Befehle mit Variablen
      for C:=iRpl to pred(slCmd.Count) do //Zeilen ab "replace"
      begin
        qV:=slCmd[C];
        iPst:=pos('$',slCmd[C]);
        if iPst<1 then break; //Replace-Abschnitt beendet

        iVid:=StrToInt(slCmd[C][succ(iPst)]); //Ziffer nach "$"
        if iVid>iCls then continue; //Index zu hoch

        sVar:=trim(ExtractWord(iVid,slTbl[T],[#9])); //Eintrag in Spalte Vid, Zeile T
        qV:=copy(slCmd[C],1,succ(iPst))+'='+sVar;
        slCmd[C]:=copy(slCmd[C],1,succ(iPst))+'='+sVar; //neue Variable
        sHnt+=sVar+', '; //Liste der Variable für Hint
      end;

      slCmd.SaveToFile(eeHme+'commands'); //Prozesskette ohne Variable
      Tools.OsCommand(eeExc,eeHme+'commands'); //Prozesskette mit modifizierten Variablen
  { TODO: [LOOP] "eeHme" ist hier konstant * $whoami liefert den Benutzer-Namen *
          /usr/home/$whoami/.imalys kann erzeugt werden * oder Benutzer-Name aus
          Parameter übernehmen }
      sHnt+='('+IntToStr(Tools.prSys.ExitCode)+')'; //Exit-Code ergänzen
      sHnt:='imalys-loop['+TimeToStr(Time)+'] '+IntToStr(T)+': '+sHnt;
      writeln(sHnt); //am Bildschirm
      Tools.TextAppend(ExtractFilePath(sTbl)+'process.log',sHnt+#10); //als Text speichern
    end;
  finally
    slCmd.Free;
    slTbl.Free;
  end;
end;

end.






