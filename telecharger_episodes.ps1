# Telecharge les MP3 de "La session de rattrapage" (Europe 1) listes dans
# session_de_rattrapage_episodes.csv (a placer dans le meme dossier).
# Lancement : double-cliquer sur telecharger_episodes.bat
# Relancer le script reprend la ou il s'est arrete (fichiers deja la ignores).

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # sinon Invoke-WebRequest est tres lent
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$csv  = Join-Path $here 'session_de_rattrapage_episodes.csv'
$out  = Join-Path $here 'mp3'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$episodes = Import-Csv -Path $csv -Encoding UTF8 | Where-Object { $_.mp3_dispo -eq 'oui' }
$total = @($episodes).Count
$seen = @{}
$i = 0; $ok = 0; $skip = 0; $fail = @()

foreach ($e in $episodes) {
    $i++
    $titre = ($e.titre -replace '[\\/:*?"<>|«»]', '').Trim()
    if ($titre.Length -gt 120) { $titre = $titre.Substring(0, 120).Trim() }
    $nom = "$($e.date) - $titre"
    if ($seen.ContainsKey($nom)) { $seen[$nom]++; $nom = "$nom ($($seen[$nom]))" } else { $seen[$nom] = 1 }
    $dest = Join-Path $out "$nom.mp3"

    if ((Test-Path -LiteralPath $dest) -and (Get-Item -LiteralPath $dest).Length -gt 100000) {
        $skip++; continue
    }

    Write-Host "[$i/$total] $nom"
    $tmp = "$dest.part"
    $done = $false
    for ($try = 1; $try -le 3 -and -not $done; $try++) {
        try {
            Invoke-WebRequest -Uri $e.mp3 -OutFile $tmp -UseBasicParsing -TimeoutSec 300
            Move-Item -LiteralPath $tmp -Destination $dest -Force
            $done = $true; $ok++
        } catch {
            Start-Sleep -Seconds (2 * $try)
        }
    }
    if (-not $done) {
        Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
        $fail += "$($e.date) $($e.titre)"
    }
}

Write-Host ""
Write-Host "Termine : $ok telecharges, $skip deja presents, $($fail.Count) echecs."
Write-Host "Dossier : $out"
if ($fail.Count) { Write-Host "Echecs :"; $fail | ForEach-Object { Write-Host "  $_" } }
