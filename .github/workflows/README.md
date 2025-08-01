# FastCopy GitHub Actions 构建流程

这个项目包含了两个 GitHub Actions workflow 文件，用于自动化构建和证书管理。

## 📁 Workflow 文件

### 1. `build.yml` - 主构建流程
自动构建 FastCopy 项目，支持多平台（x64, x86, arm64）并使用自签名证书进行代码签名。

**触发条件：**
- 推送到 `master` 或 `main` 分支
- 创建以 `v` 开头的标签（如 `v1.0.0`）
- Pull Request 到 `master` 或 `main` 分支
- 手动触发

**构建输出：**
- 已签名的 APPX/MSIX 安装包
- 自签名证书文件（用于安装时的信任设置）

### 2. `certificate.yml` - 证书管理流程
用于生成、续期或导出代码签名证书。

**功能：**
- 生成新的自签名证书
- 续期现有证书
- 导出现有证书

## 🚀 使用指南

### 自动构建（推荐）

1. **推送代码触发构建：**
   ```bash
   git add .
   git commit -m "feat: 添加新功能"
   git push origin master
   ```

2. **创建发布版本：**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
   
   这将触发构建并自动创建 GitHub Release。

### 手动构建

1. 转到 GitHub 仓库的 Actions 页面
2. 选择 "Build FastCopy" workflow
3. 点击 "Run workflow" 按钮
4. 选择分支并运行

### 证书管理

1. 转到 GitHub 仓库的 Actions 页面
2. 选择 "Certificate Management" workflow
3. 点击 "Run workflow" 按钮
4. 选择操作类型：
   - **Generate**: 生成新证书
   - **Renew**: 续期现有证书
   - **Export**: 导出现有证书

## 📦 构建产物

每次成功构建后，将生成以下产物：

### 应用安装包
- `FastCopy-x64-Release/`: 64位版本
- `FastCopy-x86-Release/`: 32位版本
- `FastCopy-arm64-Release/`: ARM64版本

每个包含：
- `.appx` 或 `.appxbundle` 文件（已签名）
- `.appxsym` 符号文件（如果有）

### 证书文件
- `FastCopy-SelfSigned.pfx`: 包含私钥的证书（用于签名）
- `FastCopy-SelfSigned.crt`: 公钥证书（用于信任设置）

## 🔐 安全和证书信任

### 对于开发者

1. **证书密码**: `FastCopy123!`（可在 workflow 中修改）
2. **证书主题**: `CN=FastCopy Developer`
3. **有效期**: 365天（可在证书管理 workflow 中自定义）

### 对于用户

由于使用自签名证书，用户首次安装时需要：

1. **方法一：安装证书（推荐）**
   ```powershell
   # 以管理员身份运行 PowerShell
   Import-Certificate -FilePath "FastCopy-SelfSigned.crt" -CertStoreLocation Cert:\LocalMachine\Root
   ```

2. **方法二：手动信任**
   - 双击 `.crt` 文件
   - 选择"安装证书"
   - 选择"本地计算机"
   - 选择"将所有的证书都放入下列存储" → "受信任的根证书颁发机构"

3. **方法三：开发者模式（Windows 10/11）**
   - 设置 → 更新和安全 → 开发者选项
   - 启用"开发人员模式"

## 🛠️ 自定义配置

### 修改证书信息

编辑 `.github/workflows/build.yml` 中的环境变量：

```yaml
env:
  CERTIFICATE_NAME: FastCopy-SelfSigned
  CERTIFICATE_PASSWORD: FastCopy123!  # 修改密码
```

在生成证书步骤中修改主题：
```powershell
$cert = New-SelfSignedCertificate -Subject "CN=您的公司名称"  # 修改主题
```

### 修改构建配置

在 `build.yml` 中修改：

```yaml
env:
  BUILD_CONFIGURATION: Release  # Debug 或 Release
  
strategy:
  matrix:
    platform: [x64, x86, arm64]  # 移除不需要的平台
```

### 添加额外的签名文件

在签名步骤中添加更多文件类型：

```powershell
$packageFiles = Get-ChildItem -Path "AppPackages" -Recurse -Include "*.exe", "*.dll", "*.appx", "*.appxbundle"
```

## 🐛 故障排除

### 常见问题

1. **vcpkg 依赖安装失败**
   - 检查 `vcpkg.json` 中的依赖版本
   - 确认 vcpkg baseline commit 是有效的

2. **证书生成失败**
   - 确保在 Windows runner 上运行
   - 检查 PowerShell 执行策略

3. **签名失败**
   - 确认证书文件存在
   - 检查证书密码是否正确
   - 验证 signtool 是否可用

4. **构建失败**
   - 检查 MSBuild 版本兼容性
   - 确认项目文件路径正确
   - 验证 NuGet 包恢复是否成功

### 调试步骤

1. **查看构建日志**
   - 转到 Actions 页面查看详细日志
   - 查看失败的步骤和错误信息

2. **本地测试**
   ```bash
   # 安装 vcpkg 依赖
   vcpkg install --triplet=x64-windows
   
   # 构建项目
   msbuild FastCopy.sln /p:Configuration=Release /p:Platform=x64
   ```

3. **证书验证**
   ```powershell
   # 检查证书存储
   Get-ChildItem -Path Cert:\CurrentUser\My
   
   # 验证签名
   signtool verify /pa "your-file.appx"
   ```

## 📄 许可证

请确保您的证书使用和代码签名符合相关法律法规和许可证要求。

## 🔗 相关链接

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [MSBuild 参考](https://docs.microsoft.com/en-us/visualstudio/msbuild/)
- [vcpkg 包管理器](https://github.com/microsoft/vcpkg)
- [Windows 应用打包](https://docs.microsoft.com/en-us/windows/msix/)
- [代码签名最佳实践](https://docs.microsoft.com/en-us/windows/win32/seccrypto/cryptography-tools)
