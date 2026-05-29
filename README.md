<div align="center">
  <img src="agent-status-light/logo.png" width="128" alt="Agent Status Light Logo">
  <h1 align="center">Agent Status Light</h1>

  <p align="center">
    <img src="https://img.shields.io/badge/platform-macOS%2013%2B-black?style=for-the-badge&logo=apple" alt="macOS 13+">
    <img src="https://img.shields.io/badge/language-Swift%205-orange?style=for-the-badge&logo=swift" alt="Swift 5">
    <img src="https://img.shields.io/badge/UI-SwiftUI-blue?style=for-the-badge" alt="SwiftUI">
    <img src="https://img.shields.io/badge/agents-Claude%20%26%20Codex-1f8b4c?style=for-the-badge" alt="Claude and Codex">
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=for-the-badge" alt="MIT License"></a>
  </p>
  <br>
  <h3>简体中文 | <a href="README-en.md">English</a></h3>
  <br>
  一款面向 <b>Claude</b> 与 <b>Codex</b> 使用场景的 macOS 菜单栏状态灯工具。<br>
  它会读取本地状态源文件，帮助你快速感知 Agent 当前是 <b>运行中</b>、<b>等待用户</b>、<b>空闲</b> 还是 <b>异常</b>。
</div>

# 1、项目简介

Agent Status Light 是一个为本地 AI 编码工作流准备的桌面状态感知工具。

当你同时在终端、编辑器、浏览器和多个项目之间切换时，它可以把 Claude 与 Codex 的运行状态收敛成菜单栏灯色和桌面悬浮窗，减少频繁切回终端确认执行进度的成本。

它当前主要解决这几类问题：

- 不切回终端，也能快速知道 Claude 或 Codex 是否仍在运行
- 正在等待确认、授权或输入时，可以立即看到黄灯常亮提醒
- 最近任务异常、接口故障或令牌问题时，可以通过红灯或故障灯快速发现
- 状态显示不准时，可以直接打开数据目录或定位状态文件排查

# 2、界面预览

<table>
  <tr>
    <td align="center"><img src="img/setting01.png" alt="设置窗口" width="720"></td>
  </tr>
  <tr>
    <td align="center">设置窗口</td>
  </tr>
</table>

<table>
  <tr>
    <td align="center"><img src="img/floating_window_light.png" alt="浅色悬浮窗" width="360"></td>
    <td align="center"><img src="img/floating_window_black.png" alt="深色悬浮窗" width="360"></td>
  </tr>
  <tr>
    <td align="center">浅色悬浮窗</td>
    <td align="center">深色悬浮窗</td>
  </tr>
</table>

<table>
  <tr>
    <td align="center"><img src="img/single_light.png" alt="单灯模式" width="360"></td>
  </tr>
  <tr>
    <td align="center">单灯模式</td>
  </tr>
</table>

# 3、功能特性

- [x] 菜单栏聚合状态灯，使用单灯快速表达当前整体状态
- [x] 独立设置窗口，集中管理状态灯、主题、刷新频率和提醒方式
- [x] 支持 Claude 与 Codex 双通道状态采集
- [x] 支持桌面悬浮窗，提供单灯模式、双灯模式、横向布局、竖向布局
- [x] 支持悬浮窗标题显示、状态文案显示与缩放调节
- [x] 支持语音提醒与弹窗提醒
- [x] 支持故障灯，用于单独标记接口异常、认证失败、额度不足等外部故障
- [x] 支持诊断排查，可直接打开数据目录或定位当前状态文件
- [x] 同时使用目录监听与轮询刷新，兼顾实时性与稳定性

# 4、状态语义

当前版本的灯色与语义对应关系如下：

- 绿灯常亮：当前空闲，或最近一次任务已经正常结束
- 黄灯慢闪：Claude 或 Codex 正在运行、思考、输出、调用工具或修改文件
- 黄灯常亮：当前正在等待用户输入、确认、授权或人工处理
- 红灯常亮：最近一次任务明确失败，或检测到命令执行异常
- 故障灯快闪：检测到 API 请求失败、令牌失效、额度不足、模型负载过高等外部故障
- 灰灯或熄灭：当前未启用、不可用，或暂时没有读取到明确状态源

聚合总灯优先级如下：

- 红灯优先级高于黄灯
- 黄灯优先级高于绿灯
- 绿灯优先级高于灰灯
- 故障灯为独立告警灯，不与普通状态灯共用语义

# 5、系统要求

- 操作系统：macOS 13.0 及以上版本
- 芯片平台：Apple Silicon 与 Intel Mac
- 开发环境：建议使用较新的 Xcode 版本打开工程

项目当前依赖了部分较新的系统能力，例如：

- SwiftUI 的 `LabeledContent`
- SwiftUI 的 `GroupedFormStyle`
- Swift 并发中的 `Task.sleep(for:)`

# 6、快速开始

## 6.1、克隆项目

```bash
git clone <你的仓库地址>
cd agent-status-light-git
```

## 6.2、使用 Xcode 打开

```bash
open agent-status-light.xcodeproj
```

## 6.3、运行应用

在 Xcode 中选择 `agent-status-light` Scheme，直接运行即可。

启动后你会得到这些交互入口：

- 菜单栏状态灯
- 独立设置窗口
- 桌面悬浮窗
- 运行状态面板
- 诊断排查入口

如果你开启了弹窗提醒，系统可能会请求通知权限。

# 7、状态源说明

项目当前基于本地文件与会话记录推断状态，默认读取如下目录或文件：

| Agent | 状态源 |
| --- | --- |
| Claude | `~/.claude/todos` |
| Claude | `~/.claude/projects` |
| Codex | `~/.codex/state_5.sqlite` |
| Codex | `~/.codex/session_index.jsonl` |
| Codex | `~/.codex/sessions` |

其中：

- Claude 主要通过 `todo` 文件与项目会话日志推断运行、等待和异常状态
- Codex 主要通过 SQLite 状态库、会话索引和 session JSONL 推断当前线程状态
- 项目会同时使用目录监听与轮询刷新，目录监听负责实时刷新，轮询作为兜底机制

# 8、使用说明

## 8.1、菜单栏

- 菜单栏会展示聚合后的总灯状态
- 左侧固定为 Claude，右侧固定为 Codex
- 当某个 Agent 被关闭时，对应灯会变灰或不参与聚合

## 8.2、设置窗口

设置窗口当前包含以下分类：

- 常规设置
- 运行状态
- 诊断排查
- 关于我们

你可以在这里完成以下操作：

- 开启或关闭 Claude 状态灯
- 开启或关闭 Codex 状态灯
- 开启或关闭桌面悬浮窗
- 开启或关闭故障灯
- 切换主题模式
- 调整轮询频率
- 切换悬浮窗模式与灯位方向
- 调整横向排列方式
- 控制标题与状态文案显示
- 开启或关闭语音提醒、弹窗提醒
- 修改提醒音频路径

## 8.3、诊断排查

如果你发现状态显示不准确，建议按下面顺序排查：

1、点击“立即刷新”
2、进入“诊断排查”分类
3、点击“打开数据目录”确认监听目录是否正确
4、点击“定位状态文件”核对当前判定所使用的状态源

# 9、项目结构

```text
agent-status-light-git
├─agent-status-light
│  ├─App
│  ├─Models
│  ├─Services
│  ├─Utilities
│  ├─Views
│  ├─Assets.xcassets
│  └─Audio
├─agent-status-light.xcodeproj
└─README.md
```

目录职责大致如下：

- `App`：应用入口与生命周期
- `Models`：状态模型、配置模型与基础数据结构
- `Services`：状态采集、聚合、提醒、悬浮窗与菜单栏控制
- `Utilities`：文件系统、SQLite、格式化等通用能力
- `Views`：设置窗口、悬浮窗、状态面板与共享主题视图
- `Assets.xcassets`：图标、颜色与资源资产
- `Audio`：默认提醒音频

# 10、适用场景

- 你在本地长期同时使用 Claude Code 与 Codex
- 你经常把 Agent 任务挂在后台，希望一眼知道是否还在运行
- 你希望在等待输入、授权或确认时尽快收到桌面级反馈
- 你需要快速定位状态源文件，排查“为什么灯色不对”

# 11、后续方向

当前项目定位为轻量状态工具，不承担会话执行本身，只负责状态采集、状态聚合和桌面展示。

后续可以继续扩展的方向包括：

- 增加更多本地 Agent 类型支持
- 优化异常态、等待态和故障态的识别准确率
- 增加更多菜单栏图标样式与悬浮窗视觉方案
- 增强通知、提醒和诊断能力

# 12、联系方式

如果你在使用过程中遇到问题，或希望扩展新的 Agent 状态支持，可以通过以下方式联系：

- 微信：`cxyax_`
- 邮箱：`gaoxin1153@163.com`

# 13、友情链接

- [Linux.do](https://linux.do/)

# 14、开源协议

本项目基于 [MIT License](./LICENSE) 开源。
