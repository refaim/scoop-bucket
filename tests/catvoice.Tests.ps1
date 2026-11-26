param(
    [string] $ScoopPath = "$env:USERPROFILE/scoop/apps/scoop/current",
    [string] $HookDirectory
)

Describe 'CatVoice manifest' {
    BeforeAll {
        . "$ScoopPath/lib/json.ps1"
        Add-Type -Path "$ScoopPath/supporting/validator/bin/Scoop.Validator.dll"
        $manifestPath = "$PSScriptRoot/../bucket/catvoice.json"
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json
        $hooks = @{}
        foreach ($hook in @(
            @{ Name = 'pre-install'; Lines = $manifest.pre_install }
            @{ Name = 'pre-uninstall'; Lines = $manifest.pre_uninstall }
            @{ Name = 'uninstaller'; Lines = $manifest.uninstaller.script }
        )) {
            if ($HookDirectory) {
                $path = Join-Path $HookDirectory "$($hook.Name).ps1"
                (Get-Content -LiteralPath $path -Raw).Trim() | Should Be ($hook.Lines -join "`r`n").Trim()
            } else {
                $path = Join-Path $TestDrive "$($hook.Name).ps1"
                Set-Content -LiteralPath $path -Value ($hook.Lines -join "`r`n") -Encoding Ascii
            }
            $hooks[$hook.Name] = $path
        }
        function is_admin { throw 'Administrator checks must be mocked.' }
        function abort($msg) { throw $msg }
        function Invoke-ExternalCommand($FilePath, $ArgumentList, $Activity) { throw 'Tests must not run installers.' }
        function Get-CatVoiceVersion([string] $page) {
            $selected = json_path $page $manifest.checkver.jsonpath $null $false $false
            [regex]::Match("$selected", $manifest.checkver.regex).Groups['version'].Value
        }
    }

    BeforeEach {
        $cmd = 'uninstall'
        Mock is_admin { $true }
        Mock Get-ItemProperty { [pscustomobject]@{ DisplayName = 'CatVoice 0.1.0'; UninstallString = '"C:\Program Files\CatVoice\unins000.exe"' } }
        Mock Test-Path { $true }
        Mock Invoke-ExternalCommand { $true }
    }

    It 'validates against the installed Scoop schema' {
        $validator = New-Object Scoop.Validator("$ScoopPath/schema.json", $true)
        $validator.Validate($manifestPath) | Should Be $true
        $validator.Errors.Count | Should Be 0
    }

    It 'runs the official Windows x64 installer without portable extraction or security bypasses' {
        @($manifest.architecture.PSObject.Properties.Name) -join ',' | Should Be '64bit'
        $release = $manifest.architecture.'64bit'
        $release.url | Should Be "https://github.com/daniilcathey/catvoice/releases/download/v$($manifest.version)/CatVoice-Setup-$($manifest.version).exe#/setup.exe"
        $release.hash | Should Match '^[a-f0-9]{64}$'
        $manifest.license.identifier | Should Be 'Proprietary'
        $manifest.installer.file | Should Be 'setup.exe'
        $manifest.installer.args -join ' ' | Should Be '/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
        $manifest.innosetup | Should BeNullOrEmpty
        $manifest.bin | Should BeNullOrEmpty
        $manifest.shortcuts | Should BeNullOrEmpty
        $manifest.persist | Should BeNullOrEmpty
        $manifest.depends | Should BeNullOrEmpty
        $manifest.post_install | Should BeNullOrEmpty
        ($manifest | ConvertTo-Json -Depth 8) | Should Not Match 'Unblock-File|Add-MpPreference|Set-MpPreference|Import-Certificate|certutil'
    }

    It 'refuses installation without administrator rights' {
        Mock is_admin { $false }
        { & $hooks['pre-install'] } | Should Throw 'administrator'
    }

    It 'allows the native installer to run from an elevated shell' {
        { & $hooks['pre-install'] } | Should Not Throw
        Assert-MockCalled Invoke-ExternalCommand -Exactly 0 -Scope It
    }

    It 'keeps the native installation in place during Scoop updates' {
        $cmd = 'update'
        Mock is_admin { $false }
        & $hooks.uninstaller
        Assert-MockCalled is_admin -Exactly 0 -Scope It
        Assert-MockCalled Get-ItemProperty -Exactly 0 -Scope It
        Assert-MockCalled Invoke-ExternalCommand -Exactly 0 -Scope It
    }

    It 'refuses unelevated <command> before Scoop unlinks the current version' -TestCases @(
        @{ command = 'update' }
        @{ command = 'uninstall' }
    ) {
        param($command)
        $cmd = $command
        Mock is_admin { $false }
        { & $hooks['pre-uninstall'] } | Should Throw 'administrator'
        Assert-MockCalled Invoke-ExternalCommand -Exactly 0 -Scope It
    }

    It 'allows an elevated update or uninstall to proceed' {
        { & $hooks['pre-uninstall'] } | Should Not Throw
    }

    It 'refuses removal without administrator rights' {
        Mock is_admin { $false }
        { & $hooks.uninstaller } | Should Throw 'administrator'
        Assert-MockCalled Get-ItemProperty -Exactly 0 -Scope It
        Assert-MockCalled Invoke-ExternalCommand -Exactly 0 -Scope It
    }

    It 'uses the registered native uninstaller with reboot suppression' {
        & $hooks.uninstaller
        Assert-MockCalled Get-ItemProperty -Exactly 1 -Scope It -ParameterFilter {
            $Path -contains 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -and
            $Path -contains 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        }
        Assert-MockCalled Invoke-ExternalCommand -Exactly 1 -Scope It -ParameterFilter {
            $FilePath -eq 'C:\Program Files\CatVoice\unins000.exe' -and
            ($ArgumentList -join ' ') -eq '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
        }
    }

    It 'accepts an unquoted registered path and filters unrelated products' {
        Mock Get-ItemProperty {
            [pscustomobject]@{ DisplayName = 'Other product'; UninstallString = 'C:\Other\remove.exe' }
            [pscustomobject]@{ DisplayName = 'CatVoice'; UninstallString = 'D:\Custom Apps\CatVoice\unins001.exe' }
            [pscustomobject]@{ DisplayName = 'CatVoiceTools'; UninstallString = 'C:\Other\remove.exe' }
        }
        & $hooks.uninstaller
        Assert-MockCalled Invoke-ExternalCommand -Exactly 1 -Scope It -ParameterFilter { $FilePath -eq 'D:\Custom Apps\CatVoice\unins001.exe' }
    }

    It 'refuses ambiguous or absent registrations: <scenario>' -TestCases @(
        @{ scenario = 'absent'; entries = @() }
        @{ scenario = 'unrelated product'; entries = @(@{ DisplayName = 'CatVoiceTools'; UninstallString = 'C:\Other\remove.exe' }) }
        @{ scenario = 'multiple matches'; entries = @(@{ DisplayName = 'CatVoice'; UninstallString = 'C:\One.exe' }, @{ DisplayName = 'CatVoice 0.2.0'; UninstallString = 'C:\Two.exe' }) }
    ) {
        param($scenario, $entries)
        Mock Get-ItemProperty { $entries }
        { & $hooks.uninstaller } | Should Throw 'locate'
        Assert-MockCalled Invoke-ExternalCommand -Exactly 0 -Scope It
    }

    It 'refuses an empty registered uninstall command' {
        Mock Get-ItemProperty { [pscustomobject]@{ DisplayName = 'CatVoice'; UninstallString = '' } }
        { & $hooks.uninstaller } | Should Throw 'command'
        Assert-MockCalled Invoke-ExternalCommand -Exactly 0 -Scope It
    }

    It 'refuses removal when the registered executable is missing' {
        Mock Test-Path { $false }
        { & $hooks.uninstaller } | Should Throw 'missing'
        Assert-MockCalled Invoke-ExternalCommand -Exactly 0 -Scope It
    }

    It 'reports failure instead of allowing Scoop to forget an unsuccessful uninstall' {
        Mock Invoke-ExternalCommand { $false }
        { & $hooks.uninstaller } | Should Throw 'failed'
    }

    It 'uses stable release assets and versioned SHA-256 digests for updates' {
        $manifest.checkver.github | Should Be 'https://api.github.com/repos/daniilcathey/catvoice/releases/latest'
        $manifest.autoupdate.architecture.'64bit'.url.Replace('$version', $manifest.version) | Should Be $manifest.architecture.'64bit'.url
        $hash = $manifest.autoupdate.architecture.'64bit'.hash
        $hash.url | Should Be 'https://api.github.com/repos/daniilcathey/catvoice/releases/tags/v$version'
        $assetName = "CatVoice-Setup-$($manifest.version).exe"
        $page = @{ assets = @(
            @{ name = "CatChat-$($manifest.version).zip"; digest = 'sha256:' + ('a' * 64) }
            @{ name = $assetName; digest = 'sha256:' + ('b' * 64) }
            @{ name = "$assetName.sha256"; digest = 'sha256:' + ('c' * 64) }
        ) } | ConvertTo-Json -Depth 4
        $jsonpath = $hash.jsonpath.Replace('$basename', $assetName)
        json_path $page $jsonpath $null $false $true | Should Be ('sha256:' + ('b' * 64))
        json_path '{"assets":[]}' $jsonpath $null $false $true | Should BeNullOrEmpty
    }

    It 'selects <expected> from tag <tag> and asset <asset>' -TestCases @(
        @{ tag = 'v0.1.0'; asset = 'CatVoice-Setup-0.1.0.exe'; expected = '0.1.0' }
        @{ tag = 'v12.34.567'; asset = 'CatVoice-Setup-12.34.567.exe'; expected = '12.34.567' }
        @{ tag = 'v0.1.0'; asset = 'CatVoice-Setup-0.2.0.exe'; expected = '' }
        @{ tag = 'v0.1.0'; asset = 'CatVoice-Setup-0.1.0.exe.sha256'; expected = '' }
        @{ tag = 'v0.1.0'; asset = 'CatChat-0.1.0.zip'; expected = '' }
        @{ tag = 'v0.2.0-rc.1'; asset = 'CatVoice-Setup-0.2.0.exe'; expected = '' }
        @{ tag = 'nightly'; asset = 'CatVoice-Setup-0.1.0.exe'; expected = '' }
        @{ tag = 'v0.1'; asset = 'CatVoice-Setup-0.1.exe'; expected = '' }
    ) {
        param($tag, $asset, $expected)
        $page = @{ assets = @(@{ browser_download_url = "https://github.com/daniilcathey/catvoice/releases/download/$tag/$asset" }) } | ConvertTo-Json -Depth 4
        Get-CatVoiceVersion $page | Should Be $expected
    }

    It 'finds the installer among addon assets and ignores an empty release' {
        $page = @{ assets = @(
            @{ browser_download_url = 'https://github.com/daniilcathey/catvoice/releases/download/v0.1.0/CatChat-0.1.1.zip' }
            @{ browser_download_url = 'https://github.com/daniilcathey/catvoice/releases/download/v0.1.0/CatVoice-Setup-0.1.0.exe' }
        ) } | ConvertTo-Json -Depth 4
        Get-CatVoiceVersion $page | Should Be '0.1.0'
        Get-CatVoiceVersion '{"assets":[]}' | Should BeNullOrEmpty
    }
}
