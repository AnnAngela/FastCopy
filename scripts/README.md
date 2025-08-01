# FastCopy 构建脚本

这个文件夹包含了用于 FastCopy 项目的构建和证书管理脚本。

## 📁 文件说明

### PowerShell 脚本

#### `Certificate-Manager.ps1`
完整的证书管理工具，提供以下功能：
- 生成新的自签名代码签名证书
- 安装证书到系统信任存储
- 删除证书和相关文件
- 列出现有证书
- 签名指定文件
- 验证文件签名

#### `Build-Local.ps1`
本地构建脚本，用于在开发环境中构建项目：
- 自动检查构建环境
- 恢复项目依赖（NuGet、vcpkg）
- 构建解决方案
- 自动生成证书（如需要）
- 代码签名
- 生成构建摘要

### 批处理文件

#### `cert-manager.bat`
Certificate-Manager.ps1 的简化调用包装器，提供易用的命令行界面。

## 🚀 使用方法

### 证书管理

#### 使用 PowerShell 脚本（推荐）

```powershell
# 生成新证书
.\Certificate-Manager.ps1 -Action Generate

# 安装证书到信任存储（需要管理员权限）
.\Certificate-Manager.ps1 -Action Install

# 列出现有证书
.\Certificate-Manager.ps1 -Action List

# 签名文件
.\Certificate-Manager.ps1 -Action Sign -FilePath "C:\path\to\file.exe"

# 验证签名
.\Certificate-Manager.ps1 -Action Verify -FilePath "C:\path\to\file.exe"

# 删除证书
.\Certificate-Manager.ps1 -Action Remove
```

#### 高级选项

```powershell
# 使用自定义证书主题和有效期
.\Certificate-Manager.ps1 -Action Generate -CertificateSubject "CN=My Company" -ValidityDays 730

# 强制重新生成证书
.\Certificate-Manager.ps1 -Action Generate -Force

# 使用自定义密码
.\Certificate-Manager.ps1 -Action Generate -CertificatePassword "MyPassword123!"
```

#### 使用批处理文件

```cmd
REM 生成证书
cert-manager.bat generate

REM 安装证书
cert-manager.bat install

REM 签名文件
cert-manager.bat sign "C:\path\to\file.exe"

REM 列出证书
cert-manager.bat list
```

### 本地构建

#### 基本构建

```powershell
# 默认构建（Release x64）
.\Build-Local.ps1

# 指定配置和平台
.\Build-Local.ps1 -Configuration Debug -Platform x86

# 完整构建流程
.\Build-Local.ps1 -Configuration Release -Platform x64 -RestorePackages -GenerateCertificate
```

#### 构建选项

```powershell
# 清理后构建
.\Build-Local.ps1 -Clean

# 恢复包依赖
.\Build-Local.ps1 -RestorePackages

# 生成新证书
.\Build-Local.ps1 -GenerateCertificate

# 跳过代码签名
.\Build-Local.ps1 -SkipSigning

# 自定义输出目录
.\Build-Local.ps1 -OutputDir "C:\MyBuilds\FastCopy"
```

#### 多平台构建示例

```powershell
# 构建所有平台
$platforms = @("x86", "x64", "arm64")
foreach ($platform in $platforms) {
    Write-Host "Building for $platform..."
    .\Build-Local.ps1 -Platform $platform -Configuration Release -Clean
}
```

## 🔧 配置

### 默认设置

- **证书主题**: `CN=FastCopy Developer`
- **证书密码**: `FastCopy123!`
- **证书有效期**: 365 天
- **构建配置**: Release
- **目标平台**: x64
- **输出目录**: `.\Build\Output`

### 自定义配置

您可以修改脚本中的以下变量来自定义配置：

#### Certificate-Manager.ps1
```powershell
$CertificateSubject = "CN=Your Company Name"
$CertificatePassword = "YourPassword123!"
$ValidityDays = 730  # 2年有效期
```

#### Build-Local.ps1
```powershell
$Configuration = "Debug"           # 或 "Release"
$Platform = "x86"                  # 或 "x64", "arm64"
$OutputDir = "C:\Custom\Output"    # 自定义输出路径
$CertificatePassword = "NewPass!"  # 自定义证书密码
```

## 🛡️ 安全注意事项

### 证书安全
- **私钥保护**: PFX 文件包含私钥，请妥善保管
- **密码安全**: 不要在代码中硬编码密码
- **证书分发**: 只分发 CRT 文件给最终用户
- **定期更新**: 建议定期更新证书

### 文件权限
```powershell
# 设置 PFX 文件权限（仅当前用户可读）
$acl = Get-Acl "FastCopy-CodeSigning.pfx"
$acl.SetAccessRuleProtection($true, $false)
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
$acl.SetAccessRule($accessRule)
Set-Acl "FastCopy-CodeSigning.pfx" $acl
```

## 🐛 故障排除

### 常见问题

#### 1. PowerShell 执行策略错误
```powershell
# 临时设置执行策略
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# 或者使用参数运行
powershell -ExecutionPolicy Bypass -File ".\Certificate-Manager.ps1"
```

#### 2. 证书生成失败
- 确保以管理员权限运行
- 检查系统时间是否正确
- 确认没有同名证书存在（使用 -Force 强制覆盖）

#### 3. 签名失败
- 验证证书文件存在且密码正确
- 确认 signtool.exe 在 PATH 中
- 检查文件是否被其他程序占用

#### 4. 构建失败
- 确认 Visual Studio 或 Build Tools 已安装
- 检查项目依赖是否正确恢复
- 验证 vcpkg 配置（如果使用）

### 调试模式

#### 启用详细日志
```powershell
# PowerShell 详细模式
$VerbosePreference = "Continue"
.\Build-Local.ps1 -Verbose

# MSBuild 详细日志
.\Build-Local.ps1 -Configuration Release -Platform x64
# 修改脚本中的 /v:normal 为 /v:detailed
```

#### 检查证书状态
```powershell
# 列出所有个人证书
Get-ChildItem -Path Cert:\CurrentUser\My

# 检查特定证书
Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -like "*FastCopy*" }

# 验证证书有效性
$cert = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -eq "CN=FastCopy Developer" }
if ($cert) {
    Write-Host "证书有效期: $($cert.NotBefore) 到 $($cert.NotAfter)"
    Write-Host "剩余天数: $(($cert.NotAfter - (Get-Date)).Days)"
}
```

## 📚 相关资源

- [PowerShell 代码签名](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/)
- [MSBuild 命令行参考](https://docs.microsoft.com/en-us/visualstudio/msbuild/msbuild-command-line-reference)
- [vcpkg 包管理器](https://github.com/microsoft/vcpkg)
- [Windows 应用打包](https://docs.microsoft.com/en-us/windows/msix/)
- [SignTool 参考](https://docs.microsoft.com/en-us/windows/win32/seccrypto/signtool)

## 📝 更新日志

### v1.0.0
- 初始版本
- 基本证书管理功能
- 本地构建支持
- 多平台构建
- 自动代码签名
