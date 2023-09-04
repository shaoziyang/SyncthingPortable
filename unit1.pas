unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, process, Forms, Controls, Graphics, Dialogs, Menus,
  ExtCtrls, ShellApi, DateUtils, Windows, jwatlhelp32, fileinfo, winpeimagereader;

const
  Title = 'tiny Syncthing Portable v1.0';
  AppPath = 'App';
  AppName = 'syncthing.exe';
  GUI_URL = 'http://127.0.0.1:8384';

type

  TDllInfo = class(TObject)
    FileName: string;
    ModulName: string;
    Info: string;
  end;

  { TfrmMain }

  TfrmMain = class(TForm)
    ImageList_Tray: TImageList;
    ImageList_16: TImageList;
    ImageList_32: TImageList;
    pmiSyncthingPortable: TMenuItem;
    pmiSyncthingVer: TMenuItem;
    pmiRunning: TMenuItem;
    N2: TMenuItem;
    pmiRestart: TMenuItem;
    pmiExit: TMenuItem;
    pmiWebGui: TMenuItem;
    N1: TMenuItem;
    pmTray: TPopupMenu;
    AppProc: TProcess;
    tmrApp: TTimer;
    tray: TTrayIcon;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure pmiExitClick(Sender: TObject);
    procedure pmiWebGuiClick(Sender: TObject);
    procedure pmiRestartClick(Sender: TObject);
    procedure tmrAppTimer(Sender: TObject);
  private

  public

  end;

var
  Path, AppFile: string;
  gui_address: string;
  AppProc: TProcess;
  frmMain: TfrmMain;
  run_start: TDateTime;

implementation

{$R *.lfm}

function GetDLLVer(const dll_fnm: string): string;
var
  i: integer;
  FileVerInfo: TFileVersionInfo;
  FileName, ModulName: string;
  aDllInfo: TDllInfo;
begin
  FileVerInfo := nil;
  try
    FileVerInfo := TFileVersionInfo.Create(nil);
    FileVerInfo.FileName := dll_fnm;
    try
      FileVerInfo.ReadFileInfo;
      ModulName := FileVerInfo.VersionStrings.Values['InternalName'];
      if ModulName <> '' then
      begin
        aDllInfo := TDllInfo.Create;
        aDllInfo.FileName := dll_fnm;
        aDllInfo.ModulName := ModulName;
        aDllInfo.Info := FileVerInfo.VersionStrings.Values['FileVersion'];
        Result := aDllInfo.Info;
      end;
    finally
      ; // nothing to do
    end;
  finally
    FileVerInfo.Free;
  end;
end;

function KillProcess(const ExeName: string): integer;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;

begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := 0;

  while integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeName))) then
    begin
      Inc(Result);
      TerminateProcess(OpenProcess(Process_Terminate, False,
        FProcessEntry32.th32ProcessID), 0);
    end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;

  CloseHandle(FSnapshotHandle);
end;

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  hnd: THandle;
  i: integer;
begin

  // already running ?
  hnd := FindWindow(nil, 'free syncthing portable');
  if hnd <> 0 then
  begin
    Halt;
  end;

  run_start := now();

  pmiSyncthingPortable.Caption := Title;
  Caption := 'fast, small and free syncthing portable';
  path := ExtractFilePath(Application.ExeName);

  AppFile := Path + AppPath + '\' + AppName;

  // syncthing file missing
  if not FileExists(AppFile) then
  begin
    MessageDlg('Syncthing exe file is not found!' + #13#10#13#10 +
      'File:' + #13#10#13#10 + AppFile, mtError, [mbOK], 0);
    Halt;
  end;

  try
    pmiSyncthingVer.Caption := 'syncthing: v' + GetDLLVer(AppFile);
  except

  end;

  // set syncthing process paramters
  AppProc := TProcess.Create(nil);
  AppProc.Executable := AppFile;
  AppProc.Parameters.Add('serve');
  AppProc.Parameters.Add('--no-console');
  AppProc.Parameters.Add('--no-browser');
  AppProc.Parameters.Add('--home=data');

  AppProc.Options := AppProc.Options + [poNoConsole];

  // start timer
  tmrApp.Enabled := True;

  gui_address := GUI_URL;

end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  // hide form windows and taskbar
  Hide;
end;

procedure TfrmMain.pmiExitClick(Sender: TObject);
begin
  tmrApp.Enabled := False;

  // terminate syncthing process
  pmiRestartClick(Sender);

  AppProc.Free;

  Close;
end;

procedure TfrmMain.pmiWebGuiClick(Sender: TObject);
begin
  // open web gui with default browser
  if AppProc.Running then
    ShellExecute(Handle, 'open', PChar(gui_address), nil, nil, 1);
end;

procedure TfrmMain.pmiRestartClick(Sender: TObject);
begin
  // terminate syncthing
  AppProc.Terminate(0);
  // kill other syncthing process
  KillProcess(AppName);
end;

procedure TfrmMain.tmrAppTimer(Sender: TObject);
var
  ts: integer;
  s: string;
begin
  // if syncthing running?
  pmiRestart.Enabled := AppProc.Running;
  if AppProc.Running then
  begin
    // show animation tay icon
    tray.Tag := ((tray.Tag) mod (ImageList_Tray.Count - 1)) + 1;
    ImageList_Tray.GetIcon(tray.Tag, tray.Icon);
  end
  else
  begin
    AppProc.Execute;
    if tray.Tag <> 0 then
    begin
      tray.Tag := 0;
      ImageList_Tray.GetIcon(0, tray.Icon);
    end;
  end;

  // display runtime
  ts := SecondsBetween(now, run_start);
  if ts < 60 then
    s := IntToStr(ts) + ' sec'
  else if ts < 600 then
    s := IntToStr(ts div 60) + ' min ' + IntToStr(ts mod 60) + ' sec'
  else if ts < 3600 then
    s := IntToStr(ts div 60) + ' min'
  else if ts < 86400 then
    s := IntToStr(ts div 3600) + ' hour ' + IntToStr((ts mod 3600) div 60) + ' min'
  else
    s := IntToStr(ts div 86400) + ' day ' + IntToStr((ts mod 86400) div 3600) + ' hour';
  pmiRunning.Caption := 'Running: ' + s;
end;

end.
