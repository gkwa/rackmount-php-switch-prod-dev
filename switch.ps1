<#

# usage: set for test:
powershell.exe -executionpolicy bypass -noninteractive -noprofile -noninteractive -command "& $([scriptblock]::Create((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/TaylorMonacelli/rackmount-php-switch-prod-dev/master/switch.ps1')))"

# usage: reset back to production:
powershell.exe -executionpolicy bypass -noninteractive -noprofile -noninteractive -command "& $([scriptblock]::Create((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/TaylorMonacelli/rackmount-php-switch-prod-dev/master/switch.ps1'))) -prod"
./switch.ps1 -prod

# testing
New-Item -Force -ItemType SymbolicLink -Name logs -Target $env:systemdrive/Apache/logs
New-Item -Force -ItemType SymbolicLink -Name conf -Target $env:systemdrive/Apache/conf
New-Item -Force -ItemType SymbolicLink -Name php.ini -Target $env:systemdrive/php/php.ini

function reset { Copy-Item C:\php\php.ini.02-23-2017_20_22_02.ini c:/php/php.ini -Force; }
function doit { Copy-Item //tsclient/rackmount-php-switch-prod-dev/switch.ps1 .; ./switch.ps1; }
reset; doit

Import-Module "$env:ChocolateyInstall\helpers\chocolateyInstaller.psm1" -Force
$glob = "${env:SYSTEMDRIVE}\Program*\Perforce\p4merge.exe"
$fpath = Get-ChildItem $glob -ea 0 | Select-Object -Last 1 | Select-Object -exp fullname
Install-Binfile -Name p4merge -Path "$fpath"

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)] [switch]$prod = $false
)

function restart_httpd {
	Get-WmiObject win32_service |
	  Where-Object {
		  $_.Name -like 'Apache2.4' -and $_.StartMode -eq 'Auto'
	  } | Stop-Service;

	<# Kill httpd.exe for sbt3-9400, its running as console app outside service #>
	Get-Process | Where-Object { $_.Name -like 'httpd' } | Stop-Process -Force;

	Get-WmiObject win32_service |
	  Where-Object {
		  $_.Name -like 'Apache2.4' -and $_.StartMode -eq 'Auto'
	  } | Start-Service;

	<# Start apache from shortcut for 9400 #>
	$glob = "${env:SYSTEMDRIVE}/ProgramData/Microsoft/Windows/Start Menu/Programs/Startup/Apache HTTP Server.lnk";
	$httpd_link = Get-ChildItem $glob -ea 0 | Select-Object -Last 1 | Select-Object -exp fullname;
	if($httpd_link -ne $null) {
		Invoke-Item $httpd_link
	}
}

if($prod){
	<# Production settings #>

	Copy-Item c:/php/php.ini c:/php/php.ini.$(Get-Date -f MM-dd-yyyy_HH_mm_ss).ini;

	(Get-Content c:/php/php.ini) `
	  -replace '^date.timezone =.*', ';date.timezone =' `
	  -replace '^error_log =.*', ';error_log = php_errors.log' `
	  -replace '^display_errors =.*', 'display_errors = Off' `
	  -replace '^display_startup_errors =.*', 'display_startup_errors = Off' `
	  -replace '^\s*;?\s*log_errors\s*=.*', 'log_errors = On' `
	  -replace '^error_reporting = E_ALL', 'error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT' | Set-Content c:/php/php.ini;

	Copy-Item c:/Apache/conf/httpd.conf c:/Apache/conf/httpd.conf.$(Get-Date -f MM-dd-yyyy_HH_mm_ss).conf;

	(Get-Content c:/Apache/conf/httpd.conf) `
	  -replace '^\s*LogLevel\s*(debug|info|notice|warn|error|crit|alert|emerg)', 'LogLevel emerg' | Set-Content c:/Apache/conf/httpd.conf;

} else {
	<# Development/Test settings #>

	Copy-Item c:/php/php.ini c:/php/php.ini.$(Get-Date -f MM-dd-yyyy_HH_mm_ss).ini;

	(Get-Content c:/php/php.ini) `
	  -replace '^\s*;?\s*date.timezone\s*=.*', 'date.timezone = America/Los_Angeles' `
	  -replace '^\s*;?\s*error_log\s*=\s*.*', 'error_log = c:/Apache/logs/php_errors.log' `
	  -replace '^\s*;?\s*display_errors\s*=.*', 'display_errors = On' `
	  -replace '^\s*;?\s*display_startup_errors\s*=.*', 'display_startup_errors = On' `
	  -replace '^\s*;?\s*log_errors\s*=.*', 'log_errors = On' `
	  -replace '^\s*;?\s*error_reporting\s*=\s*E_ALL & ~E_DEPRECATED & ~E_STRICT', 'error_reporting = E_ALL' | Set-Content -Path c:/php/php.ini;

	Copy-Item c:/Apache/conf/httpd.conf c:/Apache/conf/httpd.conf.$(Get-Date -f MM-dd-yyyy_HH_mm_ss).conf;

	(Get-Content c:/Apache/conf/httpd.conf) `
	  -replace '^\s*LogLevel\s*(debug|info|notice|warn|error|crit|alert|emerg)', 'LogLevel debug' | Set-Content c:/Apache/conf/httpd.conf;
}

restart_httpd
