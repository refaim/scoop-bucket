param(
    [string] $ScoopPath = "$env:USERPROFILE/scoop/apps/scoop/current"
)

Describe 'Bifrost gateway manifest' {
    BeforeAll {
        Add-Type -Path "$ScoopPath/supporting/validator/bin/Scoop.Validator.dll"
        $manifestPath = "$PSScriptRoot/../bucket/bifrost.json"
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop | ConvertFrom-Json

        function Get-SelectedBifrostVersion([string] $page) {
            $json = $manifest.PSObject.Copy()
            $json.version = '2.4.0'
            $selected = Invoke-Command ([scriptblock]::Create($manifest.checkver.script -join "`r`n"))
            [regex]::Match("$selected", $manifest.checkver.regex).Groups['version'].Value
        }
    }

    It 'validates against the installed Scoop schema' {
        $validator = New-Object Scoop.Validator("$ScoopPath/schema.json", $true)
        $validator.Validate($manifestPath) | Should Be $true
        $validator.Errors.Count | Should Be 0
    }

    It 'packages only the official Windows x64 gateway' {
        $manifest.version | Should Match '^\d+\.\d+\.\d+$'
        $manifest.homepage | Should Be 'https://github.com/maximhq/bifrost'
        $manifest.license | Should Be 'Apache-2.0'
        @($manifest.architecture.PSObject.Properties.Name).Count | Should Be 1
        $manifest.architecture.'64bit'.url | Should Be "https://downloads.getmaxim.ai/bifrost/v$($manifest.version)/windows/amd64/bifrost-http.exe"
        $manifest.architecture.'64bit'.hash | Should Match '^[a-f0-9]{64}$'
        $manifest.bin.Count | Should Be 1
        $manifest.bin[0][0] | Should Be 'bifrost-http.exe'
        $manifest.bin[0][1] | Should Be 'bifrost'
        $manifest.depends | Should BeNullOrEmpty
        $manifest.persist | Should BeNullOrEmpty
        $manifest.pre_install | Should BeNullOrEmpty
        $manifest.post_install | Should BeNullOrEmpty
    }

    It 'uses the authenticated release list and versioned checksum feed' {
        $manifest.checkver.github | Should Be 'https://api.github.com/repos/maximhq/bifrost/releases?per_page=100'
        $manifest.autoupdate.architecture.'64bit'.url.Replace('$version', $manifest.version) | Should Be $manifest.architecture.'64bit'.url
        $manifest.autoupdate.architecture.'64bit'.hash.url | Should Be '$url.sha256'
    }

    It 'selects <expected> for tag <tag>, draft <draft>, prerelease <prerelease>' -TestCases @(
        @{ tag = 'transports/v2.4.0'; draft = $false; prerelease = $false; expected = '2.4.0' }
        @{ tag = 'transports/v10.12.345'; draft = $false; prerelease = $false; expected = '10.12.345' }
        @{ tag = 'transports/v9.0.0'; draft = $true; prerelease = $false; expected = '' }
        @{ tag = 'transports/v9.0.0'; draft = $false; prerelease = $true; expected = '' }
        @{ tag = 'transports/v9.0.0'; draft = $true; prerelease = $true; expected = '' }
        @{ tag = 'transports/v2.5.0-prerelease1'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'transports/v2.5.0-rc.1'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'transports/v2.5.0+build'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'ent-v99.0.0-base'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'plugins/telemetry/v99.0.0'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'core/v99.0.0'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'framework/v99.0.0'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'cli/v99.0.0'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'helm-chart-v99.0.0'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'npx/v99.0.0'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'v99.0.0'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'transports/v2.4'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'transports/v2.4.0.1'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'other/transports/v99.0.0'; draft = $false; prerelease = $false; expected = '' }
        @{ tag = 'Transports/v99.0.0'; draft = $false; prerelease = $false; expected = '' }
    ) {
        param($tag, $draft, $prerelease, $expected)
        $page = ConvertTo-Json -InputObject @(@{ tag_name = $tag; draft = $draft; prerelease = $prerelease })
        Get-SelectedBifrostVersion $page | Should Be $expected
    }

    It 'finds the gateway among newer unrelated releases and multiple stable versions' {
        $page = ConvertTo-Json -InputObject @(
            @{ tag_name = 'ent-v99.0.0-base'; draft = $false; prerelease = $false }
            @{ tag_name = 'plugins/logging/v99.0.0'; draft = $false; prerelease = $false }
            @{ tag_name = 'transports/v99.0.0'; draft = $true; prerelease = $false }
            @{ tag_name = 'transports/v98.0.0'; draft = $false; prerelease = $true }
            @{ tag_name = 'transports/v97.0.0-rc.1'; draft = $false; prerelease = $false }
            @{ tag_name = 'cli/v99.0.0'; draft = $false; prerelease = $false }
            @{ tag_name = 'transports/v2.4.0'; draft = $false; prerelease = $false }
            @{ tag_name = 'transports/v2.3.2'; draft = $false; prerelease = $false }
        )
        Get-SelectedBifrostVersion $page | Should Be '2.4.0'
    }

    It 'finds no update when the release page is empty or has no gateway release' -TestCases @(
        @{ page = '[]' }
        @{ page = '[{"tag_name":"ent-v99.0.0-base","draft":false,"prerelease":false}]' }
        @{ page = '[{"tag_name":"transports/v99.0.0"}]' }
    ) {
        param($page)
        Get-SelectedBifrostVersion $page | Should BeNullOrEmpty
    }

    It 'keeps the newer gateway when an older maintenance release appears first' {
        $page = ConvertTo-Json -InputObject @(
            @{ tag_name = 'transports/v2.3.2'; draft = $false; prerelease = $false }
            @{ tag_name = 'transports/v2.4.0'; draft = $false; prerelease = $false }
        )
        Get-SelectedBifrostVersion $page | Should Be '2.4.0'
    }

    It 'sorts version components numerically instead of lexically' {
        $page = ConvertTo-Json -InputObject @(
            @{ tag_name = 'transports/v2.4.9'; draft = $false; prerelease = $false }
            @{ tag_name = 'transports/v2.4.10'; draft = $false; prerelease = $false }
        )
        Get-SelectedBifrostVersion $page | Should Be '2.4.10'
    }

    It 'never selects a version older than the installed manifest' {
        $page = '[{"tag_name":"transports/v2.3.2","draft":false,"prerelease":false}]'
        Get-SelectedBifrostVersion $page | Should BeNullOrEmpty
    }
}
