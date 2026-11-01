---
title: Hardware-Viewer - Desktop Integration
date: 2026-10-31 14:25:00
permalink: Hardware-Viewer-Desktop/
tags:
  - Hardware Viewer
  - Dev Log
  - Python
  - Windows
  - Desktop App
  - Startup
  - Usability
---

开发一个可以看硬件实时电量的 app。

仓库地址为 https://github.com/LimpidSlirm/2.4G-Hardware-Viewer

以下为 agent 输出的日志。


本日聚焦桌面使用体验：开机自启、桌面快捷方式、窗口位置记忆，以及一个由早前改动引入的关闭缺陷。

> This day focused on desktop usability: autostart, a desktop shortcut, remembering the window position, and a shutdown defect introduced by an earlier change.

## 1. 开机自启为什么没生效 | Why autostart never worked

用户反馈「没有开机自启」。排查发现代码早已写好 `--install-autostart`，但该命令从未被执行过，注册表里没有任何条目：

> The user reported that nothing started at login. The `--install-autostart` command had been written long before but was never actually run, so the registry held no entry at all:

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
  2.4G-Hardware-Viewer  ->  不存在
启动文件夹  ->  只有 OneNote 的快捷方式
```

这是一个典型的「有代码但没有生效」：功能被写进文档，却没有真正落地。教训是交付功能时要验证最终状态，而不是只验证代码存在。

> This is a textbook case of code existing without taking effect: the feature was documented but never actually installed. The lesson is to verify the end state rather than the presence of code.

## 2. 一次装好自启与快捷方式 | Installing autostart and the shortcut in one step

新增 `--setup`，一步写入自启项并创建桌面快捷方式：

> A `--setup` flag was added to write the autostart entry and create the desktop shortcut in one go:

```powershell
python -m app.main --setup             # 自启 + 快捷方式
python -m app.main --install-autostart # 只装自启
python -m app.main --remove-autostart  # 卸载自启
python -m app.main --create-shortcut   # 只建快捷方式
python -m app.main --remove-shortcut   # 删快捷方式
```

快捷方式通过 `WScript.Shell` 生成 `.lnk`，指向 `pythonw.exe` + `launch.pyw`：

> The shortcut is produced through `WScript.Shell` and points at `pythonw.exe` plus `launch.pyw`:

```text
C:\Users\<user>\Desktop\2.4G Hardware Viewer.lnk
  TargetPath  : D:\ProgramData\anaconda3\pythonw.exe
  Arguments   : "<项目>\launch.pyw"
  WorkingDir  : <项目根目录>
```

用 `pythonw.exe` 而不是 `python.exe`，双击与登录启动都不会弹出控制台窗口。

> `pythonw.exe` rather than `python.exe` means neither a double-click nor a login start flashes a console window.

## 3. 单实例保护 | Single-instance guard

做自启时发现程序没有单实例保护。这意味着登录自启后再双击快捷方式会出现两个浮窗，并且两套 HID 监听线程争用同一个设备句柄——调试期间就遇到过句柄冲突导致读不到电量。

> While adding autostart it turned out the app had no single-instance guard. Starting at login and then double-clicking the shortcut would leave two overlays on screen, with two resident HID listeners fighting over the same device handle, a conflict already seen during earlier debugging.

第一版用命名互斥量：

> The first version used a named mutex:

```python
handle = kernel32.CreateMutexW(None, False, "2.4G-Hardware-Viewer")
if ctypes.get_last_error() == ERROR_ALREADY_EXISTS:
    return False   # 已有实例
```

它确实挡住了第二个实例，但只是「静默退出」，用户双击快捷方式看到的是毫无反应。这一点在第 6 节被推翻并重做。

> It did block the second instance, but exited silently, so a double-click on the shortcut produced no visible reaction at all. Section 6 revisits and replaces this.

## 4. 记住窗口位置 | Remembering the window position

浮窗平时被拖到屏幕角落，但每次重启都回到默认位置，需要重新摆放。新增 `app/settings.py`，在拖动结束与关闭窗口时把左上角坐标和迷你/完整模式写入 `.window_state.json`：

> The overlay lives in a screen corner, yet every restart put it back at the default spot, forcing the user to move it again. `app/settings.py` now writes the top-left corner and the compact/full mode to `.window_state.json` on drop and on close:

```text
{"x": 1470, "y": 402, "compact": true}
```

启动时读回并恢复。关键细节是**校验坐标是否仍然有效**：若保存的位置不在任何屏幕的可用范围内（例如副屏被拔掉），回退到默认位置，避免窗口跑到屏幕外无法再拖回来。

> The value is read back at startup. The important detail is validating the coordinate: if the saved spot no longer falls inside any screen's available geometry, for example after a secondary monitor was unplugged, it falls back to the default instead of parking the window somewhere unreachable.

验证覆盖四条路径：

> Four paths were verified:

```text
默认启动          -> 40,40
拖动到 600,300    -> 保存 {x:600, y:300}
重启恢复          -> 600,300           一致
越界坐标 99999    -> 回退 40,40
```

真实程序端到端验证：

> End to end on the real app:

```text
重启前 state : {"x": 1470, "y": 402, "compact": true}
重启后窗口位置: 1470,402
位置比对     : 一致
```

同时新增 `--reset-position` 用于手动清除：

> `--reset-position` was added to clear it by hand:

```powershell
python -m app.main --reset-position
已清除记住的窗口位置
```

## 5. 桌面快捷方式打不开 | The desktop shortcut appeared broken

用户反馈快捷方式打不开。检查发现进程活着但窗口不可见：

> The user reported the shortcut did nothing. Inspection showed a live process with no visible window:

```text
进程 33628 pythonw.exe 存在
窗口 hwnd=1182306  visible=False
```

用 `EnumWindows` 逐个枚举该进程的窗口才看清这一点，`Process.MainWindowTitle` 此时为空，直接看任务管理器无法判断。

> Only enumerating that process's windows with `EnumWindows` made this visible; `Process.MainWindowTitle` was empty at that point, so Task Manager alone could not show it.

根因是几天前为「让窗口不出现在任务栏」而加的 `Qt.Tool` 标志。Qt 文档中 Tool 窗口默认 `WA_QuitOnClose = False`，因此关闭窗口只会隐藏它，事件循环继续运行，进程残留并占住单实例锁：

> The root cause was the `Qt.Tool` flag added earlier to keep the window out of the taskbar. Qt defaults tool windows to `WA_QuitOnClose = False`, so closing only hides them and the event loop keeps running. The leftover process then held the single-instance lock:

```text
按 Esc 关闭  -> 窗口消失，进程残留，锁未释放
点快捷方式   -> 命中单实例保护 -> 静默退出 -> 看起来「打不开」
```

修复只需一行，显式开启该属性：

> The fix is one line, forcing the attribute on:

```python
self.setAttribute(Qt.WidgetAttribute.WA_QuitOnClose, True)
```

验证确认修复生效：

> Verification confirmed it:

```text
WA_QuitOnClose: True
exec 返回: 0   -> 应用已退出
```

这是一次自造回归：为了解决「任务栏有图标」而引入 Tool 标志，副作用直到用户点快捷方式才暴露。教训是改动窗口标志后要回归验证关闭行为。

> This was a self-inflicted regression: the Tool flag was added to remove the taskbar entry, and the side effect only surfaced when the user clicked the shortcut. Changing window flags requires re-verifying close behaviour.

## 6. 让第二次启动把窗口唤到前台 | Bringing the existing window forward

根因修好后仍有一个体验问题：应用已在运行时双击快捷方式毫无反应。理想行为是把已有窗口显示到前台。

> With the root cause fixed, one usability gap remained: double-clicking while the app already runs still does nothing. The desirable behaviour is to reveal the existing window.

先尝试 `QLocalServer` / `QLocalSocket` 做进程间通信，实测不可靠 —— 客户端能连上，服务端 `newConnection` 也触发，但拿不到数据：

> `QLocalServer` / `QLocalSocket` was tried first and proved unreliable: the client connected and `newConnection` fired, yet the payload never arrived:

```text
  [服务端] newConnection
  [服务端] 收到连接, bytesAvailable= 0
  === seen = []
```

即使补上「连接后立即读取」仍未稳定复现。于是改为更简单的文件标记方案，不再依赖握手时序：

> Adding an immediate read was still not reliably reproducible, so a simpler file-marker scheme replaced it, free of handshake timing:

```text
第二个进程: 写入 .reveal_request 后退出
已运行实例: 每 800 ms 轮询该标记，命中即 reveal()
```

`reveal()` 负责 `show()` + `raise_()` + `activateWindow()`，并从最小化状态恢复。

> `reveal()` performs `show()`, `raise_()` and `activateWindow()`, restoring from minimised state if needed.

验证四步全部通过：

> All four steps passed:

```text
1) 快捷方式启动      -> 有窗口=True
2) 再点一次快捷方式  -> 进程数=1，reveal 文件已消费
3) Esc 关闭          -> 进程已退出
4) 关闭后再点快捷方式 -> 重新打开成功
```

另做了隔离测试，先隐藏窗口再写入标记，确认窗口被唤出：

> A focused test hid the window, wrote the marker, and confirmed the window returned:

```text
隐藏后 visible = False
reveal 后 visible = True
结果: 窗口被唤出
```

## 7. 时不时冒出的命令行窗口 | The console window that kept flashing

用户反馈"时不时会有一个命令行弹窗"，还贴了截图：一个标题被截断成 `C:\Windows\System32\Windo` 的黑色空窗口，闪一下就关。

> The user reported a console window that popped up now and then, and attached a screenshot: an empty black window whose title was truncated to `C:\Windows\System32\Windo`, flashing once and closing.

先定位来源。全项目搜索外部进程调用，只有两处，都在起 `powershell.exe`：

> The source was traced first. Searching the project for external process calls found only two sites, both launching `powershell.exe`:

```text
app/device_discovery.py:119   设备查询
app/autostart.py:79           创建桌面快捷方式
```

其中设备查询是**周期**执行的，这解释了"时不时"：

> The device query runs on a **timer**, which explains the "now and then":

```python
self._refresh_timer = QTimer(self)
self._refresh_timer.timeout.connect(self.refresh_devices)
self._refresh_timer.start(300000)   # 每 5 分钟
```

根因是 Windows 的控制台分配规则：程序由 `pythonw.exe` 启动，**它自己没有控制台**；此时子进程 `powershell.exe` 属于控制台子系统却没地方附着，Windows 就给它新建一个可见控制台窗口。跑完 1~2 秒随进程退出而消失，看起来就是"闪一下"。

> The cause is how Windows allocates consoles. The app is started by `pythonw.exe`, which owns **no** console. A child like `powershell.exe` is a console-subsystem program with nowhere to attach, so Windows allocates it a brand new visible console window. It disappears when the process exits one or two seconds later, which looks like a flash.

修复方式是给两处 `subprocess.run` 加上 `CREATE_NO_WINDOW`，并抽成单点常量：

> The fix passes `CREATE_NO_WINDOW` to both `subprocess.run` calls, kept in one shared constant:

```python
# app/winproc.py
NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)
```

验证没有用眼睛看，而是写了探针。第一版探针想用窗口类 `ConsoleWindowClass` 判断，结果**抓不到**：

> Verification was done with a probe rather than by eye. The first attempt looked for the window class `ConsoleWindowClass` and **found nothing**:

```text
old_behaviour: new_window_appeared = false   ← 与实际现象矛盾
```

原因是本机 Win11 默认控制台宿主已经是 Windows Terminal，类名不再是 `ConsoleWindowClass`。改成"对比 spawn 前后所有顶层窗口的差异"，才抓到真相：

> The reason is that this machine's default console host is Windows Terminal, so the class name is no longer `ConsoleWindowClass`. Switching to diffing every top-level window before and after the spawn revealed it:

```text
NO_WINDOW = 0（修复前）
  CASCADIA_HOSTING_WINDOW_CLASS   "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
  PseudoConsoleWindow             (conhost)
  Windows Terminal / IME / DDE ...

NO_WINDOW = CREATE_NO_WINDOW（修复后）
  0 个新增窗口
```

那个 `CASCADIA_HOSTING_WINDOW_CLASS` 的标题，与用户截图里被截断的 `C:\Windows\System32\Windo` 完全对应，来源确认。这次 A/B 用的是真实代码路径——从 `app.device_discovery` 直接调 `discover_devices()`，父进程用 `pythonw.exe` 跑，只有 `NO_WINDOW` 一个变量不同。

> That `CASCADIA_HOSTING_WINDOW_CLASS` title matches the truncated `C:\Windows\System32\Windo` in the screenshot exactly, confirming the source. The A/B test drove the real code path, calling `discover_devices()` from `app.device_discovery` with `pythonw.exe` as the parent, varying only `NO_WINDOW`.

教训有两条：一是 GUI 程序里任何 `subprocess` 调用默认都会弹窗，必须显式压制；二是**检测方法本身会骗人**——按旧的窗口类名去找，会得到"没有问题"的假结论，实际是宿主环境换了。

> Two lessons: any `subprocess` call inside a GUI program will pop a window unless suppressed explicitly, and the **detection method itself can lie** — searching for the old window class yields a false "no problem" because the host environment changed.

## 8. 验证记录与后续 | Verification log and next steps

本轮验证：

> Commands and results for this round:

```text
py_compile  app/main.py app/autostart.py app/settings.py app/single_instance.py  -> COMPILE_OK
python -m app.main --smoke-test                                                  -> SMOKE_OK
git diff --check                                                                 -> 无报错
```

修复弹窗后的复验：

> Re-verification after the console fix:

```text
py_compile app/winproc.py app/device_discovery.py app/autostart.py app/main.py  -> OK
python -m app.main --smoke-test                                                 -> exit=0
设备数量前后均为 8，功能无影响
重启实例 pid 15736，窗口 visible=True（title: Hardware Viewer）
```

四步端到端（快捷方式启动 / 二次启动唤出 / Esc 退出 / 关闭后重开）全部通过。

> The four-step end-to-end run (shortcut launch, reveal on second launch, exit on Esc, reopen after close) all passed.

对应提交：

> Corresponding commits:

```text
c12f085 feat: add desktop shortcut and single-instance guard
9b4364d feat: remember the window position between runs
95ce17b fix: closing the overlay now exits and the shortcut reopens it
2b06587 fix: stop the periodic device query from flashing a console window
```

后续可做：

> Possible next steps:

1. 键盘1 `3554:FA09` 的电量字段已查清：该设备在 Windows 侧没有可用电量通道，界面改为 `电量未公开`，详见下一篇《Hardware-Viewer - Hardware Limits》
2. 键盘2 `0C45:FEFE` 的中位数窗口可从 5 调大，进一步抑制 ±4 抖动
3. 耳机 `4C4A:4155` 已确认接收器不转发电量，除非厂商提供配置软件，否则无解

> 1. The `3554:FA09` battery field is still unconfirmed; `app/feature_log.py` is sampling and the CSV can be compared once the charge drops
> 2. The `0C45:FEFE` median window could grow beyond 5 to damp the ±4 jitter further
> 3. The `4C4A:4155` headset's dongle provably never forwards the charge level, so it stays unsolved unless the vendor ships a configuration tool
