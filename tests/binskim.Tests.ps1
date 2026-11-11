param(
    [string] $ScoopPath = "$env:USERPROFILE/scoop/apps/scoop/current",
    [string] $PackagePath
)

Describe 'BinSkim manifest' {
    BeforeAll {
        Add-Type -Path "$ScoopPath/supporting/validator/bin/Scoop.Validator.dll"
        $manifestPath = "$PSScriptRoot/../bucket/binskim.json"
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json
    }

    It 'validates against the installed Scoop schema' {
        $validator = New-Object Scoop.Validator("$ScoopPath/schema.json", $true)
        $validator.Validate($manifestPath) | Should Be $true
        $validator.Errors.Count | Should Be 0
    }

    It 'selects the framework-independent Windows x64 payload' {
        $manifest.extract_dir | Should Be 'tools\win-x64'
        $manifest.bin | Should Be 'BinSkim.exe'
        $manifest.depends | Should BeNullOrEmpty
        $manifest.notes -join ' ' | Should Not Match 'tools\\net\d|bump extract_dir'
    }

    It 'downloads the official versioned NuGet package on install and update' {
        $manifest.url | Should Be "https://api.nuget.org/v3-flatcontainer/microsoft.codeanalysis.binskim/$($manifest.version)/microsoft.codeanalysis.binskim.$($manifest.version).nupkg#/binskim.zip"
        $manifest.hash | Should Match '^[a-f0-9]{64}$'
        $manifest.autoupdate.url.Replace('$version', $manifest.version) | Should Be $manifest.url
    }

    It 'matches the downloaded package checksum' -Skip:(!$PackagePath) {
        (Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash.ToLowerInvariant() | Should Be $manifest.hash
    }

    It 'finds the executable and bundled runtime in the selected archive directory' -Skip:(!$PackagePath) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $PackagePath).Path)
        try {
            $prefix = $manifest.extract_dir.Replace('\', '/') + '/'
            $entries = @($archive.Entries.FullName)
            foreach ($file in @($manifest.bin, 'BinSkim.dll', 'BinSkim.runtimeconfig.json', 'coreclr.dll', 'hostfxr.dll', 'hostpolicy.dll', 'System.Private.CoreLib.dll')) {
                ($entries -ccontains "$prefix$file") | Should Be $true
            }
        } finally {
            $archive.Dispose()
        }
    }
}
