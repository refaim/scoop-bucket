param(
    [string] $ScoopPath = "$env:USERPROFILE/scoop/apps/scoop/current"
)

Describe 'FreeLLMAPI desktop manifest' {
    BeforeAll {
        . "$ScoopPath/lib/json.ps1"
        Add-Type -Path "$ScoopPath/supporting/validator/bin/Scoop.Validator.dll"
        $manifestPath = "$PSScriptRoot/../bucket/freellmapi.json"
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json

        function Get-FreeLLMAPIVersion([string] $page) {
            $selected = json_path $page $manifest.checkver.jsonpath $null $false $false
            [regex]::Match("$selected", $manifest.checkver.regex).Groups['version'].Value
        }
    }

    It 'validates against the installed Scoop schema' {
        $validator = New-Object Scoop.Validator("$ScoopPath/schema.json", $true)
        $validator.Validate($manifestPath) | Should Be $true
        $validator.Errors.Count | Should Be 0
    }

    It 'packages the official x64 desktop ZIP with a shortcut and command' {
        $manifest.version | Should Match '^\d+\.\d+\.\d+$'
        $manifest.homepage | Should Be 'https://github.com/tashfeenahmed/freellmapi'
        $manifest.license | Should Be 'MIT'
        @($manifest.architecture.PSObject.Properties.Name).Count | Should Be 1
        $manifest.architecture.'64bit'.url | Should Be "https://github.com/tashfeenahmed/freellmapi/releases/download/v$($manifest.version)/FreeLLMAPI-$($manifest.version)-win.zip"
        $manifest.architecture.'64bit'.hash | Should Match '^[a-f0-9]{64}$'
        $manifest.bin.Count | Should Be 1
        $manifest.bin[0][0] | Should Be 'FreeLLMAPI.exe'
        $manifest.bin[0][1] | Should Be 'freellmapi'
        $manifest.shortcuts.Count | Should Be 1
        $manifest.shortcuts[0][0] | Should Be 'FreeLLMAPI.exe'
        $manifest.shortcuts[0][1] | Should Be 'FreeLLMAPI'
        $manifest.extract_dir | Should BeNullOrEmpty
        $manifest.depends | Should BeNullOrEmpty
        $manifest.persist | Should BeNullOrEmpty
        $manifest.pre_install | Should BeNullOrEmpty
        $manifest.post_install | Should BeNullOrEmpty
        $manifest.env_set | Should BeNullOrEmpty
    }

    It 'uses the stable GitHub endpoint and a versioned official digest' {
        $manifest.checkver.github | Should Be 'https://api.github.com/repos/tashfeenahmed/freellmapi/releases/latest'
        $manifest.checkver.script | Should BeNullOrEmpty
        $manifest.autoupdate.architecture.'64bit'.url.Replace('$version', $manifest.version) | Should Be $manifest.architecture.'64bit'.url
        $manifest.autoupdate.architecture.'64bit'.hash.url | Should Be 'https://api.github.com/repos/tashfeenahmed/freellmapi/releases/tags/v$version'
    }

    It 'selects <expected> from the release asset <asset>' -TestCases @(
        @{ tag = 'v0.16.14'; asset = 'FreeLLMAPI-0.16.14-win.zip'; expected = '0.16.14' }
        @{ tag = 'v12.34.567'; asset = 'FreeLLMAPI-12.34.567-win.zip'; expected = '12.34.567' }
        @{ tag = 'v0.16.14'; asset = 'FreeLLMAPI-0.16.13-win.zip'; expected = '' }
        @{ tag = 'v0.16.14'; asset = 'FreeLLMAPI-0.16.14-arm64.zip'; expected = '' }
        @{ tag = 'v0.16.14'; asset = 'FreeLLMAPI-0.16.14-x64.zip'; expected = '' }
        @{ tag = 'v0.16.14'; asset = 'FreeLLMAPI-0.16.14-x64.dmg'; expected = '' }
        @{ tag = 'v0.16.14'; asset = 'FreeLLMAPI-Setup-0.16.14.exe'; expected = '' }
        @{ tag = 'v0.16.14'; asset = 'FreeLLMAPI-0.16.14.AppImage'; expected = '' }
        @{ tag = 'v0.16.14'; asset = 'freellmapi-desktop-0.16.14.tar.xz'; expected = '' }
        @{ tag = 'v0.16.14'; asset = 'freellmapi-cli-0.16.14.tgz'; expected = '' }
        @{ tag = 'v0.16.14'; asset = 'FreeLLMAPI-0.16.14-win.zip.blockmap'; expected = '' }
        @{ tag = 'v0.16.14'; asset = 'FreeLLMAPI-0.16.14-win.zip.sha256'; expected = '' }
        @{ tag = 'v0.17.0-beta.1'; asset = 'FreeLLMAPI-0.17.0-win.zip'; expected = '' }
    ) {
        param($tag, $asset, $expected)
        $page = @{ assets = @(@{ browser_download_url = "https://github.com/tashfeenahmed/freellmapi/releases/download/$tag/$asset" }) } | ConvertTo-Json -Depth 4
        Get-FreeLLMAPIVersion $page | Should Be $expected
    }

    It 'selects the Windows ZIP among other platforms in a multi-asset release' {
        $page = @{ assets = @(
            @{ browser_download_url = 'https://github.com/tashfeenahmed/freellmapi/releases/download/v0.16.14/FreeLLMAPI-Setup-0.16.14.exe' }
            @{ browser_download_url = 'https://github.com/tashfeenahmed/freellmapi/releases/download/v0.16.14/FreeLLMAPI-0.16.14-arm64.zip' }
            @{ browser_download_url = 'https://github.com/tashfeenahmed/freellmapi/releases/download/v0.16.14/FreeLLMAPI-0.16.14-win.zip' }
        ) } | ConvertTo-Json -Depth 4
        Get-FreeLLMAPIVersion $page | Should Be '0.16.14'
    }

    It 'stops when the stable release has no Windows ZIP' {
        Get-FreeLLMAPIVersion '{"assets":[]}' | Should BeNullOrEmpty
    }

    It 'selects the digest for the matching archive instead of another platform' {
        $page = @{ assets = @(
            @{ name = 'FreeLLMAPI-1.2.3-arm64.zip'; digest = 'sha256:' + ('a' * 64) }
            @{ name = 'FreeLLMAPI-1.2.3-win.zip'; digest = 'sha256:' + ('b' * 64) }
            @{ name = 'FreeLLMAPI-Setup-1.2.3.exe'; digest = 'sha256:' + ('c' * 64) }
        ) } | ConvertTo-Json -Depth 4
        $jsonpath = $manifest.autoupdate.architecture.'64bit'.hash.jsonpath.Replace('$basename', 'FreeLLMAPI-1.2.3-win.zip')
        json_path $page $jsonpath $null $false $true | Should Be ('sha256:' + ('b' * 64))
    }

    It 'does not use another asset digest when the ZIP is absent' {
        $jsonpath = $manifest.autoupdate.architecture.'64bit'.hash.jsonpath.Replace('$basename', 'FreeLLMAPI-1.2.3-win.zip')
        json_path '{"assets":[{"name":"FreeLLMAPI-Setup-1.2.3.exe","digest":"sha256:other"}]}' $jsonpath $null $false $true | Should BeNullOrEmpty
    }
}
