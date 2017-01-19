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
unit stdexecheckeredit;

{$mode objfpc}{$H+}

interface

uses
  Forms, StdCtrls, checkers, problemprops;

type

  { TStdExecuteCheckerEdit }

  TStdExecuteCheckerEdit = class(TFrame)
    CheckerNameEdit: TEdit;
    Label1: TLabel;
  public
    function GetChecker(AClass: TProblemCheckerClass): TProblemChecker;
    procedure SetChecker(AValue: TProblemChecker);
  end;

implementation

{$R *.lfm}

{ TStdExecuteCheckerEdit }

function TStdExecuteCheckerEdit.GetChecker(AClass: TProblemCheckerClass):
TProblemChecker;
begin
  Result := AClass.Create;
  (Result as TStdExecutableChecker).CheckerFileName := CheckerNameEdit.Text;
end;

procedure TStdExecuteCheckerEdit.SetChecker(AValue: TProblemChecker);
begin
  CheckerNameEdit.Text := (AValue as TStdExecutableChecker).CheckerFileName;
end;

end.