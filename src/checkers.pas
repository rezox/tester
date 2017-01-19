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
unit checkers;

{$mode objfpc}{$H+}{$B-}

interface

uses
  Classes, SysUtils, problemprops, processfork, LazFileUtils, LazUTF8, strconsts,
  testerprimitives;

type

  { TProcessProblemChecker }

  TProcessProblemChecker = class(TProblemChecker)
  protected
    procedure GetCommandLine(var ExeName: string; Args: TStringList);
      virtual; abstract;
    function ProcessCheckerOutput(Output: string; ExitCode: integer): TTestVerdict;
      virtual; abstract;
    function DoCheck: TTestVerdict; override;
  end;

  { TFileCompareChecker }

  TFileCompareChecker = class(TProblemChecker)
  protected
    function DoCheck: TTestVerdict; override;
  end;

  { TStdExecutableChecker }

  TStdExecutableChecker = class(TProcessProblemChecker)
  private
    FCheckerFileName: string;
    procedure SetCheckerFileName(AValue: string);
  protected
    procedure GetCommandLine(var ExeName: string; Args: TStringList); override;
  public
    constructor Create; override;
    procedure AssignTo(Dest: TPersistent); override;
  published
    property CheckerFileName: string read FCheckerFileName write SetCheckerFileName;
  end;

  { TTextChecker }

  TTextChecker = class(TStdExecutableChecker)
  protected
    function ProcessCheckerOutput(Output: string; ExitCode: integer): TTestVerdict;
      override;
  end;

  { TTestlibChecker }

  TTestlibChecker = class(TStdExecutableChecker)
  protected
    function ProcessCheckerOutput(Output: string; ExitCode: integer): TTestVerdict;
      override;
  end;

implementation

const
  TestlibOK = 0;
  TestlibWA = 1;
  TestlibPE = 2;

  TextOK = 'ok';
  TextWA1 = 'wa';
  TextWA2 = 'wrong answer';
  TextPE1 = 'pe';
  TextPE2 = 'presentation error';

{ TTestlibChecker }

function TTestlibChecker.ProcessCheckerOutput(Output: string;
  ExitCode: integer): TTestVerdict;
begin
  Output := Output; // to mute the hint
  case ExitCode of
    TestlibOK: Result := veAccepted;
    TestlibPE: Result := vePresentationError;
    TestlibWA: Result := veWrongAnswer;
    else
      Result := veCheckError;
  end;
end;

{ TStdExecutableChecker }

procedure TStdExecutableChecker.SetCheckerFileName(AValue: string);
begin
  if FCheckerFileName = AValue then
    Exit;
  FCheckerFileName := AValue;
end;

procedure TStdExecutableChecker.GetCommandLine(var ExeName: string; Args: TStringList);
begin
  ExeName := ExpandFileNameUTF8(CheckerFileName, WorkingDir);
  Args.Text := InputFile + LineEnding + OutputFile + LineEnding + AnswerFile;
end;

constructor TStdExecutableChecker.Create;
begin
  inherited;
  CheckerFileName := 'checker.exe';
end;

procedure TStdExecutableChecker.AssignTo(Dest: TPersistent);
begin
  inherited;
  with Dest as TStdExecutableChecker do
  begin
    CheckerFileName := Self.CheckerFileName;
  end;
end;

{ TTextChecker }

function TTextChecker.ProcessCheckerOutput(Output: string;
  ExitCode: integer): TTestVerdict;
begin
  ExitCode := ExitCode; // to mute the hint
  Output := LowerCase(Output);
  if Pos(TextOK, Output) <> 0 then
    Result := veAccepted
  else if Pos(TextWA1, Output) <> 0 then
    Result := veWrongAnswer
  else if Pos(TextWA2, Output) <> 0 then
    Result := veWrongAnswer
  else if Pos(TextPE1, Output) <> 0 then
    Result := vePresentationError
  else if Pos(TextPE2, Output) <> 0 then
    Result := vePresentationError
  else
    Result := veCheckError;
end;

{ TFileCompareChecker }

function TFileCompareChecker.DoCheck: TTestVerdict;

  procedure TrimList(List: TStringList);
  var
    I: integer;
    Pos: integer;
    S: string;
  begin
    for I := 0 to List.Count - 1 do
    begin
      S := List[I];
      Pos := Length(S);
      while (Pos > 0) and (S[Pos] = ' ') do
        Dec(Pos);
      List[I] := Copy(S, 1, Pos);
    end;
    while (List.Count > 0) and (List[List.Count - 1] = '') do
      List.Delete(List.Count - 1);
  end;

  function GetTextFromFile(const FileName: string): string;
  var
    List: TStringList;
  begin
    List := TStringList.Create;
    try
      List.LoadFromFile(AppendPathDelim(WorkingDir) + FileName);
      TrimList(List);
      Result := List.Text;
    finally
      FreeAndNil(List);
    end;
  end;

begin
  try
    if not FileExistsUTF8(AppendPathDelim(WorkingDir) + OutputFile) then
    begin
      CheckerOutput := Format(SFileNotFound, [OutputFile]);
      Result := vePresentationError;
      Exit;
    end;
    if not FileExistsUTF8(AppendPathDelim(WorkingDir) + AnswerFile) then
    begin
      CheckerOutput := Format(SFileNotFound, [AnswerFile]);
      Result := veCheckError;
      Exit;
    end;
    if GetTextFromFile(OutputFile) = GetTextFromFile(AnswerFile) then
    begin
      CheckerOutput := SFilesEqual;
      Result := veAccepted;
    end
    else
    begin
      CheckerOutput := SFilesNotEqual;
      // TODO : Show where is the inequality
      // TODO : Maybe use standard utils (as diff & fc)
      Result := veWrongAnswer;
    end;
  except
    on E: Exception do
    begin
      Result := veCheckError;
      CheckerOutput := E.Message;
    end;
  end;
end;

{ TProcessProblemChecker }

function TProcessProblemChecker.DoCheck: TTestVerdict;
var
  ExitCode: integer;
  Output: string;
  ExeName: string;
  Args: TStringList;
  ArgsArr: array of string;
  I: integer;
begin
  try
    Args := TStringList.Create;
    try
      GetCommandLine(ExeName, Args);
      SetLength(ArgsArr, Args.Count);
      for I := 0 to Args.Count - 1 do
        ArgsArr[I] := Args[I];
      ExitCode := 0;
      Output := '';
      if RunCommandIndirUTF8(WorkingDir, ExeName, ArgsArr, Output, ExitCode) <> 0 then
      begin
        CheckerOutput := Format(SCheckerRunFail, [ExeName]);
        Result := veCheckError;
      end
      else
      begin
        CheckerOutput := Output + LineEnding + Format(SCheckerExitCode, [ExitCode]);
        Result := ProcessCheckerOutput(Output, ExitCode);
      end;
    finally
      FreeAndNil(Args);
    end;
  except
    on E: Exception do
    begin
      Result := veCheckError;
      CheckerOutput := E.Message;
    end;
  end;
end;

initialization
  RegisterChecker(TFileCompareChecker);
  RegisterChecker(TTextChecker);
  RegisterChecker(TTestlibChecker);

end.