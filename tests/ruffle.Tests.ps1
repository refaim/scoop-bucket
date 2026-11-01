param(
    [string] $ScoopPath = "$env:USERPROFILE/scoop/apps/scoop/current"
)

Describe 'Ruffle desktop manifest' {
    BeforeAll {
        . "$ScoopPath/lib/json.ps1"
        Add-Type -Path "$ScoopPath/supporting/validator/bin/Scoop.Validator.dll"
        $manifestPath = "$PSScriptRoot/../bucket/ruffle.json"
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json

        function Get-RuffleVersion([string] $page) {
            $selected = json_path $page $manifest.checkver.jsonpath $null $false $false
            [regex]::Match("$selected", $manifest.checkver.regex).Groups['version'].Value
        }
    }

    It 'validates against the installed Scoop schema' {
        $validator = New-Object Scoop.Validator("$ScoopPath/schema.json", $true)
        $validator.Validate($manifestPath) | Should Be $true
        $validator.Errors.Count | Should Be 0
    }

    It 'packages the desktop player without install scripts or dependencies' {
        $manifest.version | Should Match '^\d+\.\d+\.\d+$'
        $manifest.homepage | Should Be 'https://ruffle.rs'
        $manifest.license | Should Be '(MIT OR Apache-2.0)'
        @($manifest.architecture.PSObject.Properties.Name | Sort-Object) -join ',' | Should Be '32bit,64bit'
        $manifest.bin | Should Be 'ruffle.exe'
        $manifest.shortcuts.Count | Should Be 1
        $manifest.shortcuts[0][0] | Should Be 'ruffle.exe'
        $manifest.shortcuts[0][1] | Should Be 'Ruffle'
        $manifest.extract_dir | Should BeNullOrEmpty
        $manifest.depends | Should BeNullOrEmpty
        $manifest.persist | Should BeNullOrEmpty
        $manifest.pre_install | Should BeNullOrEmpty
        $manifest.post_install | Should BeNullOrEmpty
        $manifest.env_set | Should BeNullOrEmpty
    }

    It 'uses the official <architecture> ZIP and versioned asset digest' -TestCases @(
        @{ architecture = '64bit'; target = 'x86_64' }
        @{ architecture = '32bit'; target = 'x86_32' }
    ) {
        param($architecture, $target)
        $release = $manifest.architecture.$architecture
        $update = $manifest.autoupdate.architecture.$architecture
        $release.url | Should Be "https://github.com/ruffle-rs/ruffle/releases/download/v$($manifest.version)/ruffle-$($manifest.version)-windows-$target.zip"
        $release.hash | Should Match '^[a-f0-9]{64}$'
        $update.url.Replace('$version', $manifest.version) | Should Be $release.url
        $update.hash.url | Should Be 'https://api.github.com/repos/ruffle-rs/ruffle/releases/tags/v$version'
        $basename = "ruffle-$($manifest.version)-windows-$target.zip"
        $page = @{ assets = @(
            @{ name = 'ruffle-other-platform.zip'; digest = 'sha256:' + ('a' * 64) }
            @{ name = $basename; digest = 'sha256:' + ('b' * 64) }
        ) } | ConvertTo-Json -Depth 4
        $jsonpath = $update.hash.jsonpath.Replace('$basename', $basename)
        json_path $page $jsonpath $null $false $true | Should Be ('sha256:' + ('b' * 64))
        json_path '{"assets":[]}' $jsonpath $null $false $true | Should BeNullOrEmpty
    }

    It 'tracks stable GitHub releases without a custom checkver script' {
        $manifest.checkver.github | Should Be 'https://api.github.com/repos/ruffle-rs/ruffle/releases/latest'
        $manifest.checkver.script | Should BeNullOrEmpty
    }

    It 'selects <expected> from tag <tag> and asset <asset>' -TestCases @(
        @{ tag = 'v0.7.1'; asset = 'ruffle-0.7.1-windows-x86_64.zip'; expected = '0.7.1' }
        @{ tag = 'v12.34.567'; asset = 'ruffle-12.34.567-windows-x86_64.zip'; expected = '12.34.567' }
        @{ tag = 'v0.7.1'; asset = 'ruffle-0.7.0-windows-x86_64.zip'; expected = '' }
        @{ tag = 'v0.7.1'; asset = 'ruffle-0.7.1-windows-x86_32.zip'; expected = '' }
        @{ tag = 'v0.7.1'; asset = 'ruffle-0.7.1-linux-x86_64.tar.gz'; expected = '' }
        @{ tag = 'v0.7.1'; asset = 'ruffle-0.7.1-web-extension.zip'; expected = '' }
        @{ tag = 'v0.7.1'; asset = 'ruffle-0.7.1-web-selfhosted.zip'; expected = '' }
        @{ tag = 'v0.7.1'; asset = 'ruffle-0.7.1-reproducible-source.zip'; expected = '' }
        @{ tag = 'v0.7.1'; asset = 'ruffle-0.7.1-windows-x86_64.zip.sha256'; expected = '' }
        @{ tag = 'v0.7.1'; asset = 'ruffle-0.7.1-windows-x86_64.zip.exe'; expected = '' }
        @{ tag = 'v0.8.0-rc.1'; asset = 'ruffle-0.8.0-windows-x86_64.zip'; expected = '' }
        @{ tag = 'nightly-2026-11-01'; asset = 'ruffle-nightly-2026_11_01-windows-x86_64.zip'; expected = '' }
        @{ tag = 'v0.7'; asset = 'ruffle-0.7-windows-x86_64.zip'; expected = '' }
    ) {
        param($tag, $asset, $expected)
        $page = @{ assets = @(@{ browser_download_url = "https://github.com/ruffle-rs/ruffle/releases/download/$tag/$asset" }) } | ConvertTo-Json -Depth 4
        Get-RuffleVersion $page | Should Be $expected
    }

    It 'finds the Windows player among other release artifacts' {
        $page = @{ assets = @(
            @{ browser_download_url = 'https://github.com/ruffle-rs/ruffle/releases/download/v0.7.1/ruffle-0.7.1-web-extension.zip' }
            @{ browser_download_url = 'https://github.com/ruffle-rs/ruffle/releases/download/v0.7.1/ruffle-0.7.1-windows-x86_32.zip' }
            @{ browser_download_url = 'https://github.com/ruffle-rs/ruffle/releases/download/v0.7.1/ruffle-0.7.1-windows-x86_64.zip' }
        ) } | ConvertTo-Json -Depth 4
        Get-RuffleVersion $page | Should Be '0.7.1'
    }

    It 'stops when the release has no Windows x64 player' {
        Get-RuffleVersion '{"assets":[]}' | Should BeNullOrEmpty
    }
}
