---
title: Hardware-Viewer - Hardware Limits
date: 2026-11-01 13:05:00
permalink: Hardware-Viewer-Hardware-Limits/
tags:
  - Hardware Viewer
  - Dev Log
  - Python
  - Windows
  - Reverse Engineering
  - Debugging
---

开发一个可以看硬件实时电量的 app。

仓库地址为 https://github.com/LimpidSlirm/2.4G-Hardware-Viewer

以下为 agent 输出的日志。


昨天给 3554:FA09 这块键盘显示的电量是 100%，但那是从没被证实过的猜测。今天把它查清楚了：这个设备在 Windows 侧根本读不到电量。另外发现自己昨天修「控制台弹窗」时留下了一个中文乱码的回归。

> Yesterday the 3554:FA09 keyboard showed a 100% battery that had never actually been proven. Today it is settled: this device exposes no readable charge level to Windows at all. The same session also turned up a Chinese-text regression I had introduced yesterday while fixing the flashing console window.

## 1. 三十八小时，一个字节都没动 | Thirty-eight hours, not a single byte moved

键盘1 的采样器从 10-30 晚开始记录，到 11-01 中午停了 24.6 小时没人发现。重启继续采之后，把全部数据统计了一遍：

> The keyboard-1 sampler had been recording since the evening of 10-30, then sat idle for 24.6 hours before anyone noticed. After restarting it and collecting more data, the whole log was tallied:

```text
采样条数: 273
时间跨度: 2026-10-30 22:20 -> 2026-11-01 13:00:24   （38.7 小时）
不同报文: 1 / 273
```

报文的每一列都只有一个取值：

> Every column of the report has exactly one value:

```text
byte0=6  byte1=0  byte2=2  byte3=100  byte4=100  byte5=100  byte6=53  byte7=21
```

不是「掉电了但没记到」，而是**两位都没变过**。用户当时的判断是「应该这里面没有电量吧」——这个判断方向是对的，但还需要证据。

> This is not a case of the level dropping without being logged: **nothing changed at all**. The user's hunch was that the report simply contains no battery, which pointed the right way, but a hunch still needs evidence.

## 2. 先确认设备上还有没有别的通道 | First, are there any other channels on this device

在否定 Report 6 之前，得排除「电量藏在另一个报告里」。把这块键盘的全部接口和 0~32 号 Feature Report 扫了一遍：

> Before dismissing Report 6, the possibility that the battery lives in a different report had to be ruled out. Every interface of the keyboard and every feature report ID from 0 to 32 was enumerated:

```text
usage_page=0x1      usage=0x2    in= 8  out= 0  feat=0
usage_page=0xff04   usage=0x2    in= 0  out= 0  feat=8   <- 唯一可读的 Feature Report
usage_page=0x1      usage=0x6    in=21  out= 0  feat=0
usage_page=0xff02   usage=0x2    in=20  out=20  feat=0
usage_page=0x1      usage=0x6    in= 9  out= 2  feat=0
usage_page=0xc      usage=0x1    in= 3  out= 0  feat=0
usage_page=0x1      usage=0x80   in= 2  out= 0  feat=0
```

结果只有 `0xFF04 / id 6` 一个能读出内容，没有备选报告。同时注意到**没有任何 `usage_page 0x06`** —— 也就是 HID 标准的 Battery Strength，所以 Windows 自己也不知道这块键盘还有多少电，系统设置里自然也不会显示。

> Only `0xFF04 / id 6` returned data, so there is no alternate report. Note also the absence of any `usage_page 0x06`, i.e. the HID Battery Strength usage, which means Windows itself has no idea about this keyboard's charge and never displays it in system settings.

## 3. 主动写入：它是寄存器，不是查询接口 | Active writes: a register, not a query interface

剩下的可能是「需要先写一条查询命令，它才回应」。为了验证这个假设，先证明写入通道可用：把刚读到的内容原样写回去。

> The remaining hypothesis was that a query command must be written first before the device answers. To test it, writing had to be proven to work at all: the bytes just read were written straight back.

```text
写回 [6,0,2,100,100,100,53,21]  -> 成功
再读回                          -> 完全一致
```

写入可用。接下来分两轮扫描 `byte1` 和 `byte2`（各 0~15），每次写完读回，然后立刻把原值写回去：

> Writing works. Next, `byte1` and `byte2` were swept from 0 to 15 in two passes, reading back after each write and restoring the original value immediately afterwards:

```text
byte1 扫描 0~15 ：16 次写入全部成功
  读回结果 = 写入值     （写 1 得 1，写 15 得 15）

byte2 扫描 0~15 ：16 次写入全部成功
  读回结果 = 2，一次都没变
```

两个字段的行为正好相反，这个对比很关键：`byte1` 是**可写配置项**，`byte2` 是**设备自己维护的只读状态位**。如果这只是一个查询接口，写入之后不该出现「某些字节跟着变、某些字节纹丝不动」这种分化。结论是 Report 6 属于**配置寄存器**，不是提问-应答通道，写什么都不可能问出电量。

> The two fields behave in opposite ways, and that contrast is the point: `byte1` is a **writable configuration value**, while `byte2` is a **read-only status bit maintained by the device**. A query interface would not split like that after a write. The conclusion is that Report 6 is a **configuration register**, not a request-response channel, so no write can ever ask it for a charge level.

每次试探后都写回了原值，最后确认设备配置完好：

> The original value was restored after every trial, and the device configuration was confirmed intact at the end:

```text
当前 Report 6 : [6,0,2,100,100,100,53,21]
原始 baseline : [6,0,2,100,100,100,53,21]
一致: true
```

## 4. Output Report 全部拒收 | Every output report is rejected

`0xFF02` 接口有 20 字节的 Output Report，这是最后一个可能的下行通道。第一次扫描时错误码拿到的是 0，说明错误没捕获到，结果不可信；用 `use_last_error=True` 重测：

> The `0xFF02` interface exposes a 20-byte output report, the last possible downstream channel. The first sweep reported error code 0, which means the error was never captured, so that result was worthless. Re-running with `use_last_error=True` gave a trustworthy answer:

```text
HidD_SetOutputReport：
  id=0,1,2,8   -> 失败  err=87  ERROR_INVALID_PARAMETER
  id=3,4,5,6,7 -> 失败  err=1   ERROR_INVALID_FUNCTION
WriteFile：
  结果完全相同
```

`0~8` 号全部被拒，两种写入 API 表现一致。这个设备不接受任何下行写入。

> IDs 0 through 8 are all rejected, and both write APIs agree. The device accepts no downstream writes whatsoever.

顺带说明一个教训：第一次那个「err=0」如果直接采信，会得出「写入成功了但没反应」的错误结论，方向就完全跑偏。**探针本身的 bug 会伪装成设备的 bug。**

> A lesson worth recording: taking the first "err=0" at face value would have suggested "writes succeed but nothing happens", which points in entirely the wrong direction. **A bug in the probe disguises itself as a bug in the device.**

## 5. 三条通道都堵死，那就别再显示假数据 | With all three channels closed, stop showing fake data

汇总一下：

> The tally:

| 通道 | 实测结果 |
| --- | --- |
| Feature Report 6（`0xFF04`） | 273 次采样、38.7 小时只有 1 种报文；`byte1` 可写、`byte2` 只读，是配置寄存器 |
| Output Report（`0xFF02`） | Report ID `0~8` 全部拒收，两种写入 API 一致 |
| 标准 HID Battery Strength | 设备没有暴露 `usage_page 0x06`，Windows 也无从得知 |

还有一条判据来自用户：这块键盘**一直在用**（正在用来打字），不是闲置状态。真实电量计在 38 小时里不可能一位不漂，`byte3/4/5` 三个候选值始终恰好 100、`byte6=53`、`byte7=21` 也分毫不动。

> One more piece of evidence came from the user: this keyboard **is in active use** — it was the one being typed on — rather than sitting idle. A real fuel gauge cannot hold every bit steady for 38 hours, yet the three candidate bytes `byte3/4/5` stayed at exactly 100 while `byte6=53` and `byte7=21` never budged either.

所以那个 100 是固件写死的值或配置项。删掉它：

> So that 100 is a firmware constant or a configuration value. It was removed:

```text
app/battery_protocols.py  删除 read_vendor_battery_candidates() 与 BatteryReading（37 行）
app/main.py               删除对应调用与 import（8 行）
README.md                 设备表改为「无可用通道」，新增一节记录排除过程
```

界面现在落到原有分支，标记 `电量未公开`——这也是项目从一开始就写进 README 的原则：不猜测、不伪造百分比。讽刺的是这条原则当时就被自己违反了。

> The row now falls through to the existing branch and is labelled `电量未公开`, which is the principle the project documented from day one: never guess, never invent a percentage. Ironically that principle had been violated by the project itself.

## 6. 昨天那个修复留下的回归 | A regression left behind by yesterday's fix

改完之后截图检查界面，发现音频设备名显示成 `���� (ZhuAudio ZG2)`。中文全变成替换字符了。

> After the change the UI was screenshotted for a check, and audio device names showed up as `���� (ZhuAudio ZG2)`. Every Chinese character had become a replacement glyph.

先确认这不是新问题：昨天改代码之前的探针数据里同样是乱码，所以不是第 5 节引入的。然后做 A/B 定位——同一个脚本、同一套解码，只改 `creationflags`：

> First, confirm this is not new: probe data taken yesterday before the code change was already garbled, so section 5 did not cause it. Then A/B it, same script and same decoder, varying only `creationflags`:

```text
creationflags = CREATE_NO_WINDOW  ->  "\ufffd\ufffd\ufffd (ZhuAudio ZG2)"   乱码
creationflags = 0                 ->  "\u626c\u58f0\u5668 (ZhuAudio ZG2)"   正常
```

根因清楚了：昨天为了让 PowerShell 不弹出控制台窗口，给子进程加了 `CREATE_NO_WINDOW`。这让子进程**彻底失去控制台**，`[Console]::OutputEncoding` 于是退回系统 ANSI 代码页（本机 cp936/GBK），而 Python 侧仍然按 `encoding="utf-8"` 解码。

> The cause is clear: yesterday's fix for the flashing console added `CREATE_NO_WINDOW`, which leaves the child with **no console at all**. `[Console]::OutputEncoding` therefore falls back to the system ANSI code page (cp936/GBK here) while the Python side still decodes as `encoding="utf-8"`.

这也解释了为什么只有**音频设备名**乱码：`HID-compliant mouse`、`HID Keyboard Device` 是纯 ASCII，怎么解都不会错；`扬声器`、`麦克风` 是中文，才把问题暴露出来。

> It also explains why only **audio device names** were garbled: `HID-compliant mouse` and `HID Keyboard Device` are pure ASCII and survive any decoder, whereas `扬声器` and `麦克风` expose the mismatch.

修复试了四种写法，只有明确锁定编码才有效：

> Four approaches were tried; only pinning the encoding explicitly works:

```text
plain                                    -> GBK（乱码）
[Console]::OutputEncoding = UTF8         -> UTF-8  ✓
$OutputEncoding = UTF8                   -> GBK（无效）
try{[Console]...}catch{} + $OutputEncoding -> UTF-8  ✓（等效）
```

注意 `$OutputEncoding` 单独设置**不管用** —— 它影响的是 PowerShell 传给外部原生程序的编码，不是自己写 stdout 的编码。这个区分很容易搞混。

> Note that setting `$OutputEncoding` alone does **not** work: it controls the encoding PowerShell uses when piping to external native programs, not the encoding it uses for its own stdout. That distinction is easy to get wrong.

最终在 [device_discovery.py](https://github.com/LimpidSlirm/2.4G-Hardware-Viewer/blob/main/app/device_discovery.py) 和 [autostart.py](https://github.com/LimpidSlirm/2.4G-Hardware-Viewer/blob/main/app/autostart.py) 的 PowerShell 脚本开头都加了这一行，并在代码注释和 README 里写明了因果，避免以后有人把 `CREATE_NO_WINDOW` 当成纯粹的界面优化。

> In the end the line was added to the top of the PowerShell scripts in both [device_discovery.py](https://github.com/LimpidSlirm/2.4G-Hardware-Viewer/blob/main/app/device_discovery.py) and [autostart.py](https://github.com/LimpidSlirm/2.4G-Hardware-Viewer/blob/main/app/autostart.py), with the causal link recorded in code comments and the README so nobody treats `CREATE_NO_WINDOW` as a pure UI tweak again.

## 7. 验证记录与后续 | Verification log and next steps

本轮验证：

> Commands and results for this round:

```text
py_compile app/battery_protocols.py app/main.py app/device_discovery.py app/autostart.py  -> COMPILE_OK
python -m app.main --smoke-test                                                          -> exit=0
python -m app.main --create-shortcut                                                     -> 快捷方式重建成功
删除后残留引用扫描                                                                          -> 无
```

数据层（走真实 `DeviceDiscoveryThread`）：

> Data layer, through the real `DeviceDiscoveryThread`:

```text
键盘 3554:FA09  battery = null   source = null        <- 假 100% 已消失
鼠标 24AE:1411  battery = 96     source = 厂商 HID 报告 · 缓存
音频设备名称     \u626c\u58f0\u5668 (ZhuAudio ZG2)      <- 无 \ufffd
```

界面截图确认：完整模式下音频设备显示 `扬声器 (ZhuAudio ZG2)`、`麦克风 (ZhuAudio ZG2)`，键盘行显示 `3554:FA09 · 电量未公开`。

> Screenshots confirm it: in full mode the audio rows read `扬声器 (ZhuAudio ZG2)` and `麦克风 (ZhuAudio ZG2)`, and the keyboard row reads `3554:FA09 · 电量未公开`.

对应提交：

> Corresponding commits:

```text
0f90266 fix: stop showing a fabricated battery for the 3554:FA09 keyboard
96db750 fix: pin PowerShell stdout to UTF-8 so device names stop garbling
```

后续可做：

> Possible next steps:

1. 键盘1 已放弃，采样器停在 273 条；`app/feature_log.py` 保留为通用诊断工具
2. 耳机 `4C4A:4155` 与键盘1 现在同属「协议不暴露电量」，可在 README 里合并成统一说明
3. `CREATE_NO_WINDOW` 这类「看起来只是界面优化」的改动值得加一条回归清单，下次改前后都验一遍中文显示

> 1. Keyboard 1 is given up on; the sampler stopped at 273 samples and `app/feature_log.py` stays as a general diagnostic tool
> 2. The headset `4C4A:4155` and keyboard 1 now share the same "the protocol exposes no charge level" verdict and could be merged into one README note
> 3. Changes like `CREATE_NO_WINDOW` that look like pure UI polish deserve a regression checklist, so Chinese text gets verified both before and after
