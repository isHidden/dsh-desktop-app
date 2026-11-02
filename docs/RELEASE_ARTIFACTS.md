# 发布制品说明

`latest` Release
提供四个可下载文件。所有制品都来自同一提交，并在四个平台的源码检查与单元测试通过后构建。Windows 包在
Linux 交叉构建，macOS 包在对应架构的 Mac runner 构建、进行 ad-hoc 签名，并在打包后重新解压验证签名。

| 文件                                     | 目标系统            | 渲染后端                | 适用场景                                                             |
| ---------------------------------------- | ------------------- | ----------------------- | -------------------------------------------------------------------- |
| `DSH-Desktop-windows-x86_64-cef.zip`     | Windows x86_64      | 内置 Chromium（CEF）    | 希望应用自带固定浏览器内核，或目标机器无法确认 WebView2 Runtime 状态 |
| `DSH-Desktop-windows-x86_64-webview.zip` | Windows x86_64      | Microsoft Edge WebView2 | 希望下载体积更小，且目标机器已安装 WebView2 Runtime                  |
| `DSH-Desktop-macos-aarch64.tar.gz`       | Apple Silicon macOS | 内置 Chromium（CEF）    | M 系列 Mac                                                           |
| `DSH-Desktop-macos-x86_64.tar.gz`        | Intel macOS         | 内置 Chromium（CEF）    | Intel Mac                                                            |

## Windows CEF

CEF ZIP 包含 Chromium 运行库，因此目录较大，渲染内核不依赖系统 Edge 版本。

1. 完整解压 ZIP。
2. 运行目录中的 `DSH-Desktop.exe`。
3. 更新时关闭应用，再用新版 CEF 完整目录替换旧目录。

## Windows WebView2

WebView2 ZIP 使用系统安装的 Microsoft Edge WebView2 Runtime，因此目录明显更小。Windows 10/11
通常已随 Edge 或系统组件安装该 Runtime；缺失时需先安装 Microsoft Edge WebView2 Evergreen Runtime。

1. 完整解压 ZIP。
2. 运行目录中的 `DSH-Desktop.exe`。
3. 更新时关闭应用，再用新版 WebView2 完整目录替换旧目录。

两个 Windows 版本共享服务器配置和日志目录，可在同一台机器上分别测试。两者都依赖系统 OpenSSH
Client，都是便携目录应用，无需安装程序或管理员权限。

## macOS Apple Silicon

`DSH-Desktop-macos-aarch64.tar.gz` 包含完整 `.app`、CEF Framework 符号链接和可执行权限。使用系统
`tar` 解压：

```bash
tar -xzf DSH-Desktop-macos-aarch64.tar.gz
open DSH-Desktop.app
```

## macOS Intel

`DSH-Desktop-macos-x86_64.tar.gz` 面向 Intel Mac，解压与启动方式相同：

```bash
tar -xzf DSH-Desktop-macos-x86_64.tar.gz
open DSH-Desktop.app
```

### macOS 首次启动与“已损坏”排查

两个 macOS 包使用 ad-hoc 签名，尚未进行 Apple Developer ID 签名和 notarization。ad-hoc
签名保证应用包的完整性，不代表 Apple 已认可发布者。浏览器下载的包可能带有 `com.apple.quarantine`
属性，仍会受到 Gatekeeper 拦截；签名检查通过不代表 `spctl` 会接受它。

在解压目录检查完整性（把路径换成实际 `.app` 位置）：

```bash
app="$PWD/DSH-Desktop.app"
codesign --verify --deep --strict --verbose=4 "$app"
spctl --assess --type execute --verbose=4 "$app"
xattr -p com.apple.quarantine "$app"
```

`codesign` 应成功；未公证的 ad-hoc 包被 `spctl` 拒绝是预期结果。确认来自你信任的项目 Release
且签名检查通过后，可在系统设置的“隐私与安全性”中选择“仍要打开”。若系统仍提示“已损坏”，可仅对这个
应用移除下载隔离属性，再启动：

```bash
xattr -dr com.apple.quarantine "$app"
open "$app"
```

旧版 Linux 交叉构建包没有完成组装后的应用签名：Deno 2.9.7 在非 macOS 主机会跳过这一步。 如果旧包的
`codesign` 检查失败，优先下载新版完整包。必须临时使用可信的旧包时，可以在自己的 Mac 上重新做本地
ad-hoc 签名，然后验证和移除该应用的隔离属性：

```bash
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict --verbose=4 "$app" &&
  xattr -dr com.apple.quarantine "$app" &&
  open "$app"
```

重新签名不能证明旧包来源可信。面向普通用户免除上述首次启动操作，需要后续配置 Apple Developer ID
证书并完成 notarization。

## Release 更新规则

`latest` 是滚动发布：新的 `main` 提交只有在 Linux、Windows、macOS 四个测试任务和 Windows/macOS
四个分发构建全部成功后，才会删除旧 `latest` Release 和同名 tag，再重新创建同名 Release。 Release
页面会记录来源提交和 GitHub Actions 运行链接，发布时间也会随重建刷新。客户端使用 `target_commitish`
作为发布 commit id，仅当它与应用内的构建 commit id 不一致时提示更新，用户确认后打开 Release
页面手动下载。Pull Request 运行测试及 macOS 打包、解包签名验证和启动检查，产物保存在 Actions
artifacts，不更新 Release；任何测试或打包失败都会保留上一版 Release。

Linux 源码构建任务继续保留在仓库中，`latest` Release 当前不提供 Linux 预构建文件，因此 Linux
不启用更新检查。
