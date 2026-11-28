$results = @()

function Run-Benchmark($name, $exe, $folder, $file) {
    Write-Host "`n[$name]"

    $path = Join-Path $PSScriptRoot $folder

    Copy-Item (Join-Path $PSScriptRoot "..\program.asm") `
              (Join-Path $path "program.asm") -Force

    $time = Measure-Command {
        Push-Location $path
        try {
            Write-Host "Working directory: $(Get-Location)"
            & $exe $file
        }
        finally {
            Pop-Location
        }
    }

    if ($LASTEXITCODE -eq 0) {
        $script:results += [PSCustomObject]@{
            Language = $name
            Time = $time.TotalMilliseconds
        }
    } else {
        Write-Host "FAILED - excluded from results"
    }
}

Run-Benchmark "Python" "python" "..\py-port" "main.py"
Run-Benchmark "JavaScript" "node" "..\js-port" "main.js"
Run-Benchmark "Lua" "lua" "..\lua-port" "main.lua"
Run-Benchmark "Ruby" "ruby" "..\ruby-port" "main.rb"

$sorted = $results | Sort-Object Time

$output = $sorted | ForEach-Object {
    "{0} : {1:N4} ms" -f $_.Language, $_.Time
}

$output | Set-Content (Join-Path $PSScriptRoot "results.txt")

Write-Host "`n=========================="
Write-Host "       FINAL RESULTS"
Write-Host "=========================="

$output | ForEach-Object { Write-Host $_ }

if ($sorted.Count -gt 0) {
    Write-Host "`nWinner: $($sorted[0].Language)"
} else {
    Write-Host "`nNo successful benchmarks!"
}