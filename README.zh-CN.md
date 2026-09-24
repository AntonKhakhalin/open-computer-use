<p align="center">
  <img src="./assets/logo/open-computer-use-256.png" width="144" alt="open-computer-use">
</p>

# Open Computer Use — 增强版 macOS 窗口控制

[![Release](https://img.shields.io/github/v/release/AntonKhakhalin/open-computer-use?label=fork%20release)](https://github.com/AntonKhakhalin/open-computer-use/releases)
[![Fork of opensymph/open-computer-use](https://img.shields.io/badge/fork%20of-opensymph%2Fopen--computer--use-0E7490)](https://github.com/opensymph/open-computer-use)
[![License: MIT](https://img.shields.io/badge/License-MIT-informational)](./LICENSE)
[![English](https://img.shields.io/badge/English-Click-yellow)](./README.md)

面向 Codex、Claude Code、OpenCode、Gemini、Cursor 及其他支持 MCP 的 AI Agent 的本地 Computer Use：一个本地 MCP 服务器，给 Agent 一双看得见桌面、摸得着应用的手——读取应用界面、点击、输入、滚动、拖拽，全部通过无障碍层完成，不抢占你真实的鼠标和键盘。完全本地运行，支持 macOS、Windows 和 Linux。

**安装：** [一条命令](#快速开始) · **短链接：** [`github.com/AntonKhakhalin/ocu`](https://github.com/AntonKhakhalin/ocu) · [opensymph/open-computer-use](https://github.com/opensymph/open-computer-use) 的 fork

```bash
npm i -g https://github.com/AntonKhakhalin/open-computer-use/releases/download/v1.2.1-anton.1/antonkhakhalin-open-computer-use-1.2.1-anton.1.tgz
```

**本 fork 在 macOS 上的增强**（其余全部来自上游，未做改动）：

- **精确窗口定位** —— 每个窗口都是真实的 CGWindowID；同 bounds 窗口按身份解析，绝不"取第一个"。
- **后台窗口观察** —— 无需激活、不抢焦点即可读取指定窗口的无障碍树。
- **最小化窗口观察** —— 最小化窗口仍可在 `list_windows` 中发现、可解析、可观察；最小化状态下 value 写入可用。
- **原生 `launch_app`** —— 后台启动（不抢焦点）、实例复用，返回 `pid` + `windows[]`。
- **窗口级截图** —— `get_window_state` 只截取目标窗口，坐标动作受 `screenshotId` 门禁保护。
- **后台优先的 AX 交互** —— 凡存在可靠的无障碍操作，一律优先于合成输入。

> [!NOTE]
> **本仓库是 [opensymph/open-computer-use](https://github.com/opensymph/open-computer-use) 的 fork。**
> 原始项目、架构与核心实现归属于上游项目。
> 本 fork 加入了目前正向上游提案的 macOS 窗口管理工作
>（[PR #2 — macOS 原生 `launch_app`](https://github.com/opensymph/open-computer-use/pull/2)、
> [PR #3 — macOS 原生窗口管理](https://github.com/opensymph/open-computer-use/pull/3)），
> 以及多 Agent 分发面（fork npm 包、fork GitHub Releases、fork skill 安装地址）。
> 许可证保持 **MIT**。如果你只需要上游稳定版，请直接使用
> [opensymph/open-computer-use](https://github.com/opensymph/open-computer-use)——它本身已经非常完整，
> 本 fork 不代表上游维护者任何形式的背书。

## 为什么是这个 fork

| 能力 | 上游稳定版（`v1.2.0`） | 本 fork |
| --- | --- | --- |
| macOS 原生窗口管理（`list_windows`、`get_window`、`get_window_state`、`activate_window`、窗口定向动作） | 仅 Windows；macOS "进行中" | **已包含并经过测试**（上游提案 [PR #3](https://github.com/opensymph/open-computer-use/pull/3)） |
| macOS 原生 `launch_app`（后台启动、实例复用、返回 `pid` + `windows[]`） | 不可用 | **已包含并经过测试**（上游提案 [PR #2](https://github.com/opensymph/open-computer-use/pull/2)） |
| 精确 CGWindowID 窗口身份；同 bounds 窗口消歧；已关闭/幽灵窗口拒绝 | — | 已包含（PR #3） |
| macOS 上带 `screenshotId` 观察门禁的窗口定向坐标动作 | — | 已包含（PR #3） |
| Agent skill 中的 macOS 输入投递与后台操作最佳实践 | — | 已包含 |
| 安装入口 | npm `@opensymph/open-computer-use` | fork npm 包、fork GitHub Releases、fork skill 地址（见下） |

其余一切——九个核心工具、14-tool MCP 面、三平台统一契约、内置护栏——都来自上游，未做改动。

## 支持的 Agent

| Agent | 方式 |
| --- | --- |
| Codex CLI 与 Codex App | `ocu install-codex-mcp` 或 `ocu install-codex-plugin` |
| Claude Code | `ocu install-claude-mcp` |
| OpenCode | `ocu install-opencode-mcp` |
| Gemini CLI | `ocu install-gemini-mcp`（`--scope user` 装到用户级） |
| Cursor | `ocu install-cursor-mcp`（写入 `~/.cursor/mcp.json`；`--scope project` 写入 `./.cursor/mcp.json`） |
| ZCode | [插件安装](#zcode)（skill + 自动连接的 MCP 服务器） |
| 其他任何 MCP 客户端 | [通用 MCP 配置](#通用-mcp-配置) |
| 支持 Agent Skills 的 Agent | [Skill 安装](#skill-安装) |

安装器都是幂等的：检测已有配置、保留无关的 MCP server 与设置，并明确报告写入了什么。

想一条命令配完所有 Agent？`ocu setup` 会检测本机装了哪些 Agent（Codex、Claude Code、OpenCode、Gemini、Cursor），只配置存在的，且绝不覆盖已有条目：

```bash
ocu setup                # 一次性配置所有检测到的 Agent
ocu setup --dry-run      # 先预览会做什么改动
ocu setup --agents codex,claude
```

## 快速开始

最简单的可用路径——从 [GitHub Releases](https://github.com/AntonKhakhalin/open-computer-use/releases) 安装 fork 的 npm tarball：

```bash
npm i -g https://github.com/AntonKhakhalin/open-computer-use/releases/download/v1.2.1-anton.1/antonkhakhalin-open-computer-use-1.2.1-anton.1.tgz
ocu doctor        # 验证安装；macOS 会引导授予 Accessibility + Screen Recording
ocu call list_apps
```

tarball 内置所有支持 `os-arch` 组合的原生运行时（macOS、Windows、Linux），启动器自动选择。fork npm 包发布后，`npm i -g @antonkhakhalin/open-computer-use` 将与之等效。

不想用 npm？从源码构建并链接二进制：

```bash
git clone https://github.com/AntonKhakhalin/open-computer-use.git
cd open-computer-use
./scripts/install-local-runtime.sh   # 构建当前平台的 runtime，链接 open-computer-use + ocu
```

macOS 14+ 需要一次性授予 `Accessibility` 和 `Screen Recording`。Windows 和 Linux 在已登录桌面会话中开箱即用（Linux 桌面需要 AT-SPI2，GNOME 等主流桌面默认自带）。

## 接入 Agent

```bash
ocu setup                  # 自动检测本机所有已安装的 Agent 并一次性配置

# 或显式配置某一个 Agent：
ocu install-codex-mcp      # Codex CLI 与 Codex App
ocu install-codex-plugin   # Codex App 插件形态
ocu install-claude-mcp     # Claude Code
ocu install-gemini-mcp     # Gemini CLI（--scope user 装到用户级）
ocu install-opencode-mcp   # opencode
ocu install-cursor-mcp     # Cursor（用户级；--scope project 写 ./.cursor/mcp.json）
```

### ZCode

本仓库自带 ZCode 插件形态——一次安装同时获得 skill 和自动连接的 MCP 服务器：

1. 先装一次 runtime（插件在本地没有构建产物时会回退到它）：

   ```bash
   npm i -g https://github.com/AntonKhakhalin/open-computer-use/releases/download/v1.2.1-anton.1/antonkhakhalin-open-computer-use-1.2.1-anton.1.tgz
   ```

2. 在 ZCode 里打开 **Settings → Plugin Management → Discover**，点 **+**。
3. 添加本仓库——GitHub 地址 `AntonKhakhalin/open-computer-use`，或本地 checkout 目录。
4. 在列表里找到 **Open Computer Use**，点 **Get** 安装。
5. 新开一个会话。到 **Settings → MCP** 确认 `open-computer-use` 已连接，然后直接说："列出我屏幕上的窗口"。

以后想移除：Installed 标签 → Open Computer Use → uninstall。

## Skill 安装

Skill 是教 Agent 用好这套工具的可安装指引。安装 skill **不会**安装运行时二进制——它只添加说明文档。三个步骤相互独立，按顺序执行：

1. **运行时安装**——让 `open-computer-use` / `ocu` 命令出现在 PATH 上（[快速开始](#快速开始)）。
2. **MCP 连接**——把你的 Agent 指向运行时（[接入 Agent](#接入-agent)）。
3. **Skill 安装**——可选，添加最佳实践指引：

```bash
npx skills add AntonKhakhalin/open-computer-use -g -a claude-code --skill open-computer-use -y
npx skills add AntonKhakhalin/open-computer-use -g -a codex --skill open-computer-use -y
```

[`skills`](https://www.npmjs.com/package/skills) CLI 支持的任意 Agent 都可以（`-a <agent>`，完整列表见 `npx skills add -h`）。skill 也存放在本仓库 [`skills/open-computer-use`](./skills/open-computer-use)，可手动复制。

## 通用 MCP 配置

任何能启动本地 stdio MCP server 的宿主都可以使用这个运行时。

JSON（Claude Code、Cursor、Gemini CLI 及大多数客户端）：

```json
{
  "mcpServers": {
    "open-computer-use": {
      "command": "open-computer-use",
      "args": ["mcp"]
    }
  }
}
```

TOML（Codex `~/.codex/config.toml`）：

```toml
[mcp_servers."open-computer-use"]
command = "open-computer-use"
args = ["mcp"]
```

这是一个**本地 stdio** server：它运行在你的机器上，不涉及任何远程/网络端点。

## macOS 高级能力

**已验证：**

- 枚举并识别单个窗口——`list_windows` 返回真实窗口与精确的 **CGWindowID**。
- 定向操作同一个应用的多个窗口——按窗口 id，而不是 app 级 key-window 猜测。
- 激活指定窗口——`activate_window` 把指定窗口带到前台并回验结果。
- 观察与交互后台窗口——无障碍优先路径无需激活、不抢焦点。
- 窗口级截图——`get_window_state` 捕获目标窗口本身，坐标动作受 `screenshotId` 门禁（stale id 直接拒绝）。
- 同 bounds 窗口身份——frame 完全相同的窗口按 AX 身份解析，绝不"取第一个匹配"；已关闭/幽灵窗口被拒绝，而不是被当成 live 回显。
- 原生应用启动——`launch_app` 后台启动（不抢焦点）、复用运行中实例、返回 `pid` + `windows[]`。
- 最小化窗口——可在 `list_windows` 中发现、可解析、可观察；`set_value` 可用。

**已知限制：**

- 最小化窗口：其发现依赖一个 macOS 私有窗口身份能力——能力不可用时 `list_windows` 只列出屏幕上的窗口（`ocu doctor` 的能力行可见）。依赖按键事件输入前请先恢复为可见（值写入在最小化状态下仍可用）。
- 无修饰键的 `press_key` 事件在用户正在打字时会被丢弃（输入安静时正常投递）；优先使用 `type_text` / AX 路径——见 [skill 参考](./skills/open-computer-use/references/macos-input.md)。
- `list_windows` 的窗口标题依赖 Screen Recording 授权；无授权时 id 仍然可用。
- Linux 的 window2 工具返回显式的 "not supported yet" 错误。
- fork 发布产物为 **ad-hoc 签名**（无 Developer ID / 公证），macOS 权限与具体构建绑定——替换二进制后如权限失效，用 `ocu doctor` 重新授权。

## 安全 / 隐私

- **本地执行。** 桌面控制完全不离开你的机器；computer-use 操作没有任何云端依赖。
- **无障碍优先。** 运行时优先走无障碍 API 而非合成输入；除非你显式开启全局输入，真实指针、焦点和前台应用都不会被碰。
- **密码管理器 deny 名单。** 密码管理器一律不会被启动或自动化，与任何开关无关。
- **强能力门控。** 启动应用、抢占焦点的激活、全局输入注入各自需要显式环境变量开启（默认关闭）。
- **macOS 权限。** 需要 `Accessibility` 与 `Screen Recording`，通过 `ocu doctor` 一次性引导授权。
- **许可证。** [MIT](./LICENSE)——上游版权声明完整保留。

## 工具面

九个核心工具，三个平台完全一致：

| 工具 | 作用 |
| --- | --- |
| `list_apps` | 列出运行中和最近使用的应用。 |
| `get_app_state` | 读取应用的完整无障碍树和截图。 |
| `click` | 按 `element_index` 或截图坐标点击。 |
| `perform_secondary_action` | 调用元素自带的次要操作。 |
| `scroll` | 按页滚动元素，或按像素增量滚动窗口。 |
| `drag` | 在两个坐标之间拖拽。 |
| `type_text` | 输入文本，Unicode 安全，优先后台写入。 |
| `press_key` | 按键或组合键（`ctrl+s`、`return`、`page_up`…）。 |
| `set_value` | 直接设置可写控件的值。 |

另有五个窗口级工具——`list_windows`、`get_window`、`get_window_state`、`launch_app`、`activate_window`——遵循新的 window2 API，macOS 和 Windows 均可用（Linux 进行中）；macOS 上窗口 id 即 CGWindowID，动作工具同样接受可选 `window` 参数与 `screenshotId` 坐标参数。

## 平台状态

| 平台 | 运行时 | 说明 |
| --- | --- | --- |
| macOS | Swift | 视觉光标、权限引导、`sky_click` 后台点击、完整 window2 API 与精确 CGWindowID 身份；含显示级桌面命令（见下）。 |
| Windows | Go 单 exe | UI Automation + Win32，操作进程隔离，完整 window2 API；含显示级桌面命令（见下）。 |
| Linux | Go 单二进制 | 原生 AT-SPI2 over D-Bus，零运行时依赖；含显示级 X11 命令（见下）。 |

### 显示级桌面命令（三平台）

三个运行时提供同一套整屏 CLI 命令（命令名、参数、JSON 输出对齐，详见英文 README 的 "Display-level desktop commands"）：`screenshot` 整屏 PNG、`cursor-position` 指针坐标 JSON、`input` 全局合成输入（每平台独立环境变量门控，默认关闭：Linux `OPEN_COMPUTER_USE_ALLOW_GLOBAL_POINTER_FALLBACKS=1`、Windows `OPEN_COMPUTER_USE_WINDOWS_ALLOW_FOREGROUND_INPUT=1`、macOS `OPEN_COMPUTER_USE_MACOS_ALLOW_FOREGROUND_INPUT=1`）、`record start/stop/discard/polish/status` 录屏（默认 `--quality demo`；`--polish` / `record polish` 默认 clean-room 帧合成器对齐 polished-renderer：空闲重映射→缩放→镜头畸变→运动模糊→光标 depress/拖影→按键字幕；`--engine ffmpeg` 为旧滤镜路径，可选 `--ripples`；`input` 写入 `<stem>.events.json`）。这些是 CLI-only，不进入官方对齐的 14 个 MCP tool 面。

## 与上游的关系

- **短链接：** [github.com/AntonKhakhalin/ocu](https://github.com/AntonKhakhalin/ocu) —— 本项目的别名仓库（仅 README + 安装指引）。
- **上游项目：** [opensymph/open-computer-use](https://github.com/opensymph/open-computer-use)——原始架构与核心实现。
- **已向上游提案的 fork 工作：** [PR #2 — macOS 原生 `launch_app`](https://github.com/opensymph/open-computer-use/pull/2)（分支 `feat/macos-launch-app`）、[PR #3 — macOS 原生窗口管理与窗口定向动作](https://github.com/opensymph/open-computer-use/pull/3)（分支 `feat/macos-window-management`）。
- **仅 fork 分支的工作：** 本仓库的 `feat/public-distribution` 分支（品牌、fork 打包、安装器、发布产物）。
- **许可证：** MIT，上游版权声明完整保留于 [LICENSE](./LICENSE)。
- 上游维护者未审查、也未背书本 fork。

## 文档

- [架构](./docs/ARCHITECTURE.md) —— 三个运行时如何工作
- [对外发布文案](./docs/PUBLIC_LAUNCH.md) —— 可复用的公告、slogan 与功能要点
- [Skill 参考](./skills/open-computer-use) —— 用法、安装、排障
- [安全策略](./SECURITY.md) 与 [第三方声明](./THIRD_PARTY_NOTICES.md)
- [参与贡献](./CONTRIBUTING.md)

## License

[MIT](./LICENSE)
