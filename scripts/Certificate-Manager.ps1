# FastCopy 证书管理脚本
# 用于本地开发环境的证书生成和管理

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("Generate", "Install", "Remove", "List", "Sign", "Verify")]
    [string]$Action = "Generate",
    
    [Parameter(Mandatory=$false)]
    [string]$CertificateSubject = "CN=FastCopy Developer",
    
    [Parameter(Mandatory=$false)]
    [string]$CertificatePassword = "FastCopy123!",
    
    [Parameter(Mandatory=$false)]
    [int]$ValidityDays = 365,
    
    [Parameter(Mandatory=$false)]
    [string]$FilePath = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# 证书文件名
$CertName = "FastCopy-CodeSigning"
$PfxFile = "$CertName.pfx"
$CrtFile = "$CertName.crt"

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""
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

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Generate-Certificate {
    Write-Header "生成新的代码签名证书"
    
    try {
        # 检查是否已存在证书
        $existingCert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $CertificateSubject }
        
        if ($existingCert -and -not $Force) {
            Write-Warning "证书已存在。使用 -Force 参数强制重新生成。"
            Write-Info "现有证书信息："
            Write-Host "  主题: $($existingCert.Subject)" -ForegroundColor White
            Write-Host "  指纹: $($existingCert.Thumbprint)" -ForegroundColor White
            Write-Host "  过期时间: $($existingCert.NotAfter)" -ForegroundColor White
            return
        }
        
        # 删除现有证书（如果使用 -Force）
        if ($existingCert -and $Force) {
            Write-Info "删除现有证书..."
            $existingCert | Remove-Item
        }
        
        Write-Info "创建新的自签名证书..."
        Write-Host "  主题: $CertificateSubject" -ForegroundColor White
        Write-Host "  有效期: $ValidityDays 天" -ForegroundColor White
        
        $cert = New-SelfSignedCertificate `
            -Type CodeSigningCert `
            -Subject $CertificateSubject `
            -KeyAlgorithm RSA `
            -KeyLength 2048 `
            -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider" `
            -KeyExportPolicy Exportable `
            -KeyUsage DigitalSignature `
            -CertStoreLocation Cert:\CurrentUser\My `
            -NotAfter (Get-Date).AddDays($ValidityDays)
        
        Write-Success "证书创建成功！"
        Write-Host "  指纹: $($cert.Thumbprint)" -ForegroundColor White
        Write-Host "  生效时间: $($cert.NotBefore)" -ForegroundColor White
        Write-Host "  过期时间: $($cert.NotAfter)" -ForegroundColor White
        
        # 导出证书文件
        Write-Info "导出证书文件..."
        
        $password = ConvertTo-SecureString -String $CertificatePassword -Force -AsPlainText
        Export-PfxCertificate -cert "Cert:\CurrentUser\My\$($cert.thumbprint)" -FilePath $PfxFile -Password $password | Out-Null
        Export-Certificate -Cert "Cert:\CurrentUser\My\$($cert.thumbprint)" -FilePath $CrtFile | Out-Null
        
        Write-Success "证书文件已导出："
        Write-Host "  $PfxFile (私钥+证书，用于签名)" -ForegroundColor White
        Write-Host "  $CrtFile (公钥证书，用于安装信任)" -ForegroundColor White
        
        # 创建信息文件
        $certInfo = @"
FastCopy 代码签名证书信息
========================

证书详情:
  主题: $($cert.Subject)
  颁发者: $($cert.Issuer)
  指纹: $($cert.Thumbprint)
  序列号: $($cert.SerialNumber)
  生效时间: $($cert.NotBefore)
  过期时间: $($cert.NotAfter)
  算法: $($cert.PublicKey.Oid.FriendlyName)
  密钥长度: $($cert.PublicKey.Key.KeySize) 位

文件说明:
  $PfxFile - 包含私钥的证书文件（密码: $CertificatePassword）
  $CrtFile - 公钥证书文件（用于信任安装）
  
安装信任证书（管理员权限）:
  Import-Certificate -FilePath "$CrtFile" -CertStoreLocation Cert:\LocalMachine\Root

使用证书签名:
  signtool sign /fd SHA256 /f "$PfxFile" /p "$CertificatePassword" "your-file.exe"

生成时间: $(Get-Date)
"@
        
        $certInfo | Out-File -FilePath "Certificate-Info.txt" -Encoding UTF8
        Write-Success "证书信息已保存到 Certificate-Info.txt"
        
    } catch {
        Write-Error "证书生成失败: $($_.Exception.Message)"
        throw
    }
}

function Install-Certificate {
    Write-Header "安装证书到信任存储"
    
    if (-not (Test-Path $CrtFile)) {
        Write-Error "证书文件 $CrtFile 不存在。请先生成证书。"
        return
    }
    
    if (-not (Test-AdminRights)) {
        Write-Warning "需要管理员权限来安装证书到受信任的根证书颁发机构。"
        Write-Info "请以管理员身份运行此脚本，或手动安装证书。"
        
        Write-Host ""
        Write-Host "手动安装步骤：" -ForegroundColor Yellow
        Write-Host "1. 双击 $CrtFile 文件" -ForegroundColor White
        Write-Host "2. 点击 '安装证书...'" -ForegroundColor White
        Write-Host "3. 选择 '本地计算机'" -ForegroundColor White
        Write-Host "4. 选择 '将所有的证书都放入下列存储'" -ForegroundColor White
        Write-Host "5. 浏览并选择 '受信任的根证书颁发机构'" -ForegroundColor White
        Write-Host "6. 完成安装" -ForegroundColor White
        return
    }
    
    try {
        Write-Info "安装证书到受信任的根证书颁发机构..."
        Import-Certificate -FilePath $CrtFile -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
        
        Write-Info "安装证书到受信任的发布者..."
        Import-Certificate -FilePath $CrtFile -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null
        
        Write-Success "证书安装成功！应用程序现在可以信任使用此证书签名的文件。"
        
    } catch {
        Write-Error "证书安装失败: $($_.Exception.Message)"
        throw
    }
}

function Remove-Certificate {
    Write-Header "删除证书"
    
    try {
        # 从个人存储删除
        $personalCerts = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq $CertificateSubject }
        foreach ($cert in $personalCerts) {
            Write-Info "从个人存储删除证书: $($cert.Thumbprint)"
            $cert | Remove-Item
        }
        
        if (Test-AdminRights) {
            # 从受信任的根证书颁发机构删除
            $rootCerts = Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.Subject -eq $CertificateSubject }
            foreach ($cert in $rootCerts) {
                Write-Info "从受信任的根证书颁发机构删除证书: $($cert.Thumbprint)"
                $cert | Remove-Item
            }
            
            # 从受信任的发布者删除
            $publisherCerts = Get-ChildItem -Path Cert:\LocalMachine\TrustedPublisher | Where-Object { $_.Subject -eq $CertificateSubject }
            foreach ($cert in $publisherCerts) {
                Write-Info "从受信任的发布者删除证书: $($cert.Thumbprint)"
                $cert | Remove-Item
            }
        } else {
            Write-Warning "需要管理员权限来删除系统存储中的证书。"
        }
        
        # 删除证书文件
        if (Test-Path $PfxFile) {
            Remove-Item $PfxFile
            Write-Info "删除文件: $PfxFile"
        }
        
        if (Test-Path $CrtFile) {
            Remove-Item $CrtFile
            Write-Info "删除文件: $CrtFile"
        }
        
        if (Test-Path "Certificate-Info.txt") {
            Remove-Item "Certificate-Info.txt"
            Write-Info "删除文件: Certificate-Info.txt"
        }
        
        Write-Success "证书删除完成！"
        
    } catch {
        Write-Error "证书删除失败: $($_.Exception.Message)"
        throw
    }
}

function List-Certificates {
    Write-Header "列出代码签名证书"
    
    Write-Info "个人存储中的代码签名证书："
    $personalCerts = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.EnhancedKeyUsageList -match "Code Signing" }
    
    if ($personalCerts) {
        foreach ($cert in $personalCerts) {
            $daysUntilExpiry = ($cert.NotAfter - (Get-Date)).Days
            $status = if ($daysUntilExpiry -lt 0) { "已过期" } elseif ($daysUntilExpiry -lt 30) { "即将过期" } else { "有效" }
            $statusColor = if ($daysUntilExpiry -lt 0) { "Red" } elseif ($daysUntilExpiry -lt 30) { "Yellow" } else { "Green" }
            
            Write-Host ""
            Write-Host "  主题: $($cert.Subject)" -ForegroundColor White
            Write-Host "  指纹: $($cert.Thumbprint)" -ForegroundColor Gray
            Write-Host "  过期时间: $($cert.NotAfter)" -ForegroundColor White
            Write-Host "  状态: $status ($daysUntilExpiry 天)" -ForegroundColor $statusColor
        }
    } else {
        Write-Warning "未找到代码签名证书。"
    }
    
    Write-Host ""
    Write-Info "证书文件状态："
    if (Test-Path $PfxFile) {
        Write-Host "  ✅ $PfxFile 存在" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $PfxFile 不存在" -ForegroundColor Red
    }
    
    if (Test-Path $CrtFile) {
        Write-Host "  ✅ $CrtFile 存在" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $CrtFile 不存在" -ForegroundColor Red
    }
}

function Sign-File {
    Write-Header "签名文件"
    
    if (-not $FilePath) {
        Write-Error "请使用 -FilePath 参数指定要签名的文件路径。"
        return
    }
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "文件不存在: $FilePath"
        return
    }
    
    if (-not (Test-Path $PfxFile)) {
        Write-Error "证书文件 $PfxFile 不存在。请先生成证书。"
        return
    }
    
    try {
        Write-Info "正在签名文件: $FilePath"
        
        $signResult = & signtool sign /fd SHA256 /f $PfxFile /p $CertificatePassword $FilePath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "文件签名成功！"
        } else {
            Write-Error "文件签名失败："
            Write-Host $signResult -ForegroundColor Red
        }
        
    } catch {
        Write-Error "签名过程中发生错误: $($_.Exception.Message)"
        throw
    }
}

function Verify-Signature {
    Write-Header "验证文件签名"
    
    if (-not $FilePath) {
        Write-Error "请使用 -FilePath 参数指定要验证的文件路径。"
        return
    }
    
    if (-not (Test-Path $FilePath)) {
        Write-Error "文件不存在: $FilePath"
        return
    }
    
    try {
        Write-Info "验证文件签名: $FilePath"
        
        $verifyResult = & signtool verify /pa $FilePath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "文件签名验证成功！"
            Write-Host $verifyResult -ForegroundColor Green
        } else {
            Write-Warning "文件签名验证失败或未签名："
            Write-Host $verifyResult -ForegroundColor Yellow
        }
        
    } catch {
        Write-Error "验证过程中发生错误: $($_.Exception.Message)"
        throw
    }
}

# 主执行逻辑
try {
    Write-Host "FastCopy 证书管理工具" -ForegroundColor Magenta
    Write-Host "当前目录: $(Get-Location)" -ForegroundColor Gray
    Write-Host "执行操作: $Action" -ForegroundColor Gray
    
    switch ($Action) {
        "Generate" { Generate-Certificate }
        "Install" { Install-Certificate }
        "Remove" { Remove-Certificate }
        "List" { List-Certificates }
        "Sign" { Sign-File }
        "Verify" { Verify-Signature }
        default { 
            Write-Error "未知操作: $Action"
            Write-Host "可用操作: Generate, Install, Remove, List, Sign, Verify"
        }
    }
    
} catch {
    Write-Error "操作失败: $($_.Exception.Message)"
    exit 1
}

Write-Host ""
Write-Host "操作完成！" -ForegroundColor Green
