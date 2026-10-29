/* Lua Node Studio official site — i18n + reveal animations */
(function () {
  "use strict";

  var ZH = {
    brandTag: "节点编程",
    navFeatures: "功能",
    navAi: "AI 助手",
    navScreens: "截图",
    navDownload: "下载",
    navGithub: "GitHub",
    heroBadge: "最新版本 · Android + Windows",
    heroLicense: "开源 · Apache-2.0",
    heroTitle1: "拖拽节点，",
    heroTitle2: "直接生成 Lua 代码",
    heroLead:
      "Lua Node Studio 是一个可视化节点编程编辑器：把「开始」「循环」「打印」这样的节点拖到画布上连起来，就能实时得到一份可读的 Lua 5.3 源码，并在内置运行时里直接执行。手机和电脑都能用，还能接入你自己的 AI 模型，用一句话生成节点图。",
    ctaAndroid: "下载 Android 版",
    ctaWindows: "Windows 便携版",
    ctaGithub: "GitHub 仓库",
    heroHint: "开源免费 · 无需注册 · 工程数据只保存在本机",
    statNodes: "种节点，覆盖流程 / 数据 / 运算 / 控制 / 函数 / 模块",
    statSamples: "个内置算法示例，打开即运行",
    statTests: "个自动化测试持续保证质量",
    statPlatforms: "平台：Android 与 Windows",
    floatA: "实时生成",
    floatASub: "拖拽、连线，代码立刻更新",
    floatB: "一键运行",
    floatBSub: "内置 Lua 5.3，无需装环境",
    featEyebrow: "核心能力",
    featTitle: "把写代码变成搭积木",
    featLead: "从节点到代码，再到运行结果，全部在同一个界面里完成。",
    f1t: "可视化节点画布",
    f1p: "拖拽、连线、缩放、平移，网格对齐；执行流用菱形端口，数据流用圆形端口，一眼分清。",
    f2t: "实时生成 Lua 代码",
    f2p: "执行流决定语句顺序，数据流递归展开为表达式；分支与循环自动找到汇合点，不需要额外的 merge 节点。",
    f3t: "内置 Lua 5.3 运行时",
    f3p: "纯 Dart 实现的 Lua 解释器，在 Isolate 中执行并带 8 秒超时保护，不卡界面，输出面板实时显示 print 结果。",
    f4t: "项目管理首页",
    f4p: "内置示例和「我的项目」在同一个列表；新建、导入 JSON、重命名、创建副本、删除都在这里，自动保存随时恢复。",
    f5t: "AI 对话生成节点图",
    f5p: "接入任意 OpenAI 兼容接口（OpenAI / DeepSeek / Ollama / 自建网关），描述需求即可得到经过校验的节点图，密钥只留在本机。",
    f6t: "中英双语 · 双平台",
    f6p: "中文 / English 一键切换，选择会被记住；同一份代码构建 Android APK 与 Windows 便携版。",
    f7t: "专用运算与表达式节点",
    f7p: "加、减、乘、除、取余、幂运算各有独立节点；表达式节点里直接写 (a + b) * (a - b)，a / b / c 自动替换成输入端口的值。",
    f8t: "算法模块节点",
    f8p: "求和、阶乘、斐波那契、最大公约数、素数判断各一个模块节点；生成代码时只输出真正用到的模块函数，源码依然干净。",
    aiEyebrow: "AI 助手（可选）",
    aiTitle: "说一句话，生成一张能跑的节点图",
    aiLead:
      "在项目管理页点「AI 生成」，填入你自己的接口地址、密钥和模型即可。AI 返回的节点图会先经过严格校验——节点类型、端口、执行流与数据流规则、是否需要补「开始」节点、坐标缺失时自动布局。",
    aiS1t: "配置接口",
    aiS1p: "支持 OpenAI、DeepSeek、通义、Kimi、Ollama 以及任意兼容服务；保存前会先测试连通性。",
    aiS2t: "描述程序",
    aiS2p: "例如「写一个 1 到 10 求和的程序」「计算 5 的阶乘并打印」。",
    aiS3t: "审阅并打开",
    aiS3p: "查看节点/连线数量与警告，一键在画布打开，继续修改、生成代码、运行。",
    aiNote: "API Key 只保存在本机设置文件里，不会上传；应用只会向你填写的地址发起请求。",
    aiMore: "查看配置说明",
    scrEyebrow: "界面预览",
    scrTitle: "从节点到运行结果，一屏完成",
    scrLead: "以下截图来自应用实际界面，可在 GitHub 仓库查看大图。",
    scr1t: "节点画布 + 代码面板",
    scr1p: "拖拽连线后代码实时更新，点运行即可查看输出。",
    scr2t: "项目管理首页",
    scr2p: "内置示例与自己的工程放在同一个列表。",
    scr3t: "AI 生成节点图",
    scr3p: "接入自己的模型，用对话生成可编辑的节点图。",
    dlEyebrow: "下载",
    dlTitle: "开源免费，直接下载使用",
    dlLead: "下载按钮始终指向最新版本。所有历史版本与校验信息都在 GitHub Releases。",
    dlAndroidMeta: "APK · 最新版本 · 约 53 MB",
    dlAndroidP: "适用于 Android 6.0 及以上（minSdk 24）。下载后允许「安装未知应用」即可安装。",
    dlAndroidBtn: "下载 APK",
    dlAndroidTiny: "已修复旧版 release 包缺少网络权限的问题，接入 AI 接口请使用最新版本。",
    dlWinMeta: "zip · 最新版本 · 约 13 MB · Windows 10/11 x64",
    dlWinP: "解压后直接双击 lua_node_studio.exe，无需安装；data/ 目录与 dll 需和 exe 放在一起。",
    dlWinBtn: "下载便携版",
    dlWinTiny: "首次打开 Windows 应用时若出现 SmartScreen 提示，选择「更多信息 → 仍要运行」即可。",
    dlAll: "查看全部版本与更新日志",
    samEyebrow: "内置示例",
    samTitle: "8 个算法示例，打开就能运行",
    samLead: "每一个都配好了节点与预期输出，适合学习或作为新工程的起点。",
    sam1: "for 循环 + 变量累加，最基础的执行流",
    sam2: "带参数与返回值的函数：计算 5!",
    sam3: "带参数的函数 + 循环维护两个变量：求 fib(10)",
    sam4: "两个参数 + while 循环 + 取模：gcd(48, 36)",
    sam5: "if/else 提前返回 + while 试除：判断 97 是否为素数",
    sam6: "用「求和模块」一个节点算 1 到 100 的和",
    sam7: "一个「表达式」节点写完 (a + b) * (a - b)",
    sam8: "12 和 4 分别做加减乘除四种运算",
    ossEyebrow: "开源",
    ossTitle: "Apache-2.0 · 欢迎贡献",
    ossP: "源码、Issue 与 PR 都在 GitHub。觉得有用的话，给个 Star 会很有帮助。",
    ossRepo: "访问 GitHub 仓库",
    ossLicense: "查看许可证",
    footTag: "拖拽节点，生成 Lua 代码",
    footProject: "项目",
    footDocs: "文档与协议",
    footChangelog: "更新日志",
    footLicense: "基于 Apache License 2.0 开源",
    footTop: "回到顶部 ↑"
  };

  var EN = {
    brandTag: "Node coding",
    navFeatures: "Features",
    navAi: "AI",
    navScreens: "Screenshots",
    navDownload: "Download",
    navGithub: "GitHub",
    heroBadge: "Latest · Android + Windows",
    heroLicense: "Open source · Apache-2.0",
    heroTitle1: "Drag nodes,",
    heroTitle2: "get Lua code instantly",
    heroLead:
      "Lua Node Studio is a visual node-based editor for Lua: drop nodes like Start, Loop and Print onto the canvas, connect them, and get readable Lua 5.3 source code in real time — then run it right inside the app. Available on Android and Windows, with an optional AI assistant that turns a sentence into an editable node graph.",
    ctaAndroid: "Download for Android",
    ctaWindows: "Windows portable",
    ctaGithub: "GitHub repo",
    heroHint: "Free & open source · no sign-up · projects stay on your device",
    statNodes: "node types across flow / data / math / control / function / modules",
    statSamples: "built-in algorithm samples, ready to run",
    statTests: "automated tests keeping it stable",
    statPlatforms: "platforms: Android and Windows",
    floatA: "Live codegen",
    floatASub: "Drag, connect — code updates instantly",
    floatB: "One-click run",
    floatBSub: "Embedded Lua 5.3, nothing to install",
    featEyebrow: "Core features",
    featTitle: "Programming, but like building blocks",
    featLead: "From nodes to code to output — all in one place.",
    f1t: "Visual node canvas",
    f1p: "Drag, connect, zoom and pan with grid snapping; diamond ports carry execution flow and round ports carry data.",
    f2t: "Real-time Lua codegen",
    f2p: "Execution flow sets statement order, data flow expands into expressions, and branches/loops find their convergence point automatically — no merge nodes needed.",
    f3t: "Embedded Lua 5.3 runtime",
    f3p: "A pure-Dart Lua interpreter running in an isolate with an 8-second timeout, so the UI never blocks; the output panel shows every print.",
    f4t: "Project manager home",
    f4p: "Built-in samples and your own projects in one list; create, import JSON, rename, duplicate and delete — autosave is restored on the next launch.",
    f5t: "AI graph generation",
    f5p: "Plug in any OpenAI-compatible endpoint (OpenAI / DeepSeek / Ollama / self-hosted) and describe what you want; the returned graph is validated, and your key never leaves the device.",
    f6t: "Bilingual · cross-platform",
    f6p: "Switch between 中文 and English with one tap and it is remembered; one codebase builds both the Android APK and the Windows portable app.",
    f7t: "Dedicated math & expression nodes",
    f7p: "Separate add, subtract, multiply, divide, modulo and power nodes; the expression node evaluates (a + b) * (a - b) with a / b / c replaced by input port values.",
    f8t: "Algorithm modules",
    f8p: "Sum, factorial, Fibonacci, GCD and prime-check modules; helper functions are emitted only for the modules you actually use.",
    aiEyebrow: "AI assistant (optional)",
    aiTitle: "Say it in a sentence, get a runnable graph",
    aiLead:
      "Open “Generate with AI” on the projects page, enter your own endpoint, key and model. The returned graph is strictly validated — node types, ports, exec/data rules, a missing Start node is inserted, and coordinates are auto-laid out.",
    aiS1t: "Configure",
    aiS1p: "Works with OpenAI, DeepSeek, Qwen, Kimi, Ollama and any compatible gateway; connectivity is tested before saving.",
    aiS2t: "Describe",
    aiS2p: "For example “sum numbers from 1 to 10” or “compute 5! and print it”.",
    aiS3t: "Review & open",
    aiS3p: "Check node/link counts and warnings, then open the graph on the canvas to edit, generate code and run it.",
    aiNote: "Your API key is stored only in the local settings file; the app only talks to the endpoint you enter.",
    aiMore: "Read the setup guide",
    scrEyebrow: "Screenshots",
    scrTitle: "From nodes to output, on one screen",
    scrLead: "Screenshots from the app; larger versions are in the GitHub repo.",
    scr1t: "Canvas + code panel",
    scr1p: "Code updates as you connect nodes; hit run to see the output.",
    scr2t: "Project manager",
    scr2p: "Samples and your own projects in one list.",
    scr3t: "AI graph generation",
    scr3p: "Bring your own model and chat your way to an editable graph.",
    dlEyebrow: "Download",
    dlTitle: "Free and open source — grab it",
    dlLead: "Download buttons always point to the latest release. All versions and checksums live on GitHub Releases.",
    dlAndroidMeta: "APK · latest release · ~53 MB",
    dlAndroidP: "Works on Android 6.0+ (minSdk 24). Allow installing unknown apps when prompted.",
    dlAndroidBtn: "Download APK",
    dlAndroidTiny: "Use the latest release; older builds may lack the network permission required by the AI feature.",
    dlWinMeta: "zip · latest release · ~13 MB · Windows 10/11 x64",
    dlWinP: "Unzip and double-click lua_node_studio.exe — no installer. Keep data/ and the dlls next to the exe.",
    dlWinBtn: "Download portable",
    dlWinTiny: "If SmartScreen appears on first launch, choose “More info → Run anyway”.",
    dlAll: "All versions and changelog",
    samEyebrow: "Built-in samples",
    samTitle: "Eight algorithm samples, ready to run",
    samLead: "Each comes with nodes and the expected output — good for learning or as a starting point.",
    sam1: "for loop + variable accumulation, the simplest flow",
    sam2: "Functions with parameters and return values: 5!",
    sam3: "A parametrised function plus a loop with two variables: fib(10)",
    sam4: "Two parameters, a while loop and modulo: gcd(48, 36)",
    sam5: "Early return with if/else and a while trial-division: is 97 prime?",
    sam6: "Total 1..100 with a single Sum module node",
    sam7: "Evaluate (a + b) * (a - b) inside one Expression node",
    sam8: "Add, subtract, multiply and divide 12 by 4",
    ossEyebrow: "Open source",
    ossTitle: "Apache-2.0 · contributions welcome",
    ossP: "Source, issues and PRs are on GitHub. A star is much appreciated if you find it useful.",
    ossRepo: "Visit the GitHub repo",
    ossLicense: "Read the license",
    footTag: "Drag nodes, generate Lua code",
    footProject: "Project",
    footDocs: "Docs & license",
    footChangelog: "Changelog",
    footLicense: "Open source under Apache License 2.0",
    footTop: "Back to top ↑"
  };

  var dict = { zh: ZH, en: EN };
  var current = "zh";
  try {
    var saved = localStorage.getItem("lns-site-lang");
    if (saved === "en" || saved === "zh") current = saved;
  } catch (e) { /* ignore */ }

  var langBtn = document.getElementById("langBtn");

  function applyLang(lang) {
    current = lang;
    var d = dict[lang];
    document.documentElement.lang = lang === "zh" ? "zh-CN" : "en";
    var nodes = document.querySelectorAll("[data-i18n]");
    for (var i = 0; i < nodes.length; i++) {
      var key = nodes[i].getAttribute("data-i18n");
      if (Object.prototype.hasOwnProperty.call(d, key)) {
        nodes[i].textContent = d[key];
      }
    }
    if (langBtn) langBtn.textContent = lang === "zh" ? "EN" : "中文";
    try { localStorage.setItem("lns-site-lang", lang); } catch (e) { /* ignore */ }
  }

  if (langBtn) {
    langBtn.addEventListener("click", function () {
      applyLang(current === "zh" ? "en" : "zh");
    });
  }

  // Reveal-on-scroll
  var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var revealNodes = document.querySelectorAll(".reveal");
  if (reduceMotion || !("IntersectionObserver" in window)) {
    for (var j = 0; j < revealNodes.length; j++) revealNodes[j].classList.add("in");
  } else {
    var observer = new IntersectionObserver(
      function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var el = entry.target;
          var parent = el.parentElement;
          var idx = parent ? Array.prototype.indexOf.call(parent.children, el) : 0;
          if (idx > 0) el.style.transitionDelay = Math.min(idx * 0.06, 0.3) + "s";
          el.classList.add("in");
          observer.unobserve(el);
        });
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.12 }
    );
    for (var k = 0; k < revealNodes.length; k++) observer.observe(revealNodes[k]);
  }

  applyLang(current);
})();
