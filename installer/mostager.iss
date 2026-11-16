; Script generated for Inno Setup 6
; نظام مُستأجِر لإدارة العقارات والعقود - سكربت التثبيت الاحترافي

#define MyAppName "نظام مُستأجِر"
#define MyAppNameEn "Mostager"
#define MyAppVersion "2.5.0"
#define MyAppPublisher "Mostager Management Systems"
#define MyAppURL "http://127.0.0.1:8080"
#define MyAppExeName "mostager.exe"
#define MyAppIcon "..\app.ico"

[Setup]
; معلومات التطبيق الأساسية
AppId={{D37D82F2-8B24-4B33-9D12-3269389D91A8}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} إصدار {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; مسارات التثبيت (64-بت افتراضياً لويندوز 10 و 11)
DefaultDirName={autopf}\{#MyAppNameEn}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible

; إعدادات ملف التثبيت
OutputDir=..\dist_setup
OutputBaseFilename=Setup
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

; صور الواجهة والمظهر
WizardImageFile=wizard_large.bmp
WizardSmallImageFile=wizard_small.bmp

; الحماية والصلاحيات
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=commandline
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; الملف التنفيذي الرئيسي وجميع الملحقات
Source: "..\dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppIcon}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\avatar.png"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; اختصارات قائمة ابدأ وسطح المكتب
Name: "{autoprograms}\{#MyAppName}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app.ico"
Name: "{autoprograms}\{#MyAppName}\إلغاء التثبيت (Uninstall)"; Filename: "{uninstallexe}"; IconFilename: "{app}\app.ico"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\app.ico"; Tasks: desktopicon

[Run]
; تشغيل التطبيق بعد انتهاء التثبيت
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; حذف الملفات المؤقتة في مجلد البرنامج فقط
Type: files; Name: "{app}\*.log"

[Code]
// التحقق من الحفاظ على بيانات المستخدم عند إلغاء التثبيت
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataPath: String;
  ConfirmDelete: Integer;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DataPath := ExpandConstant('{userappdata}\Mostager');
    if DirExists(DataPath) then
    begin
      ConfirmDelete := MsgBox(
        'تم حذف ملفات برنامج مُستأجِر بنجاح.' + #13#10 + #13#10 +
        'هل تريد حذف قاعدة بيانات المستأجرين والعقود والصور المحفوظة أيضاً؟' + #13#10 +
        '(اختر "لا" للاحتفاظ ببياناتك في حال أردت إعادة التثبيت لاحقاً)',
        mbConfirmation, MB_YESNO or MB_DEFBUTTON2);
        
      if ConfirmDelete = IDYES then
      begin
        DelTree(DataPath, True, True, True);
      end;
    end;
  end;
end;
