param(
    [string] $ScoopPath = "$env:USERPROFILE/scoop/apps/scoop/current",
    [string] $HookDirectory
)

Describe 'Gemini web2api Go manifest' {
    BeforeAll {
        . "$ScoopPath/lib/json.ps1"
        . "$ScoopPath/lib/manifest.ps1"
        . "$ScoopPath/lib/install.ps1"
        Add-Type -Path "$ScoopPath/supporting/validator/bin/Scoop.Validator.dll"
        $manifestPath = "$PSScriptRoot/../bucket/gemini-web2api-go.json"
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json

        # Load Scoop's substitution helper without loading global Scoop settings.
        $core = [System.Management.Automation.Language.Parser]::ParseFile("$ScoopPath/lib/core.ps1", [ref]$null, [ref]$null)
        $definition = $core.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'substitute' }, $false)
        . ([scriptblock]::Create($definition.Extent.Text))

        if ($HookDirectory) {
            $hookPath = Join-Path $HookDirectory 'pre-install.ps1'
            (Get-Content -LiteralPath $hookPath -Raw).Trim() | Should Be ($manifest.pre_install -join "`r`n").Trim()
        } else {
            $hookPath = Join-Path $TestDrive 'pre-install.ps1'
            Set-Content -LiteralPath $hookPath -Value ($manifest.pre_install -join "`r`n") -Encoding Ascii
        }

        function Get-GeminiVersion([string] $page) {
            $selected = json_path $page $manifest.checkver.jsonpath $null $false $false
            [regex]::Match("$selected", $manifest.checkver.regex).Groups['version'].Value
        }

        function shim($path, $global, $name, $arg) {
            throw 'Tests must not create real Scoop shims.'
        }
    }

    It 'validates against the installed Scoop schema' {
        $validator = New-Object Scoop.Validator("$ScoopPath/schema.json", $true)
        $validator.Validate($manifestPath) | Should Be $true
        $validator.Errors.Count | Should Be 0
    }

    It 'packages standalone Windows builds without runtime dependencies' {
        $manifest.version | Should Match '^[0-9]+\.[0-9]+\.[0-9]+$'
        $manifest.homepage | Should Be 'https://github.com/zexadev/gemini-web2api-go'
        $manifest.license | Should Be 'MIT'
        @($manifest.architecture.PSObject.Properties.Name | Sort-Object) -join ',' | Should Be '64bit,arm64'
        $manifest.depends | Should BeNullOrEmpty
        $manifest.extract_dir | Should BeNullOrEmpty
        $manifest.post_install | Should BeNullOrEmpty
        $manifest.env_set | Should BeNullOrEmpty
        @($manifest.persist | Sort-Object) -join ',' | Should Be 'config.json,data'
    }

    It 'uses the official <target> binary and its matching release digest' -TestCases @(
        @{ architecture = '64bit'; target = 'amd64' }
        @{ architecture = 'arm64'; target = 'arm64' }
    ) {
        param($architecture, $target)
        $release = $manifest.architecture.$architecture
        $update = $manifest.autoupdate.architecture.$architecture
        $assetName = "gemini-web2api-go_v$($manifest.version)_windows_$target.exe"
        $release.url | Should Be "https://github.com/zexadev/gemini-web2api-go/releases/download/v$($manifest.version)/$assetName#/gemini-web2api-go.exe"
        $release.hash | Should Match '^[a-f0-9]{64}$'
        $update.url.Replace('$version', $manifest.version) | Should Be $release.url
        $update.hash.url | Should Be 'https://api.github.com/repos/zexadev/gemini-web2api-go/releases/tags/v$version'
        $page = @{ assets = @(
            @{ name = 'gemini-web2api-go_v0.0.0_linux_amd64'; digest = 'sha256:' + ('a' * 64) }
            @{ name = $assetName; digest = 'sha256:' + ('b' * 64) }
        ) } | ConvertTo-Json -Depth 4
        $basename = [IO.Path]::GetFileName(([uri]$release.url).AbsolutePath)
        $jsonpath = $update.hash.jsonpath.Replace('$basename', $basename)
        json_path $page $jsonpath $null $false $true | Should Be ('sha256:' + ('b' * 64))
        json_path '{"assets":[]}' $jsonpath $null $false $true | Should BeNullOrEmpty
    }

    It 'keeps config and SQLite paths absolute and quoted in the native Scoop shim' {
        $dir = New-Item -ItemType Directory -Path "$TestDrive/app with spaces"
        $persist_dir = "$TestDrive/persist with spaces"
        Set-Content -LiteralPath "$dir/gemini-web2api-go.exe" -Value ''
        Mock shim {}

        create_shims $manifest $dir.FullName $false '64bit' | Out-Null

        Assert-MockCalled shim -Exactly 1 -ParameterFilter {
            $path -eq "$dir\gemini-web2api-go.exe" -and
            $name -eq 'gemini-web2api-go' -and
            $arg -eq "--config `"$persist_dir\config.json`" --db `"$persist_dir\data\gemini.db`""
        }
    }

    It 'creates a BOM-free loopback configuration on first install' {
        $dir = New-Item -ItemType Directory -Path "$TestDrive/fresh app"
        $persist_dir = "$TestDrive/fresh persist"
        & $hookPath
        $configPath = "$dir/config.json"
        (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json).host | Should Be '127.0.0.1'
        (Get-Item -LiteralPath $configPath).PSIsContainer | Should Be $false
        [IO.File]::ReadAllBytes($configPath)[0] | Should Be 123
    }

    It 'leaves existing persisted configuration and database untouched on upgrade' {
        $dir = New-Item -ItemType Directory -Path "$TestDrive/updated app"
        $persist_dir = New-Item -ItemType Directory -Path "$TestDrive/existing persist"
        New-Item -ItemType Directory -Path "$persist_dir/data" | Out-Null
        $config = '{"host":"192.0.2.1","port":9083}'
        Set-Content -LiteralPath "$persist_dir/config.json" -Value $config -Encoding Ascii
        Set-Content -LiteralPath "$persist_dir/data/gemini.db" -Value 'saved database fixture' -Encoding Ascii
        & $hookPath
        (Get-Content -LiteralPath "$persist_dir/config.json" -Raw).Trim() | Should Be $config
        (Get-Content -LiteralPath "$persist_dir/data/gemini.db" -Raw).Trim() | Should Be 'saved database fixture'
        Test-Path -LiteralPath "$dir/config.json" | Should Be $false
    }

    It 'tracks stable releases through the Windows asset' {
        $manifest.checkver.github | Should Be 'https://api.github.com/repos/zexadev/gemini-web2api-go/releases/latest'
        $manifest.checkver.script | Should BeNullOrEmpty
    }

    It 'selects <expected> for tag <tag> and asset <asset>' -TestCases @(
        @{ tag = 'v4.28.0'; asset = 'gemini-web2api-go_v4.28.0_windows_amd64.exe'; expected = '4.28.0' }
        @{ tag = 'v12.34.567'; asset = 'gemini-web2api-go_v12.34.567_windows_amd64.exe'; expected = '12.34.567' }
        @{ tag = 'v4.28.0'; asset = 'gemini-web2api-go_v4.27.0_windows_amd64.exe'; expected = '' }
        @{ tag = 'v4.28.0'; asset = 'gemini-web2api-go_v4.28.0_windows_arm64.exe'; expected = '' }
        @{ tag = 'v4.28.0'; asset = 'gemini-web2api-go_v4.28.0_linux_amd64'; expected = '' }
        @{ tag = 'v4.28.0'; asset = 'gemini-web2api-go_v4.28.0_darwin_amd64'; expected = '' }
        @{ tag = 'v4.28.0'; asset = 'gemini-web2api-go_v4.28.0_windows_386.exe'; expected = '' }
        @{ tag = 'v4.28.0'; asset = 'gemini-web2api-go_v4.28.0_windows_amd64.exe.sha256'; expected = '' }
        @{ tag = 'v4.28.0'; asset = 'gemini-web2api-go_v4.28.0_windows_amd64.exe.zip'; expected = '' }
        @{ tag = 'v4.29.0-rc.1'; asset = 'gemini-web2api-go_v4.29.0_windows_amd64.exe'; expected = '' }
        @{ tag = 'nightly'; asset = 'gemini-web2api-go_nightly_windows_amd64.exe'; expected = '' }
        @{ tag = 'v4.28'; asset = 'gemini-web2api-go_v4.28_windows_amd64.exe'; expected = '' }
    ) {
        param($tag, $asset, $expected)
        $page = @{ assets = @(@{ browser_download_url = "https://github.com/zexadev/gemini-web2api-go/releases/download/$tag/$asset" }) } | ConvertTo-Json -Depth 4
        Get-GeminiVersion $page | Should Be $expected
    }

    It 'selects Windows x64 among other platforms and stops when it is absent' {
        $page = @{ assets = @(
            @{ browser_download_url = 'https://github.com/zexadev/gemini-web2api-go/releases/download/v4.28.0/gemini-web2api-go_v4.28.0_linux_amd64' }
            @{ browser_download_url = 'https://github.com/zexadev/gemini-web2api-go/releases/download/v4.28.0/gemini-web2api-go_v4.28.0_windows_amd64.exe' }
        ) } | ConvertTo-Json -Depth 4
        Get-GeminiVersion $page | Should Be '4.28.0'
        Get-GeminiVersion '{"assets":[]}' | Should BeNullOrEmpty
    }
}
