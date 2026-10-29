# Lua Node Studio（Lua 节点工作室）

Flutter 可视化节点编程编辑器：在画布上拖拽节点、连线，实时生成 Lua 源码，并用内置 Lua 5.3 运行时直接执行、查看输出。同一份代码支持 **Android** 与 **Windows** 双平台。

当前版本 **v1.6.1 (build 8)**，Android 安装包见 [`installer/`](installer/)。界面支持 **中文 / English** 切换，并支持接入自定义 AI API（OpenAI 兼容）用对话直接生成节点图。

![Lua Node Studio 界面演示](docs/screenshot.jpg)

![项目管理首页](docs/project_manager.jpg)

![AI 对话生成节点图](docs/ai_chat.jpg)

## English

**Lua Node Studio** is a visual node-based editor for Lua. Drag nodes onto the canvas and connect ports; the editor generates readable Lua 5.3 source code in real time and runs it with an embedded Lua 5.3 runtime (pure Dart, executed in an isolate with an 8-second timeout).

- Node categories: flow, data, math, control, function, including **user-defined functions with parameters and return values**
- Live Lua code generation, one-click run, output panel with stdout / errors / timing
- JSON project save / autosave, undo / redo, automatic layout
- 5 built-in sample graphs: 1-to-10 sum, factorial, Fibonacci, greatest common divisor, primality test
- Cross-platform: **Android** (APK) and **Windows** (portable x64) — downloads on the [Releases](https://github.com/ONGIKAN/lua-node-studio/releases) page
- **Project manager as the home screen**: built-in samples, your own projects, new / import / rename / duplicate / delete — saved projects and imported JSON show up in one list
- **AI assistant (optional)**: plug in your own OpenAI-compatible API (base URL / API key / model); describe the program in chat and the app asks the model for a node graph, validates it and opens it on the canvas — API keys stay on your device
- Flutter / Dart, Material 3, 44 unit + golden tests
- **Bilingual UI**: switch between 中文 and English in the top-bar menu (`⋮`); the choice is remembered between launches
- Licensed under the **Apache License 2.0**

## 功能

- **项目管理首页**：启动即进入「项目管理」，内置示例与「我的项目」放在同一个列表；新建、导入 JSON、重命名、创建副本、删除都在这里完成，上次退出前的自动保存会显示成「继续上次编辑」
- **AI 对话生成节点图（可选）**：在项目管理页点「AI 生成」→ 填入自己的 OpenAI 兼容 API 地址 / 密钥 / 模型（OpenAI、DeepSeek、Ollama、任意兼容服务均可），保存时会先测试连通性；之后用自然语言描述程序，模型返回节点图 JSON，客户端做完整校验（节点类型、端口类型、执行流/数据流规则、自动补「开始」节点、自动布局），确认后一键在画布打开并生成代码。密钥只保存在本机设置里（`lib/ai/`）
- **可视化节点画布**：节点拖拽、端口连线、网格背景、缩放/平移，适配手机与桌面窗口尺寸
- **内置节点库**：流程 / 数据 / 数学 / 控制 / 函数五类节点（定义见 `lib/models/node_spec.dart`）
- **带参数函数**：`定义函数` 节点支持参数列表（逗号分隔，如 `a, b`），参数会变成节点上可连线的数据端口；`调用函数` 最多传 3 个参数，可用 `返回值` 端口接收结果；`结束` 节点可写 `return 表达式`
- **一键生成 Lua 代码**：执行流决定语句顺序，数据流递归展开为表达式；分支与循环用「汇合点」规则收口，无需额外 merge 节点（`lib/codegen/lua_generator.dart`）
- **内置 Lua 5.3 运行时**：纯 Dart 实现（`lua_dardo_plus`），在 Isolate 中执行并默认 8 秒超时，不阻塞 UI（`lib/engine/lua_engine.dart`）
- **输出面板**：查看运行时 stdout、错误与耗时
- **工程管理**：JSON 工程保存 / 打开，工程列表记录名称与修改时间；编辑自动保存并在下次启动时恢复（应用文档目录 `LuaNodeStudio/`）
- **内置示例图**：1 到 10 求和、阶乘、斐波那契数列、最大公约数、素数判断，项目管理页直接列出，也可从编辑器菜单「载入示例图」切换（`lib/samples/`）
- **撤销 / 重做**、节点自动布局
- **中英双语界面**：顶栏 `⋮` 菜单底部可在「English / 中文」之间切换，选择保存在本地设置里，下次启动沿用（`lib/l10n/`）
- 深色 Material 3 主题

## 下载与安装

两个平台的产物都发布在 [Releases](https://github.com/ONGIKAN/lua-node-studio/releases)；仓库内也附带了最新 Android 安装包。

### Android

| 项目 | 说明 |
| --- | --- |
| 文件 | `installer/lua_node_studio-v1.6.1-release.apk` |
| 版本 | 1.6.1 (versionCode 8) |
| 包名 | `com.luanode.lua_node_studio` |
| 大小 | 约 53.6 MB |

下载后允许“安装未知应用”即可安装。

### Windows（桌面版）

| 项目 | 说明 |
| --- | --- |
| 文件 | Release 资产 `lua_node_studio-v1.6.1-windows-x64.zip` |
| 版本 | 1.6.1 |
| 系统要求 | Windows 10 / 11 x64 |
| 大小 | 约 12.9 MB |

解压后双击 `lua_node_studio.exe` 即可运行；`data/` 目录与 dll 需要和 exe 保持在同一个文件夹里。

## 本地开发

环境：Flutter 3.x（Dart SDK ^3.12.2）

```bash
flutter pub get
flutter run                      # 运行到已连接的设备 / 模拟器
flutter test                     # 单元 + Golden 测试
flutter build apk --release      # 构建 Android 安装包
flutter build windows --release  # 构建 Windows 桌面版
```

Android 产物在 `build/app/outputs/flutter-apk/`，Windows 产物在 `build/windows/x64/runner/Release/`（需安装 Visual Studio 的“使用 C++ 的桌面开发”工作负载）。

## 目录结构

```
lib/
  main.dart          应用入口与主题
  ui/                项目管理页、编辑器页面、节点画布、输出面板、编辑对话框
  models/            图数据模型、节点注册表、自动布局
  state/             图编辑控制器（撤销/重做、运行、保存）
  codegen/           节点图 → Lua 源码生成器
  engine/            Lua 运行时（Isolate + 超时控制）
  l10n/              中英文文案与语言持久化
  ai/                自定义 AI API 客户端、对话页、节点图蓝图解析
  storage/           工程 JSON 存取
  samples/           内置示例图
android/             Android 平台工程
windows/             Windows 桌面平台工程
assets/             应用图标等资源
test/                单元与 Golden 测试（含项目管理页测试）
LICENSE / NOTICE     Apache-2.0 许可证与第三方声明
installer/           Android 安装包（APK）
```

## 技术栈

Flutter / Dart · Material 3 · [lua_dardo_plus](https://pub.dev/packages/lua_dardo_plus)（纯 Dart Lua 5.3） · [path_provider](https://pub.dev/packages/path_provider) · OpenAI 兼容 Chat Completions API（直接使用 `dart:io HttpClient`，无额外依赖）

## 开源协议

本项目使用 **Apache License 2.0**，全文见 [LICENSE](LICENSE)，第三方依赖声明见 [NOTICE](NOTICE)。欢迎 Star、提 Issue 和 PR。

## 更新日志

### v1.6.1

- 修复 Android Release 安装包缺少 `INTERNET` 权限的问题：此前在手机上测试 AI API 会报 “网络连接失败：Failed host lookup”，现在已可正常访问网络
- 允许明文 HTTP 接口（`usesCleartextTraffic`），本地 Ollama / 自建 http 网关也可直接填写
- 其余功能与 v1.6.0 相同（Windows 桌面版不受影响）

### v1.6.0

- 新增 **AI 对话生成节点图**：项目管理页「AI 生成」入口，支持任意 OpenAI 兼容 API（OpenAI / DeepSeek / Ollama / 自建服务）
- 配置页可填 API 地址、密钥、模型名，保存时自动测试连通性；密钥只保存在本机设置，不上传
- AI 返回的节点图会经过严格校验：节点类型、端口是否存在、执行流/数据流规则、类型兼容、自动补「开始」节点、坐标缺失时自动布局
- 校验通过后可一键在画布打开、继续编辑、生成代码并运行；对话结果卡片显示节点/连线数量与警告
- 新增 8 个 AI 相关自动化测试（配置、蓝图解析、对话流程），项目共 44 个测试

### v1.5.0

- 新增 **项目管理首页**：启动后先看到项目管理页，内置示例与「我的项目」在同一个列表里
- 新建、导入 JSON、重命名、创建副本、删除工程都在项目管理页完成；工程列表显示节点数与修改时间
- 上次退出前的自动保存会以「继续上次编辑」卡片出现在首页
- 自动记录每个工程的展示名与更新时间（`__projects.json`）
- 新增应用图标（Android 自适应图标 + Windows ico）与项目管理页自动化测试（共 36 个测试）
- 采用 **Apache License 2.0** 开源协议

### v1.4.0

- 界面支持 **中文 / English** 一键切换（顶栏 `⋮` 菜单），选择保存在本地并自动恢复
- 节点标题、端口名、字段名、菜单、对话框、工具栏、状态提示全部跟随语言切换
- Lua 代码注释、警告与运行状态（超时/语法错误/输出截断等）同样支持中英文
- 新增语言切换与持久化的自动化测试

### v1.3.0

- `定义函数` 节点支持参数列表（如 `a, b`），参数自动变成可连线的数据端口
- `调用函数` 节点支持最多 3 个参数，并可把返回值接到其它节点；`结束` 节点支持 `return 表达式`
- 新增 4 个常见算法示例：阶乘、斐波那契数列、最大公约数、素数判断
- 菜单「载入示例图」改为示例选择对话框；补充示例执行与代码生成的自动化测试
- 新增 **Windows 桌面版**：同一份 Dart 代码编译为 Android APK 与 Windows 可执行程序

### v1.2.0

- 首个公开版本：节点画布、Lua 代码生成、内置 Lua 5.3 运行时、工程保存与自动保存
