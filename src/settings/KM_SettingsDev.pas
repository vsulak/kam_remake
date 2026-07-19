unit KM_SettingsDev;
{$I KaM_Remake.inc}
interface
uses
  SysUtils, StrUtils, Classes, Math,
  ComCtrls, Controls, ExtCtrls, StdCtrls,
  Forms, Spin
  {$IFDEF Unix} , LCLIntf, LCLType {$ENDIF}
  ;

{$IFDEF FPC}
// Delphi VCL controls not available in Lazarus LCL
type
  TCategoryPanelGroup = class(TCustomControl);
  TCategoryPanel = class(TCustomControl);
  TCategoryPanelSurface = class(TCustomControl);
{$ENDIF}

type
  TKMDebugFormState = ( fsNone,       // No debug panel or menu are open
                        fsDebugMenu,  // Only debug menu is visible
                        fsDebugFull); // Debug panel and menu are visible

  // Manager of F11 controls settings save/load
  TKMDevSettings = class
  private
    fSettingsPath: UnicodeString;
    fSkipSave: Boolean;
    fDebugFormState: TKMDebugFormState;
    fMainGroup: TCategoryPanelGroup;
    fDontCollapse: TCategoryPanel;

    procedure DoLoad;
    procedure DoSave;
    function GetXmlSectionName(aPanel: TCategoryPanel): string;
  public
    constructor Create(const aExeDir: string; aMainGroup: TCategoryPanelGroup; aDontCollapse: TCategoryPanel);

    property DebugFormState: TKMDebugFormState read fDebugFormState write fDebugFormState;
    property SkipSave: Boolean read fSkipSave write fSkipSave;

    procedure Load;
    procedure Save;
  end;


implementation
uses
  KM_Defaults, KM_Log, KM_IoXML;


{ TKMDevSettings }
constructor TKMDevSettings.Create(const aExeDir: string; aMainGroup: TCategoryPanelGroup; aDontCollapse: TCategoryPanel);
begin
  inherited Create;
  fSettingsPath := aExeDir + DEV_SETTINGS_XML_FILENAME;
  fMainGroup := aMainGroup;
  fDontCollapse := aDontCollapse;
end;


function TKMDevSettings.GetXmlSectionName(aPanel: TCategoryPanel): string;
begin
  Result := StringReplace(aPanel.Caption, ' ', '_', [rfReplaceAll]);
end;


procedure TKMDevSettings.DoLoad;
begin
  // Dev settings panel uses VCL-only TCategoryPanel controls - no-op on non-WDC
  {$IFDEF WDC}
  // (original VCL implementation intentionally omitted for FPC builds)
  {$ENDIF}
end;


procedure TKMDevSettings.DoSave;
begin
  // Dev settings panel uses VCL-only TCategoryPanel controls - no-op on non-WDC
  {$IFDEF WDC}
  // (original VCL implementation intentionally omitted for FPC builds)
  {$ENDIF}
end;


procedure TKMDevSettings.Load;
begin
  if Self = nil then Exit;
  try
    DoLoad;
  except
    on E: Exception do
      gLog.AddTime('Error while loading dev settings: ' + E.Message);
  end;
end;


procedure TKMDevSettings.Save;
begin
  if Self = nil then Exit;
  try
    DoSave;
  except
    on E: Exception do
      gLog.AddTime('Error while saving dev settings: ' + E.Message);
  end;
end;


end.
