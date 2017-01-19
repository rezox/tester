{
  This file is part of Tester

  Copyright (C) 2017 Kernozhitsky Alexander <sh200105@mail.ru>

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
unit problemprops;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, AvgLvlTree, testresults, strconsts;

type
  EProblemChecker = class(Exception);

  { TProblemChecker }

  TProblemChecker = class(TPersistent)
  private
    FAnswerFile: string;
    FCheckerOutput: string;
    FInputFile: string;
    FOutputFile: string;
    FWorkingDir: string;
    procedure SetAnswerFile(AValue: string);
    procedure SetCheckerOutput(AValue: string);
    procedure SetInputFile(AValue: string);
    procedure SetOutputFile(AValue: string);
    procedure SetWorkingDir(AValue: string);
  protected
    function DoCheck: TTestVerdict; virtual; abstract;
  public
    property WorkingDir: string read FWorkingDir write SetWorkingDir;
    property InputFile: string read FInputFile write SetInputFile;
    property OutputFile: string read FOutputFile write SetOutputFile;
    property AnswerFile: string read FAnswerFile write SetAnswerFile;
    property CheckerOutput: string read FCheckerOutput write SetCheckerOutput;
    constructor Create; virtual;
    function Check: TTestVerdict;
    procedure AssignTo(Dest: TPersistent); override;
  end;

  TProblemCheckerClass = class of TProblemChecker;

  { TProblemTest }

  TProblemTest = class(TCollectionItem)
  private
    FCost: double;
    FInputFile: string;
    FOutputFile: string;
    procedure SetCost(AValue: double);
    procedure SetInputFile(AValue: string);
    procedure SetOutputFile(AValue: string);
  public
    procedure AssignTo(Dest: TPersistent); override;
    constructor Create(AInputFile, AOutputFile: string; ACost: double);
  published
    property InputFile: string read FInputFile write SetInputFile;
    property OutputFile: string read FOutputFile write SetOutputFile;
    property Cost: double read FCost write SetCost;
    constructor Create(ACollection: TCollection); override;
  end;

  { TProblemTestList }

  TProblemTestList = class(TCollection)
  private
    procedure SetItem(Index: integer; AValue: TProblemTest);
    function GetItem(Index: integer): TProblemTest;
  public
    function Add: TProblemTest;
    function Insert(Index: integer): TProblemTest;
    property Items[Index: integer]: TProblemTest read GetItem write SetItem; default;
    constructor Create;
  end;


  { TProblemProperties }

  TProblemProperties = class(TPersistent)
  private
    FChecker: TProblemChecker;
    FInputFile: string;
    FMemoryLimit: TProblemTime;
    FOutputFile: string;
    FTestList: TProblemTestList;
    FTimeLimit: TProblemTime;
    function GetTestCount: integer;
    function GetTests(I: integer): TProblemTest;
    procedure SetChecker(AValue: TProblemChecker);
    procedure SetInputFile(AValue: string);
    procedure SetMemoryLimit(AValue: TProblemTime);
    procedure SetOutputFile(AValue: string);
    procedure SetTests(I: integer; AValue: TProblemTest);
    procedure SetTimeLimit(AValue: TProblemTime);
  public
    property Tests[I: integer]: TProblemTest read GetTests write SetTests;
    property TestCount: integer read GetTestCount;
    property Checker: TProblemChecker read FChecker write SetChecker;
    destructor Destroy; override;
    procedure AddTest(ATest: TProblemTest);
    procedure InsertTest(AIndex: integer; ATest: TProblemTest);
    procedure DeleteTest(AIndex: integer);
    procedure ClearTests;
    function MaxScore: double;
    procedure AssignTo(Dest: TPersistent); override;
  published
    property InputFile: string read FInputFile write SetInputFile;
    property OutputFile: string read FOutputFile write SetOutputFile;
    property TimeLimit: TProblemTime read FTimeLimit write SetTimeLimit;
    property MemoryLimit: TProblemTime read FMemoryLimit write SetMemoryLimit;
    property TestList: TProblemTestList read FTestList;
    constructor Create;
  end;

procedure RegisterChecker(AClass: TProblemCheckerClass);
function CreateChecker(const AName: string): TProblemChecker;

implementation

var
  Checkers: TStringToPointerTree;

procedure RegisterChecker(AClass: TProblemCheckerClass);
begin
  Checkers[AClass.ClassName] := AClass;
end;

function CreateChecker(const AName: string): TProblemChecker;
var
  AClass: TProblemCheckerClass;
begin
  AClass := TProblemCheckerClass(Checkers[AName]);
  if AClass = nil then
    raise EProblemChecker.CreateFmt(SUnknownChecker, [AName]);
  Result := AClass.Create;
end;

{ TProblemChecker }

procedure TProblemChecker.SetAnswerFile(AValue: string);
begin
  if FAnswerFile = AValue then
    Exit;
  FAnswerFile := AValue;
end;

procedure TProblemChecker.SetCheckerOutput(AValue: string);
begin
  if FCheckerOutput = AValue then
    Exit;
  FCheckerOutput := AValue;
end;

procedure TProblemChecker.SetInputFile(AValue: string);
begin
  if FInputFile = AValue then
    Exit;
  FInputFile := AValue;
end;

procedure TProblemChecker.SetOutputFile(AValue: string);
begin
  if FOutputFile = AValue then
    Exit;
  FOutputFile := AValue;
end;

procedure TProblemChecker.SetWorkingDir(AValue: string);
begin
  if FWorkingDir = AValue then
    Exit;
  FWorkingDir := AValue;
end;

constructor TProblemChecker.Create;
begin
  WorkingDir := '';
  CheckerOutput := '';
end;

function TProblemChecker.Check: TTestVerdict;
begin
  FCheckerOutput := '';
  Result := DoCheck;
end;

procedure TProblemChecker.AssignTo(Dest: TPersistent);
begin
  with Dest as TProblemChecker do
  begin
    WorkingDir := Self.WorkingDir;
    InputFile := Self.InputFile;
    OutputFile := Self.OutputFile;
    AnswerFile := Self.AnswerFile;
    CheckerOutput := Self.CheckerOutput;
  end;
end;

{ TProblemTestList }

procedure TProblemTestList.SetItem(Index: integer; AValue: TProblemTest);
begin
  inherited SetItem(Index, AValue);
end;

function TProblemTestList.GetItem(Index: integer): TProblemTest;
begin
  Result := (inherited Items[Index]) as TProblemTest;
end;

function TProblemTestList.Add: TProblemTest;
begin
  Result := (inherited Add) as TProblemTest;
end;

function TProblemTestList.Insert(Index: integer): TProblemTest;
begin
  Result := (inherited Insert(Index)) as TProblemTest;
end;

constructor TProblemTestList.Create;
begin
  inherited Create(TProblemTest);
end;

{ TProblemTest }

procedure TProblemTest.SetCost(AValue: double);
begin
  if FCost = AValue then
    Exit;
  FCost := AValue;
end;

procedure TProblemTest.SetInputFile(AValue: string);
begin
  if FInputFile = AValue then
    Exit;
  FInputFile := AValue;
end;

procedure TProblemTest.SetOutputFile(AValue: string);
begin
  if FOutputFile = AValue then
    Exit;
  FOutputFile := AValue;
end;

procedure TProblemTest.AssignTo(Dest: TPersistent);
begin
  with Dest as TProblemTest do
  begin
    InputFile := Self.InputFile;
    OutputFile := Self.OutputFile;
    Cost := Self.Cost;
  end;
end;

constructor TProblemTest.Create(AInputFile, AOutputFile: string; ACost: double);
begin
  inherited Create(nil);
  InputFile := AInputFile;
  OutputFile := AOutputFile;
  Cost := ACost;
end;

constructor TProblemTest.Create(ACollection: TCollection);
begin
  inherited;
end;

{ TProblemProperties }

function TProblemProperties.GetTestCount: integer;
begin
  Result := FTestList.Count;
end;

function TProblemProperties.GetTests(I: integer): TProblemTest;
begin
  Result := FTestList.Items[I];
end;

procedure TProblemProperties.SetChecker(AValue: TProblemChecker);
begin
  if FChecker = AValue then
    Exit;
  FreeAndNil(FChecker);
  FChecker := AValue;
end;

procedure TProblemProperties.SetInputFile(AValue: string);
begin
  AValue := Trim(AValue);
  if (AValue = '') or (LowerCase(AValue) = 'stdin') then
    AValue := 'stdin';
  if FInputFile = AValue then
    Exit;
  FInputFile := AValue;
end;

procedure TProblemProperties.SetMemoryLimit(AValue: TProblemTime);
begin
  if FMemoryLimit = AValue then
    Exit;
  FMemoryLimit := AValue;
end;

procedure TProblemProperties.SetOutputFile(AValue: string);
begin
  AValue := Trim(AValue);
  if (AValue = '') or (LowerCase(AValue) = 'stdout') then
    AValue := 'stdout';
  if FOutputFile = AValue then
    Exit;
  FOutputFile := AValue;
end;

procedure TProblemProperties.SetTests(I: integer; AValue: TProblemTest);
begin
  FTestList.Items[I] := AValue;
end;

procedure TProblemProperties.SetTimeLimit(AValue: TProblemTime);
begin
  if FTimeLimit = AValue then
    Exit;
  FTimeLimit := AValue;
end;

constructor TProblemProperties.Create;
begin
  inherited;
  InputFile := 'stdin';
  OutputFile := 'stdout';
  TimeLimit := 1000;
  MemoryLimit := 65536;
  FTestList := TProblemTestList.Create;
end;

destructor TProblemProperties.Destroy;
begin
  FreeAndNil(FChecker);
  FreeAndNil(FTestList);
  inherited Destroy;
end;

procedure TProblemProperties.AddTest(ATest: TProblemTest);
begin
  InsertTest(TestCount, ATest);
end;

procedure TProblemProperties.InsertTest(AIndex: integer; ATest: TProblemTest);
begin
  FTestList.Insert(AIndex).Assign(ATest);
  FreeAndNil(ATest);
end;

procedure TProblemProperties.DeleteTest(AIndex: integer);
begin
  FTestList.Delete(AIndex);
end;

procedure TProblemProperties.ClearTests;
begin
  FTestList.Clear;
end;

function TProblemProperties.MaxScore: double;
var
  I: integer;
begin
  Result := 0.0;
  for I := 0 to TestCount - 1 do
    Result := Result + Tests[I].Cost;
end;

procedure TProblemProperties.AssignTo(Dest: TPersistent);
begin
  with Dest as TProblemProperties do
  begin
    InputFile := Self.InputFile;
    OutputFile := Self.OutputFile;
    TimeLimit := Self.TimeLimit;
    MemoryLimit := Self.MemoryLimit;
    TestList.Assign(Self.TestList);
    if Self.Checker = nil then
      Checker := nil
    else
    begin
      Checker := TProblemCheckerClass(Self.Checker.ClassType).Create;
      Checker.Assign(Self.Checker);
    end;
  end;
end;

initialization
  Checkers := TStringToPointerTree.Create(False);

finalization
  FreeAndNil(Checkers);

end.