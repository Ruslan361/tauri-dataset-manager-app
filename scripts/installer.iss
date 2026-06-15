[Setup]
; Базовая информация
AppName=Атрофовизуализация
AppVersion=1.0
DefaultGroupName=Атрофовизуализация

; Вызываем нашу умную функцию для определения пути установки
DefaultDirName={code:GetInstallDir}

; Установщику НЕ нужны права администратора
PrivilegesRequired=lowest
DisableDirPage=no

; Настройки вывода (установщик появится в папке release)
OutputDir=..\release
OutputBaseFilename=Atrofovizualizatia
Compression=lzma
SolidCompression=yes

[Files]
Source: "..\release\windows\dataset-manager.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\release\windows\install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\release\windows\install.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\release\windows\start.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\release\windows\start.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\release\windows\start-backend-only.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\release\windows\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\release\windows\tools\*"; DestDir: "{app}\tools"; Flags: ignoreversion
Source: "..\release\windows\requirements.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\release\windows\wheels\*"; DestDir: "{app}\wheels"; Flags: ignoreversion
Source: "..\release\windows\backend\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autodesktop}\Атрофовизуализация"; Filename: "{app}\start.bat"; IconFilename: "{app}\dataset-manager.exe"
Name: "{group}\Атрофовизуализация"; Filename: "{app}\start.bat"; IconFilename: "{app}\dataset-manager.exe"

[Run]
Filename: "powershell.exe"; Parameters: "-Command Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force"; Flags: runhidden waituntilterminated
Filename: "{app}\install.bat"; Description: "Установить Python-зависимости"; Flags: postinstall nowait shellexec

[UninstallDelete]
Type: filesandordirs; Name: "{app}\backend\.venv"
Type: filesandordirs; Name: "{app}\backend\__pycache__"
Type: filesandordirs; Name: "{app}\tools"
Type: filesandordirs; Name: "{app}\wheels"
Type: filesandordirs; Name: "{localappdata}\dataset-manager"
Type: filesandordirs; Name: "{app}"

[Code]
// --- УМНЫЙ ПУТЬ УСТАНОВКИ (Защита от кириллицы) ---
function HasNonAscii(S: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  // Проверяем каждый символ. Если код > 127, значит это не базовая латиница (кириллица, спецсимволы и тд)
  for i := 1 to Length(S) do
  begin
    if Ord(S[i]) > 127 then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function GetInstallDir(Param: String): String;
var
  DefaultPath: String;
  FallbackPath: String;
begin
  // Стандартный путь: C:\Users\Имя\AppData\Local\Atrofovizualizatia
  DefaultPath := ExpandConstant('{localappdata}\Atrofovizualizatia');
  
  // Безопасный путь без кириллицы: C:\Users\Public\Documents\Atrofovizualizatia
  FallbackPath := ExpandConstant('{commondocs}\Atrofovizualizatia');

  // Если в стандартном пути есть русские буквы, возвращаем безопасный путь
  if HasNonAscii(DefaultPath) then
    Result := FallbackPath
  else
    Result := DefaultPath;
end;

// --- ПРОВЕРКА НАЛИЧИЯ КОМПИЛЯТОРОВ C/C++ ---
function IsCppCompilerInstalled(): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;

  // 1. Проверяем наличие GCC (MinGW)
  if Exec('cmd.exe', '/C where gcc', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then begin
    if ResultCode = 0 then begin
      Result := True;
      Exit;
    end;
  end;

  // 2. Проверяем наличие MSVC (cl.exe)
  if Exec('cmd.exe', '/C where cl', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then begin
    if ResultCode = 0 then begin
      Result := True;
      Exit;
    end;
  end;

  // 3. Проверяем реестр на Visual Studio Build Tools
  if RegKeyExists(HKEY_LOCAL_MACHINE, 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\SxS\VS7') then begin
    Result := True;
    Exit;
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  
  // Предупреждение о компиляторах
  if not IsCppCompilerInstalled() then
  begin
    if MsgBox('ВНИМАНИЕ: На вашем компьютере не найдены компиляторы C/C++ (GCC или MSVC).' #13#13 +
              'Некоторые модули Python для Backend могут не установиться без C++ Build Tools.' #13#13 +
              'Хотите продолжить установку?', 
              mbConfirmation, MB_YESNO) = IDNO then
    begin
      Result := False;
      Exit;
    end;
  end;
  
  // Если у пользователя кириллица, покажем информационное сообщение
  if HasNonAscii(ExpandConstant('{localappdata}')) then
  begin
    MsgBox('ℹ Обнаружены русские символы в имени пользователя.' #13#13 +
           'Чтобы избежать ошибок при установке Python, программа будет установлена в общую папку: ' #13 +
           'C:\Users\Public\Documents\Atrofovizualizatia', 
           mbInformation, MB_OK);
  end;
end;