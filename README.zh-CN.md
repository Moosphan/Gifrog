# Gifrog

一款轻量的 macOS 菜单栏屏幕录制工具，支持导出 GIF/MP4/WebM 格式。可以录制屏幕任意区域、窗口或全屏，录制完成后直接在编辑器中裁剪并导出。

## 功能特性

- **三种录制模式** — 区域选取、窗口录制、全屏录制
- **多种导出格式** — GIF、MP4 (H.264)、WebM (VP9)
- **内置编辑器** — 视频预览、时间线裁剪、实时文件大小预估
- **鼠标点击高亮** — 录制时自动标记鼠标点击位置
- **全局快捷键** — `⌥⇧G` 随时开始/停止录制
- **剪贴板集成** — 导出文件自动复制到剪贴板
- **拖拽导入** — 支持导入 MP4、MOV、M4V、WebM 文件
- **崩溃恢复** — 启动时自动恢复未完成的录制
- **开机自启** — 可选的 macOS ServiceManagement 自动启动

## 系统要求

- macOS 13 (Ventura) 或更高版本
- [FFmpeg](https://ffmpeg.org/) — 通过 Homebrew 安装：
  ```bash
  brew install ffmpeg
  ```
- 屏幕录制权限（首次启动时应用会引导授权）

## 安装

### 从源码构建

```bash
git clone git@github.com:Moosphan/Gifrog.git
cd Gifrog
swift build -c release
```

编译产物位于 `.build/release/Gifrog`。

### 打包为 .app

```bash
bash scripts/build_app.sh
open dist/Gifrog.app
```

## 使用方法

1. 启动 Gifrog — 菜单栏出现青蛙图标
2. 点击图标选择录制模式（区域 / 窗口 / 全屏）
3. 首次使用时授予屏幕录制权限
4. 开始录制 — 使用浮动工具栏暂停或停止
5. 在编辑器窗口中裁剪并配置导出参数
6. 导出 — 文件自动保存并复制到剪贴板

### 全局快捷键

在任意应用中按 `⌥⇧G` 即可开始/停止录制。

### 快捷键列表

| 快捷键 | 功能 |
|--------|------|
| `⌥⇧G` | 开始 / 停止录制 |
| `Space` | 暂停 / 继续（录制中） |
| `Esc` | 取消录制 |

## 配置选项

点击状态栏弹出窗口中的齿轮图标打开设置：

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| 帧率 | 15 | 录制帧率（10 / 15 / 24 / 30） |
| 缩放 | 100% | 输出缩放（100% / 75% / 50%） |
| 格式 | GIF | 导出格式（GIF / MP4 / WebM） |
| 质量 | 中等 | 导出质量预设 |
| 倒计时 | 3秒 | 录制开始前的倒计时 |
| 显示光标 | 开 | 录制时包含鼠标光标 |
| 点击高亮 | 开 | 在点击位置显示视觉标记 |
| 开机自启 | 关 | macOS 登录时自动启动 Gifrog |
| 保存路径 | `~/Movies/Gifrog` | 默认导出目录 |

## 项目架构

```
Sources/Gifrog/
├── main.swift                    # 应用入口
├── Models.swift                  # 数据模型
├── Controllers/                  # AppKit 窗口与状态管理
│   ├── GifrogController.swift    # 核心协调器
│   ├── StatusBarController.swift # 菜单栏图标与弹出窗口
│   └── ...
├── Recording/                    # 屏幕录制管线
│   ├── ScreenCaptureRecorder.swift  # 基于 ScreenCaptureKit
│   ├── FrameRecorder.swift          # 录制编排器
│   └── ClickEventRecorder.swift     # 鼠标点击捕获
├── Export/                       # 基于 FFmpeg 的导出
│   └── ExportManager.swift
├── Views/                        # SwiftUI 视图
└── Resources/                    # 应用图标资源
```

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 | Swift 5.10 |
| 构建 | Swift Package Manager |
| UI | SwiftUI + AppKit |
| 录制 | ScreenCaptureKit |
| 视频 | AVFoundation |
| 导出 | FFmpeg |
| 快捷键 | Carbon HIToolbox |

## 许可证

Copyright © 2026 Gifrog. 保留所有权利。
