# CI/CD 说明

这个模板自带一套不依赖具体语言栈的 CI/CD 骨架。

## 当前 release 入口

- `scripts/release-package.sh`：构建 universal `Open Computer Use.app`，cross-compile Linux / Windows runtime，stage 三个既有 root/alias npm 包；每个包都会内置 macOS app、Linux binaries 和 Windows exes，并暴露 `open-computer-use` / `ocu` 等 npm bin 入口，产出 `dist/release/npm/*.tgz` 与 `dist/release/release-manifest.json`。当前 CI 继续显式使用 ad-hoc signing，保持和此前发布链路一致；本地 debug/dev 构建则允许使用开发机自己的签名身份。
- `scripts/build-open-computer-use-linux.sh`：本地构建实验性 Linux `open-computer-use` binary，支持 `arm64` / `amd64`；release package 会把这两个产物内置进既有 npm 包的 `dist/linux/`。
- `scripts/build-open-computer-use-windows.sh`：本地构建实验性 Windows `open-computer-use.exe`，支持 `arm64` / `amd64`；release package 会把这两个产物内置进既有 npm 包的 `dist/windows/`。
- `.github/workflows/release.yml`：支持 push semver tag 自动发布，也支持手动触发；tag push 时会跑 npm release 打包逻辑并发布 npm 包。`Open Computer Use` 的 npm 产物默认走 ad-hoc signing；如果配置了 `OPEN_COMPUTER_USE_CODESIGN_*` secrets，则会先导入 `Developer ID Application` 证书，再按同一 identity 对 release `.app` 统一签名。

## macOS CI（`ci-macos.yml`）

- `.github/workflows/ci-macos.yml`：push 到 `main` 与所有 PR 触发，跑在 **`macos-26`**（带版本号的 GitHub-hosted macOS runner，与 `release.yml` 相同标签——稳定、预装 Xcode + Swift 工具链）。action 全部 pin 到 commit SHA。
- `scripts/ci-macos.sh` 依次执行：
  1. 脚本卫生检查（所有 `scripts/*.sh` 过 `bash -n`、所有 `scripts/*.mjs` 过 `node --check`）；
  2. `swift build` —— 完整编译 Swift package（Kit + app + fixture）；
  3. `swift test` —— 单元测试：所有**纯测试**都跑；依赖真实 GUI / 权限的 **live 测试**由 `OCU_RUN_LIVE_TESTS` 门控（默认关），CI 中默认 skip，因此 CI 绝不会拉起 GUI 应用、也不会卡在 TCC 授权弹窗上；
  4. `scripts/build-open-computer-use-app.sh debug` —— 校验 macOS app bundle 打包链路（Info.plist、iconset、ad-hoc codesign 路径）；
  5. `go vet` + `go build` —— release tooling（平台无关）。

**CI 里跑不了的测试（按任务要求显式记录）：**

- live fixture 测试（`WindowManagementTests` 的 "Live fixture tests" / "Window identity" 段，以及最小化窗口列出的 live 测试）：需要真实 GUI 会话，且多数断言需要测试进程被授予 Accessibility；CI runner 没有 TCC 授权，弹窗会挂死构建。本地运行：`OCU_RUN_LIVE_TESTS=1 swift test`。
- SkyClick live 测试：额外依赖 SkyLight SPI 与一个运行中的 Chrome 实例（`OPEN_COMPUTER_USE_RUN_SKY_CLICK_LIVE_TEST=1`）。
- `launch_app` live 测试：会启动 Calculator（`OCU_RUN_LIVE_TESTS=1`）。

## 设计原则

这套默认流水线的目标，是在项目真正成形前先把交付链路搭起来，而不是假装已经知道未来项目该怎么 build 和 deploy。

当新项目的技术栈确定后，你应该继续在 `scripts/release-package.sh` 这条真实构建链路上扩展，而不是另起一套平行流程。

所有 GitHub Actions 都已经 pin 到 commit SHA。后续升级 action 时，也要继续保持这个约束。

## 推荐接入顺序

1. 保留 `ci.yml`，作为仓库的基础门禁。
2. 在 `scripts/ci.sh` 里继续叠加项目自己的验证命令。
3. 在 `scripts/release-package.sh` 已有的真实构建基础上继续扩展 release 产物。
4. 技术栈和环境稳定后，再补具体的部署 job。
5. 即使交付方式变化，SBOM 和 provenance 这类供应链能力也建议保留。

## 默认 release 产物

当前 release 流水线会产出：

- `dist/release/release-manifest.json`
- `dist/release/npm/antonkhakhalin-open-computer-use-<version>.tgz`（fork 包名 `@antonkhakhalin/open-computer-use`）
- GitHub Actions 中上传的 npm release artifact

也就是说，即使项目还没进入更复杂的部署阶段，仓库现在也已经同时具备了一条真实可复用的 npm 制品封装链路，以及一条由 git tag 驱动的 macOS app DMG 交付链路。
