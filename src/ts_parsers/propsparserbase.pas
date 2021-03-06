{
  This file is part of Tester

  Copyright (C) 2017-2018 Alexander Kernozhitsky <sh200105@mail.ru>

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}
unit propsparserbase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, problemprops, checkers, logfile, LazFileUtils,
  testerfileutil, compilers, checkercompile;

type

  { TPropertiesParserBase }

  TPropertiesParserBase = class
  private
    FIsTerminated: boolean;
    FProperties: TProblemProperties;
    FWorkingDir: string;
    procedure SetWorkingDir(AValue: string);
  protected
    procedure ParseTestlibChecker(ACheckerSrc: string; var Success: boolean);
    procedure AddTestsFmt(const InputFmt, OutputFmt: string; TestCount: integer);
    function DoParse: boolean; virtual; abstract;
  public
    property WorkingDir: string read FWorkingDir write SetWorkingDir;
    property IsTerminated: boolean read FIsTerminated;
    procedure Terminate;
    property Properties: TProblemProperties read FProperties;
    function Parse: boolean;
    constructor Create; virtual;
    destructor Destroy; override;
  end;

  TPropertiesParserClass = class of TPropertiesParserBase;

  { TProblemPropsCollector }

  TProblemPropsCollector = class
  private
    FIsTerminated: boolean;
    FProperties: TProblemProperties;
  public
  const
    UnknownStr = '%*unknown*%';
    UnknownInt = -2147483648;
  public
    property IsTerminated: boolean read FIsTerminated;
    property Properties: TProblemProperties read FProperties;
    class function CleanProperties: TProblemProperties;
    class function MergeStr(const Str1, Str2: string; var Success: boolean): string;
    class function MergeInt(Int1, Int2: integer; var Success: boolean): integer;
    class function MergeChecker(Chk1, Chk2: TProblemChecker;
      var Success: boolean): TProblemChecker;
    class procedure MergeTests(BaseTst, MergeTst: TProblemTestList; Terminated: PBoolean = nil);
    procedure Terminate;
    function Merge(Props: TProblemProperties): boolean;
    function Finalize: boolean;
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TPropertiesParserBase }

procedure TPropertiesParserBase.SetWorkingDir(AValue: string);
begin
  if FWorkingDir = AValue then
    Exit;
  FWorkingDir := AValue;
end;

procedure TPropertiesParserBase.ParseTestlibChecker(ACheckerSrc: string;
  var Success: boolean);
var
  CheckerExe: string;
begin
  ACheckerSrc := CorrectFileName(AppendPathDelim(WorkingDir) + ACheckerSrc);
  CheckerExe := CompileChecker(ACheckerSrc);
  if CheckerExe <> '' then
    Properties.Checker :=
      TTestlibChecker.Create(CreateRelativePath(CheckerExe, WorkingDir))
  else
    Success := False;
end;

procedure TPropertiesParserBase.AddTestsFmt(const InputFmt, OutputFmt: string;
  TestCount: integer);
var
  I: integer;
begin
  with TProblemPropsCollector do
    if (InputFmt = UnknownStr) or (OutputFmt = UnknownStr) then
      Exit;
  BeginCache;
  try
    for I := 1 to TestCount do
      with Properties.TestList.Add do
      begin
        try
          InputFile := CorrectFileName(Format(InputFmt, [I]));
          InputFile := CreateRelativePath(InputFile, WorkingDir);
          OutputFile := CorrectFileName(Format(OutputFmt, [I]));
          OutputFile := CreateRelativePath(OutputFile, WorkingDir);
          Cost := 1;
          WriteLog('Add tests: ' + InputFile + ' ' + OutputFile);
        except
          // if fail, delete the tests
          InputFile := '';
          OutputFile := '';
        end;
        if (not FileExistsUTF8(AppendPathDelim(WorkingDir) + InputFile)) or
          (not FileExistsUTF8(AppendPathDelim(WorkingDir) + OutputFile)) then
          // if non-existing tests, delete them also
        begin
          InputFile := '';
          OutputFile := '';
        end;
        if (InputFile = '') or (OutputFile = '') then
          Properties.TestList.Delete(Properties.TestCount - 1);
        if IsTerminated then
          Break;
      end;
  finally
    EndCache;
  end;
end;

procedure TPropertiesParserBase.Terminate;
begin
  FIsTerminated := True;
end;

function TPropertiesParserBase.Parse: boolean;
begin
  FIsTerminated := False;
  try
    Result := DoParse;
    if IsTerminated then
      Result := False;
  except
    on E: Exception do
    begin
      WriteLog(ClassName + ' error: ' + E.Message);
      Result := False;
    end;
  end;
  FIsTerminated := True;
end;

constructor TPropertiesParserBase.Create;
begin
  FProperties := TProblemPropsCollector.CleanProperties;
  FIsTerminated := False;
end;

destructor TPropertiesParserBase.Destroy;
begin
  FreeAndNil(FProperties);
  inherited Destroy;
end;

{ TProblemPropsCollector }

class function TProblemPropsCollector.CleanProperties: TProblemProperties;
begin
  Result := TProblemProperties.Create;
  try
    with Result do
    begin
      InputFile := UnknownStr;
      OutputFile := UnknownStr;
      TimeLimit := UnknownInt;
      MemoryLimit := UnknownInt;
      Checker := nil;
      TestList.Clear;
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

class function TProblemPropsCollector.MergeStr(const Str1, Str2: string;
  var Success: boolean): string;
begin
  if Str1 = UnknownStr then // str1 unknown
    Result := Str2
  else if Str2 = UnknownStr then // str2 unknown
    Result := Str1
  else if Str1 = Str2 then // all are equal
    Result := Str1
  else
  begin // all are known, but differ (this is not good)
    Success := False;
    Result := Str1;
  end;
end;

class function TProblemPropsCollector.MergeInt(Int1, Int2: integer;
  var Success: boolean): integer;
begin
  if Int1 = UnknownInt then // int1 unknown
    Result := Int2
  else if Int2 = UnknownInt then // int2 unknown
    Result := Int1
  else if Int1 = Int2 then // all are equal
    Result := Int1
  else
  begin // all are known, but differ (this is not good)
    Success := False;
    Result := Int1;
  end;
end;

class function TProblemPropsCollector.MergeChecker(Chk1, Chk2: TProblemChecker;
  var Success: boolean): TProblemChecker;
begin
  if  Chk1 = nil then // chk1 unknown
    Result := Chk2
  else if Chk2 = nil then // chk2 unknown
    Result := Chk1
  else if Chk1.Replaceable then // chk1 replaceable
    Result := Chk2
  else if Chk2.Replaceable then // chk2 replaceable
    Result := Chk1
  else if Chk1.Equals(Chk2) then // all are equal
    Result := Chk1
  else
  begin // all are known, but differ (this is not good)
    Success := False;
    Result := Chk1;
  end;
end;

class procedure TProblemPropsCollector.MergeTests(BaseTst,
  MergeTst: TProblemTestList; Terminated: PBoolean);
var
  I: integer;
  Target, Source: TProblemTestList;
begin
  Target := TProblemTestList.Create;
  Source := TProblemTestList.Create;
  try
    // decide who is target and who is source
    if MergeTst.LowPriority then
    begin
      Target.Assign(BaseTst);
      Source.Assign(MergeTst);
    end
    else
    begin
      Target.Assign(MergeTst);
      Source.Assign(BaseTst);
    end;
    BaseTst.Assign(Target);
    // add tests from Source that don't exist in Target
    for I := 0 to Source.Count - 1 do
      if Target.Find(Source[I]) < 0 then
      begin
        Target.Add.Assign(Source[I]);
        // termination check
        if Terminated <> nil then
          if Terminated^ then
            Break;
      end;
    // push Target into BaseTst
    BaseTst.Assign(Target);
  finally
    FreeAndNil(Target);
    FreeAndNil(Source);
  end;
end;

procedure TProblemPropsCollector.Terminate;
begin
  FIsTerminated := True;
end;

function TProblemPropsCollector.Merge(Props: TProblemProperties): boolean;
begin
  FIsTerminated := False;
  Result := True;
  with FProperties do
  begin
    InputFile := MergeStr(InputFile, Props.InputFile, Result);
    OutputFile := MergeStr(OutputFile, Props.OutputFile, Result);
    TimeLimit := MergeInt(TimeLimit, Props.TimeLimit, Result);
    MemoryLimit := MergeInt(MemoryLimit, Props.MemoryLimit, Result);
    Checker := CloneChecker(MergeChecker(Checker, Props.Checker, Result));
    MergeTests(TestList, Props.TestList, @FIsTerminated);
  end;
end;

function TProblemPropsCollector.Finalize: boolean;
begin
  FIsTerminated := False;
  Result := True;
  with FProperties do
  begin
    if InputFile = UnknownStr then
    begin
      Result := False;
      InputFile := 'stdin';
    end;
    if OutputFile = UnknownStr then
    begin
      Result := False;
      OutputFile := 'stdout';
    end;
    if TimeLimit = UnknownInt then
    begin
      Result := False;
      TimeLimit := 2000;
    end;
    if MemoryLimit = UnknownInt then
    begin
      Result := False;
      MemoryLimit := 65536;
    end;
    if Checker = nil then
    begin
      Result := False;
      Checker := TFileCompareChecker.Create;
    end;
    if TestList.Count = 0 then
      Result := False;
    RescaleCosts(100.0, tcepMakeEqual);
  end;
end;

constructor TProblemPropsCollector.Create;
begin
  FProperties := CleanProperties;
  FIsTerminated := False;
end;

destructor TProblemPropsCollector.Destroy;
begin
  FreeAndNil(FProperties);
  inherited Destroy;
end;

end.
