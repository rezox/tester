{
  This file is part of Tester

  Copyright (C) 2017 Alexander Kernozhitsky <sh200105@mail.ru>

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
unit parserforms;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Dialogs, StdCtrls, ComCtrls, ButtonPanel,
  parserlists, propsparserbase, strconsts, problemprops, baseforms;

type
  EParserForm = class(Exception);

  { TParserForm }

  TParserForm = class(TBaseForm)
    ButtonPanel: TButtonPanel;
    Label1: TLabel;
    ProgressBar: TProgressBar;
    procedure CancelButtonClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure ThreadTerminate(Sender: TObject);
  private
    FTerminating: boolean;
    FProperties: TProblemProperties;
    FThread: TPropertiesParserThread;
    procedure SetProperties(AValue: TProblemProperties);
  public
    property Properties: TProblemProperties read FProperties write SetProperties;
    procedure RunThread(AThread: TPropertiesParserThread);
    constructor Create(TheOwner: TComponent); override;
  end;

var
  ParserForm: TParserForm;

procedure RunParsers(const WorkingDir: string;
  const Parsers: array of TPropertiesParserClass; Props: TProblemProperties);
procedure RunAllParsers(const WorkingDir: string; Props: TProblemProperties);

implementation

uses
  // Parsers
  parser_alltest, parser_xml, parser_simplecfg, parser_findfile, parser_ejudgecfg;

procedure RunParsers(const WorkingDir: string;
  const Parsers: array of TPropertiesParserClass; Props: TProblemProperties);
var
  AThread: TPropertiesParserThread;
  I: integer;
begin
  AThread := TPropertiesParserThread.Create(True);
  with AThread do
  begin
    List.WorkingDir := WorkingDir;
    for I := Low(Parsers) to High(Parsers) do
      List.AddParser(Parsers[I]);
  end;
  ParserForm.Properties := Props;
  ParserForm.RunThread(AThread);
end;

procedure RunAllParsers(const WorkingDir: string; Props: TProblemProperties);
begin
  RunParsers(WorkingDir, [TFindFilePropertiesParser, TAllTestPropertiesParser,
    TPolygonPropertiesParser, TRoiPropertiesParser, TSimpleCfgPropertiesParser,
    TEjudgeCfgPropertiesParser], Props);
end;

{$R *.lfm}

{ TParserForm }

procedure TParserForm.CancelButtonClick(Sender: TObject);
begin
  CloseQuery;
end;

procedure TParserForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  if FTerminating then
  begin
    CanClose := True;
    Exit;
  end;
  if FThread <> nil then
    FThread.Terminate;
  CanClose := False;
end;

procedure TParserForm.ThreadTerminate(Sender: TObject);
begin
  FTerminating := True;
  Close;
end;

procedure TParserForm.SetProperties(AValue: TProblemProperties);
begin
  if FProperties = AValue then
    Exit;
  FProperties := AValue;
end;

procedure TParserForm.RunThread(AThread: TPropertiesParserThread);
var
  ChangeProps: boolean;
  MsgText: string;
begin
  if FThread <> nil then
    raise EParserForm.Create(SThreadAlreadyRunning);
  FThread := AThread;
  try
    FTerminating := False;
    with FThread do
    begin
      FreeOnTerminate := False;
      OnTerminate := @ThreadTerminate;
      Start;
    end;
    // show
    ShowModal;
    // process thread info
    ChangeProps := True;
    MsgText := '';
    case FThread.Status of
      ppNone, ppTerminated: ChangeProps := False;
      ppOK: ; // everything is ok, do nothing
      ppParserFail: MsgText :=
          Format(SParserWarningFmt, [SParserFail, SCheckRecommendation]);
      ppMergeConflicts: MsgText :=
          Format(SParserWarningFmt, [SMergeConflict, SCheckRecommendation]);
      ppNotFullInfo: MsgText :=
          Format(SParserWarningFmt, [SNotFullInfo, SCheckRecommendation]);
    end;
    if MsgText <> '' then
      MessageDlg(MsgText, mtWarning, [mbOK], 0);
    if ChangeProps then
      FProperties.Assign(AThread.List.Properties);
  finally
    FreeAndNil(FThread);
  end;
end;

constructor TParserForm.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FThread := nil;
  FTerminating := False;
end;

end.
