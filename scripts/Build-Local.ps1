# FastCopy 本地构建脚本
# 用于在本地环境构建和签名 FastCopy 项目

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("x86", "x64", "arm64")]
    [string]$Platform = "x64",
    
    [Parameter(Mandatory=$false)]
    [switch]$Clean,
    
    [Parameter(Mandatory=$false)]
    [switch]$RestorePackages,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateCertificate,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSigning,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\Build\Output"
)

$ErrorActionPreference = "Stop"

# 配置变量
$SolutionFile = "FastCopy.sln"
$CertificatePassword = "FastCopy123!"
$CertificateName = "FastCopy-CodeSigning"
$CertificateSubject = "CN=FastCopy Developer"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host "🔄 $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-Prerequisites {
    Write-Section "检查构建环境"
    
    # 检查解决方案文件
    if (-not (Test-Path $SolutionFile)) {
        Write-Error "找不到解决方案文件: $SolutionFile"
        throw "解决方案文件不存在"
    }
    Write-Success "解决方案文件: $SolutionFile"
    
    # 检查 MSBuild
    try {
        $msbuildPath = & where msbuild 2>$null
        if ($msbuildPath) {
            Write-Success "MSBuild: $msbuildPath"
        } else {
            throw "MSBuild not found"
        }
    } catch {
        Write-Error "未找到 MSBuild。请确保已安装 Visual Studio 或 Build Tools。"
        throw "MSBuild 不可用"
    }
    
    # 检查 vcpkg（如果存在）
    if (Test-Path "vcpkg.json") {
        try {
            $vcpkgPath = & where vcpkg 2>$null
            if ($vcpkgPath) {
                Write-Success "vcpkg: $vcpkgPath"
            } else {
                Write-Warning "未找到 vcpkg。如果项目需要 vcpkg 依赖，请确保已安装并配置。"
            }
        } catch {
            Write-Warning "vcpkg 检查失败，但将继续构建。"
        }
    }
    
    # 检查 signtool（用于代码签名）
    if (-not $SkipSigning) {
        try {
            $signtoolPath = & where signtool 2>$null
            if ($signtoolPath) {
                Write-Success "SignTool: $signtoolPath"
            } else {
                Write-Warning "未找到 SignTool。将跳过代码签名步骤。"
                $script:SkipSigning = $true
            }
        } catch {
            Write-Warning "SignTool 检查失败。将跳过代码签名步骤。"
            $script:SkipSigning = $true
        }
    }
}

function Initialize-BuildEnvironment {
    Write-Section "初始化构建环境"
    
    # 创建输出目录
    if (-not (Test-Path $OutputDir)) {
        Write-Step "创建输出目录: $OutputDir"
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-Success "输出目录已创建"
    }
    
    # 生成证书（如果需要）
    if ($GenerateCertificate -or (-not (Test-Path "$CertificateName.pfx") -and -not $SkipSigning)) {
        Write-Step "生成代码签名证书"
        
        # 检查是否已存在证书
        $existingCert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $CertificateSubject } | Select-Object -First 1
        
        if (-not $existingCert -or $GenerateCertificate) {
            if ($existingCert -and $GenerateCertificate) {
                Write-Step "删除现有证书"
                $existingCert | Remove-Item
            }
            
            $cert = New-SelfSignedCertificate `
                -Type CodeSigningCert `
                -Subject $CertificateSubject `
                -KeyAlgorithm RSA `
                -KeyLength 2048 `
                -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
                -KeyExportPolicy Exportable `
                -KeyUsage DigitalSignature `
                -CertStoreLocation Cert:\CurrentUser\My `
                -NotAfter (Get-Date).AddDays(365)
            
            # 导出证书
            $password = ConvertTo-SecureString -String $CertificatePassword -Force -AsPlainText
            Export-PfxCertificate -cert "Cert:\CurrentUser\My\$($cert.thumbprint)" -FilePath "$CertificateName.pfx" -Password $password | Out-Null
            Export-Certificate -Cert "Cert:\CurrentUser\My\$($cert.thumbprint)" -FilePath "$CertificateName.crt" | Out-Null
            
            Write-Success "证书生成并导出成功"
        } else {
            Write-Success "使用现有证书"
        }
    }
}

function Restore-Dependencies {
    if ($RestorePackages) {
        Write-Section "恢复项目依赖"
        
        # 恢复 NuGet 包
        Write-Step "恢复 NuGet 包"
        try {
            & nuget restore $SolutionFile
            if ($LASTEXITCODE -eq 0) {
                Write-Success "NuGet 包恢复成功"
            } else {
                Write-Warning "NuGet 包恢复失败，但将继续构建"
            }
        } catch {
            Write-Warning "NuGet 恢复失败: $($_.Exception.Message)"
        }
        
        # 安装 vcpkg 依赖（如果存在）
        if (Test-Path "vcpkg.json") {
            Write-Step "安装 vcpkg 依赖"
            try {
                & vcpkg install --triplet="$Platform-windows"
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "vcpkg 依赖安装成功"
                } else {
                    Write-Warning "vcpkg 依赖安装失败，但将继续构建"
                }
            } catch {
                Write-Warning "vcpkg 安装失败: $($_.Exception.Message)"
            }
        }
    }
}

function Build-Solution {
    Write-Section "构建解决方案"
    
    if ($Clean) {
        Write-Step "清理解决方案"
        & msbuild $SolutionFile /t:Clean /p:Configuration=$Configuration /p:Platform=$Platform /v:minimal
        Write-Success "解决方案清理完成"
    }
    
    Write-Step "构建解决方案"
    Write-Host "  配置: $Configuration" -ForegroundColor White
    Write-Host "  平台: $Platform" -ForegroundColor White
    
    $buildArgs = @(
        $SolutionFile
        "/p:Configuration=$Configuration"
        "/p:Platform=$Platform"
        "/m"
        "/v:normal"
    )
    
    # 如果是 UWP 应用，添加额外的参数
    if (Test-Path "FastCopy\Package.appxmanifest") {
        $appPackageDir = Join-Path $OutputDir "AppPackages"
        $buildArgs += @(
            "/p:AppxBundlePlatforms=$Platform"
            "/p:AppxPackageDir=$appPackageDir\"
            "/p:AppxBundle=Always"
            "/p:UapAppxPackageBuildMode=SideloadOnly"
        )
        
        # 如果有证书文件，添加签名参数
        if ((Test-Path "$CertificateName.pfx") -and -not $SkipSigning) {
            $buildArgs += @(
                "/p:PackageCertificateKeyFile=$CertificateName.pfx"
                "/p:PackageCertificatePassword=$CertificatePassword"
            )
        }
    }
    
    Write-Host "构建命令: msbuild $($buildArgs -join ' ')" -ForegroundColor Gray
    
    & msbuild @buildArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "解决方案构建成功"
    } else {
        Write-Error "解决方案构建失败"
        throw "构建失败"
    }
}

function Sign-OutputFiles {
    if ($SkipSigning) {
        Write-Warning "跳过代码签名步骤"
        return
    }
    
    if (-not (Test-Path "$CertificateName.pfx")) {
        Write-Warning "证书文件不存在，跳过代码签名"
        return
    }
    
    Write-Section "代码签名"
    
    # 查找需要签名的文件
    $signableExtensions = @("*.exe", "*.dll", "*.appx", "*.appxbundle", "*.msix", "*.msixbundle")
    $filesToSign = @()
    
    foreach ($ext in $signableExtensions) {
        $files = Get-ChildItem -Path $OutputDir -Recurse -Include $ext -ErrorAction SilentlyContinue
        $filesToSign += $files
    }
    
    if ($filesToSign.Count -eq 0) {
        Write-Warning "未找到需要签名的文件"
        return
    }
    
    Write-Step "找到 $($filesToSign.Count) 个文件需要签名"
    
    foreach ($file in $filesToSign) {
        Write-Host "  签名: $($file.Name)" -ForegroundColor White
        
        try {
            & signtool sign /fd SHA256 /f "$CertificateName.pfx" /p $CertificatePassword $file.FullName
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✅ 签名成功" -ForegroundColor Green
            } else {
                Write-Host "    ❌ 签名失败" -ForegroundColor Red
            }
        } catch {
            Write-Host "    ❌ 签名异常: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Success "代码签名完成"
}

function Show-BuildSummary {
    Write-Section "构建摘要"
    
    Write-Host "构建配置:" -ForegroundColor Yellow
    Write-Host "  解决方案: $SolutionFile" -ForegroundColor White
    Write-Host "  配置: $Configuration" -ForegroundColor White
    Write-Host "  平台: $Platform" -ForegroundColor White
    Write-Host "  输出目录: $OutputDir" -ForegroundColor White
    Write-Host "  代码签名: $(if ($SkipSigning) { '跳过' } else { '已执行' })" -ForegroundColor White
    
    Write-Host ""
    Write-Host "输出文件:" -ForegroundColor Yellow
    
    if (Test-Path $OutputDir) {
        $outputFiles = Get-ChildItem -Path $OutputDir -Recurse -File | Where-Object { 
            $_.Extension -in @('.exe', '.dll', '.appx', '.appxbundle', '.msix', '.msixbundle') 
        }
        
        if ($outputFiles) {
            foreach ($file in $outputFiles) {
                $size = [math]::Round($file.Length / 1MB, 2)
                Write-Host "  📁 $($file.Name) ($size MB)" -ForegroundColor White
            }
        } else {
            Write-Warning "输出目录中未找到构建产物"
        }
    }
    
    Write-Host ""
    Write-Success "构建流程完成！"
    
    if (Test-Path "$CertificateName.crt") {
        Write-Host ""
        Write-Host "🔐 安装信任证书 (可选):" -ForegroundColor Yellow
        Write-Host "  Import-Certificate -FilePath '$CertificateName.crt' -CertStoreLocation Cert:\LocalMachine\Root" -ForegroundColor Gray
    }
}

# 主执行流程
try {
    Write-Host "FastCopy 本地构建工具" -ForegroundColor Magenta
    Write-Host "启动时间: $(Get-Date)" -ForegroundColor Gray
    Write-Host ""
    
    Test-Prerequisites
    Initialize-BuildEnvironment
    Restore-Dependencies
    Build-Solution
    Sign-OutputFiles
    Show-BuildSummary
    
} catch {
    Write-Error "构建失败: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
