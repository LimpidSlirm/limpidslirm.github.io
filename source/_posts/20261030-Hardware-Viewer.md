---
title: Hardware-Viewer
date: 2026-10-30 18:00:00
tags:
  - Hardware Viewer
  - Dev Log
  - Python
  - Windows
  - Reverse Engineering
  - Desktop App
  - Hardware
---

开发一个可以看硬件实时电量的 app。

仓库地址为 https://github.com/LimpidSlirm/2.4G-Hardware-Viewer

以下为 agent 输出的日志。


面向已连接的音频、键盘与鼠标设备的 Windows 硬件状态查看器。

> Windows hardware status viewer for connected audio, keyboard, and mouse devices.

## 1. 当前范围 | Current scope

第一版只读取 Windows 已经暴露的设备信息，不抓取空中的 2.4G 无线报文。

> The first version reads device information already exposed by Windows. It does not capture raw 2.4G radio packets from the air.

目标设备包括：

> The target devices are:

- 耳机或其他音频设备
- 键盘
- 鼠标

> - Headset or other audio endpoints
> - Keyboard
> - Mouse

## 2. 第一步验证 | Step 1 verification

在开发机上，Windows 当前枚举到：

> On the development computer, Windows currently enumerates:

- HUAWEI FreeBuds SE 2 的音频端点与媒体设备
- HID 与 USB 键盘设备
- HID 鼠标设备

> - HUAWEI FreeBuds SE 2 audio endpoints and media devices
> - HID and USB keyboard devices
> - HID mouse devices

所有匹配到的设备状态均为 `OK`。

> All inspected matching devices reported status `OK`.

## 3. 已知限制 | Known limitations

应用能拿到的信息取决于设备本身及其 Windows 驱动。连接状态与设备身份预期可用；电量、信号质量、延迟以及厂商私有信息则可能不会暴露。

> The information available to the application depends on the device and its Windows driver. Connection state and device identity are expected to be available; battery, signal quality, latency, and vendor-specific details may not be exposed.

## 4. 技术路线 | Technical direction

项目使用：

> The project will use:

- Python 3.13
- PySide6 构建 Windows 桌面界面
- pywin32 访问 Windows 设备与系统接口
- pyserial，仅在将来某款受支持设备提供串口时使用

> - Python 3.13
> - PySide6 for the Windows desktop user interface
> - pywin32 for Windows device and system interfaces
> - pyserial only if a future supported device exposes a serial interface

应用以 Windows 为首要目标。曾考虑 .NET/WPF 方案，但当前开发环境已经具备可用的 Python GUI 与 Windows API 栈，因此对第一个可用版本而言，Python 的阻力更小。

> The application targets Windows first. The .NET/WPF option was considered, but the current development environment has a usable Python GUI and Windows API stack already installed, so Python is the lower-friction choice for the first working version.

## 5. 第二步验证 | Step 2 verification

开发环境当前提供：

> The development environment currently provides:

- Python 3.13.9（当前 `python` 命令指向的版本）
- PySide6 6.9.2
- pywin32
- pyserial 3.5
- Tkinter，作为标准库的兜底 GUI 工具包

> - Python 3.13.9 through the active `python` command
> - PySide6 6.9.2
> - pywin32
> - pyserial 3.5
> - Tkinter as a fallback standard-library GUI toolkit

这些组件足以在不安装额外包的情况下创建并运行初始桌面应用。

> These components are sufficient to create and run the initial desktop application without installing additional packages.

## 6. 界面方案 | Interface direction

应用使用一个透明悬浮窗，它：

> The application uses a transparent overlay window that:

- 没有标准 Windows 边框与标题栏
- 始终位于其他窗口之上
- 可通过拖动可见面板移动
- 原型阶段按 `Esc` 关闭

> - Has no standard Windows border or title bar
> - Stays above other windows
> - Can be moved by dragging the visible panel
> - Closes with the `Esc` key during the prototype stage

透明悬浮层只是初始外壳。设备状态卡片与控件会在此基础上添加，不改变窗口行为。

> The transparent overlay is the initial shell. Device status cards and controls will be added without changing this window behavior.

## 7. 项目结构 | Project structure

```text
app/
  __init__.py
  main.py
requirements.txt
```

## 8. 第三步验证 | Step 3 verification

在项目目录下运行原型：

> Run the prototype from the project directory:

```powershell
python -m app.main
```

运行自动启动冒烟测试：

> Run the automatic startup smoke test:

```powershell
python -m app.main --smoke-test
```

## 9. 第四步验证 | Step 4 verification

原型现在通过 `Get-PnpDevice -PresentOnly` 查询 Windows 即插即用设备，并显示匹配到的音频端点、键盘与鼠标。在开发机上，该查询返回 15 个设备，状态全部为 `OK`。

> The prototype now queries Windows Plug and Play devices through `Get-PnpDevice -PresentOnly` and displays matching audio endpoints, keyboards, and mice. On the development computer, the query returned 15 devices and all reported status `OK`.

当前发现层只读取设备身份与连接状态，不捕获键盘输入、鼠标移动、音频内容或原始 2.4G 报文。

> The current discovery layer only reads device identity and connection status. It does not capture keyboard input, mouse movement, audio content, or raw 2.4G packets.

设备面板按类别分组结果，去掉类别、名称与状态都相同的重复显示项，显示正常状态计数，并每五秒自动刷新。底层 Windows 实例 ID 会被保留，供后续详情视图使用。

> The device panel groups results by category, removes repeated display entries that represent the same category, name, and status, shows normal-status counts, and refreshes automatically every five seconds. The underlying Windows instance IDs are retained for future detail views.

面板同时提供即时刷新按钮。鼠标悬停在设备上会显示其 Windows 实例 ID，而不把技术标识塞进主界面。

> The panel also provides an immediate refresh button. Hovering over a device shows its Windows instance ID without adding the technical identifier to the main display.

设备发现在后台 Qt 线程中运行，因此无论即时刷新还是自动刷新，查询 Windows 时透明窗口都保持响应。

> Device discovery runs in a background Qt thread, so the transparent window remains responsive while an immediate or automatic refresh queries Windows.

点击某行设备，会在设备列表下方的详情区显示其类别、状态与 Windows 实例 ID。较长的实例 ID 会在悬浮窗内换行，而不会把窗口横向撑开。

> Clicking a device row shows its category, status, and Windows instance ID in the detail area below the device list. Long instance IDs wrap inside the overlay instead of expanding the window horizontally.

悬浮窗支持 `F5` 立即刷新；`Ctrl+Up` 与 `Ctrl+Down` 在 35% 到 100% 之间增减不透明度；`Esc` 关闭窗口。面板显示最近一次刷新时间与当前不透明度。

> The overlay supports `F5` for an immediate refresh. `Ctrl+Up` and `Ctrl+Down` increase or decrease opacity between 35% and 100%; `Esc` closes the window. The panel displays the most recent refresh time and current opacity.

## 10. 电量读取 | Battery readings

发现查询同时检查 Windows ACPI 电池。Windows 未公开外设电量时显示 `未知（Windows 未公开）`；应用不会根据连接状态或电源管理数据推断百分比。在开发机上，系统电池报告 100%，而已连接的耳机、键盘与鼠标在测试过的通用 PnP 属性中都未暴露百分比。

> The discovery query also checks the Windows ACPI battery. Peripheral battery levels are shown as `未知（Windows 未公开）` unless Windows exposes a device-specific battery value; the application does not infer a percentage from connection or power-management data. On the development computer, the system battery reports 100%, while the connected headset, keyboard, and mouse do not currently expose a percentage through the tested generic PnP properties.

参考项目 [`2.4G-battery-viewer`](https://github.com/yszyszysz233/2.4G-battery-viewer) 针对 VID:PID `373B:1216` 与 `3654:6901` 使用设备私有 HID 协议。开发机当前的 HID 键鼠设备为 `3554:FA09` 与 `24AE:1411`，耳机则以蓝牙设备形式出现，因此不会自动套用参考项目里的命令。

> The reference project [`2.4G-battery-viewer`](https://github.com/yszyszysz233/2.4G-battery-viewer) uses device-specific HID protocols for VID:PID `373B:1216` and `3654:6901`. The development computer currently exposes `3554:FA09` and `24AE:1411` for its HID keyboard/mouse devices, and the headset appears as a Bluetooth device, so those reference commands are not applied automatically.

发现视图排除了笔记本的 ACPI/PS/2 键盘与内置麦克风阵列。Windows 设备的自动读取每五分钟运行一次；`立即刷新` 按钮与 `F5` 仍可触发按需读取。

> The discovery view excludes the ACPI/PS/2 keyboard of the laptop and the built-in microphone array. Automatic Windows device reading runs every five minutes; the `立即刷新` button and `F5` still trigger an on-demand read.

详情视图现在会识别设备传输方式，并在存在时给出 VID:PID。这是为选择安全的设备私有电量协议而做的只读识别步骤，不会发送 HID 命令。

> The detail view now identifies the device transport and, when present, its VID:PID. This is a read-only identification step for selecting a safe device-specific battery protocol; it does not send HID commands.

设备列表不再使用滚动区域；悬浮窗按行数自适应高度，上限 720 px。已知电量的外设显示绿色进度条与百分比，没有数值的行显示 `电量：未知（Windows 未公开）`。点击某行展开列表下方的详情面板，再次点击同一行收起；在点击任何行之前该面板保持隐藏。系统电池不再查询或显示。

> The device list no longer uses a scroll area; the overlay sizes itself to the number of rows and caps at 720 px. Each peripheral with a known battery shows a green progress bar with its percentage, and rows without a value show `电量：未知（Windows 未公开）`. Clicking a row expands a detail panel below the list; clicking the same row again collapses it, and the panel stays hidden until a row is clicked. The system battery is no longer queried or displayed.

应用仍会统计读到多少个外设电量值、还有多少个仍未被 Windows 公开，但该汇总在悬浮窗中隐藏，以保持面板紧凑。

> The application still calculates how many peripheral battery values were read and how many remain undisclosed by Windows, but this summary is hidden from the overlay to keep the panel compact.

## 11. HID 电量排查 | HID battery investigation

项目现在包含一个只读 HID 清单，基于 Windows HID 与 SetupAPI DLL 实现。它记录 VID:PID、Usage Page、Usage 以及输入/输出/Feature 报文长度，不发送报文，也不读取输入事件。

> The project now includes a read-only HID inventory using the Windows HID and SetupAPI DLLs. It records VID:PID, Usage Page, Usage, and input/output/Feature Report lengths without sending reports or reading input events.

在开发机上，该清单找到 22 个 HID 接口。外接键鼠接口使用 VID:PID `3554:FA09` 与 `24AE:1411`，共匹配到 17 个接口，其中 3 个带 Feature 报文。这些接口是下一步安全排查设备私有电量的来源。

> On the development computer, the inventory found 22 HID interfaces. The external keyboard/mouse interfaces use VID:PID `3554:FA09` and `24AE:1411`; 17 matching interfaces were found, including 3 with Feature Reports. These interfaces are the next safe source for device-specific battery investigation.

第一次只读 Feature 报文探测尝试了 Report ID `0` 到 `3`。只有一条报文有响应：`093A:0255`，Usage `0x0D/0x05`，长度 257，属于触摸板而非目标外接键鼠。目标 `3554:FA09` 与 `24AE:1411` 的 Feature 报文接口没有返回报文，因此这次探测没有推断出任何电量值。

> The first read-only Feature Report probe tried Report IDs `0` through `3`. Only one report responded: `093A:0255`, Usage `0x0D/0x05`, length 257, which belongs to the touchpad rather than the target external keyboard or mouse. The target `3554:FA09` and `24AE:1411` Feature Report interfaces did not return a report, so no battery value is inferred from this probe.

当前厂商探测可以通过 `pywinusb` 读取 `3554:FA09` 的 Report 6，且不发送报文。在开发机上它连续三次返回稳定的候选字节 `(100, 100, 100)`。由于该接收器同时暴露键盘与鼠标，第一个值目前显示为 `键盘电量候选 100%`；在受控的放电测试确认字节映射之前，它仍被明确标记为候选值。

> The current vendor probe can read `3554:FA09` Report 6 through `pywinusb` without sending a report. On the development computer it returned stable candidate bytes `(100, 100, 100)` in three consecutive reads. Because this receiver exposes the keyboard and mouse together, the first value is currently shown as `键盘电量候选 100%`; it remains explicitly marked as a candidate until a controlled battery-change test confirms the byte mapping.

连接对比现在把这个接收器归为键盘通路：断开键盘时 `3554:FA09` 消失，Report 6 不返回数据；只连接键盘时它重新出现，并三次返回相同的原始报文：

> The connection comparison now identifies this receiver as the keyboard path: when the keyboard was disconnected, `3554:FA09` disappeared and Report 6 returned no data; when only the keyboard was connected, it reappeared and returned the same raw report three times:

```text
[6, 0, 2, 100, 100, 100, 53, 21]
```

这确认了它与键盘接收器的关联，也支持当前满电的观测结果。由于尚未进行放电测量，三个候选字节各自的准确含义仍未独立确认。

> This confirms the association with the keyboard receiver and supports the current full-charge observation. The exact meaning of each of the three candidate bytes is still not independently confirmed because no discharge measurement has been performed.

## 12. 断连测试 | Disconnect test

断开键盘与耳机后，`3554:FA09` 从 HID 清单中消失，其厂商电量探测也没有读数。`24AE:1411` 的接口仍然存在，Windows 也继续枚举耳机的蓝牙/音频端点。这意味着下一次映射测试必须一次只连接一个外设；蓝牙设备断开后，Windows 可能仍保留其音频端点。

> After the keyboard and headset were disconnected, `3554:FA09` disappeared from the HID inventory and its vendor battery probe returned no reading. The `24AE:1411` interfaces remained present, and Windows continued to enumerate the Bluetooth/audio endpoints of the headset. This means the next mapping test must connect one peripheral at a time; Windows may retain audio endpoints after a Bluetooth device is disconnected.

只连接鼠标时，活动目标是 `24AE:1411`（`Rapoo Gaming Device`）。它的 HID 接口声明了 33 字节的 Feature 报文。只读探测对 Report 8 返回报文 ID 不兼容的错误，对 Report 9 返回 33 个零字节。这些值不被当作电量读数：零可能是协议数据，也可能是不受支持的报文，而不是 0% 电量。既有的 `3554:FA09` 电量读取逻辑在该配置下正确地返回无结果。

> With only the mouse connected, the active target was `24AE:1411` (`Rapoo Gaming Device`). Its HID interfaces declared 33-byte Feature Reports. A read-only probe returned an incompatible-report-ID error for Report 8 and 33 zero bytes for Report 9. These values are not treated as a battery reading: zero may be protocol data or an unsupported report, not 0% battery. The existing `3554:FA09` battery reader correctly returned no result in this configuration.

报文描述符检查还发现，这两条报文都只以 32 字节原始字段的形式暴露厂商 Usage `0xFF00/0x0003`，不存在标准 HID Battery Strength usage。由于现有证据无法定位电量字节，应用不会向该鼠标发送输出报文或厂商命令，而是继续将其电量显示为未公开。

> The report descriptor inspection also found that both reports expose only the vendor Usage `0xFF00/0x0003` as a 32-byte raw field. No standard HID Battery Strength usage was present. Because the current evidence does not identify a battery byte, the application does not send an output report or vendor command to this mouse and continues to show its battery as undisclosed.

## 13. 鼠标电量报文 | Mouse battery report

当前鼠标（`24AE:1411`，雷柏游戏设备）使用的协议与参考截图中 `373B:1216` 的命令协议不同。它在 `UsagePage 0xFF00 / Usage 0x0002` 接口上被动发送 Input Report 7。一次捕获到的报文为：

> The current mouse (`24AE:1411`, Rapoo Gaming Device) uses a different protocol from the command protocol of the reference screenshot's `373B:1216`. It passively sends Input Report 7 on its `UsagePage 0xFF00 / Usage 0x0002` interface. A captured report was:

```text
[7, 16, 3, 64, 6, 64, 6, 1, 99, 0, 2, 2, 0]
```

读取器使用的字段布局：

> Field layout used by the reader:

| 偏移 / Offset | 含义 / Meaning |
| --- | --- |
| `[0]` | 报文 ID `0x07` / Report ID |
| `[1]` | 设备/接收器标识 / Device-receiver identifier |
| `[2]` | DPI 档位索引 / DPI profile index |
| `[3..4]` | X 轴 DPI，16 位小端 / X DPI, 16-bit little-endian |
| `[5..6]` | Y 轴 DPI，16 位小端 / Y DPI, 16-bit little-endian |
| `[7]` | 活动状态标志 / Active state flag |
| `[8]` | 电量百分比，`0x00`-`0x64` / Battery percentage |

这些偏移在运行时通过 DPI 对做校验：该 DPI 对解码为合理的 `1600 x 1600`；若某条报文的 DPI 对不合理，整条报文会被拒绝，而不会被当作电量读取。不同采样观测到的电量为 `99` 与 `100`，说明该字节是活数据而非固定占位值。该设备为 `24AE:1411`、报文 13 字节，而雷柏 VT7 的公开文档描述的是 `24AE:1413`、报文 19 字节，设备标识字节为 `0x10` 而非 `0x20`；即便如此，共用偏移仍能一致解码，包括 DPI 自检。

> The offsets are validated at runtime through the DPI pair, which decoded to a plausible `1600 x 1600`; a report whose DPI pair is implausible is rejected instead of being read as battery. Observed battery values were `99` and `100` across separate samples, so the byte is live rather than a fixed placeholder. The device is `24AE:1411` with a 13-byte report while the published Rapoo VT7 documentation describes `24AE:1413` with a 19-byte report, and the device identifier byte is `0x10` instead of `0x20`; the shared offsets still decode consistently, including the DPI self-check.

应用只监听这条被动报文，从不发送 Output 或 Feature 报文。鼠标可能处于休眠状态，直到被移动才发出报文；没有报文一律视为未知值，而不是 0%。

> The application only listens for this passive report and never sends an Output or Feature Report. The mouse may be asleep and emit no report until it is moved; no report is treated as an unknown value, not as 0%.

## 14. 耳机连接测试 | Headset connection test

连接 HUAWEI FreeBuds SE 2 后，Windows 枚举到该蓝牙设备及其 A2DP、AVRCP 与 Hands-Free 服务。它没有枚举到参考项目中的 `3654:6901` 接收器，也没有出现新的 HID 电量接口。`Win32_Battery` 与 WMI 的 `BatteryStatus` 查询仍只报告笔记本 ACPI 电池 100%，该蓝牙耳机没有通过这些接口提供电量百分比。它的蓝牙 `DEVPKEY_Device_PowerData` 值是电源管理元数据，而不是电量百分比，因此不被当作电量使用。

> After connecting the HUAWEI FreeBuds SE 2, Windows enumerated the Bluetooth device and its A2DP, AVRCP, and Hands-Free services. It did not enumerate the `3654:6901` receiver of the reference project, and no new HID battery interface appeared. `Win32_Battery` and the WMI `BatteryStatus` query continued to report only the laptop ACPI battery at 100%; the Bluetooth headset did not provide a battery percentage through these interfaces. Its Bluetooth `DEVPKEY_Device_PowerData` value is power-management metadata, not a battery percentage, so it is not used as one.

后来的耳机测试识别到另一台设备：`ZhuAudio ZG2`（`4C4A:4155`）。这是一台 USB 复合音频设备，带扬声器与麦克风端点，以及一个用户控制 HID 接口。该 HID 接口没有 Feature 报文，设备的 Windows 电源属性也只暴露电源管理元数据，因此在测试过的只读接口中都拿不到电量百分比。此前关于 HUAWEI 的结论仅适用于那副蓝牙耳机，不适用于这台 USB 耳机。

> The later headset test identified a different device: `ZhuAudio ZG2` (`4C4A:4155`). This is a USB composite audio device with speaker and microphone endpoints plus a user-control HID interface. The HID interface has no Feature Reports, and the Windows power properties of the device expose only power-management metadata. No battery percentage was available through the tested read-only interfaces. The earlier HUAWEI result applies only to the Bluetooth earbuds and not to this USB headset.

Windows 蓝牙设置可以在 HUAWEI FreeBuds SE 2 连接时显示一个合并的 `100%` 电量指示。该视图只显示一个值，而不是左右耳各自的值。设备通过经典蓝牙音频服务（A2DP、AVRCP 与 HFP）枚举，测试过的 PnP/WMI 接口不暴露分左右耳的电量。应用不得把合并值拆成两个臆造的百分比；要支持左右耳，需要找到设备私有的蓝牙电量协议，或其他能暴露双通道的 API。

> Windows Bluetooth settings can display a combined `100%` battery indicator for the HUAWEI FreeBuds SE 2 when it is connected. The settings view shows one value rather than separate left- and right-earbud values. The device is enumerated through classic Bluetooth audio services (A2DP, AVRCP, and HFP), and the tested PnP/WMI interfaces do not expose separate earbud batteries. The application must not split the combined value into two invented percentages; left/right support requires locating the device-specific Bluetooth battery protocol or another API that exposes both channels.

## 15. 设备归属调查与内置设备过滤 | Device ownership survey and built-in device filtering

界面上曾同时出现 2 条键盘与 3 条鼠标，逐条核对 HID 集合后确认这不是重复渲染，而是 Windows 把一个物理设备拆成了多个顶层集合：

> The UI once showed two keyboards and three mice at the same time. Checking each HID collection showed this was not duplicate rendering: Windows splits one physical device into several top-level collections.

| 显示条目 | VID:PID | 真实身份 |
| --- | --- | --- |
| 键盘 | `3554:FA09` | 2.4G 键盘接收器的键盘集合（`MI_00`） |
| 键盘 | `24AE:1411` | 雷柏接收器的键盘集合（`MI_01` `COL01`/`COL02`） |
| 鼠标 | `3554:FA09` | 同一键盘接收器附带的鼠标集合（`MI_01` `COL05`） |
| 鼠标 | `24AE:1411` | 雷柏鼠标本体（`MI_00`） |
| 鼠标 | 无 | 笔记本触摸板 `HID\UNIW0001`（`093A:0255`） |

> | Entry | VID:PID | Real identity |
> | --- | --- | --- |
> | Keyboard | `3554:FA09` | Keyboard collection of the 2.4G keyboard receiver (`MI_00`) |
> | Keyboard | `24AE:1411` | Keyboard collection of the Rapoo receiver (`MI_01` `COL01`/`COL02`) |
> | Mouse | `3554:FA09` | Mouse collection shipped by the same keyboard receiver (`MI_01` `COL05`) |
> | Mouse | `24AE:1411` | The Rapoo mouse itself (`MI_00`) |
> | Mouse | none | Laptop touchpad `HID\UNIW0001` (`093A:0255`) |

原因有三点：一个 2.4G 接收器会注册 4–6 个 HID 集合；显示层只保留音频、键盘、鼠标三类，其余厂商自定义集合被隐藏，但同一接收器仍会同时冒出键盘与鼠标两条；名称来自 Windows 通用驱动，例如 `HID Keyboard Device`，不含品牌型号，所以两台不同键盘看起来完全一样。

> There are three reasons: one 2.4G receiver registers 4–6 HID collections; the display layer keeps only audio, keyboard, and mouse classes, so vendor-defined collections are hidden while the same receiver still produces both a keyboard and a mouse row; and the names come from generic Windows drivers such as `HID Keyboard Device`, so two different keyboards look identical.

内置触摸板与之前的内置键盘、麦克风阵列一样被过滤，不再参与显示：

> The built-in touchpad is now filtered like the built-in keyboard and microphone array, and no longer appears:

- `HID\UNIW...` 开头的鼠标类实例
- 名称包含 `触摸板` 或 `touchpad` 的鼠标类设备

> - Mouse-class instances whose ID starts with `HID\UNIW...`
> - Mouse-class devices whose name contains `触摸板` or `touchpad`

## 16. 按接收器合并与电量条界面 | Receiver-level merging and battery bars

设备列表改为按 VID:PID 把同一物理设备的多个 HID 集合合并成一行，并用 `MI_00`（主功能接口）决定该行的类别与名称。合并后的名称按实际角色生成：只有键盘集合时为 `无线键盘`，只有鼠标集合时为 `无线鼠标`，两者都有时为 `无线键鼠接收器`。

> The device list now merges every HID collection of one physical device into a single row by VID:PID, and uses `MI_00` (the main function interface) to decide that row's category and name. The merged name follows the real role: `无线键盘` when only a keyboard collection exists, `无线鼠标` when only a mouse collection exists, and `无线键鼠接收器` when both exist.

`DeviceRecord` 增加 `battery_readings` 字段，用于在一行里同时承载键盘与鼠标两个读数：

> `DeviceRecord` gained a `battery_readings` field so one row can carry both keyboard and mouse readings:

```python
battery_readings: tuple[tuple[str, int, str], ...] = ()
# ("键盘", 100, "厂商 HID 报告（候选）"), ("鼠标", 87, "厂商 HID 报告")
```

> ```python
> battery_readings: tuple[tuple[str, int, str], ...] = ()
> # ("键盘", 100, "厂商 HID 报告（候选）"), ("鼠标", 87, "厂商 HID 报告")
> ```

去重键原本是 `(类别, 名称, 状态)`，会把两台不同鼠标合成一行并丢掉其中一台的电量；现在加入 VID:PID，改为 `(类别, 名称, 状态, VID:PID)`。这是合并过程中实际暴露并修复的缺陷。

> The dedupe key used to be `(category, name, status)`, which merged two different mice into one row and dropped one of the readings. It is now `(category, name, status, VID:PID)`. This defect was exposed by the merging work and fixed.

界面同时做了这些调整：

> The UI was adjusted as well:

- 有电量的行显示绿色电量条与百分比；电量未知的行显示 `电量未公开`
- 点击设备行展开详情，再次点击收起；不点击时不占空间
- 移除滚动区域，窗口高度改为按内容自适应，上限为屏幕可用高度
- 移除本机电量（不再查询 `Win32_Battery`）
- 文案精简为 `7 个设备 · 6 个在线`、`更新 18:05:12 · 每 5 分钟 · 透明度 92%`

> - Rows with a value show a green battery bar and percentage; rows without one show `电量未公开`
> - Clicking a row expands details, clicking again collapses them, and nothing is taken up when idle
> - The scroll area was removed; the window height now fits the content and caps at the screen's usable height
> - The system battery row was removed and `Win32_Battery` is no longer queried
> - Copy was tightened to `7 个设备 · 6 个在线` and `更新 18:05:12 · 每 5 分钟 · 透明度 92%`

## 17. 迷你电量窗与全局快捷键 | Mini battery window and global hotkey

程序默认以迷你窗启动，尺寸约 210 px 宽，只显示键盘与鼠标的电量条，不再展示设备清单。完整界面保留原有一切功能，可通过两种方式切换：

> The program now starts as a mini window about 210 px wide that shows only the keyboard and mouse battery bars, without the device list. The full view keeps every previous feature and can be reached in two ways:

- 全局快捷键 `Ctrl + Alt + B`（应用未获得焦点时同样有效）
- 双击窗口任意位置

> - The global hotkey `Ctrl + Alt + B` (works even when the app is not focused)
> - Double-clicking anywhere on the window

快捷键通过 Win32 `RegisterHotKey` 注册，并由 `QAbstractNativeEventFilter` 捕获 `WM_HOTKEY`，实现在 `app/hotkey.py`：

> The hotkey is registered through Win32 `RegisterHotKey` and captured via `QAbstractNativeEventFilter` on `WM_HOTKEY`, implemented in `app/hotkey.py`:

```python
app.installNativeEventFilter(hotkey)
# hotkey = GlobalHotkey(HOTKEY_ID, MOD_CONTROL | MOD_ALT, 0x42, window.toggle_mode)
```

> ```python
> app.installNativeEventFilter(hotkey)
> # hotkey = GlobalHotkey(HOTKEY_ID, MOD_CONTROL | MOD_ALT, 0x42, window.toggle_mode)
> ```

实测确认：迷你窗 `210x60`、完整界面 `500x5xx`，快捷键触发一次后 `_compact` 由 `True` 变为 `False`，`hotkey_registered: True`。

> Verified: the mini window measured `210x60` and the full view `500x5xx`; one hotkey press flipped `_compact` from `True` to `False`, with `hotkey_registered: True`.

## 18. 开机自启 | Autostart

自启项写入当前用户 `Run` 项，命令使用 `pythonw.exe`，避免开机弹出控制台窗口：

> The startup entry is written to the current-user `Run` key and uses `pythonw.exe` so no console window appears at boot:

```text
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
  2.4G-Hardware-Viewer = "<pythonw.exe>" "<项目>\launch.pyw"
```

> ```text
> HKCU\Software\Microsoft\Windows\CurrentVersion\Run
>   2.4G-Hardware-Viewer = "<pythonw.exe>" "<project>\launch.pyw"
> ```

入口脚本 `launch.pyw` 只负责把项目目录加入 `sys.path` 并调用 `app.main.main()`；扩展名 `.pyw` 保证由 `pythonw.exe` 关联执行。

> The `launch.pyw` entry script only adds the project directory to `sys.path` and calls `app.main.main()`; the `.pyw` extension makes it run under `pythonw.exe`.

安装与移除：

> Install and remove:

```powershell
python -m app.main --install-autostart
python -m app.main --remove-autostart
```

> ```powershell
> python -m app.main --install-autostart
> python -m app.main --remove-autostart
> ```

实测：写入后回读值与生成命令完全一致，移除后查询返回 `None`，未在系统中残留。

> Verified: the value read back after install matched the generated command exactly, and after removal the query returned `None` with nothing left behind.

## 19. 鼠标电量缓存 | Mouse battery cache

鼠标只在状态变化或有动作时广播 Report 7，休眠期间完全静默。原始实现对静默直接返回空，界面会从 `87%` 掉回“电量未公开”。现在改为在进程内保留最后一次有效读数：

> The mouse broadcasts Report 7 only on state changes or activity and stays completely silent while asleep. The original implementation returned nothing on silence, so the UI dropped from `87%` back to `电量未公开`. It now keeps the last valid reading in process memory:

- `_MOUSE_CACHE` 按 VID:PID 存放读数与单调时钟时间戳，并用锁保护
- 收到新报文即刷新缓存，并记录 `captured_clock`（`HH:MM`）
- 无报文时返回缓存值，`cached=True`，界面来源标注 `厂商 HID 报告 · 缓存 18:42`
- 超过 24 小时未更新则回退为无读数，绝不显示无限期过期的数据
- 单次监听拆分为 `_listen_mouse_report()`，仍然不发送任何报文

> - `_MOUSE_CACHE` stores the reading plus a monotonic timestamp per VID:PID, guarded by a lock
> - A fresh report refreshes the cache and records `captured_clock` (`HH:MM`)
> - Without a report the cached value is returned with `cached=True`, and the UI labels the source `厂商 HID 报告 · 缓存 18:42`
> - Anything older than 24 hours falls back to no reading; indefinitely stale data is never shown
> - The single listen pass was extracted into `_listen_mouse_report()` and still sends no report

缓存行为用打桩验证，覆盖四种路径：

> The cache was verified with stubs across four paths:

```text
fresh               : 87  cached=False  clock=19:18
silent_with_cache   : (87, True, '19:18')
expired_returns_none: True
no_cache_no_report  : True
```

> ```text
> fresh               : 87  cached=False  clock=19:18
> silent_with_cache   : (87, True, '19:18')
> expired_returns_none: True
> no_cache_no_report  : True
> ```

缓存只存在于进程内存。程序重启后仍需一次新的广播才能恢复读数，移动鼠标即可触发；是否改为写本地缓存文件仍在权衡，因为那会在项目目录留下状态文件。

> The cache lives only in process memory. After a restart one new broadcast is still required, which a mouse movement triggers; switching to an on-disk cache file is still being weighed because it would leave a state file in the project directory.

## 20. 验证记录与后续 | Verification log and next steps

本轮验证命令与结果：

> Commands and results for this round:

```text
py_compile  app/*.py launch.pyw   -> COMPILE_OK
python -m app.main --smoke-test   -> SMOKE_OK
git diff --check                  -> 无报错
```

> ```text
> py_compile  app/*.py launch.pyw   -> COMPILE_OK
> python -m app.main --smoke-test   -> SMOKE_OK
> git diff --check                  -> no errors
> ```

对应提交：

> Corresponding commit:

```text
ef110db feat: add mini battery window, global hotkey and autostart
```

> ```text
> ef110db feat: add mini battery window, global hotkey and autostart
> ```

后续可做：

> Possible next steps:

1. 左右耳机电量：需要找到设备私有的蓝牙电量协议，或其他能分通道暴露的 API
2. 键盘候选字节：`3554:FA09` Report 6 中 `[3..6]` 三个值尚未逐字节验证，仍需一次放电对照
3. 电量缓存持久化：决定是否落盘，权衡“重启即有值”与“在项目目录留下状态文件”

> 1. Left/right earbud battery: requires the device-private Bluetooth battery protocol or another channel-aware API
> 2. Keyboard candidate bytes: the three values at `[3..6]` of `3554:FA09` Report 6 are still unverified byte by byte; a discharge comparison is needed
> 3. Cache persistence: decide whether to write to disk, weighing "value available right after restart" against "leaving a state file in the project directory"

## 21. 托盘常驻 | Notification-area tray

程序不再只依赖浮窗，而是常驻任务栏通知区域（默认落在隐藏图标栏）。托盘图标本身显示电量：≥60% 绿色、≥25% 黄色、<25% 红色，无读数时画空心电池，0% 额外画一道斜杠。图标由 `QPainter` 直接绘制，不引入任何第三方图标或托盘库。

> The program no longer depends on the floating window alone: it now lives in the taskbar notification area (usually the hidden-icons tray). The tray icon itself shows charge: green at ≥60%, yellow at ≥25%, red below 25%, a hollow battery when there is no reading, and a slash at 0%. The icon is drawn directly with `QPainter`, so no third-party icon or tray library is pulled in.

交互设计：

> Interaction design:

| 操作 | 效果 |
| --- | --- |
| 单击图标 | 显示 / 隐藏迷你窗 |
| 双击图标 | 打开完整界面 |
| 右键菜单 | 显示迷你窗 / 显示完整界面 / 立即刷新 / 退出 |
| 悬停 | 提示 `键盘 100% · 鼠标 87%` |
| `Esc` 或关闭窗口 | 收起到托盘，进程继续运行 |
| 菜单「退出」 | 真正结束进程 |

> | Action | Effect |
> | --- | --- |
> | Single click | Show / hide the mini window |
> | Double click | Open the full view |
> | Context menu | Show mini / show full / refresh now / quit |
> | Hover | Tooltip `键盘 100% · 鼠标 87%` |
> | `Esc` or closing the window | Collapse to the tray, process keeps running |
> | Menu `退出` | Really terminates the process |

退出路径会依次注销全局快捷键、停止刷新定时器、等待发现线程结束、隐藏托盘图标，再退出应用；这样不会留下僵尸进程，也不会残留已注册的 hotkey 占用。

> The quit path unregisters the global hotkey, stops the refresh timer, waits for the discovery thread, hides the tray icon, and only then exits the application, so no zombie process or stale hotkey registration is left behind.

验证时发现并修掉了一个缺陷：`closeEvent` 原本在判断「是否真正退出」之前就隐藏托盘图标，导致按 `Esc` 收起窗口时托盘图标一起消失，热键虽仍生效却没了入口。现在只有真正退出时才隐藏图标。

> A defect was found and fixed during verification: `closeEvent` hid the tray icon before checking whether the app was really quitting, so pressing `Esc` removed the tray entry even though the hotkey still worked. The icon is now hidden only on a real quit.

实测输出：

> Measured output:

```text
system_tray_available: True
tray_visible: True
menu_actions: ['显示迷你窗', '显示完整界面', '立即刷新', '退出']
tooltip_with_data: '2.4G Hardware Viewer\n键盘 100% · 鼠标 87%'
tooltip_empty: '2.4G Hardware Viewer\n暂无电量'
hidden_after_esc_style: True
tray_still_shown: True
tray_hidden_after_quit_close: False
```

> ```text
> system_tray_available: True
> tray_visible: True
> menu_actions: ['显示迷你窗', '显示完整界面', '立即刷新', '退出']
> tooltip_with_data: '2.4G Hardware Viewer\n键盘 100% · 鼠标 87%'
> tooltip_empty: '2.4G Hardware Viewer\n暂无电量'
> hidden_after_esc_style: True
> tray_still_shown: True
> tray_hidden_after_quit_close: False
> ```

### 后续：已按要求移除 | Follow-up: removed on request

该托盘功能随后被明确移除，`app/tray.py` 删除，`main.py` 恢复为「`Esc` 关闭窗口、不做托盘常驻」，也不再引入 `QSystemTrayIcon` 与 `QMenu`。保留的仍是迷你窗、`Ctrl + Alt + B` 全局快捷键与开机自启。验证：应用中 `QSystemTrayIcon` 数量为 0，迷你窗 `210x60`，完整界面正常，关闭后窗口不可见。

> The tray feature was subsequently removed by request: `app/tray.py` was deleted and `main.py` returned to "`Esc` closes the window, no tray residency", with `QSystemTrayIcon` and `QMenu` no longer imported. The mini window, the `Ctrl + Alt + B` global hotkey, and autostart remain. Verified: zero `QSystemTrayIcon` instances in the app, a `210x60` mini window, a working full view, and an invisible window after closing.

移除代码后，Win11 任务栏里仍能看见那个托盘图标。排查结论：代码已不再创建图标，残留来自 Windows 11 的托盘缓存——`HKCU\Control Panel\NotifyIconSettings` 下仍留着一条 `ExecutablePath = ...\python.exe` 的记录，其 `IconSnapshot` 是一张 612 字节 PNG。把该图导出查看，正是本项目的空心电池图标，因此确认是旧进程被强制结束时留下的缓存，而不是另一个程序。

> After the code was removed, that tray icon was still visible in the Windows 11 taskbar. Investigation: the code no longer creates an icon, and the leftover came from the Windows 11 tray cache — an entry under `HKCU\Control Panel\NotifyIconSettings` still listed `ExecutablePath = ...\python.exe`, whose `IconSnapshot` was a 612-byte PNG. Dumping that image showed this project's own hollow battery icon, confirming the cache was left behind when the old process was force-killed rather than belonging to another program.

处理方式：删除该注册表项，再重启 `explorer.exe` 让托盘重建。之后确认 `NotifyIconSettings` 下已无任何指向 python 的记录，应用进程与迷你窗均正常。

> Fix: delete that registry key, then restart `explorer.exe` so the tray rebuilds. Afterwards no entry under `NotifyIconSettings` pointed at python, and both the app process and the mini window remained healthy.

教训：注册过 `QSystemTrayIcon` 的程序即使退出，Win11 仍可能把图标快照留在缓存里，务必在删除托盘功能后额外清理一次缓存。

> Lesson: on Windows 11 an app that once registered a `QSystemTrayIcon` may leave its icon snapshot in that cache even after exit, so removing the tray feature also requires clearing the cache once.

本文件是本地开发日志，已加入 `.gitignore`，不进入版本库，也不推送到 GitHub。

> This file is a local development log. It is listed in `.gitignore`, stays out of the repository, and is never pushed to GitHub.

## 22. 新键盘 `0C45:FEFE` 的主动探测 | Active probe of the new keyboard

接入新键盘后，`0C45:FEFE` 暴露出 9 个 HID 接口，其中两个是厂商自定义接口：

> After the new keyboard was connected, `0C45:FEFE` exposed nine HID interfaces, two of which are vendor-defined:

| 接口 | Usage | 报告长度 | 推测 |
| --- | --- | --- | --- |
| `mi_03` | `0xFF60/0x61` | in 33 / out 33 | QMK / VIA 标准 raw HID |
| `mi_04` | `0xFF59/0x61` | in 65 / out 65 | 厂商私有协议 |

> | Interface | Usage | Report size | Guess |
> | --- | --- | --- | --- |
> | `mi_03` | `0xFF60/0x61` | in 33 / out 33 | QMK / VIA raw HID |
> | `mi_04` | `0xFF59/0x61` | in 65 / out 65 | vendor-specific protocol |

先做只读探测：9 个接口的 `FeatureReportByteLength` 全部为 0，因此原键盘那种「读 Feature Report」的办法在这里不成立；对两个厂商接口各被动监听 8 秒，也都是 0 条。也就是说这块键盘不会主动广播任何状态，必须主动写入 Output Report 才能拿到回复。

> A read-only probe came first: all nine interfaces report `FeatureReportByteLength = 0`, so the Feature Report read used for the earlier keyboard is not available here. Passive listening for eight seconds on each vendor interface also returned zero reports: this keyboard never broadcasts state on its own, so only an Output Report write can elicit a reply.

### VIA 标准查询：无响应 | Standard VIA query: no reply

向 `0xFF60/0x61` 依次发送四条标准 VIA 命令（33 字节，首字节为 Report ID `0x00`）：

> Four standard VIA commands were sent to `0xFF60/0x61` (33 bytes, first byte Report ID `0x00`):

| 命令 | 含义 | 结果 |
| --- | --- | --- |
| `01` | 查询协议版本 | 超时无回复 |
| `02 04` | 查询固件版本 | 超时无回复 |
| `02 01` | 查询运行时间 | 超时无回复 |
| `02 02` | 查询布局选项 | 超时无回复 |

> | Command | Meaning | Result |
> | --- | --- | --- |
> | `01` | Protocol version | timeout |
> | `02 04` | Firmware version | timeout |
> | `02 01` | Uptime | timeout |
> | `02 02` | Layout options | timeout |

结论：这块键盘不是标准 QMK/VIA 固件，`0xFF60` 接口即使存在也不走 VIA 协议。

> Conclusion: this keyboard is not standard QMK/VIA firmware, so the `0xFF60` interface does not speak the VIA protocol.

### `0xFF59` 厂商接口：有回复 | Vendor interface: it answers

为把风险控制到最低，只发送**全 0 的 65 字节包**（不构造任何未知命令字节），`mi_04` 立即返回：

> To keep risk minimal, only an all-zero 65-byte packet was sent, with no unknown command byte. `mi_04` replied immediately:

```text
请求: [0] * 65
回复: [0, 15, 1, 254, 14, 0, 0, 0, 0, ...]   （共 65 字节，[5] 之后全为 0）
```

> ```text
> request : [0] * 65
> reply   : [0, 15, 1, 254, 14, 0, 0, 0, 0, ...]   (65 bytes, all zero from [5])
> ```

连续发送 4 次，回复**完全一致**，说明这是一个确定性的状态/握手响应，而不是噪声：

> Four consecutive sends produced an identical reply, so it is a deterministic status or handshake response rather than noise:

```text
#1: [0, 15, 1, 254, 14, 0, 0, 0]  尾随全零=True
#2: [0, 15, 1, 254, 14, 0, 0, 0]  尾随全零=True
#3: [0, 15, 1, 254, 14, 0, 0, 0]  尾随全零=True
#4: [0, 15, 1, 254, 14, 0, 0, 0]  尾随全零=True
```

> ```text
> #1: [0, 15, 1, 254, 14, 0, 0, 0]  trailing zeros=True
> #2: [0, 15, 1, 254, 14, 0, 0, 0]  trailing zeros=True
> #3: [0, 15, 1, 254, 14, 0, 0, 0]  trailing zeros=True
> #4: [0, 15, 1, 254, 14, 0, 0, 0]  trailing zeros=True
> ```

已知字段：`[0]` 是 Report ID `0x00`；`[1]=15`、`[2]=1`、`[3]=254`、`[4]=14` 含义未确认，`[5]` 之后恒为 0。由于请求是全零，`[1]` 不可能是命令回显，更像是固定的响应标记或协议头。

> Known so far: `[0]` is Report ID `0x00`; the meaning of `[1]=15`, `[2]=1`, `[3]=254`, `[4]=14` is unconfirmed, and everything from `[5]` stays zero. Because the request was all zeros, `[1]` cannot be a command echo and looks more like a fixed response marker or protocol header.

### 与原始键盘的区别 | Difference from the original keyboard

| 键盘 | VID:PID | 读取方式 | 是否发过写命令 |
| --- | --- | --- | --- |
| 原键盘 | `3554:FA09` | 读取 Feature Report 6（纯只读） | 从未 |
| 新键盘 | `0C45:FEFE` | 无 Feature Report，只能写 Output Report 再读回复 | 是（探测用） |

> | Keyboard | VID:PID | Method | Writes sent |
> | --- | --- | --- | --- |
> | Original | `3554:FA09` | Read Feature Report 6 (read-only) | never |
> | New | `0C45:FEFE` | No Feature Report; must write an Output Report and read the reply | yes (probing only) |

因此「跟原键盘一样只读」这条路对新键盘并不存在，这次是项目里第一次真正向 HID 设备写入数据。后续若要继续找电量字段，需要构造非零命令字节，属于未知协议逆向，风险明显高于此前所有只读步骤。

> So the "read-only like the original keyboard" path simply does not exist for the new keyboard, and this was the project's first real HID write. Continuing to look for a battery field would require constructing non-zero command bytes, which is unknown-protocol reverse engineering and clearly riskier than every earlier read-only step.

## 23. 键盘2 电量字段的确认 | Confirming the second keyboard's battery field

被动监听 `0xFF60` 后发现该接口持续推送 33 字节报文（约每秒 3 条）。首轮统计 378 条样本：除 `byte[1]` 外所有字节都在变化，`byte[1]` 恒为 `0x55`。按 BCD 解码 `0x55` 正是 55，与键盘当时显示的电量吻合，于是初步判定为电量字段。

> Passive listening on `0xFF60` showed it pushes 33-byte reports continuously, about three per second. The first pass over 378 samples found every byte moving except `byte[1]`, which stayed `0x55`. Decoded as BCD that is exactly 55, matching the level the keyboard showed at the time, so it was taken as the battery field.

该假设随后被证伪：电量从 55 涨到 56 后重新采样，`byte[1]` 仍然是 `0x55`。固定帧头不会随电量变化，因此 BCD 解读错误，代码立即撤除，界面不再显示错误的 55%。

> That guess was then disproven: after the charge rose from 55 to 56, a fresh sample still reported `byte[1] = 0x55`. A fixed frame marker does not track the charge, so the BCD reading was wrong, the code was removed at once, and the UI stopped showing the wrong 55%.

按报文类型分组重新统计后，真正跟随电量的是类型 `0x10` 报文的 `byte[26]`：

> Grouping the reports by type located the byte that actually tracks the charge: `byte[26]` of the type-`0x10` report.

| 采样时刻 | 键盘显示电量 | `byte[26]` 取值 |
| --- | --- | --- |
| 21:56 | 55% | 52、56（均值 54.2） |
| 22:05 | 56% | 51、55、57、59（均值 55.7） |
| 22:10 充电中 | — | 51 → 54（单调上升） |
| 22:07 复测 | — | 58 |

> | Sampled at | Level on the keyboard | `byte[26]` values |
> | --- | --- | --- |
> | 21:56 | 55% | 52, 56 (mean 54.2) |
> | 22:05 | 56% | 51, 55, 57, 59 (mean 55.7) |
> | 22:10 while charging | — | 51 to 54 (rising) |
> | 22:07 re-check | — | 58 |

两个均值与真实值的偏差分别只有 0.8 和 0.3，且充电期间单调上升，因此确定为电量字段。

> The two means sit within 0.8 and 0.3 of the true level and the value rises monotonically while charging, so it is the battery field.

最后由官方软件交叉确认：该键盘为狼蛛 AULA MINI 60 HE PRO，官方网页驱动 `hub.aulacn.com` 显示的数值同样在 `53 / 54 / 59` 之间跳动，与本程序观测到的 `51~59` 区间完全一致。这说明抖动来自硬件电量计本身，而不是偏移错误。

> Official software finally cross-confirmed it: the keyboard is an AULA MINI 60 HE PRO, and the vendor web driver at `hub.aulacn.com` oscillates between 53, 54 and 59, matching the 51-59 band this reader observes. The jitter therefore comes from the device gauge rather than a wrong offset.

由于原始字段抖动约 ±4，程序取最近 5 次读数的中位数，界面显示比官方网页驱动更稳定；读数同时落盘缓存，因为这条流在键盘空闲时会静默数分钟。

> Because the raw field jitters by roughly ±4, the reader takes the median of the last five samples, which is steadier than the vendor web driver, and the value is cached on disk because the stream goes quiet for minutes while the keyboard is idle.

顺带确认了一个 Python 侧的陷阱：`pywinusb` 的回调依赖 Windows 消息循环，而 Qt 事件循环占用主线程后回调不会触发。同一段代码在纯脚本里能收到报文，放进 Qt 应用却一条都收不到，改用独立线程中的阻塞 `kernel32.ReadFile` 后恢复正常。

> A Python-side trap was confirmed along the way: `pywinusb` callbacks depend on the Windows message loop, and once the Qt event loop owns the main thread those callbacks never fire. The same code receives reports in a plain script but nothing inside the Qt app; switching to a blocking `kernel32.ReadFile` on a dedicated thread fixed it.

## 24. 键盘1 能否复用该方案 | Can that approach work for the first keyboard

结论是不能直接复用。`3554:FA09` 的厂商接口 `0xFF02/0x02` 监听 40 秒收到 0 条报文，说明它只支持请求-响应，而用 Report ID 0 写入会被驱动以 `err 87`（`ERROR_INVALID_PARAMETER`）拒绝。两块键盘的能力正好相反：

> The short answer is no, not directly. Listening on the vendor interface `0xFF02/0x02` of `3554:FA09` for 40 seconds produced zero reports, so it only speaks request-response, and writing with Report ID 0 is rejected by the driver with `err 87` (`ERROR_INVALID_PARAMETER`). The two keyboards are opposites:

| | 键盘1 `3554:FA09` | 键盘2 `0C45:FEFE` |
| --- | --- | --- |
| Feature Report | 有，可主动拉取 | 无 |
| 主动广播 | 完全没有 | 持续推送 |
| 写入 | Report ID 0 被拒绝 | 接受但无有效响应 |

> | | Keyboard 1 `3554:FA09` | Keyboard 2 `0C45:FEFE` |
> | --- | --- | --- |
> | Feature Report | present, can be pulled | none |
> | Broadcast | none at all | continuous |
> | Write | Report ID 0 rejected | accepted but no useful reply |

可以借用的是对照实验的方法论：键盘2 的字段是靠「电量 55 → 56 前后两次采集对比」确认的。`3554:FA09` 当前三个候选值都是 100（满电），满电时所有候选一致，无论采样多少次都无法区分。

> What does transfer is the comparison method: the second keyboard's field was identified by comparing captures taken before and after the charge moved from 55 to 56. Every candidate on `3554:FA09` currently reads 100 because the keyboard is full, and at full charge all candidates agree, so no amount of sampling can separate them.

为此新增 `app/feature_log.py`，每分钟把 Feature Report 6 追加到 CSV，仅在数值变化时打印：

> So `app/feature_log.py` was added: it appends Feature Report 6 to a CSV every minute and only prints when a value changes.

```powershell
python -m app.feature_log                 # 每 60 秒采样，Ctrl+C 结束
python -m app.feature_log --interval 30   # 调整间隔
python -m app.feature_log --count 10      # 只采 10 次
```

> ```powershell
> python -m app.feature_log                 # sample every 60s, Ctrl+C to stop
> python -m app.feature_log --interval 30   # change the interval
> python -m app.feature_log --count 10      # stop after 10 samples
> ```

首条记录：

> The first row:

```csv
timestamp,byte0,byte1,byte2,byte3,byte4,byte5,byte6,byte7
2026-10-30 22:20:18,6,0,2,100,100,100,53,21
```

> ```csv
> timestamp,byte0,byte1,byte2,byte3,byte4,byte5,byte6,byte7
> 2026-10-30 22:20:18,6,0,2,100,100,100,53,21
> ```

待电量明显下降后对比各行即可定位字段。需要注意反向可能：如果只有 `byte6`（当前 53）发生变化，说明真正的电量是 53，而当前「候选 100%」的判断本身需要修正。

> Once the charge has dropped noticeably, comparing the rows identifies the field. The reverse case also matters: if only `byte6` (currently 53) moves, then the real battery is 53 and the current "candidate 100%" assumption needs revisiting.

## 25. 耳机能否用同样的方法 | Can the same method work for the headset

当前接入的耳机是 ZhuAudio ZG2（`4C4A:4155`），USB 复合音频设备，Windows 暴露的 HID 接口只有一个：`0x000C/0x0001`（多媒体键，3 字节输入）。三项检查结果：

> The headset currently connected is the ZhuAudio ZG2 (`4C4A:4155`), a USB composite audio device, and Windows exposes exactly one HID interface for it: `0x000C/0x0001` (consumer control, 3-byte input). Three checks were run:

| 检查 | 结果 |
| --- | --- |
| Feature Report | 所有接口 `feature_report_length = 0`，不存在 |
| 被动监听 30 秒 | 0 条报文 |
| `DEVPKEY_Device_BatteryLevel` | 全部节点为空 |

> | Check | Result |
> | --- | --- |
> | Feature Report | `feature_report_length = 0` on every interface, none exist |
> | 30-second passive listen | zero reports |
> | `DEVPKEY_Device_BatteryLevel` | empty on every node |

`DEVPKEY_Device_PowerData` 有 56 字节数据，但那是 USB 电源管理描述符（含 `D2` 挂起支持、延迟等字段），不是电量百分比，因此不予采用。

> `DEVPKEY_Device_PowerData` does hold 56 bytes, but that is a USB power-management descriptor (suspend support, latency and similar fields) rather than a charge percentage, so it is not used.

结论：键盘2 的方法在这里不成立。该方法依赖两个前提之一——设备提供可主动拉取的 Feature Report，或提供厂商自定义的广播通道。这台耳机两者都没有，只有一个标准多媒体键接口，因此没有任何可读电量入口。

> Conclusion: the second keyboard's method does not apply here. It relies on one of two preconditions, either a Feature Report that can be pulled or a vendor-defined broadcast channel. This headset offers neither, only a standard consumer-control interface, so there is no readable battery entry point.

作为对比，蓝牙耳机 HUAWEI FreeBuds SE 2 的情况不同：它没有 HID 接口，Windows 设置里能显示合并电量，但该数值未通过 PnP 属性或 WinRT 的 `BluetoothDevice` / `BluetoothLEDevice` 暴露（第 14 节已记录）。

> For contrast, the Bluetooth headset HUAWEI FreeBuds SE 2 differs: it has no HID interface, and although Windows Settings shows a combined charge level, that value is not exposed through PnP properties or through WinRT `BluetoothDevice` / `BluetoothLEDevice` (recorded in section 14).

要在耳机上继续推进，可行的方向只有官方软件：若厂商提供配置工具，从中抓取其真实通信即可定位电量字段，这与键盘2 最终由 `hub.aulacn.com` 交叉确认的路径一致。

> Pushing further on a headset would require vendor software: if the manufacturer ships a configuration tool, capturing its real traffic would locate the battery field, which is the same route that finally cross-confirmed keyboard 2 through `hub.aulacn.com`.

### 补充排查：接口与描述符级别 | Follow-up: interface and descriptor level

上一节的结论最初只基于顶层集合，随后又做了三层确认。

> The previous conclusion was first based on top-level collections only, so three more checks were run.

第一，设备树里只有两个功能，不存在厂商接口：

> First, the device tree holds only two functions, with no vendor interface:

```text
USB Composite Device (usbccgp)
├── MI_00  → usbaudio    （音频，接口 0/1/2）
└── MI_03  → HidUsb      （多媒体键，接口 3）
```

> ```text
> USB Composite Device (usbccgp)
> ├── MI_00  → usbaudio    (audio, interfaces 0/1/2)
> └── MI_03  → HidUsb      (consumer control, interface 3)
> ```

`MI_XX` 表示该功能的起始接口号，因此接口总数只有 0~3，没有额外的厂商接口可供发送探测包。

> `MI_XX` names the first interface of a function, so the interfaces only span 0 to 3 and there is no extra vendor interface to send a probe to.

第二，尝试读取原始报表描述符。`DeviceIoControl` 配合 `IOCTL_HID_GET_REPORT_DESCRIPTOR`（`0x000B0007`）对三个设备全部失败；改查注册表 `Enum\HID\...\Device Parameters` 时该键为空，`Properties` 子键无访问权限。两条路都没拿到原始字节。

> Second, reading the raw report descriptor was attempted. `DeviceIoControl` with `IOCTL_HID_GET_REPORT_DESCRIPTOR` (`0x000B0007`) failed on all three devices, and the registry key `Enum\HID\...\Device Parameters` is empty while its `Properties` subkey denies access. Neither route yielded the raw bytes.

第三，改用 `pywinusb` 已解析的 usage 列表，枚举每个报文声明的全部字段。耳机的结果全是多媒体键：

> Third, `pywinusb`'s already-parsed usage lists were used to enumerate every field each report declares. The headset returns only consumer-control usages:

```text
input id=0 usage=0x000C/0x00B0  （播放）
input id=0 usage=0x000C/0x00B1  （暂停）
input id=0 usage=0x000C/0x00E2  （静音）
input id=0 usage=0x000C/0x00E9  （音量+）
input id=0 usage=0x000C/0x00EA  （音量-）
... 共 16 个字段，全部属于 0x000C 页面
含 Battery Strength (0x0006/0x0020)：False
```

> ```text
> input id=0 usage=0x000C/0x00B0  (play)
> input id=0 usage=0x000C/0x00B1  (pause)
> input id=0 usage=0x000C/0x00E2  (mute)
> input id=0 usage=0x000C/0x00E9  (volume up)
> input id=0 usage=0x000C/0x00EA  (volume down)
> ... 16 fields in total, all on page 0x000C
> contains Battery Strength (0x0006/0x0020): False
> ```

确认该耳机为**无线 2.4G 接收器形态**，且用户表示没有任何官方配置软件。综合三层证据，结论是：接收器根本没有把耳机电量转发给主机，Windows 侧不存在任何可读入口。

> The headset was confirmed to be a wireless 2.4G dongle, and the user reports no vendor configuration software at all. With all three layers checked, the conclusion is that the dongle simply never forwards the headset's charge level to the host, so no readable entry point exists on the Windows side.

剩余理论路径只有截获耳机与接收器之间的 2.4G 无线链路，需要额外射频硬件且大概率加密，已超出本项目「只读系统已公开数据」的范围，不再尝试。

> The only remaining theoretical path is intercepting the 2.4G link between headset and dongle, which needs extra radio hardware and is likely encrypted. That is well outside this project's scope of reading data Windows already exposes, so it is not attempted.
