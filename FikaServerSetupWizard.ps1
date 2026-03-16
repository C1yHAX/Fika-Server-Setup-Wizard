#Requires -Version 5.1

if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $self = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $arg  = if (-not [string]::IsNullOrEmpty($PSCommandPath)) {
                "-ExecutionPolicy Bypass -Sta -File `"$PSCommandPath`""
            } else { $null }
    if ($arg) { Start-Process powershell.exe -ArgumentList $arg }
    else      { Start-Process $self }
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class UxThemeHelper {
    [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)]
    public static extern int SetWindowTheme(IntPtr hwnd, string pszSubAppName, string pszSubIdList);
}
"@ -ErrorAction SilentlyContinue

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $PSDefaultParameterValues['Out-File:Encoding'] = 'utf8' } catch {}

$identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show(
        "DE: Bitte als Administrator ausfuehren.`nEN: Please run as Administrator.`n`nProgramm wird neu gestartet / Restarting...",
        "FIKA-Server Setup", 0, 48)
    $self = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if (-not [string]::IsNullOrEmpty($PSCommandPath)) {
        Start-Process powershell.exe `
            -ArgumentList "-ExecutionPolicy Bypass -Sta -File `"$PSCommandPath`"" -Verb RunAs
    } else {
        Start-Process $self -Verb RunAs
    }
    exit
}

trap {
    $msg = "FEHLER / ERROR: $_`n$($_.ScriptStackTrace)"
    try { $msg | Out-File "$env:TEMP\FikaSetup_error.log" -Append } catch {}
    [System.Windows.Forms.MessageBox]::Show($msg, "Kritischer Fehler / Critical Error", 0, 16)
    break
}

$script:Cfg = [hashtable]::Synchronized(@{
    SptDir    = ""
    EftDir    = ""
    SteamExe  = "C:\Program Files (x86)\Steam\Steam.exe"
    StPlugDir = "C:\Program Files (x86)\Steam\config\stplug-in"
    DepotDir  = "C:\Program Files (x86)\Steam\depotcache"
    TempDir   = "$env:TEMP\FikaSetup"
    ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    ApiKey    = ""
    EftMethod = "BSG"
    Busy      = $false
})
New-Item -ItemType Directory -Force -Path $script:Cfg.TempDir | Out-Null

$script:Lang = "DE"

$script:Tr = @{
    "sb_ready"     = @{ DE="  BEREIT  //  STATUS WIRD AUTOMATISCH GEPRUEFT"
                        EN="  READY  //  STATUS IS BEING CHECKED AUTOMATICALLY" }
    "s_install"    = @{ DE="INSTALLATION";          EN="INSTALLATION" }
    "s_all"        = @{ DE=">> ALLE INSTALLIEREN";  EN=">> INSTALL ALL" }
    "s_check"      = @{ DE=">> STATUS PRUEFEN";     EN=">> CHECK STATUS" }
    "s_settings"   = @{ DE="EINSTELLUNGEN";         EN="SETTINGS" }
    "lang_label"   = @{ DE="SPRACHE";               EN="LANGUAGE" }
    "n_Steam"      = @{ DE="STEAM";                 EN="STEAM" }
    "n_EFT"        = @{ DE="ESCAPE FROM TARKOV";    EN="ESCAPE FROM TARKOV" }
    "n_SPT"        = @{ DE="SPT SERVER";            EN="SPT SERVER" }
    "n_Fika"       = @{ DE="FIKA";                  EN="FIKA" }
    "n_Headless"   = @{ DE="HEADLESS CLIENT";       EN="HEADLESS CLIENT" }
    "n_Docker"     = @{ DE="DOCKER + WSL2";         EN="DOCKER + WSL2" }
    "n_Firewall"   = @{ DE="FIREWALL";              EN="FIREWALL" }
    "n_WebApp"     = @{ DE="FIKAWEBAPP";            EN="FIKAWEBAPP" }
    "btn_install"  = @{ DE="INSTALLIEREN";          EN="INSTALL" }
    "btn_browse"   = @{ DE="DURCHSUCHEN";           EN="BROWSE" }
    "btn_cancel"   = @{ DE="ABBRECHEN";             EN="CANCEL" }
    "btn_save"     = @{ DE="SPEICHERN";             EN="SAVE" }
    "btn_recheck"  = @{ DE="STATUS NEU PRUEFEN";    EN="RECHECK STATUS" }
    "btn_clear"    = @{ DE="LEEREN";                EN="CLEAR" }
    "btn_ports"    = @{ DE="PORTS FREISCHALTEN";    EN="OPEN PORTS" }
    "btn_wa"       = @{ DE="WEBAPP STARTEN";        EN="START WEBAPP" }
    "btn_vsteam"   = @{ DE="VIA STEAM";             EN="VIA STEAM" }
    "h_sub"        = @{ DE="Automatische Erkennung und Installation aller Serverkomponenten."
                        EN="Automatic detection and installation of all server components." }
    "h_steps"      = @{ DE="INSTALLATIONSSCHRITTE"; EN="INSTALLATION STEPS" }
    "h_all"        = @{ DE=">> ALLE INSTALLIEREN";  EN=">> INSTALL ALL" }
    "sec_action"   = @{ DE="AKTION";                EN="ACTION" }
    "st_desc"      = @{ DE="Laedt den offiziellen Steam Installer herunter und startet die Installation."
                        EN="Downloads the official Steam installer and starts the installation." }
    "e_sec"        = @{ DE="INSTALLATIONSQUELLE WAEHLEN"; EN="CHOOSE INSTALLATION SOURCE" }
    "e_note"       = @{ DE="Steam: ...steamapps\common\Escape from Tarkov  /  BSG: beliebiger Pfad"
                        EN="Steam: ...steamapps\common\Escape from Tarkov  /  BSG: any path" }
    "e_bsg_t"      = @{ DE="BSG LAUNCHER";              EN="BSG LAUNCHER" }
    "e_bsg_s"      = @{ DE="Gekauft auf escapefromtarkov.com"
                        EN="Purchased at escapefromtarkov.com" }
    "e_st_t"       = @{ DE="STEAM  (App-ID 3932890)";   EN="STEAM  (App-ID 3932890)" }
    "e_st_s"       = @{ DE="Gekauft im Steam-Store";    EN="Purchased in the Steam Store" }
    "spt_desc"     = @{ DE="Offizieller SPT Installer. Alle Laufwerke werden automatisch durchsucht."
                        EN="Official SPT Installer. All drives are searched automatically." }
    "spt_note"     = @{ DE="(!) Falls SPT nicht erkannt wird: Pfad in Einstellungen manuell setzen."
                        EN="(!) If SPT is not detected: manually set the path in Settings." }
    "fika_desc"    = @{ DE="Fika-Plugin (BepInEx\plugins\) + Server-Mod (user\mods\fika-server\)"
                        EN="Fika Plugin (BepInEx\plugins\) + Server Mod (user\mods\fika-server\)" }
    "fika_note"    = @{ DE="(!) SPT Server wird einmalig 60s gestartet um API Key zu generieren."
                        EN="(!) SPT Server is started once for 60s to generate the API Key." }
    "hl_desc"      = @{ DE="Fika.Headless Plugin (BepInEx\plugins\) + FikaHeadlessManager.exe"
                        EN="Fika.Headless Plugin (BepInEx\plugins\) + FikaHeadlessManager.exe" }
    "dk_desc"      = @{ DE="Aktiviert WSL2-Features, Kernel-Update und installiert Docker Desktop."
                        EN="Enables WSL2 features, kernel update and installs Docker Desktop." }
    "dk_note"      = @{ DE="(!) Nach der Installation ist ein Neustart erforderlich."
                        EN="(!) A restart is required after installation." }
    "fw_sec"       = @{ DE="PORT-KONFIGURATION";    EN="PORT CONFIGURATION" }
    "fw_p1"        = @{ DE="SPT Server API";        EN="SPT Server API" }
    "fw_p2"        = @{ DE="SPT Server UDP";        EN="SPT Server UDP" }
    "fw_p3"        = @{ DE="Fika Peer-to-Peer";     EN="Fika Peer-to-Peer" }
    "fw_p4"        = @{ DE="FikaWebApp HTTP";        EN="FikaWebApp HTTP" }
    "fw_p5"        = @{ DE="Container intern";       EN="Container internal" }
    "wa_sec"       = @{ DE="KONFIGURATION";          EN="CONFIGURATION" }
    "wa_desc"      = @{ DE="Docker Container -> http://localhost:8080"
                        EN="Docker Container -> http://localhost:8080" }
    "wa_api"       = @{ DE="API KEY  (wird automatisch aus fika.jsonc gelesen)"
                        EN="API KEY  (read automatically from fika.jsonc)" }
    "wa_note"      = @{ DE="(!) Standard-Login: admin / Admin123  ---  SOFORT AENDERN"
                        EN="(!) Default login: admin / Admin123  ---  CHANGE IMMEDIATELY" }
    "set_title"    = @{ DE="EINSTELLUNGEN";          EN="SETTINGS" }
    "set_spt_h"    = @{ DE="SPT-PFAD";              EN="SPT PATH" }
    "set_spt_d"    = @{ DE="Muss SPT.Server.exe enthalten. Fika/Headless werden dort geprueft."
                        EN="Must contain SPT.Server.exe. Fika/Headless are checked there." }
    "set_eft_h"    = @{ DE="EFT-PFAD  (OPTIONAL)";  EN="EFT PATH  (OPTIONAL)" }
    "set_eft_d"    = @{ DE="Steam: ...steamapps\common\Escape from Tarkov"
                        EN="Steam: ...steamapps\common\Escape from Tarkov" }
    "set_api_h"    = @{ DE="API KEY";               EN="API KEY" }
    "log_hdr"      = @{ DE="  AUSGABE  //  SYSTEMLOG"; EN="  OUTPUT  //  SYSTEM LOG" }
    "dlg_title"    = @{ DE="EFT Installationsmethode";         EN="EFT Installation Method" }
    "dlg_hdr"      = @{ DE="EFT INSTALLATIONSMETHODE WAEHLEN"; EN="CHOOSE EFT INSTALLATION METHOD" }
    "dlg_sub"      = @{ DE="Welche Methode soll bei >> ALLE INSTALLIEREN fuer EFT verwendet werden?"
                        EN="Which method should be used for >> INSTALL ALL for EFT?" }
    "dlg_bsg_t"    = @{ DE="BSG LAUNCHER";                     EN="BSG LAUNCHER" }
    "dlg_bsg_s"    = @{ DE="Gekauft auf escapefromtarkov.com  (empfohlen)"
                        EN="Purchased at escapefromtarkov.com  (recommended)" }
    "dlg_st_t"     = @{ DE="STEAM  (App-ID 3932890)";          EN="STEAM  (App-ID 3932890)" }
    "dlg_st_s"     = @{ DE="Gekauft im Steam-Store";           EN="Purchased in the Steam Store" }
    "fbr_spt"      = @{ DE="SPT-Ordner waehlen (Ordner mit SPT.Server.exe)"
                        EN="Choose SPT folder (folder containing SPT.Server.exe)" }
    "fbr_eft"      = @{ DE="EFT-Ordner waehlen"; EN="Choose EFT folder" }
    "log_cancel"   = @{ DE="Komplett-Installation abgebrochen."; EN="Full installation cancelled." }
    "log_method"   = @{ DE="EFT-Methode gewaehlt:";             EN="EFT method selected:" }
    "log_started"  = @{ DE="FIKA-SERVER SETUP UTILITY v1.0 GESTARTET"
                        EN="FIKA-SERVER SETUP UTILITY v1.0 STARTED" }
    "log_autocheck"= @{ DE="Starte automatische Status-Pruefung..."
                        EN="Starting automatic status check..." }
}

$script:I18nCtrl       = [System.Collections.Generic.List[object]]::new()
$script:HomeStepLabels = @{}

function T($key) {
    if ($script:Tr.ContainsKey($key)) {
        $v = $script:Tr[$key][$script:Lang]
        if ($null -ne $v) { return $v }
    }
    return $key
}

function RegI18n($ctrl,$key,[switch]$Sec) {
    $null = $script:I18nCtrl.Add([PSCustomObject]@{
        Ctrl = $ctrl
        Key  = $key
        Sec  = $Sec.IsPresent
    })
}

function Set-Language($lang) {
    $script:Lang = $lang
    foreach ($item in $script:I18nCtrl) {
        if (-not $item.Ctrl) { continue }
        $text = T $item.Key
        if ($item.Sec) { $text = " $text " }
        $item.Ctrl.Text = $text
    }
    foreach ($ni in $script:NavItemsDef) {
        $nk = "n_$($ni.Id)"
        if ($script:NavTxtLbls.ContainsKey($ni.Id)) {
            $script:NavTxtLbls[$ni.Id].Text = T $nk
        }
        if ($script:HomeStepLabels.ContainsKey($ni.Id)) {
            $script:HomeStepLabels[$ni.Id].Text = T $nk
        }
    }
    if ($script:NavTxtLbls.ContainsKey("Settings")) {
        $script:NavTxtLbls["Settings"].Text = T "s_settings"
    }
    $activeBack   = rgb 16 12 4
    $activeFore   = $script:C_Gold
    $activeBord   = $script:C_GoldD
    $inactiveBack = $script:C_Bg2
    $inactiveFore = $script:C_Tx2
    $inactiveBord = $script:C_Line
    if ($script:LangBtnDE) {
        if ($lang -eq "DE") {
            $script:LangBtnDE.BackColor = $activeBack
            $script:LangBtnDE.ForeColor = $activeFore
            $script:LangBtnDE.FlatAppearance.BorderColor = $activeBord
        } else {
            $script:LangBtnDE.BackColor = $inactiveBack
            $script:LangBtnDE.ForeColor = $inactiveFore
            $script:LangBtnDE.FlatAppearance.BorderColor = $inactiveBord
        }
    }
    if ($script:LangBtnEN) {
        if ($lang -eq "EN") {
            $script:LangBtnEN.BackColor = $activeBack
            $script:LangBtnEN.ForeColor = $activeFore
            $script:LangBtnEN.FlatAppearance.BorderColor = $activeBord
        } else {
            $script:LangBtnEN.BackColor = $inactiveBack
            $script:LangBtnEN.ForeColor = $inactiveFore
            $script:LangBtnEN.FlatAppearance.BorderColor = $inactiveBord
        }
    }
    if ($script:MainForm) { $script:MainForm.Refresh() }
}

function rgb($r,$g,$b) { [System.Drawing.Color]::FromArgb($r,$g,$b) }

$script:C_Bg0      = rgb   5   5   5
$script:C_Bg1      = rgb  10   9   8
$script:C_Bg2      = rgb  16  15  13
$script:C_Bg3      = rgb  24  22  18
$script:C_BgActive = rgb  20  17  10
$script:C_Line     = rgb  34  30  24
$script:C_LineHL   = rgb  78  64  38
$script:C_Gold     = rgb 196 165 105
$script:C_GoldD    = rgb 116  95  50
$script:C_GoldL    = rgb 224 196 146
$script:C_GoldBg   = rgb  18  14   5
$script:C_Green    = rgb  62 102  66
$script:C_GreenL   = rgb  96 152 102
$script:C_GreenBg  = rgb   6  14   8
$script:C_Red      = rgb 122  44  44
$script:C_RedL     = rgb 188  80  80
$script:C_RedBg    = rgb  18   4   4
$script:C_Amber    = rgb 184 144  44
$script:C_AmberL   = rgb 214 176  88
$script:C_AmberBg  = rgb  20  14   3
$script:C_Tx0      = rgb 188 184 176
$script:C_Tx1      = rgb 108 104  98
$script:C_Tx2      = rgb  50  48  44

$script:F = @{
    H1  = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
    H2  = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    H3  = New-Object System.Drawing.Font("Segoe UI",  9, [System.Drawing.FontStyle]::Bold)
    Bd  = New-Object System.Drawing.Font("Segoe UI",  9)
    Sm  = New-Object System.Drawing.Font("Segoe UI",  8)
    Nav = New-Object System.Drawing.Font("Segoe UI",  8, [System.Drawing.FontStyle]::Bold)
    Cap = New-Object System.Drawing.Font("Segoe UI",  7, [System.Drawing.FontStyle]::Bold)
    Mn  = New-Object System.Drawing.Font("Consolas",  9)
    Mn2 = New-Object System.Drawing.Font("Consolas",  8)
    Hdr = New-Object System.Drawing.Font("Segoe UI",  7)
}

function Lbl($text,$font=$script:F.Bd,$fg=$script:C_Tx0,$x=0,$y=0,$w=500,$h=22) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text=$text; $l.Font=$font; $l.ForeColor=$fg
    $l.BackColor=[System.Drawing.Color]::Transparent
    $l.Location=[System.Drawing.Point]::new($x,$y)
    $l.Size=[System.Drawing.Size]::new($w,$h)
    $l.AutoSize=$false
    return $l
}

function Btn($text,$x=0,$y=0,$w=170,$h=34,$pri=$true) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text=$text.ToUpper()
    $b.Location=[System.Drawing.Point]::new($x,$y)
    $b.Size=[System.Drawing.Size]::new($w,$h)
    $b.FlatStyle=[System.Windows.Forms.FlatStyle]::Flat
    $b.Cursor=[System.Windows.Forms.Cursors]::Hand
    if ($pri) {
        $b.BackColor = rgb 16 12 4
        $b.ForeColor = $script:C_Gold
        $b.Font      = $script:F.H3
        $b.FlatAppearance.BorderSize  = 1
        $b.FlatAppearance.BorderColor = $script:C_GoldD
        $b.FlatAppearance.MouseOverBackColor = rgb 28 22 8
        $b.FlatAppearance.MouseDownBackColor = rgb 36 28 10
    } else {
        $b.BackColor = $script:C_Bg2
        $b.ForeColor = $script:C_Tx1
        $b.Font      = $script:F.H3
        $b.FlatAppearance.BorderSize  = 1
        $b.FlatAppearance.BorderColor = $script:C_Line
        $b.FlatAppearance.MouseOverBackColor = $script:C_Bg3
        $b.FlatAppearance.MouseDownBackColor = rgb 30 28 24
    }
    return $b
}

function TBox($text="",$x=0,$y=0,$w=360,$h=26) {
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Text=$text; $tb.Location=[System.Drawing.Point]::new($x,$y)
    $tb.Size=[System.Drawing.Size]::new($w,$h)
    $tb.Font=$script:F.Mn2; $tb.ForeColor=$script:C_Tx0
    $tb.BackColor=$script:C_Bg2
    $tb.BorderStyle=[System.Windows.Forms.BorderStyle]::FixedSingle
    return $tb
}

$script:LogQueue    = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$script:BadgeQueue  = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$script:StatusQueue = [System.Collections.Concurrent.ConcurrentQueue[object]]::new()
$script:LogRTB      = $null

function Log {
    param([string]$Msg,[string]$Lv="I")
    $ts   = Get-Date -Format "HH:mm:ss"
    $icon = switch ($Lv) {
        "O"{"[OK] "} "E"{"[ERR]"} "W"{"[ W ]"} "S"{"[ > ]"} default{"[ - ]"}
    }
    $col = switch ($Lv) {
        "O" { $script:C_GreenL }
        "E" { $script:C_RedL   }
        "W" { $script:C_AmberL }
        "S" { $script:C_Gold   }
        default { $script:C_Tx1 }
    }
    $line = "[$ts] $icon $Msg"
    try { $line | Out-File "$env:TEMP\FikaSetup_run.log" -Append } catch {}
    $null = $script:LogQueue.Enqueue([PSCustomObject]@{ Txt=$line; Col=$col })
}

$script:Badges      = @{}
$script:NavLeftBars = @{}
$script:NavTxtLbls  = @{}

function SetBadge($id,[int]$state) {
    if ([string]::IsNullOrEmpty($id)) { return }
    $null = $script:BadgeQueue.Enqueue([PSCustomObject]@{ Id=$id; State=$state })
}

$script:StatusLabels = @{}
$script:FWPortLabels = @{}

function MakeStatusCard($id,$x=0,$y=0,$w=640,$h=50) {
    $outer = New-Object System.Windows.Forms.Panel
    $outer.Location=[System.Drawing.Point]::new($x,$y)
    $outer.Size=[System.Drawing.Size]::new($w,$h)
    $outer.BackColor=$script:C_Bg2
    $strip = New-Object System.Windows.Forms.Panel
    $strip.Location=[System.Drawing.Point]::new(0,0)
    $strip.Size=[System.Drawing.Size]::new(3,$h)
    $strip.BackColor=$script:C_Tx2
    $icon = New-Object System.Windows.Forms.Label
    $icon.Location=[System.Drawing.Point]::new(12,13)
    $icon.Size=[System.Drawing.Size]::new(18,18)
    $icon.Text="x"
    $icon.Font=$script:F.H3
    $icon.ForeColor=$script:C_Tx2
    $icon.BackColor=[System.Drawing.Color]::Transparent
    $icon.TextAlign=[System.Drawing.ContentAlignment]::MiddleCenter
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Location=[System.Drawing.Point]::new(36,5)
    $lbl.Size=[System.Drawing.Size]::new($w-46,38)
    $lbl.Text="STATUS..."
    $lbl.Font=$script:F.Mn2
    $lbl.ForeColor=$script:C_Tx1
    $lbl.BackColor=[System.Drawing.Color]::Transparent
    $outer.Controls.AddRange(@($strip,$icon,$lbl))
    $script:StatusLabels[$id] = @{ Panel=$outer; Strip=$strip; Icon=$icon; Label=$lbl }
    return $outer
}

function Show-EftMethodDialog {
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text            = T "dlg_title"
    $dlg.Size            = [System.Drawing.Size]::new(530, 300)
    $dlg.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dlg.BackColor       = $script:C_Bg0
    $dlg.ForeColor       = $script:C_Tx0
    $dlg.Font            = $script:F.Bd
    $dlg.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dlg.MaximizeBox     = $false
    $dlg.MinimizeBox     = $false
    $dlg.Tag             = $null

    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Dock      = [System.Windows.Forms.DockStyle]::Top
    $hdr.Height    = 46
    $hdr.BackColor = $script:C_Bg1
    $hdrBotLine = New-Object System.Windows.Forms.Panel
    $hdrBotLine.Dock      = [System.Windows.Forms.DockStyle]::Bottom
    $hdrBotLine.Height    = 1
    $hdrBotLine.BackColor = $script:C_GoldD
    $hdrLeftBar = New-Object System.Windows.Forms.Panel
    $hdrLeftBar.Dock      = [System.Windows.Forms.DockStyle]::Left
    $hdrLeftBar.Width     = 3
    $hdrLeftBar.BackColor = $script:C_Gold
    $hdr.Controls.AddRange(@(
        $hdrLeftBar,
        $hdrBotLine,
        (Lbl (T "dlg_hdr") $script:F.H2 $script:C_Gold 14 11 470 24)
    ))
    $dlg.Controls.Add($hdr)
    $dlg.Controls.Add((Lbl (T "dlg_sub") $script:F.Sm $script:C_Tx1 20 58 470 18))

    $cBg2 = $script:C_Bg2; $cBg3 = $script:C_Bg3

    function MakeDlgCard($yPos,$title,$titleColor,$sub,$tag,$dlgRef) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Location  = [System.Drawing.Point]::new(20,$yPos)
        $card.Size      = [System.Drawing.Size]::new(474, 58)
        $card.BackColor = $cBg2
        $card.Cursor    = [System.Windows.Forms.Cursors]::Hand
        $bar = New-Object System.Windows.Forms.Panel
        $bar.Location  = [System.Drawing.Point]::new(0,0)
        $bar.Size      = [System.Drawing.Size]::new(2,58)
        $bar.BackColor = $script:C_GoldD
        $lT = Lbl $title $script:F.H3 $titleColor 12 8 400 18
        $lS = Lbl $sub   $script:F.Sm $script:C_Tx2 12 28 450 16
        $card.Controls.AddRange(@($bar,$lT,$lS))
        $t=$tag; $d=$dlgRef
        $card.Add_MouseEnter({ param($s,$e) $s.BackColor=$cBg3 }.GetNewClosure())
        $card.Add_MouseLeave({ param($s,$e) $s.BackColor=$cBg2 }.GetNewClosure())
        $lT.Add_MouseEnter({ param($s,$e) if($s.Parent){$s.Parent.BackColor=$cBg3} }.GetNewClosure())
        $lT.Add_MouseLeave({ param($s,$e) if($s.Parent){$s.Parent.BackColor=$cBg2} }.GetNewClosure())
        $lS.Add_MouseEnter({ param($s,$e) if($s.Parent){$s.Parent.BackColor=$cBg3} }.GetNewClosure())
        $lS.Add_MouseLeave({ param($s,$e) if($s.Parent){$s.Parent.BackColor=$cBg2} }.GetNewClosure())
        $card.Add_Click({ $d.Tag=$t; $d.Close() }.GetNewClosure())
        $lT.Add_Click({  $d.Tag=$t; $d.Close() }.GetNewClosure())
        $lS.Add_Click({  $d.Tag=$t; $d.Close() }.GetNewClosure())
        return $card
    }

    $dlg.Controls.Add((MakeDlgCard 86  (T "dlg_bsg_t") $script:C_Tx0 (T "dlg_bsg_s") "BSG"   $dlg))
    $dlg.Controls.Add((MakeDlgCard 152 (T "dlg_st_t")  $script:C_Tx0 (T "dlg_st_s")  "Steam" $dlg))

    $divLine = New-Object System.Windows.Forms.Panel
    $divLine.Location  = [System.Drawing.Point]::new(0,224)
    $divLine.Size      = [System.Drawing.Size]::new(530,1)
    $divLine.BackColor = $script:C_Line
    $dlg.Controls.Add($divLine)

    $bCancel = Btn (T "btn_cancel") 20 234 150 30 $false
    $dCan    = $dlg
    $bCancel.Add_Click({ $dCan.Tag=$null; $dCan.Close() }.GetNewClosure())
    $dlg.Controls.Add($bCancel)
    $dlg.ShowDialog($script:MainForm) | Out-Null
    return $dlg.Tag
}

function StartOpAll {
    $method = Show-EftMethodDialog
    if ($null -eq $method) {
        Log (T "log_cancel") "W"
        return
    }
    $script:Cfg.EftMethod = $method
    $methodName = switch ($method) {
        "BSG"   { "BSG Launcher" }
        "Steam" { "Steam" }
        default { $method }
    }
    Log "$(T 'log_method') $methodName" "O"
    RunBG { Op-All }
}

$script:FunctionDefs = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function rgb($r,$g,$b) { [System.Drawing.Color]::FromArgb($r,$g,$b) }

function Log {
    param([string]$Msg,[string]$Lv="I")
    $ts   = Get-Date -Format "HH:mm:ss"
    $icon = switch ($Lv) {
        "O"{"[OK] "} "E"{"[ERR]"} "W"{"[ W ]"} "S"{"[ > ]"} default{"[ - ]"}
    }
    $col = switch ($Lv) {
        "O"{rgb 96 152 102} "E"{rgb 188 80 80} "W"{rgb 214 176 88} "S"{rgb 196 165 105}
        default{rgb 108 104 98}
    }
    $line = "[$ts] $icon $Msg"
    try { $line | Out-File "$env:TEMP\FikaSetup_run.log" -Append } catch {}
    $null = $LogQueue.Enqueue([PSCustomObject]@{ Txt=$line; Col=$col })
}

function SetBadge($id,[int]$state) {
    if ([string]::IsNullOrEmpty($id)) { return }
    $null = $BadgeQueue.Enqueue([PSCustomObject]@{ Id=$id; State=$state })
}

function NotifyStatus($id,[int]$state,[string]$msg) {
    $null = $StatusQueue.Enqueue([PSCustomObject]@{ Id=$id; State=$state; Msg=$msg })
    switch ($state) {
        2 { SetBadge $id 2 } 3 { SetBadge $id 3 }
        4 { SetBadge $id 4 } 1 { SetBadge $id 1 } 0 { SetBadge $id 0 }
    }
}

function FWPort($port,$proto,$status) {
    $col = if ($status -eq 'v') { rgb 96 152 102 } else { rgb 188 80 80 }
    $null = $LogQueue.Enqueue([PSCustomObject]@{
        Txt="__FWPORT__:${port}|${proto}|${status}"; Col=$col
    })
}

function Get-AvailDrives {
    return [System.IO.DriveInfo]::GetDrives() |
           Where-Object { $_.IsReady } |
           ForEach-Object { $_.Name[0].ToString().ToUpper() } |
           Where-Object   { $_ -match '[A-Z]' }
}

function Get-SteamLibraries {
    $libs   = [System.Collections.Generic.List[string]]::new()
    $steamB = $null
    foreach ($rp in @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam"
        "HKLM:\SOFTWARE\Valve\Steam"
        "HKCU:\SOFTWARE\Valve\Steam"
    )) {
        try {
            $reg = Get-ItemProperty $rp -ErrorAction Stop
            if ($reg -and -not [string]::IsNullOrWhiteSpace($reg.InstallPath) -and
                (Test-Path $reg.InstallPath -ErrorAction SilentlyContinue)) {
                $steamB = $reg.InstallPath; break
            }
        } catch {}
    }
    if (-not $steamB) {
        foreach ($tp in @(
            "C:\Program Files (x86)\Steam"
            "C:\Program Files\Steam"
            "D:\Steam"
            "D:\Programme\Steam"
        )) {
            if (Test-Path $tp -ErrorAction SilentlyContinue) { $steamB=$tp; break }
        }
    }
    if ($steamB) {
        $libs.Add($steamB)
        $vdf = Join-Path $steamB "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf -ErrorAction SilentlyContinue) {
            try {
                $content = Get-Content $vdf -Raw -ErrorAction SilentlyContinue
                $ms = [regex]::Matches($content, '"path"\s+"([^"]+)"')
                foreach ($m in $ms) {
                    $lp = $m.Groups[1].Value -replace '\\\\','\'
                    if ((Test-Path $lp -ErrorAction SilentlyContinue) -and -not $libs.Contains($lp)) {
                        $libs.Add($lp)
                    }
                }
            } catch {}
        }
    }
    foreach ($d in (Get-AvailDrives)) {
        foreach ($sub in @("SteamLibrary","Steam","SteamGames","steamlibrary","games\Steam","Games\Steam")) {
            $tp = "${d}:\$sub"
            if ((Test-Path $tp -ErrorAction SilentlyContinue) -and -not $libs.Contains($tp)) {
                $libs.Add($tp)
            }
        }
    }
    return $libs
}

function Get-SptRootCandidates {
    param([string]$sptDir)
    $list = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($sptDir)) { return $list }
    $list.Add($sptDir)
    $p1 = [System.IO.Path]::GetDirectoryName($sptDir)
    if (-not [string]::IsNullOrWhiteSpace($p1) -and
        (Test-Path $p1 -ErrorAction SilentlyContinue)) {
        $list.Add($p1)
        $p2 = [System.IO.Path]::GetDirectoryName($p1)
        if (-not [string]::IsNullOrWhiteSpace($p2) -and
            (Test-Path $p2 -ErrorAction SilentlyContinue)) {
            $list.Add($p2)
        }
    }
    return $list
}

function Find-FileNative {
    param([string]$Root,[string]$FileName,[int]$TimeoutMs=90000)
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "cmd.exe"
        $psi.Arguments = "/c dir /s /b `"$Root\$FileName`" 2>nul"
        $psi.UseShellExecute=$false; $psi.RedirectStandardOutput=$true
        $psi.RedirectStandardError=$true; $psi.CreateNoWindow=$true
        $proc  = [System.Diagnostics.Process]::Start($psi)
        $found = $null
        $sw    = [System.Diagnostics.Stopwatch]::StartNew()
        while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
            if ($proc.StandardOutput.EndOfStream) { break }
            $line = $proc.StandardOutput.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) {
                if ($proc.HasExited) { break }
                Start-Sleep -Milliseconds 10; continue
            }
            if ($line -match ([regex]::Escape($FileName) + '$')) {
                $found = $line.Trim(); break
            }
        }
        if (-not $proc.HasExited) { try { $proc.Kill() } catch {} }
        try { $proc.Dispose() } catch {}
        return $found
    } catch { Log "Find-FileNative Error ($Root): $_" "W"; return $null }
}

function Get-SptCandidates {
    $list   = [System.Collections.Generic.List[string]]::new()
    $drives = Get-AvailDrives
    if (-not [string]::IsNullOrWhiteSpace($Cfg.SptDir)) { $list.Add($Cfg.SptDir) }
    $names = @(
        "SPT","SPT-AKI","spt","spt-aki","SPT_AKI","SPT_Server",
        "FIKA","fika","FikaServer","fika-server","FIKAServer",
        "Games\SPT","Games\SPT-AKI","Games\fika","Games\FIKA","Games\FikaServer",
        "Spiele\SPT","Spiele\SPT-AKI","Spiele\fika",
        "Gaming\SPT","Gaming\SPT-AKI","Gaming\fika",
        "Server","Server\SPT","Server\fika",
        "EFT\SPT","Tarkov\SPT","EscapeFromTarkov\SPT",
        "GameServer\SPT","gameserver\spt",
        "Program Files\SPT","Program Files (x86)\SPT",
        "Apps\SPT","App\SPT","tools\SPT","Tools\SPT"
    )
    foreach ($d in $drives) { foreach ($n in $names) { $list.Add("${d}:\$n") } }
    $steamLibs = Get-SteamLibraries
    foreach ($lib in $steamLibs) {
        foreach ($n in @("SPT","SPT-AKI","spt","fika","FIKA","FikaServer")) {
            $list.Add("$lib\$n")
            $list.Add("$lib\steamapps\common\$n")
        }
        $eftCommon = "$lib\steamapps\common\Escape from Tarkov"
        if (Test-Path $eftCommon -ErrorAction SilentlyContinue) {
            foreach ($n in @("SPT","SPT-AKI","spt","fika","FIKA","FikaServer")) {
                $list.Add("$eftCommon\$n")
                $list.Add("$eftCommon\$n\$n")
            }
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($Cfg.EftDir)) {
        foreach ($n in @("SPT","SPT-AKI","spt","fika","FIKA","FikaServer")) {
            $list.Add("$($Cfg.EftDir)\$n")
            $list.Add("$($Cfg.EftDir)\$n\$n")
        }
    }
    $userBases = @(
        $env:USERPROFILE
        [Environment]::GetFolderPath('Desktop')
        [Environment]::GetFolderPath('MyDocuments')
        "$env:USERPROFILE\Downloads"
        "C:\Users\Public"
    )
    foreach ($base in $userBases) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }
        foreach ($n in @("SPT","SPT-AKI","spt","fika","FIKA","FikaServer","server")) {
            $list.Add("$base\$n")
        }
    }
    return $list
}

function Check-Steam {
    foreach ($rp in @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam"
        "HKLM:\SOFTWARE\Valve\Steam"
        "HKCU:\SOFTWARE\Valve\Steam"
    )) {
        try {
            $reg = Get-ItemProperty $rp -ErrorAction Stop
            if ($reg -and -not [string]::IsNullOrWhiteSpace($reg.InstallPath)) {
                if (Test-Path (Join-Path $reg.InstallPath "Steam.exe") -ErrorAction SilentlyContinue) {
                    return @{ Ok=$true; Path=$reg.InstallPath }
                }
            }
        } catch {}
    }
    foreach ($p in @(
        "C:\Program Files (x86)\Steam\Steam.exe"
        "C:\Program Files\Steam\Steam.exe"
        "D:\Steam\Steam.exe"
    )) {
        if (Test-Path $p -ErrorAction SilentlyContinue) {
            return @{ Ok=$true; Path=(Split-Path $p) }
        }
    }
    return @{ Ok=$false; Path=$null }
}

function Check-EFT {
    foreach ($rp in @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\EscapeFromTarkov"
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EscapeFromTarkov"
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\EscapeFromTarkov"
    )) {
        try {
            $reg = Get-ItemProperty $rp -ErrorAction Stop
            if ($reg -and -not [string]::IsNullOrWhiteSpace($reg.InstallLocation)) {
                $il = $reg.InstallLocation
                if ((Test-Path (Join-Path $il "EscapeFromTarkov.exe") -ErrorAction SilentlyContinue) -or
                    (Test-Path (Join-Path $il "build\EscapeFromTarkov.exe") -ErrorAction SilentlyContinue)) {
                    return @{ Ok=$true; Path=$il; Via="BSG Launcher" }
                }
            }
        } catch {}
    }
    $steamLibs = Get-SteamLibraries
    foreach ($lib in $steamLibs) {
        $ep = Join-Path $lib "steamapps\common\Escape from Tarkov"
        if (Test-Path $ep -ErrorAction SilentlyContinue) {
            $exeBuild = Join-Path $ep "build\EscapeFromTarkov.exe"
            $exeRoot  = Join-Path $ep "EscapeFromTarkov.exe"
            if ((Test-Path $exeBuild -ErrorAction SilentlyContinue) -or
                (Test-Path $exeRoot  -ErrorAction SilentlyContinue)) {
                $null = $LogQueue.Enqueue([PSCustomObject]@{ Txt="__EFTDIR__:$ep"; Col=(rgb 96 152 102) })
                return @{ Ok=$true; Path=$ep; Via="Steam" }
            }
        }
    }
    foreach ($d in (Get-AvailDrives)) {
        foreach ($sub in @(
            "Battlestate Games\EFT (live)","Battlestate Games\EFT",
            "Battlestate Games\Escape from Tarkov",
            "Program Files\Battlestate Games\EFT (live)",
            "Games\EFT","Games\EFT (live)","Games\Escape from Tarkov",
            "Spiele\EFT","EFT","EFT (live)","Escape from Tarkov","Tarkov"
        )) {
            $p = "${d}:\$sub"
            if (Test-Path (Join-Path $p "EscapeFromTarkov.exe") -ErrorAction SilentlyContinue) {
                return @{ Ok=$true; Path=$p; Via="BSG" }
            }
            if (Test-Path (Join-Path $p "build\EscapeFromTarkov.exe") -ErrorAction SilentlyContinue) {
                return @{ Ok=$true; Path=$p; Via="BSG/Steam" }
            }
        }
    }
    foreach ($d in (Get-AvailDrives)) {
        Log "EFT full-scan ${d}: ..." "S"
        $hit = Find-FileNative "${d}:" "EscapeFromTarkov.exe" 60000
        if ($hit) {
            $dir = [System.IO.Path]::GetDirectoryName($hit)
            $parent = [System.IO.Path]::GetDirectoryName($dir)
            if ((Split-Path $dir -Leaf) -eq 'build' -and $parent) { $dir=$parent }
            $null = $LogQueue.Enqueue([PSCustomObject]@{ Txt="__EFTDIR__:$dir"; Col=(rgb 96 152 102) })
            return @{ Ok=$true; Path=$dir; Via="Scan" }
        }
    }
    return @{ Ok=$false; Path=$null; Via=$null }
}

function Check-SPT {
    $candidates = Get-SptCandidates
    foreach ($p in $candidates) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (-not (Test-Path $p -ErrorAction SilentlyContinue)) { continue }
        $exe = Join-Path $p "SPT.Server.exe"
        if (Test-Path $exe -ErrorAction SilentlyContinue) {
            if ($p -ne $Cfg.SptDir) {
                $Cfg.SptDir = $p
                $null = $LogQueue.Enqueue([PSCustomObject]@{ Txt="__SPTDIR__:$p"; Col=(rgb 96 152 102) })
            }
            return @{ Ok=$true; Path=$p }
        }
    }
    foreach ($d in (Get-AvailDrives)) {
        Log "Full-scan ${d}:\ for SPT.Server.exe ..." "S"
        $hit = Find-FileNative "${d}:" "SPT.Server.exe" 90000
        if ($hit) {
            $dir = [System.IO.Path]::GetDirectoryName($hit.Trim())
            if ([string]::IsNullOrWhiteSpace($dir)) { continue }
            if (-not (Test-Path $dir -ErrorAction SilentlyContinue)) { continue }
            Log "SPT.Server.exe found: $dir" "O"
            $Cfg.SptDir = $dir
            $null = $LogQueue.Enqueue([PSCustomObject]@{ Txt="__SPTDIR__:$dir"; Col=(rgb 96 152 102) })
            return @{ Ok=$true; Path=$dir }
        }
        Log "SPT not found on ${d}:." "I"
    }
    return @{ Ok=$false; Path=$null }
}

function Check-Fika {
    try {
        $sptDir = $null
        if (-not [string]::IsNullOrWhiteSpace($Cfg.SptDir) -and
            (Test-Path $Cfg.SptDir -ErrorAction SilentlyContinue)) {
            $sptDir = $Cfg.SptDir
        } else {
            $spt = Check-SPT
            if (-not $spt.Ok) { return @{ Ok=$false; Partial=$false; Msg="SPT not found" } }
            $sptDir = $spt.Path
        }
        if ([string]::IsNullOrWhiteSpace($sptDir)) {
            return @{ Ok=$false; Partial=$false; Msg="SPT not found" }
        }
        $roots = Get-SptRootCandidates $sptDir
        $dll = $null
        foreach ($r in $roots) {
            $plugDir = Join-Path $r "BepInEx\plugins"
            if (Test-Path $plugDir -ErrorAction SilentlyContinue) {
                $found = Get-ChildItem $plugDir -Recurse -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -like "Fika.Core*" } | Select-Object -First 1
                if ($found) { $dll = $found; break }
            }
        }
        $mod = $false; $modDir = $null
        foreach ($r in $roots) {
            $md = Join-Path $r "user\mods\fika-server"
            if (Test-Path $md -ErrorAction SilentlyContinue) { $mod=$true; $modDir=$md; break }
        }
        $version = ""
        if ($mod -and $modDir) {
            $pkgJson = Join-Path $modDir "package.json"
            if (Test-Path $pkgJson -ErrorAction SilentlyContinue) {
                try { $pkg = Get-Content $pkgJson -Raw | ConvertFrom-Json; $version=" v$($pkg.version)" } catch {}
            }
        }
        if ($dll -and $mod)  { return @{ Ok=$true;  Partial=$false; Msg="Plugin $($dll.Name) + Server-Mod$version" } }
        if ($dll) { return @{ Ok=$false; Partial=$true; Msg="Plugin only ($($dll.Name)) - Server-Mod missing" } }
        if ($mod) { return @{ Ok=$false; Partial=$true; Msg="Server-Mod only$version - Plugin missing" } }
        return @{ Ok=$false; Partial=$false; Msg="Not installed" }
    } catch { return @{ Ok=$false; Partial=$false; Msg="Error: $_" } }
}

function Check-Headless {
    try {
        $sptDir = $null
        if (-not [string]::IsNullOrWhiteSpace($Cfg.SptDir) -and
            (Test-Path $Cfg.SptDir -ErrorAction SilentlyContinue)) {
            $sptDir = $Cfg.SptDir
        } else {
            $spt = Check-SPT
            if (-not $spt.Ok) { return @{ Ok=$false; Partial=$false; Msg="SPT not found" } }
            $sptDir = $spt.Path
        }
        $roots = Get-SptRootCandidates $sptDir
        $dll = $null
        foreach ($r in $roots) {
            $plugDir = Join-Path $r "BepInEx\plugins"
            if (Test-Path $plugDir -ErrorAction SilentlyContinue) {
                $found = Get-ChildItem $plugDir -Recurse -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -like "Fika.Headless*" } | Select-Object -First 1
                if ($found) { $dll = $found; break }
            }
        }
        $mgr = $false
        foreach ($r in $roots) {
            if (Test-Path (Join-Path $r "FikaHeadlessManager.exe") -ErrorAction SilentlyContinue) {
                $mgr = $true; break
            }
        }
        if ($dll -and $mgr) { return @{ Ok=$true;  Partial=$false; Msg="Plugin $($dll.Name) + Manager present" } }
        if ($dll)           { return @{ Ok=$false; Partial=$true;  Msg="Plugin only $($dll.Name) - Manager missing" } }
        if ($mgr)           { return @{ Ok=$false; Partial=$true;  Msg="Manager only - Plugin missing" } }
        return @{ Ok=$false; Partial=$false; Msg="Not installed" }
    } catch { return @{ Ok=$false; Partial=$false; Msg="Error: $_" } }
}

function Check-Docker {
    try {
        $v = (& docker --version 2>&1) -join ' '
        if ($LASTEXITCODE -eq 0 -and $v -match 'Docker') { return @{ Ok=$true; Version=$v } }
    } catch {}
    foreach ($rp in @(
        "HKLM:\SOFTWARE\Docker Inc.\Docker Desktop"
        "HKCU:\SOFTWARE\Docker Inc.\Docker Desktop"
    )) {
        if (Get-ItemProperty $rp -ErrorAction SilentlyContinue) {
            return @{ Ok=$true; Version="Docker Desktop installed (Engine not active)" }
        }
    }
    foreach ($exe in @(
        "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        "C:\Program Files\Docker\Docker Desktop.exe"
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    )) {
        if (Test-Path $exe -ErrorAction SilentlyContinue) {
            return @{ Ok=$true; Version="Docker Desktop present (not active)" }
        }
    }
    return @{ Ok=$false; Version=$null }
}

function Check-FirewallRule($name) {
    $out = (& netsh advfirewall firewall show rule name="$name" 2>&1) -join "`n"
    return ($out -match 'Regelname:|Rule Name:')
}

function Check-Firewall {
    $rules = @(
        @{ N="FIKA-SPT-TCP-6969";    P="TCP"; Port=6969  }
        @{ N="FIKA-SPT-UDP-6969";    P="UDP"; Port=6969  }
        @{ N="FIKA-P2P-UDP-25565";   P="UDP"; Port=25565 }
        @{ N="FIKA-WebApp-TCP-8080"; P="TCP"; Port=8080  }
        @{ N="FIKA-WebApp-TCP-5000"; P="TCP"; Port=5000  }
    )
    $results = @()
    foreach ($r in $rules) {
        $exists = Check-FirewallRule $r.N
        $results += [PSCustomObject]@{ Name=$r.N; Port=$r.Port; Protocol=$r.P; Exists=$exists }
    }
    $open  = ($results | Where-Object { $_.Exists }).Count
    $total = $results.Count
    return @{ Ok=($open -eq $total); Partial=($open -gt 0 -and $open -lt $total); Results=$results; Open=$open; Total=$total }
}

function Check-WebApp {
    try {
        $running = (& docker ps --filter "name=fikawebapp" --format "{{.Status}}" 2>&1) -join ''
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($running)) {
            return @{ Ok=$true; Running=$true; Status=$running }
        }
        $all = (& docker ps -a --filter "name=fikawebapp" --format "{{.Status}}" 2>&1) -join ''
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($all)) {
            return @{ Ok=$false; Exists=$true; Running=$false; Status=$all }
        }
    } catch {}
    return @{ Ok=$false; Exists=$false; Running=$false; Status=$null }
}

function Op-CheckAll {
    Log "=== STATUS CHECK ALL COMPONENTS ===" "S"
    NotifyStatus "Steam" 1 "Checking Steam..."
    $r = Check-Steam
    if ($r.Ok) { NotifyStatus "Steam" 2 "Installed: $($r.Path)"; Log "Steam: OK ($($r.Path))" "O" }
    else       { NotifyStatus "Steam" 3 "Not found"; Log "Steam: Not found" "W" }
    NotifyStatus "EFT" 1 "Checking Escape from Tarkov..."
    $r = Check-EFT
    if ($r.Ok) { NotifyStatus "EFT" 2 "Installed via $($r.Via): $($r.Path)"; Log "EFT: OK via $($r.Via) -> $($r.Path)" "O" }
    else       { NotifyStatus "EFT" 3 "Not found"; Log "EFT: Not found" "W" }
    NotifyStatus "SPT" 1 "Searching SPT (all drives)..."
    $r = Check-SPT
    if ($r.Ok) { NotifyStatus "SPT" 2 "Found: $($r.Path)"; Log "SPT: OK ($($r.Path))" "O" }
    else       { NotifyStatus "SPT" 3 "Not found - set path in Settings"; Log "SPT: Not found" "W" }
    NotifyStatus "Fika" 1 "Checking Fika..."
    $r = Check-Fika
    if ($r.Ok)          { NotifyStatus "Fika" 2 $r.Msg; Log "Fika: OK - $($r.Msg)" "O" }
    elseif ($r.Partial) { NotifyStatus "Fika" 4 $r.Msg; Log "Fika: Partial - $($r.Msg)" "W" }
    else                { NotifyStatus "Fika" 3 $r.Msg; Log "Fika: $($r.Msg)" "W" }
    NotifyStatus "Headless" 1 "Checking Headless Client..."
    $r = Check-Headless
    if ($r.Ok)          { NotifyStatus "Headless" 2 $r.Msg; Log "Headless: OK - $($r.Msg)" "O" }
    elseif ($r.Partial) { NotifyStatus "Headless" 4 $r.Msg; Log "Headless: Partial - $($r.Msg)" "W" }
    else                { NotifyStatus "Headless" 3 $r.Msg; Log "Headless: $($r.Msg)" "W" }
    NotifyStatus "Docker" 1 "Checking Docker..."
    $r = Check-Docker
    if ($r.Ok) { NotifyStatus "Docker" 2 $r.Version; Log "Docker: OK" "O" }
    else       { NotifyStatus "Docker" 3 "Not found"; Log "Docker: Not found" "W" }
    NotifyStatus "Firewall" 1 "Checking firewall rules..."
    $r = Check-Firewall
    foreach ($pr in $r.Results) {
        $fwSt  = if ($pr.Exists) { 'v' } else { 'x' }
        $fwMsg = if ($pr.Exists) { 'OK' } else { 'MISSING' }
        FWPort $pr.Port $pr.Protocol $fwSt
        Log "  Port $($pr.Port)/$($pr.Protocol) -> $fwMsg" "I"
    }
    if ($r.Ok) {
        NotifyStatus "Firewall" 2 "All $($r.Total) ports open"
        Log "Firewall: All ports OK" "O"
    } elseif ($r.Partial) {
        $closedList = ($r.Results | Where-Object { -not $_.Exists } |
                       ForEach-Object { "$($_.Port)/$($_.Protocol)" }) -join ', '
        NotifyStatus "Firewall" 4 "$($r.Open)/$($r.Total) open  Missing: $closedList"
        Log "Firewall: $($r.Open)/$($r.Total) ports open" "W"
    } else {
        NotifyStatus "Firewall" 3 "No FIKA firewall rules"
        Log "Firewall: No rules" "W"
    }
    NotifyStatus "WebApp" 1 "Checking FikaWebApp..."
    $r = Check-WebApp
    if ($r.Ok)         { NotifyStatus "WebApp" 2 "Container running: $($r.Status)"; Log "WebApp: Running" "O" }
    elseif ($r.Exists) { NotifyStatus "WebApp" 4 "Container stopped: $($r.Status)"; Log "WebApp: Stopped" "W" }
    else               { NotifyStatus "WebApp" 3 "No container found"; Log "WebApp: Not found" "W" }
    Log "=== CHECK COMPLETE ===" "O"
}

function DL($url,$outFile) {
    $leaf = Split-Path $outFile -Leaf
    Log "Downloading: $leaf" "S"
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent","Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $wc.DownloadFile($url,$outFile)
        Log "Done: $leaf" "O"; return $true
    } catch {}
    try {
        Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing `
            -UserAgent "Mozilla/5.0" -ErrorAction Stop
        Log "Done: $leaf" "O"; return $true
    } catch { Log "Download error: $_" "E"; return $false }
}

function GH($repo,$pattern="*.zip") {
    try {
        $rel   = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
        $asset = $rel.assets | Where-Object { $_.name -like $pattern } | Select-Object -First 1
        if ($asset) { Log "GitHub $($rel.tag_name) -> $($asset.name)" "O"; return $asset.browser_download_url }
        Log "No asset ($pattern) in $repo" "E"; return $null
    } catch { Log "GitHub API error ($repo): $_" "E"; return $null }
}

function Remove-MdFiles($dir) {
    $n = 0
    Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -eq '.md' -or $_.Name -like 'README*' -or
            $_.Name -like 'CHANGELOG*' -or $_.Name -like 'LICENSE*'
        } |
        ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue; $n++ }
    if ($n -gt 0) { Log "$n MD/README files removed." "O" }
}

function Op-Steam {
    Log "=== STEAM ===" "S"; SetBadge "Steam" 1
    $c = Check-Steam
    if ($c.Ok) { Log "Steam already present: $($c.Path)" "O"; NotifyStatus "Steam" 2 "Installed: $($c.Path)"; return }
    $out = Join-Path $Cfg.TempDir "SteamSetup.exe"
    if (DL "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe" $out) {
        Start-Process $out -Wait
        $c2 = Check-Steam
        if ($c2.Ok) { Log "Steam installed." "O"; NotifyStatus "Steam" 2 "Installed: $($c2.Path)" }
        else        { NotifyStatus "Steam" 4 "Installed (path not verified)" }
    } else {
        Start-Process "https://store.steampowered.com/about/"
        NotifyStatus "Steam" 3 "Download failed"
    }
}

function Op-EFT-BSG {
    Log "=== EFT VIA BSG LAUNCHER ===" "S"; SetBadge "EFT" 1
    $c = Check-EFT
    if ($c.Ok) { Log "EFT already present: $($c.Path)" "O"; NotifyStatus "EFT" 2 "Installed ($($c.Via)): $($c.Path)"; return }
    $out = Join-Path $Cfg.TempDir "BsgLauncher.exe"
    if (-not (DL "https://launcher.escapefromtarkov.com/launcher/download" $out)) {
        Start-Process "https://launcher.escapefromtarkov.com/launcher/download"
    } else { Start-Process $out -Wait }
    Log "BSG Launcher opened." "W"
    NotifyStatus "EFT" 4 "BSG Launcher opened - install EFT manually"
}

function Op-EFT-Steam {
    Log "=== EFT VIA STEAM ===" "S"; SetBadge "EFT" 1
    $c = Check-EFT
    if ($c.Ok) { Log "EFT already present: $($c.Path)" "O"; NotifyStatus "EFT" 2 "Installed ($($c.Via)): $($c.Path)"; return }
    Start-Process "steam://install/3932890"
    Log "Steam EFT installation opened." "O"
    NotifyStatus "EFT" 4 "Steam opened - waiting for EFT download"
}

function Op-SPT {
    Log "=== SPT ===" "S"; SetBadge "SPT" 1
    $c = Check-SPT
    if ($c.Ok) { Log "SPT already present: $($c.Path)" "O"; NotifyStatus "SPT" 2 "Installed: $($c.Path)"; return }
    $inst = Join-Path $Cfg.TempDir "SPTInstaller.exe"
    if (-not (DL "https://ligma.waffle-lord.net/SPTInstaller.exe" $inst)) {
        Log "Download failed." "E"; NotifyStatus "SPT" 3 "Download failed"; return
    }
    Log "Starting SPT Installer..." "S"
    $proc = Start-Process -FilePath $inst -PassThru; $proc.WaitForExit()
    Log "SPT Installer done (Exit=$($proc.ExitCode))." "O"
    $c2 = Check-SPT
    if ($c2.Ok) {
        $null = $LogQueue.Enqueue([PSCustomObject]@{ Txt="__SPTDIR__:$($c2.Path)"; Col=(rgb 96 152 102) })
        NotifyStatus "SPT" 2 "Installed: $($c2.Path)"
    } else {
        NotifyStatus "SPT" 4 "Installed - check path in Settings"
    }
}

function Op-Fika {
    Log "=== FIKA ===" "S"; SetBadge "Fika" 1
    $sptRoot = $null
    if (-not [string]::IsNullOrWhiteSpace($Cfg.SptDir) -and
        (Test-Path $Cfg.SptDir -ErrorAction SilentlyContinue)) {
        $sptRoot = $Cfg.SptDir
    } else { $sptRoot = (Check-SPT).Path }
    if (-not $sptRoot) { Log "SPT not found." "E"; NotifyStatus "Fika" 3 "Error: SPT not found"; return }
    $err = $false
    $u1 = GH "project-fika/Fika-Server-CSharp" "*.zip"
    if ($u1) {
        $o1 = Join-Path $Cfg.TempDir "FikaServer.zip"
        if (DL $u1 $o1) { Expand-Archive $o1 $sptRoot -Force; Log "Fika-Server-CSharp -> $sptRoot" "O" }
        else { $err=$true }
    } else { Log "Fika-Server-CSharp: no release." "E"; $err=$true }
    $u2 = GH "project-fika/Fika-Plugin" "*.zip"
    if ($u2) {
        $o2 = Join-Path $Cfg.TempDir "FikaPlugin.zip"
        if (DL $u2 $o2) { Expand-Archive $o2 $sptRoot -Force; Log "Fika-Plugin -> $sptRoot" "O" }
        else { $err=$true }
    } else { Log "Fika-Plugin: no release." "E"; $err=$true }
    Remove-MdFiles $sptRoot
    if ($err) { NotifyStatus "Fika" 3 "Installation failed"; return }
    $sptExe = Join-Path $sptRoot "SPT.Server.exe"
    if (Test-Path $sptExe -ErrorAction SilentlyContinue) {
        Log "Starting SPT Server once (API Key generation, up to 60s)..." "S"
        $p = Start-Process $sptExe -PassThru -WorkingDirectory $sptRoot
        for ($i=5; $i -le 60; $i+=5) {
            Start-Sleep 5
            if ($p.HasExited) { break }
            Log "Waiting... $i/60s" "I"
        }
        try { if (-not $p.HasExited) { $p.Kill() } } catch {}
        Start-Sleep 2; Log "SPT Server stopped." "O"
        $jsonc = Join-Path $sptRoot "user\mods\fika-server\assets\configs\fika.jsonc"
        if (Test-Path $jsonc -ErrorAction SilentlyContinue) {
            $raw = Get-Content $jsonc -Raw
            if ($raw -match '"apiKey"\s*:\s*"([^"]+)"') {
                $Cfg.ApiKey = $matches[1]
                $null = $LogQueue.Enqueue([PSCustomObject]@{
                    Txt="__APIKEY__:$($Cfg.ApiKey)"; Col=(rgb 96 152 102)
                })
                Log "API Key read: $($Cfg.ApiKey.Substring(0,[Math]::Min(8,$Cfg.ApiKey.Length)))..." "O"
            }
        }
    }
    NotifyStatus "Fika" 2 "Plugin + Server-Mod installed: $sptRoot"
}

function Op-Headless {
    Log "=== HEADLESS CLIENT ===" "S"; SetBadge "Headless" 1
    $sptRoot = $null
    if (-not [string]::IsNullOrWhiteSpace($Cfg.SptDir) -and
        (Test-Path $Cfg.SptDir -ErrorAction SilentlyContinue)) {
        $sptRoot = $Cfg.SptDir
    } else { $sptRoot = (Check-SPT).Path }
    if (-not $sptRoot) { Log "SPT not found." "E"; NotifyStatus "Headless" 3 "Error: SPT not found"; return }
    $err = $false
    $u = GH "project-fika/Fika-Headless" "*.zip"
    if ($u) {
        $o = Join-Path $Cfg.TempDir "FikaHeadless.zip"
        if (DL $u $o) { Expand-Archive $o $sptRoot -Force; Log "Fika-Headless -> $sptRoot" "O" }
        else { $err=$true }
    } else {
        Log "Fika-Headless: no release." "E"
        Start-Process "https://github.com/project-fika/Fika-Headless/releases/latest"
        $err=$true
    }
    $mz = GH "project-fika/Fika-Headless-Manager" "*.zip"
    $me = GH "project-fika/Fika-Headless-Manager" "*.exe"
    if ($mz) {
        $oz = Join-Path $Cfg.TempDir "FikaHLMgr.zip"
        if (DL $mz $oz) { Expand-Archive $oz $sptRoot -Force; Log "FikaHeadlessManager -> $sptRoot" "O" }
        else { $err=$true }
    } elseif ($me) {
        $oe = Join-Path $sptRoot "FikaHeadlessManager.exe"
        if (-not (DL $me $oe)) { $err=$true }
    } else { Log "Fika-Headless-Manager: no release." "E"; $err=$true }
    Remove-MdFiles $sptRoot
    $mgr = Join-Path $sptRoot "FikaHeadlessManager.exe"
    if (Test-Path $mgr -ErrorAction SilentlyContinue) {
        Start-Process $mgr; Log "FikaHeadlessManager started." "O"
    }
    if ($err) { NotifyStatus "Headless" 3 "Installation failed" }
    else      { NotifyStatus "Headless" 2 "Plugin + Manager installed: $sptRoot" }
}

function Op-Docker {
    Log "=== DOCKER + WSL2 ===" "S"; SetBadge "Docker" 1
    $c = Check-Docker
    if ($c.Ok) { Log "Docker already present: $($c.Version)" "O"; NotifyStatus "Docker" 2 $c.Version; return }
    Log "Enabling WSL2..." "S"
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>&1 | Out-Null
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>&1 | Out-Null
    Log "WSL2 features enabled." "O"
    $wsl = Join-Path $Cfg.TempDir "wsl_update.msi"
    if (DL "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" $wsl) {
        Start-Process msiexec -ArgumentList "/i `"$wsl`" /quiet /norestart" -Wait
        wsl --set-default-version 2 2>&1 | Out-Null
        Log "WSL2 kernel updated." "O"
    }
    $dk    = Join-Path $Cfg.TempDir "DockerInstaller.exe"
    $dkUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
    if (DL $dkUrl $dk) {
        Log "Installing Docker Desktop..." "S"
        Start-Process $dk -ArgumentList "install --quiet --backend=wsl-2 --accept-license" -Wait
        Log "Docker Desktop installed. Restart required." "O"
        NotifyStatus "Docker" 2 "Installed - restart required"
        $resp = [System.Windows.Forms.MessageBox]::Show(
            "Docker installed.`nRestart required.`n`nRestart now? / Jetzt neu starten?",
            "Restart / Neustart",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($resp -eq [System.Windows.Forms.DialogResult]::Yes) {
            Start-Process shutdown -ArgumentList "/r /t 15 /c `"Restart for Docker/WSL2`""
        }
    } else { NotifyStatus "Docker" 3 "Download failed" }
}

function Op-Firewall {
    Log "=== FIREWALL ===" "S"; SetBadge "Firewall" 1
    $ok = $true
    $portList = @(
        @{ N="FIKA-SPT-TCP-6969";    P="TCP"; Port=6969  }
        @{ N="FIKA-SPT-UDP-6969";    P="UDP"; Port=6969  }
        @{ N="FIKA-P2P-UDP-25565";   P="UDP"; Port=25565 }
        @{ N="FIKA-WebApp-TCP-8080"; P="TCP"; Port=8080  }
        @{ N="FIKA-WebApp-TCP-5000"; P="TCP"; Port=5000  }
    )
    foreach ($entry in $portList) {
        $n=$entry.N; $prt=$entry.P; $port=$entry.Port
        & netsh advfirewall firewall delete rule name="$n" 2>&1 | Out-Null
        & netsh advfirewall firewall add rule `
            name="$n" dir=in action=allow protocol=$prt localport=$port `
            profile=any enable=yes 2>&1 | Out-Null
        $added = ($LASTEXITCODE -eq 0)
        if ($added) { $added = Check-FirewallRule $n }
        if ($added) {
            Log "Port $port/$prt opened ($n)" "O"; FWPort $port $prt 'v'
        } else {
            Log "Port $port/$prt ERROR: $n" "E"; FWPort $port $prt 'x'; $ok=$false
        }
    }
    if ($ok) { NotifyStatus "Firewall" 2 "All 5 ports successfully opened" }
    else     { NotifyStatus "Firewall" 3 "Some ports could not be opened" }
}

function Op-WebApp {
    Log "=== FIKAWEBAPP ===" "S"; SetBadge "WebApp" 1
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Log "Docker not active - starting Docker Desktop..." "W"
        foreach ($dExe in @(
            "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            "C:\Program Files\Docker\Docker Desktop.exe"
        )) {
            if (Test-Path $dExe -ErrorAction SilentlyContinue) { Start-Process $dExe; break }
        }
        $w = 0
        do {
            Start-Sleep 5; $w+=5; Log "Waiting for Docker... $w/90s" "S"
            docker info 2>&1 | Out-Null
        } while ($LASTEXITCODE -ne 0 -and $w -lt 90)
        if ($LASTEXITCODE -ne 0) {
            Log "Docker not reachable." "E"; NotifyStatus "WebApp" 3 "Docker not reachable"; return
        }
    }
    if ([string]::IsNullOrWhiteSpace($Cfg.ApiKey)) {
        $sptRoot = $null
        if (-not [string]::IsNullOrWhiteSpace($Cfg.SptDir) -and
            (Test-Path $Cfg.SptDir -ErrorAction SilentlyContinue)) {
            $sptRoot = $Cfg.SptDir
        } else { $sptRoot = (Check-SPT).Path }
        if ($sptRoot) {
            $roots = Get-SptRootCandidates $sptRoot
            foreach ($r in $roots) {
                $jsonc = Join-Path $r "user\mods\fika-server\assets\configs\fika.jsonc"
                if (Test-Path $jsonc -ErrorAction SilentlyContinue) {
                    $raw = Get-Content $jsonc -Raw
                    if ($raw -match '"apiKey"\s*:\s*"([^"]+)"') {
                        $Cfg.ApiKey = $matches[1]
                        $null = $LogQueue.Enqueue([PSCustomObject]@{
                            Txt="__APIKEY__:$($Cfg.ApiKey)"; Col=(rgb 96 152 102)
                        })
                        Log "API Key read from fika.jsonc ($r)." "O"; break
                    }
                }
            }
        }
    }
    if ([string]::IsNullOrWhiteSpace($Cfg.ApiKey)) {
        Log "No API Key found." "E"
        NotifyStatus "WebApp" 3 "No API Key - enter in Settings"; return
    }
    docker rm -f fikawebapp 2>&1 | Out-Null
    $runArgs = @(
        "run","-d","--name","fikawebapp",
        "-p","8080:5000","-e","PORT=5000",
        "-e","API_KEY=$($Cfg.ApiKey)",
        "-e","BASE_URL=https://host.docker.internal:6969",
        "-v","C:\FikaWebApp\webappdata:/app/data",
        "--add-host=host.docker.internal:host-gateway",
        "--restart","unless-stopped",
        "lacyway/fikawebapp:latest","--quiet-logs"
    )
    $result = (& docker $runArgs 2>&1) -join ' '
    if ($LASTEXITCODE -eq 0) {
        Log "FikaWebApp started -> http://localhost:8080" "O"
        Log "Login: admin / Admin123  -- CHANGE IMMEDIATELY" "W"
        Start-Sleep 3; Start-Process "http://localhost:8080"
        NotifyStatus "WebApp" 2 "Running on http://localhost:8080"
    } else {
        Log "Error: $result" "E"; NotifyStatus "WebApp" 3 "Start failed"
    }
}

function Op-All {
    Log "=== FULL INSTALLATION ===" "S"
    $methodName = switch ($Cfg.EftMethod) {
        "Steam" { "Steam" } default { "BSG Launcher" }
    }
    Log "EFT method: $methodName" "O"
    Op-Steam
    switch ($Cfg.EftMethod) {
        "Steam" { Op-EFT-Steam }
        default { Op-EFT-BSG  }
    }
    Op-SPT; Op-Fika; Op-Headless; Op-Docker; Op-Firewall; Op-WebApp
    Log "=== INSTALLATION COMPLETE ===" "O"
}
'@

$script:BgPS=$null; $script:BgHandle=$null; $script:BgRS=$null

function RunBG([scriptblock]$Block) {
    if ($script:Cfg.Busy) {
        [System.Windows.Forms.MessageBox]::Show(
            "DE: Ein Vorgang laeuft bereits. Bitte warten.`nEN: A process is already running. Please wait.",
            "FIKA-Server Setup",0,48)
        return
    }
    $script:Cfg.Busy=$true
    $rs=[runspacefactory]::CreateRunspace()
    $rs.ApartmentState='MTA'; $rs.ThreadOptions='ReuseThread'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('LogQueue',    $script:LogQueue)
    $rs.SessionStateProxy.SetVariable('BadgeQueue',  $script:BadgeQueue)
    $rs.SessionStateProxy.SetVariable('StatusQueue', $script:StatusQueue)
    $rs.SessionStateProxy.SetVariable('Cfg',         $script:Cfg)
    $ps=[System.Management.Automation.PowerShell]::Create()
    $ps.Runspace=$rs
    $tsNow=Get-Date -Format "HH:mm:ss"
    $blockStr=$Block.ToString()
    $full=$script:FunctionDefs+@"

try { $blockStr }
catch {
    `$errMsg=`$_.ToString()
    try { `$errMsg | Out-File "`$env:TEMP\FikaSetup_error.log" -Append } catch {}
    `$null=`$LogQueue.Enqueue([PSCustomObject]@{
        Txt="[$tsNow] [ERR] `$errMsg"
        Col=[System.Drawing.Color]::FromArgb(188,80,80)
    })
}
"@
    $null=$ps.AddScript($full)
    $script:BgPS=$ps; $script:BgRS=$rs; $script:BgHandle=$ps.BeginInvoke()
}

$script:MainForm = New-Object System.Windows.Forms.Form
$script:MainForm.Text = "FIKA-SERVER SETUP UTILITY  //  v1.0"
$script:MainForm.Size = [System.Drawing.Size]::new(1200,800)
$script:MainForm.MinimumSize = [System.Drawing.Size]::new(1000,680)
$script:MainForm.BackColor = $script:C_Bg0
$script:MainForm.ForeColor = $script:C_Tx0
$script:MainForm.Font = $script:F.Bd
$script:MainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$script:MainForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
try {
    $ep=[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $script:MainForm.Icon=[System.Drawing.Icon]::ExtractAssociatedIcon($ep)
} catch {}

# HEADER
$Header = New-Object System.Windows.Forms.Panel
$Header.Dock = [System.Windows.Forms.DockStyle]::Top
$Header.Height = 44
$Header.BackColor = $script:C_Bg1
$hTopLine = New-Object System.Windows.Forms.Panel
$hTopLine.Dock = [System.Windows.Forms.DockStyle]::Top
$hTopLine.Height = 1
$hTopLine.BackColor = $script:C_GoldD
$hLeftBar = New-Object System.Windows.Forms.Panel
$hLeftBar.Dock = [System.Windows.Forms.DockStyle]::Left
$hLeftBar.Width = 3
$hLeftBar.BackColor = $script:C_Gold
$hTitle = Lbl "FIKA-SERVER SETUP UTILITY" $script:F.H1 $script:C_Gold 18 8 600 28
$hBotLine = New-Object System.Windows.Forms.Panel
$hBotLine.Dock = [System.Windows.Forms.DockStyle]::Bottom
$hBotLine.Height = 1
$hBotLine.BackColor = $script:C_Line
$Header.Controls.AddRange(@($hLeftBar,$hTopLine,$hBotLine,$hTitle))

# STATUS BAR
$StatusBar = New-Object System.Windows.Forms.Panel
$StatusBar.Dock = [System.Windows.Forms.DockStyle]::Bottom
$StatusBar.Height = 22
$StatusBar.BackColor = $script:C_Bg1
$sbLine = New-Object System.Windows.Forms.Panel
$sbLine.Dock=[System.Windows.Forms.DockStyle]::Top
$sbLine.Height=1; $sbLine.BackColor=$script:C_Line
$StatusBar.Controls.Add($sbLine)
$sbLbl = Lbl (T "sb_ready") $script:F.Cap $script:C_Tx2 0 5 900 14
RegI18n $sbLbl "sb_ready"
$StatusBar.Controls.Add($sbLbl)

# SPLITS
$MainSplit = New-Object System.Windows.Forms.SplitContainer
$MainSplit.Dock = [System.Windows.Forms.DockStyle]::Fill
$MainSplit.Panel1MinSize = 240; $MainSplit.Panel2MinSize = 100
$MainSplit.FixedPanel = [System.Windows.Forms.FixedPanel]::Panel1
$MainSplit.IsSplitterFixed = $true; $MainSplit.SplitterWidth = 1
$MainSplit.BackColor = $script:C_Line
$MainSplit.Panel1.BackColor = $script:C_Bg1
$MainSplit.Panel2.BackColor = $script:C_Bg0

$RightSplit = New-Object System.Windows.Forms.SplitContainer
$RightSplit.Dock = [System.Windows.Forms.DockStyle]::Fill
$RightSplit.Orientation = [System.Windows.Forms.Orientation]::Horizontal
$RightSplit.SplitterDistance = 440; $RightSplit.SplitterWidth = 1
$RightSplit.BackColor = $script:C_Line
$RightSplit.Panel1.BackColor = $script:C_Bg0
$RightSplit.Panel2.BackColor = $script:C_Bg1

#  SIDEBAR
$Sidebar = New-Object System.Windows.Forms.FlowLayoutPanel
$Sidebar.Dock = [System.Windows.Forms.DockStyle]::Fill
$Sidebar.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$Sidebar.WrapContents = $false; $Sidebar.BackColor = $script:C_Bg1
$Sidebar.Padding = [System.Windows.Forms.Padding]::new(0,10,0,8)
$Sidebar.AutoScroll = $true

$NAV_W = 290

$sHdrPnl = New-Object System.Windows.Forms.Panel
$sHdrPnl.Size = [System.Drawing.Size]::new($NAV_W, 28)
$sHdrPnl.BackColor = $script:C_Bg1
$sHdrPnl.Margin = [System.Windows.Forms.Padding]::new(0,0,0,4)
$sGoldLine = New-Object System.Windows.Forms.Panel
$sGoldLine.Location = [System.Drawing.Point]::new(14,14)
$sGoldLine.Size = [System.Drawing.Size]::new(20,1)
$sGoldLine.BackColor = $script:C_GoldD
$sHdrLbl = Lbl (T "s_install") $script:F.Cap $script:C_Tx2 42 9 180 14
RegI18n $sHdrLbl "s_install"
$sGoldLine2 = New-Object System.Windows.Forms.Panel
$sGoldLine2.Location = [System.Drawing.Point]::new(118,14)
$sGoldLine2.Size = [System.Drawing.Size]::new(160,1)
$sGoldLine2.BackColor = $script:C_Line
$sHdrPnl.Controls.AddRange(@($sGoldLine,$sHdrLbl,$sGoldLine2))
$Sidebar.Controls.Add($sHdrPnl)

$script:NavPanels     = @{}
$script:ContentPanels = @{}
$script:ActiveNavId   = "Home"

$script:NavItemsDef = @(
    @{Id="Steam";    Num="01"; Title="STEAM"}
    @{Id="EFT";      Num="02"; Title="ESCAPE FROM TARKOV"}
    @{Id="SPT";      Num="03"; Title="SPT SERVER"}
    @{Id="Fika";     Num="04"; Title="FIKA"}
    @{Id="Headless"; Num="05"; Title="HEADLESS CLIENT"}
    @{Id="Docker";   Num="06"; Title="DOCKER + WSL2"}
    @{Id="Firewall"; Num="07"; Title="FIREWALL"}
    @{Id="WebApp";   Num="08"; Title="FIKAWEBAPP"}
)

function ShowPanel($id) {
    if ([string]::IsNullOrEmpty($id)) { return }
    foreach ($k in $script:ContentPanels.Keys) { $script:ContentPanels[$k].Visible = $false }
    foreach ($k in $script:NavPanels.Keys) {
        $script:NavPanels[$k].BackColor = $script:C_Bg1
        if ($script:NavLeftBars.ContainsKey($k)) { $script:NavLeftBars[$k].BackColor = $script:C_Bg1 }
        if ($script:NavTxtLbls.ContainsKey($k))  { $script:NavTxtLbls[$k].ForeColor  = $script:C_Tx2 }
    }
    $script:ActiveNavId = $id
    if ($script:NavPanels.ContainsKey($id)) {
        $script:NavPanels[$id].BackColor = $script:C_BgActive
        if ($script:NavLeftBars.ContainsKey($id)) { $script:NavLeftBars[$id].BackColor = $script:C_Gold }
        if ($script:NavTxtLbls.ContainsKey($id))  { $script:NavTxtLbls[$id].ForeColor  = $script:C_Gold }
    }
    if ($script:ContentPanels.ContainsKey($id)) { $script:ContentPanels[$id].Visible = $true }
}

function Make-NavButton($id,$num,$title) {
    $cBg1=$script:C_Bg1; $cBg3=$script:C_Bg3
    $p = New-Object System.Windows.Forms.Panel
    $p.Size     = [System.Drawing.Size]::new($NAV_W, 42)
    $p.BackColor= $cBg1
    $p.Cursor   = [System.Windows.Forms.Cursors]::Hand
    $p.Margin   = [System.Windows.Forms.Padding]::new(0,0,0,1)
    $p.Tag      = $id
    $leftBar = New-Object System.Windows.Forms.Panel
    $leftBar.Location = [System.Drawing.Point]::new(0,0)
    $leftBar.Size     = [System.Drawing.Size]::new(2,42)
    $leftBar.BackColor= $cBg1; $leftBar.Tag=$id
    $badge = New-Object System.Windows.Forms.Label
    $badge.Size     = [System.Drawing.Size]::new(16,16)
    $badge.Location = [System.Drawing.Point]::new(12,13)
    $badge.Text     = $num
    $badge.Font     = $script:F.Cap
    $badge.ForeColor= $script:C_Tx2
    $badge.BackColor= $script:C_Bg3
    $badge.TextAlign= [System.Drawing.ContentAlignment]::MiddleCenter
    $badge.Tag      = $id
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = $title
    $lbl.Font      = $script:F.Nav
    $lbl.ForeColor = $script:C_Tx2
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.Location  = [System.Drawing.Point]::new(36,13)
    $lbl.Size      = [System.Drawing.Size]::new($NAV_W-50,16)
    $lbl.Tag       = $id
    $sq = New-Object System.Windows.Forms.Panel
    $sq.Size     = [System.Drawing.Size]::new(6,6)
    $sq.Location = [System.Drawing.Point]::new($NAV_W-16,18)
    $sq.BackColor= $script:C_Tx2; $sq.Tag=$id
    $p.Controls.AddRange(@($leftBar,$badge,$lbl,$sq))
    $script:Badges[$id]      = $sq
    $script:NavLeftBars[$id] = $leftBar
    $script:NavTxtLbls[$id]  = $lbl
    $cid   = $id
    $click = { ShowPanel $cid }.GetNewClosure()
    $pIn   = { param($s,$e) if($script:ActiveNavId -ne $s.Tag){$s.BackColor=$cBg3} }.GetNewClosure()
    $pOut  = { param($s,$e) if($script:ActiveNavId -ne $s.Tag){$s.BackColor=$cBg1} }.GetNewClosure()
    $cIn   = { param($s,$e) if($script:ActiveNavId -ne $s.Tag -and $s.Parent){$s.Parent.BackColor=$cBg3} }.GetNewClosure()
    $cOut  = { param($s,$e) if($script:ActiveNavId -ne $s.Tag -and $s.Parent){$s.Parent.BackColor=$cBg1} }.GetNewClosure()
    $p.Add_Click($click); $lbl.Add_Click($click); $badge.Add_Click($click)
    $p.Add_MouseEnter($pIn); $p.Add_MouseLeave($pOut)
    $lbl.Add_MouseEnter($cIn); $lbl.Add_MouseLeave($cOut)
    $badge.Add_MouseEnter($cIn); $badge.Add_MouseLeave($cOut)
    return $p
}

foreach ($ni in $script:NavItemsDef) {
    $nb = Make-NavButton $ni.Id $ni.Num (T "n_$($ni.Id)")
    $Sidebar.Controls.Add($nb)
    $script:NavPanels[$ni.Id] = $nb
}

$sDiv = New-Object System.Windows.Forms.Panel
$sDiv.Size = [System.Drawing.Size]::new($NAV_W,1)
$sDiv.BackColor = $script:C_Line
$sDiv.Margin = [System.Windows.Forms.Padding]::new(0,10,0,6)
$Sidebar.Controls.Add($sDiv)

# ALLE INSTALLIEREN
$AllBtn = New-Object System.Windows.Forms.Panel
$AllBtn.Size = [System.Drawing.Size]::new($NAV_W,40)
$AllBtn.BackColor = rgb 16 12 4
$AllBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$AllBtn.Margin = [System.Windows.Forms.Padding]::new(0,1,0,1)
$allLeftBar = New-Object System.Windows.Forms.Panel
$allLeftBar.Location=[System.Drawing.Point]::new(0,0)
$allLeftBar.Size=[System.Drawing.Size]::new(2,40)
$allLeftBar.BackColor=$script:C_GoldD
$allLbl = Lbl (T "s_all") $script:F.Nav $script:C_Gold 14 12 ($NAV_W-18) 16
RegI18n $allLbl "s_all"
$AllBtn.Controls.AddRange(@($allLeftBar,$allLbl))
$AllBtn.Add_MouseEnter({ $script:AllBtn.BackColor=rgb 24 18 6 })
$AllBtn.Add_MouseLeave({ $script:AllBtn.BackColor=rgb 16 12 4 })
$AllBtn.Add_Click({ StartOpAll })
$allLbl.Add_Click({ StartOpAll })
$script:AllBtn = $AllBtn
$Sidebar.Controls.Add($AllBtn)

# STATUS PRUEFEN
$ChkBtn = New-Object System.Windows.Forms.Panel
$ChkBtn.Size = [System.Drawing.Size]::new($NAV_W,40)
$ChkBtn.BackColor = rgb 6 14 8
$ChkBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$ChkBtn.Margin = [System.Windows.Forms.Padding]::new(0,1,0,1)
$chkLeftBar = New-Object System.Windows.Forms.Panel
$chkLeftBar.Location=[System.Drawing.Point]::new(0,0)
$chkLeftBar.Size=[System.Drawing.Size]::new(2,40)
$chkLeftBar.BackColor=$script:C_Green
$chkLbl = Lbl (T "s_check") $script:F.Nav $script:C_GreenL 14 12 ($NAV_W-18) 16
RegI18n $chkLbl "s_check"
$ChkBtn.Controls.AddRange(@($chkLeftBar,$chkLbl))
$ChkBtn.Add_MouseEnter({ $script:ChkBtn.BackColor=rgb 10 20 12 })
$ChkBtn.Add_MouseLeave({ $script:ChkBtn.BackColor=rgb  6 14  8 })
$ChkBtn.Add_Click({ RunBG { Op-CheckAll } })
$chkLbl.Add_Click({ RunBG { Op-CheckAll } })
$script:ChkBtn = $ChkBtn
$Sidebar.Controls.Add($ChkBtn)

# EINSTELLUNGEN
$SetBtn = New-Object System.Windows.Forms.Panel
$SetBtn.Size = [System.Drawing.Size]::new($NAV_W,40)
$SetBtn.BackColor = $script:C_Bg1
$SetBtn.Cursor = [System.Windows.Forms.Cursors]::Hand
$SetBtn.Margin = [System.Windows.Forms.Padding]::new(0,1,0,1)
$SetBtn.Tag = "Settings"
$setLeftBar = New-Object System.Windows.Forms.Panel
$setLeftBar.Location=[System.Drawing.Point]::new(0,0)
$setLeftBar.Size=[System.Drawing.Size]::new(2,40)
$setLeftBar.BackColor=$script:C_Bg1; $setLeftBar.Tag="Settings"
$setLbl = Lbl (T "s_settings") $script:F.Nav $script:C_Tx2 14 12 ($NAV_W-18) 16
$setLbl.Tag="Settings"
$SetBtn.Controls.AddRange(@($setLeftBar,$setLbl))
$script:NavLeftBars["Settings"] = $setLeftBar
$script:NavTxtLbls["Settings"]  = $setLbl
$SetBtn.Add_MouseEnter({
    if ($script:ActiveNavId -ne "Settings") { $script:SetBtn.BackColor=$script:C_Bg3 }
})
$SetBtn.Add_MouseLeave({
    if ($script:ActiveNavId -ne "Settings") { $script:SetBtn.BackColor=$script:C_Bg1 }
})
$SetBtn.Add_Click({ ShowPanel "Settings" })
$setLbl.Add_Click({ ShowPanel "Settings" })
$script:SetBtn = $SetBtn
$script:NavPanels["Settings"] = $SetBtn
$Sidebar.Controls.Add($SetBtn)

# SPRACHE
$sDiv2 = New-Object System.Windows.Forms.Panel
$sDiv2.Size = [System.Drawing.Size]::new($NAV_W,1)
$sDiv2.BackColor = $script:C_Line
$sDiv2.Margin = [System.Windows.Forms.Padding]::new(0,8,0,0)
$Sidebar.Controls.Add($sDiv2)

$LangPnl = New-Object System.Windows.Forms.Panel
$LangPnl.Size = [System.Drawing.Size]::new($NAV_W, 44)
$LangPnl.BackColor = $script:C_Bg1
$LangPnl.Margin = [System.Windows.Forms.Padding]::new(0,0,0,0)
$lpLbl = Lbl (T "lang_label") $script:F.Cap $script:C_Tx2 14 15 80 14
RegI18n $lpLbl "lang_label"
$script:LangBtnDE = New-Object System.Windows.Forms.Button
$script:LangBtnDE.Text       = "DE"
$script:LangBtnDE.Location   = [System.Drawing.Point]::new(144, 10)
$script:LangBtnDE.Size       = [System.Drawing.Size]::new(68, 24)
$script:LangBtnDE.Font       = $script:F.Nav
$script:LangBtnDE.FlatStyle  = [System.Windows.Forms.FlatStyle]::Flat
$script:LangBtnDE.Cursor     = [System.Windows.Forms.Cursors]::Hand
$script:LangBtnDE.BackColor  = rgb 16 12 4
$script:LangBtnDE.ForeColor  = $script:C_Gold
$script:LangBtnDE.FlatAppearance.BorderSize  = 1
$script:LangBtnDE.FlatAppearance.BorderColor = $script:C_GoldD
$script:LangBtnDE.FlatAppearance.MouseOverBackColor = rgb 28 22 8
$script:LangBtnDE.Add_Click({ Set-Language "DE" })
$script:LangBtnEN = New-Object System.Windows.Forms.Button
$script:LangBtnEN.Text       = "EN"
$script:LangBtnEN.Location   = [System.Drawing.Point]::new(216, 10)
$script:LangBtnEN.Size       = [System.Drawing.Size]::new(68, 24)
$script:LangBtnEN.Font       = $script:F.Nav
$script:LangBtnEN.FlatStyle  = [System.Windows.Forms.FlatStyle]::Flat
$script:LangBtnEN.Cursor     = [System.Windows.Forms.Cursors]::Hand
$script:LangBtnEN.BackColor  = $script:C_Bg2
$script:LangBtnEN.ForeColor  = $script:C_Tx2
$script:LangBtnEN.FlatAppearance.BorderSize  = 1
$script:LangBtnEN.FlatAppearance.BorderColor = $script:C_Line
$script:LangBtnEN.FlatAppearance.MouseOverBackColor = $script:C_Bg3
$script:LangBtnEN.Add_Click({ Set-Language "EN" })
$LangPnl.Controls.AddRange(@($lpLbl,$script:LangBtnDE,$script:LangBtnEN))
$Sidebar.Controls.Add($LangPnl)

$MainSplit.Panel1.Controls.Add($Sidebar)

#  CONTENT PANELS
function NewCP {
    $p = New-Object System.Windows.Forms.Panel
    $p.Dock = [System.Windows.Forms.DockStyle]::Fill
    $p.BackColor = $script:C_Bg0
    $p.Padding = [System.Windows.Forms.Padding]::new(36,28,36,20)
    $p.Visible = $false; $p.AutoScroll = $true
    return $p
}

function SectionHdr($text,$y=0,$w=700) {
    $ph = New-Object System.Windows.Forms.Panel
    $ph.Location = [System.Drawing.Point]::new(0,$y)
    $ph.Size = [System.Drawing.Size]::new($w,30)
    $ph.BackColor = [System.Drawing.Color]::Transparent
    $gl = New-Object System.Windows.Forms.Panel
    $gl.Location = [System.Drawing.Point]::new(0,14)
    $gl.Size = [System.Drawing.Size]::new($w,1)
    $gl.BackColor = $script:C_Line
    $tl = Lbl " $text " $script:F.Cap $script:C_GoldD 0 4 240 16
    $tl.BackColor = $script:C_Bg0
    $ph.Controls.AddRange(@($gl,$tl))
    return $ph
}

function SectionHdrI18n($key,$y=0,$w=700) {
    $ph = SectionHdr (T $key) $y $w
    $tl = $ph.Controls | Where-Object { $_ -is [System.Windows.Forms.Label] } | Select-Object -First 1
    if ($tl) { RegI18n $tl $key -Sec }
    return $ph
}

#  HOME PANEL
$pHome = NewCP; $pHome.Visible = $true
$pHome.Controls.Add((Lbl "FIKA-SERVER SETUP UTILITY" $script:F.H1 $script:C_Gold 0 0 700 32))
$hSubLbl = Lbl (T "h_sub") $script:F.Bd $script:C_Tx1 0 40 760 20
RegI18n $hSubLbl "h_sub"
$pHome.Controls.Add($hSubLbl)
$pHome.Controls.Add((SectionHdrI18n "h_steps" 72 660))
$hy = 112
foreach ($ni in $script:NavItemsDef) {
    $row = New-Object System.Windows.Forms.Panel
    $row.Location = [System.Drawing.Point]::new(0,$hy)
    $row.Size = [System.Drawing.Size]::new(640,28)
    $row.BackColor = $script:C_Bg2
    $numLbl = Lbl $ni.Num $script:F.Cap $script:C_GoldD 10 7 24 14
    $namLbl = Lbl (T "n_$($ni.Id)") $script:F.Nav $script:C_Tx0 38 7 560 14
    $script:HomeStepLabels[$ni.Id] = $namLbl
    $leftAccent = New-Object System.Windows.Forms.Panel
    $leftAccent.Location=[System.Drawing.Point]::new(0,0)
    $leftAccent.Size=[System.Drawing.Size]::new(2,28)
    $leftAccent.BackColor=$script:C_Tx2
    $row.Controls.AddRange(@($numLbl,$namLbl,$leftAccent))
    $pHome.Controls.Add($row)
    $hy += 30
}
$hy += 16
$bHomeAll = Btn (T "h_all") 0 $hy 260 38
RegI18n $bHomeAll "h_all"
$bHomeAll.Add_Click({ StartOpAll })
$pHome.Controls.Add($bHomeAll)
$script:ContentPanels["Home"] = $pHome
$RightSplit.Panel1.Controls.Add($pHome)

#  STEAM PANEL

$pSteam = NewCP
$pSteam.Controls.Add((Lbl "STEAM" $script:F.H1 $script:C_Gold 0 0 400 32))
$pSteam.Controls.Add((MakeStatusCard "Steam" 0 44 640 50))
$pSteam.Controls.Add((SectionHdrI18n "sec_action" 108 640))
$stDescLbl = Lbl (T "st_desc") $script:F.Bd $script:C_Tx1 0 146 720 20
RegI18n $stDescLbl "st_desc"
$pSteam.Controls.Add($stDescLbl)
$bSteam = Btn (T "btn_install") 0 180 200 36
RegI18n $bSteam "btn_install"
$bSteam.Add_Click({ RunBG { Op-Steam } })
$pSteam.Controls.Add($bSteam)
$script:ContentPanels["Steam"] = $pSteam
$RightSplit.Panel1.Controls.Add($pSteam)

#  EFT PANEL
$pEFT = NewCP
$pEFT.Controls.Add((Lbl "ESCAPE FROM TARKOV" $script:F.H1 $script:C_Gold 0 0 700 32))
$pEFT.Controls.Add((MakeStatusCard "EFT" 0 44 640 50))
$pEFT.Controls.Add((SectionHdrI18n "e_sec" 108 640))
$eNoteLbl = Lbl (T "e_note") $script:F.Sm $script:C_Tx2 0 144 760 16
RegI18n $eNoteLbl "e_note"
$pEFT.Controls.Add($eNoteLbl)

# BSG CARD
$c1 = New-Object System.Windows.Forms.Panel
$c1.Location=[System.Drawing.Point]::new(0,168)
$c1.Size=[System.Drawing.Size]::new(640,60)
$c1.BackColor=$script:C_Bg2
$c1lBar=New-Object System.Windows.Forms.Panel
$c1lBar.Location=[System.Drawing.Point]::new(0,0)
$c1lBar.Size=[System.Drawing.Size]::new(2,60)
$c1lBar.BackColor=$script:C_GoldD
$c1.Controls.Add($c1lBar)
$c1T = Lbl (T "e_bsg_t") $script:F.H3 $script:C_Tx0 14 10 440 18; RegI18n $c1T "e_bsg_t"
$c1S = Lbl (T "e_bsg_s") $script:F.Sm $script:C_Tx2 14 30 440 16; RegI18n $c1S "e_bsg_s"
$bBSG = Btn (T "btn_install") 468 12 160 34; RegI18n $bBSG "btn_install"
$bBSG.Add_Click({ RunBG { Op-EFT-BSG } })
$c1.Controls.AddRange(@($c1T,$c1S,$bBSG))

# STEAM CARD
$c2 = New-Object System.Windows.Forms.Panel
$c2.Location=[System.Drawing.Point]::new(0,234)
$c2.Size=[System.Drawing.Size]::new(640,60)
$c2.BackColor=$script:C_Bg2
$c2lBar=New-Object System.Windows.Forms.Panel
$c2lBar.Location=[System.Drawing.Point]::new(0,0)
$c2lBar.Size=[System.Drawing.Size]::new(2,60)
$c2lBar.BackColor=$script:C_GoldD
$c2.Controls.Add($c2lBar)
$c2T = Lbl (T "e_st_t") $script:F.H3 $script:C_Tx0 14 10 440 18; RegI18n $c2T "e_st_t"
$c2S = Lbl (T "e_st_s") $script:F.Sm $script:C_Tx2 14 30 440 16; RegI18n $c2S "e_st_s"
$bESteam = Btn (T "btn_vsteam") 468 12 160 34; RegI18n $bESteam "btn_vsteam"
$bESteam.Add_Click({ RunBG { Op-EFT-Steam } })
$c2.Controls.AddRange(@($c2T,$c2S,$bESteam))

$pEFT.Controls.AddRange(@($c1,$c2))
$script:ContentPanels["EFT"] = $pEFT
$RightSplit.Panel1.Controls.Add($pEFT)

#  SPT PANEL
$pSPT = NewCP
$pSPT.Controls.Add((Lbl "SPT SERVER" $script:F.H1 $script:C_Gold 0 0 500 32))
$pSPT.Controls.Add((MakeStatusCard "SPT" 0 44 640 50))
$pSPT.Controls.Add((SectionHdrI18n "sec_action" 108 640))
$sptDescLbl = Lbl (T "spt_desc") $script:F.Bd $script:C_Tx1 0 146 760 20; RegI18n $sptDescLbl "spt_desc"
$sptNoteLbl = Lbl (T "spt_note") $script:F.Sm $script:C_AmberL 0 170 720 16; RegI18n $sptNoteLbl "spt_note"
$pSPT.Controls.AddRange(@($sptDescLbl,$sptNoteLbl))
$bSPT = Btn (T "btn_install") 0 202 200 36; RegI18n $bSPT "btn_install"
$bSPT.Add_Click({ RunBG { Op-SPT } })
$pSPT.Controls.Add($bSPT)
$script:ContentPanels["SPT"] = $pSPT
$RightSplit.Panel1.Controls.Add($pSPT)

#  FIKA PANEL
$pFika = NewCP
$pFika.Controls.Add((Lbl "FIKA" $script:F.H1 $script:C_Gold 0 0 400 32))
$pFika.Controls.Add((MakeStatusCard "Fika" 0 44 640 50))
$pFika.Controls.Add((SectionHdrI18n "sec_action" 108 640))
$fikaDescLbl = Lbl (T "fika_desc") $script:F.Bd $script:C_Tx1 0 146 720 20; RegI18n $fikaDescLbl "fika_desc"
$fikaNoteLbl = Lbl (T "fika_note") $script:F.Sm $script:C_AmberL 0 170 750 16; RegI18n $fikaNoteLbl "fika_note"
$pFika.Controls.AddRange(@($fikaDescLbl,$fikaNoteLbl))
$bFika = Btn (T "btn_install") 0 202 200 36; RegI18n $bFika "btn_install"
$bFika.Add_Click({ RunBG { Op-Fika } })
$pFika.Controls.Add($bFika)
$script:ContentPanels["Fika"] = $pFika
$RightSplit.Panel1.Controls.Add($pFika)

#  HEADLESS PANEL
$pHL = NewCP
$pHL.Controls.Add((Lbl "HEADLESS CLIENT" $script:F.H1 $script:C_Gold 0 0 600 32))
$pHL.Controls.Add((MakeStatusCard "Headless" 0 44 640 50))
$pHL.Controls.Add((SectionHdrI18n "sec_action" 108 640))
$hlDescLbl = Lbl (T "hl_desc") $script:F.Bd $script:C_Tx1 0 146 760 20; RegI18n $hlDescLbl "hl_desc"
$pHL.Controls.Add($hlDescLbl)
$bHL = Btn (T "btn_install") 0 182 200 36; RegI18n $bHL "btn_install"
$bHL.Add_Click({ RunBG { Op-Headless } })
$pHL.Controls.Add($bHL)
$script:ContentPanels["Headless"] = $pHL
$RightSplit.Panel1.Controls.Add($pHL)

#  DOCKER PANEL
$pDocker = NewCP
$pDocker.Controls.Add((Lbl "DOCKER + WSL2" $script:F.H1 $script:C_Gold 0 0 600 32))
$pDocker.Controls.Add((MakeStatusCard "Docker" 0 44 640 50))
$pDocker.Controls.Add((SectionHdrI18n "sec_action" 108 640))
$dkDescLbl = Lbl (T "dk_desc") $script:F.Bd $script:C_Tx1 0 146 720 20; RegI18n $dkDescLbl "dk_desc"
$dkNoteLbl = Lbl (T "dk_note") $script:F.H3 $script:C_AmberL 0 172 720 20; RegI18n $dkNoteLbl "dk_note"
$pDocker.Controls.AddRange(@($dkDescLbl,$dkNoteLbl))
$bDocker = Btn (T "btn_install") 0 208 200 36; RegI18n $bDocker "btn_install"
$bDocker.Add_Click({ RunBG { Op-Docker } })
$pDocker.Controls.Add($bDocker)
$script:ContentPanels["Docker"] = $pDocker
$RightSplit.Panel1.Controls.Add($pDocker)

#  FIREWALL PANEL
$pFW = NewCP
$pFW.Controls.Add((Lbl "FIREWALL" $script:F.H1 $script:C_Gold 0 0 500 32))
$pFW.Controls.Add((MakeStatusCard "Firewall" 0 44 640 50))
$pFW.Controls.Add((SectionHdrI18n "fw_sec" 108 640))

$portDefs = @(
    @{ Port=6969;  Proto="TCP"; Key="fw_p1" }
    @{ Port=6969;  Proto="UDP"; Key="fw_p2" }
    @{ Port=25565; Proto="UDP"; Key="fw_p3" }
    @{ Port=8080;  Proto="TCP"; Key="fw_p4" }
    @{ Port=5000;  Proto="TCP"; Key="fw_p5" }
)
$fy = 148
foreach ($pd in $portDefs) {
    $portVal  = $pd.Port
    $protoVal = $pd.Proto
    $nameKey  = $pd.Key
    $fwRowKey = "$portVal-$protoVal"
    $row = New-Object System.Windows.Forms.Panel
    $row.Location = [System.Drawing.Point]::new(0,$fy)
    $row.Size = [System.Drawing.Size]::new(640,28)
    $row.BackColor = $script:C_Bg2
    $stBar = New-Object System.Windows.Forms.Panel
    $stBar.Location=[System.Drawing.Point]::new(0,0); $stBar.Size=[System.Drawing.Size]::new(2,28)
    $stBar.BackColor=$script:C_Tx2; $row.Controls.Add($stBar)
    $stLbl = New-Object System.Windows.Forms.Label
    $stLbl.Location=[System.Drawing.Point]::new(8,7); $stLbl.Size=[System.Drawing.Size]::new(12,14)
    $stLbl.Text="x"; $stLbl.Font=$script:F.Cap; $stLbl.ForeColor=$script:C_Tx2
    $stLbl.BackColor=[System.Drawing.Color]::Transparent
    $stLbl.TextAlign=[System.Drawing.ContentAlignment]::MiddleCenter
    $row.Controls.Add($stLbl)
    $portLbl  = Lbl "$portVal"    $script:F.Mn2 $script:C_Gold  26  7 54 14
    $protoLbl = Lbl "$protoVal"   $script:F.Cap $script:C_Tx2   86  8 32 12
    $nameLbl  = Lbl (T $nameKey)  $script:F.Sm  $script:C_Tx1  128  7 400 14
    RegI18n $nameLbl $nameKey
    $row.Controls.AddRange(@($portLbl,$protoLbl,$nameLbl))
    $pFW.Controls.Add($row)
    $script:FWPortLabels[$fwRowKey] = $stLbl
    $fy += 30
}
$bFW = Btn (T "btn_ports") 0 ($fy+14) 240 36; RegI18n $bFW "btn_ports"
$bFW.Add_Click({ RunBG { Op-Firewall } })
$pFW.Controls.Add($bFW)
$script:ContentPanels["Firewall"] = $pFW
$RightSplit.Panel1.Controls.Add($pFW)

#  WEBAPP PANEL
$pWA = NewCP
$pWA.Controls.Add((Lbl "FIKAWEBAPP" $script:F.H1 $script:C_Gold 0 0 500 32))
$pWA.Controls.Add((MakeStatusCard "WebApp" 0 44 640 50))
$pWA.Controls.Add((SectionHdrI18n "wa_sec" 108 640))
$waDescLbl = Lbl (T "wa_desc") $script:F.Bd $script:C_Tx1 0 146 720 20; RegI18n $waDescLbl "wa_desc"
$waApiLbl  = Lbl (T "wa_api")  $script:F.Cap $script:C_Tx2 0 174 640 14; RegI18n $waApiLbl "wa_api"
$pWA.Controls.AddRange(@($waDescLbl,$waApiLbl))
$tbApiKey = TBox $script:Cfg.ApiKey 0 192 460 26
$tbApiKey.Add_TextChanged({ $script:Cfg.ApiKey=$script:tbApiKey.Text })
$waNtLbl = Lbl (T "wa_note") $script:F.Sm $script:C_AmberL 0 226 680 16; RegI18n $waNtLbl "wa_note"
$pWA.Controls.Add($waNtLbl)
$bWA = Btn (T "btn_wa") 0 254 220 36; RegI18n $bWA "btn_wa"
$bWA.Add_Click({
    $script:Cfg.ApiKey=$script:tbApiKey.Text
    RunBG { Op-WebApp }
})
$script:tbApiKey = $tbApiKey
$pWA.Controls.AddRange(@($tbApiKey,$bWA))
$script:ContentPanels["WebApp"] = $pWA
$RightSplit.Panel1.Controls.Add($pWA)

#  SETTINGS PANEL
$pSet = NewCP
$pSetTitleLbl = Lbl (T "set_title") $script:F.H1 $script:C_Gold 0 0 500 32
RegI18n $pSetTitleLbl "set_title"
$pSet.Controls.Add($pSetTitleLbl)
$pSet.Controls.Add((SectionHdrI18n "set_spt_h" 46 640))
$setSptDescLbl = Lbl (T "set_spt_d") $script:F.Sm $script:C_Tx2 0 82 720 16
RegI18n $setSptDescLbl "set_spt_d"
$pSet.Controls.Add($setSptDescLbl)
$tbSetSPT = TBox $script:Cfg.SptDir 0 102 400 26
$bBrowse = Btn (T "btn_browse") 408 102 160 26 $false; RegI18n $bBrowse "btn_browse"
$bBrowse.Add_Click({
    $fbd=New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = T "fbr_spt"
    $fbd.ShowNewFolderButton=$false
    if (-not [string]::IsNullOrWhiteSpace($script:tbSetSPT.Text) -and
        (Test-Path $script:tbSetSPT.Text -ErrorAction SilentlyContinue)) {
        $fbd.SelectedPath=$script:tbSetSPT.Text
    }
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:tbSetSPT.Text=$fbd.SelectedPath
        $sptExe=Join-Path $fbd.SelectedPath "SPT.Server.exe"
        if (Test-Path $sptExe -ErrorAction SilentlyContinue) {
            Log "SPT.Server.exe confirmed: $($fbd.SelectedPath)" "O"
        } else {
            Log "Warning: SPT.Server.exe NOT found in this folder." "W"
        }
    }
})
$pSet.Controls.Add((SectionHdrI18n "set_eft_h" 138 640))
$setEftDescLbl = Lbl (T "set_eft_d") $script:F.Sm $script:C_Tx2 0 170 720 16
RegI18n $setEftDescLbl "set_eft_d"
$pSet.Controls.Add($setEftDescLbl)
$tbSetEFT = TBox $script:Cfg.EftDir 0 190 400 26
$bBrowseEFT = Btn (T "btn_browse") 408 190 160 26 $false; RegI18n $bBrowseEFT "btn_browse"
$bBrowseEFT.Add_Click({
    $fbd=New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = T "fbr_eft"
    $fbd.ShowNewFolderButton=$false
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:tbSetEFT.Text=$fbd.SelectedPath
        $exeB=Join-Path $fbd.SelectedPath "build\EscapeFromTarkov.exe"
        $exeR=Join-Path $fbd.SelectedPath "EscapeFromTarkov.exe"
        if ((Test-Path $exeB -ErrorAction SilentlyContinue) -or
            (Test-Path $exeR -ErrorAction SilentlyContinue)) {
            Log "EscapeFromTarkov.exe confirmed: $($fbd.SelectedPath)" "O"
        } else {
            Log "Warning: EscapeFromTarkov.exe not found." "W"
        }
    }
})
$pSet.Controls.Add((SectionHdrI18n "set_api_h" 226 640))
$tbSetAPI = TBox $script:Cfg.ApiKey 0 258 460 26
$script:tbSetSPT=$tbSetSPT; $script:tbSetEFT=$tbSetEFT; $script:tbSetAPI=$tbSetAPI
$bSave = Btn (T "btn_save") 0 300 180 36; RegI18n $bSave "btn_save"
$bSave.Add_Click({
    $script:Cfg.SptDir=$script:tbSetSPT.Text
    $script:Cfg.EftDir=$script:tbSetEFT.Text
    $script:Cfg.ApiKey=$script:tbSetAPI.Text
    Log "Settings saved. SPT: $($script:Cfg.SptDir)" "O"
})
$bRescan = Btn (T "btn_recheck") 196 300 220 36 $false; RegI18n $bRescan "btn_recheck"
$bRescan.Add_Click({ RunBG { Op-CheckAll } })
$pSet.Controls.AddRange(@($tbSetSPT,$bBrowse,$tbSetEFT,$bBrowseEFT,$tbSetAPI,$bSave,$bRescan))
$script:ContentPanels["Settings"]=$pSet
$RightSplit.Panel1.Controls.Add($pSet)

#  LOG PANEL
$LogHeader = New-Object System.Windows.Forms.Panel
$LogHeader.Dock = [System.Windows.Forms.DockStyle]::Top
$LogHeader.Height = 28; $LogHeader.BackColor = $script:C_Bg1
$lhLine = New-Object System.Windows.Forms.Panel
$lhLine.Dock=[System.Windows.Forms.DockStyle]::Bottom
$lhLine.Height=1; $lhLine.BackColor=$script:C_LineHL
$LogHeader.Controls.Add($lhLine)
$lhLeftBar = New-Object System.Windows.Forms.Panel
$lhLeftBar.Location=[System.Drawing.Point]::new(0,0)
$lhLeftBar.Size=[System.Drawing.Size]::new(2,28)
$lhLeftBar.BackColor=$script:C_GoldD
$LogHeader.Controls.Add($lhLeftBar)
$lhTitleLbl = Lbl (T "log_hdr") $script:F.Cap $script:C_Tx2 6 8 300 14
RegI18n $lhTitleLbl "log_hdr"
$LogHeader.Controls.Add($lhTitleLbl)
$bClearLog = Btn (T "btn_clear") 0 4 72 20 $false
RegI18n $bClearLog "btn_clear"
$bClearLog.Dock = [System.Windows.Forms.DockStyle]::Right
$bClearLog.Font = $script:F.Cap
$bClearLog.Add_Click({ $script:LogRTB.Clear() })
$LogHeader.Controls.Add($bClearLog)

$script:LogRTB = New-Object System.Windows.Forms.RichTextBox
$script:LogRTB.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:LogRTB.BackColor = $script:C_Bg1
$script:LogRTB.ForeColor = $script:C_Tx0
$script:LogRTB.Font = $script:F.Mn2
$script:LogRTB.ReadOnly = $true
$script:LogRTB.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$script:LogRTB.Padding = [System.Windows.Forms.Padding]::new(8,4,8,4)
$RightSplit.Panel2.Controls.AddRange(@($script:LogRTB,$LogHeader))

#  UI TIMER
$script:UITimer = New-Object System.Windows.Forms.Timer
$script:UITimer.Interval = 80
$script:UITimer.Add_Tick({
    $item = $null
    while ($script:LogQueue.TryDequeue([ref]$item)) {
        if ($item.Txt -like '__SPTDIR__:*') {
            $nd=$item.Txt.Substring(11)
            if ($script:tbSetSPT -and $script:tbSetSPT.IsHandleCreated) {
                $script:tbSetSPT.Text=$nd
            }
            continue
        }
        if ($item.Txt -like '__EFTDIR__:*') {
            $nd=$item.Txt.Substring(11)
            if ($script:tbSetEFT -and $script:tbSetEFT.IsHandleCreated) {
                $script:tbSetEFT.Text=$nd
            }
            continue
        }
        if ($item.Txt -like '__APIKEY__:*') {
            $nk=$item.Txt.Substring(11)
            if ($script:tbApiKey -and $script:tbApiKey.IsHandleCreated) {
                $script:tbApiKey.Text=$nk
            }
            if ($script:tbSetAPI -and $script:tbSetAPI.IsHandleCreated) {
                $script:tbSetAPI.Text=$nk
            }
            continue
        }
        if ($item.Txt -like '__FWPORT__:*') {
            $raw=$item.Txt.Substring(11)
            $pts=$raw -split '\|'
            if ($pts.Count -ge 3) {
                $fwKey="$($pts[0])-$($pts[1])"
                if ($script:FWPortLabels.ContainsKey($fwKey) -and
                    $script:FWPortLabels[$fwKey].IsHandleCreated) {
                    $fwLbl=$script:FWPortLabels[$fwKey]
                    if ($pts[2] -eq 'v') {
                        $fwLbl.Text="v"; $fwLbl.ForeColor=$script:C_GreenL
                    } else {
                        $fwLbl.Text="x"; $fwLbl.ForeColor=$script:C_RedL
                    }
                }
            }
            continue
        }
        if ($script:LogRTB -and $script:LogRTB.IsHandleCreated) {
            $script:LogRTB.SelectionStart=$script:LogRTB.TextLength
            $script:LogRTB.SelectionLength=0
            $script:LogRTB.SelectionColor=$item.Col
            $script:LogRTB.AppendText("$($item.Txt)`n")
            $script:LogRTB.ScrollToCaret()
        }
    }

    $bItem = $null
    while ($script:BadgeQueue.TryDequeue([ref]$bItem)) {
        if (-not $script:Badges.ContainsKey($bItem.Id)) { continue }
        $sq = $script:Badges[$bItem.Id]
        if (-not $sq -or -not $sq.IsHandleCreated) { continue }
        switch ($bItem.State) {
            0 { $sq.BackColor=$script:C_Tx2   }
            1 { $sq.BackColor=$script:C_Gold  }
            2 { $sq.BackColor=$script:C_Green }
            3 { $sq.BackColor=$script:C_Red   }
            4 { $sq.BackColor=$script:C_Amber }
        }
        $sq.Invalidate()
    }

    $sItem = $null
    while ($script:StatusQueue.TryDequeue([ref]$sItem)) {
        if (-not $script:StatusLabels.ContainsKey($sItem.Id)) { continue }
        $sl = $script:StatusLabels[$sItem.Id]
        if (-not $sl.Panel.IsHandleCreated) { continue }
        switch ($sItem.State) {
            0 {
                $sl.Strip.BackColor=$script:C_Tx2; $sl.Panel.BackColor=$script:C_Bg2
                $sl.Icon.ForeColor=$script:C_Tx2; $sl.Icon.Text="x"; $sl.Label.ForeColor=$script:C_Tx1
            }
            1 {
                $sl.Strip.BackColor=$script:C_Gold; $sl.Panel.BackColor=$script:C_GoldBg
                $sl.Icon.ForeColor=$script:C_Gold; $sl.Icon.Text=">"; $sl.Label.ForeColor=$script:C_Gold
            }
            2 {
                $sl.Strip.BackColor=$script:C_Green; $sl.Panel.BackColor=$script:C_GreenBg
                $sl.Icon.ForeColor=$script:C_GreenL; $sl.Icon.Text="v"; $sl.Label.ForeColor=$script:C_Tx0
            }
            3 {
                $sl.Strip.BackColor=$script:C_Red; $sl.Panel.BackColor=$script:C_RedBg
                $sl.Icon.ForeColor=$script:C_RedL; $sl.Icon.Text="x"; $sl.Label.ForeColor=$script:C_Tx1
            }
            4 {
                $sl.Strip.BackColor=$script:C_Amber; $sl.Panel.BackColor=$script:C_AmberBg
                $sl.Icon.ForeColor=$script:C_AmberL; $sl.Icon.Text="i"; $sl.Label.ForeColor=$script:C_AmberL
            }
        }
        $sl.Label.Text=$sItem.Msg
        $sl.Panel.Invalidate(); $sl.Strip.Invalidate()
        $sl.Icon.Invalidate(); $sl.Label.Invalidate()
    }
})

$script:CompletionTimer = New-Object System.Windows.Forms.Timer
$script:CompletionTimer.Interval = 300
$script:CompletionTimer.Add_Tick({
    if (-not $script:Cfg.Busy)             { return }
    if (-not $script:BgHandle)             { return }
    if (-not $script:BgHandle.IsCompleted) { return }
    try {
        $script:BgPS.EndInvoke($script:BgHandle)
        if ($script:BgPS.HadErrors) {
            foreach ($e2 in $script:BgPS.Streams.Error) {
                $ts2=Get-Date -Format "HH:mm:ss"
                $null=$script:LogQueue.Enqueue([PSCustomObject]@{
                    Txt="[$ts2] [ERR] $e2"
                    Col=[System.Drawing.Color]::FromArgb(188,80,80)
                })
            }
        }
    } catch {
        $ts2=Get-Date -Format "HH:mm:ss"
        $null=$script:LogQueue.Enqueue([PSCustomObject]@{
            Txt="[$ts2] [ERR] EndInvoke: $_"
            Col=[System.Drawing.Color]::FromArgb(188,80,80)
        })
    } finally {
        try { $script:BgPS.Dispose() } catch {}
        try { $script:BgRS.Close()   } catch {}
        try { $script:BgRS.Dispose() } catch {}
        $script:BgPS=$null; $script:BgHandle=$null; $script:BgRS=$null
        $script:Cfg.Busy=$false
    }
})

#  START
$MainSplit.Panel2.Controls.Add($RightSplit)
$script:MainForm.Controls.AddRange(@($StatusBar,$MainSplit,$Header))

$script:MainForm.Add_Shown({
    $script:MainSplit.SplitterDistance = 310
    $script:MainForm.Refresh()
    try {
        [UxThemeHelper]::SetWindowTheme($script:LogRTB.Handle, "DarkMode_Explorer", $null) | Out-Null
    } catch {}
    RunBG { Op-CheckAll }
})

ShowPanel "Home"
Log (T "log_started")   "O"
Log (T "log_autocheck") "S"

$script:UITimer.Start()
$script:CompletionTimer.Start()
[System.Windows.Forms.Application]::Run($script:MainForm)
$script:UITimer.Stop()
$script:CompletionTimer.Stop()