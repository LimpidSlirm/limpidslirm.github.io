---
title: 智能车的 Headless Build
date: 2026-10-26 15:18:00
index_img: /img/1.png
tags:
  - Smart Car
  - Embedded Systems
  - Headless Build
---

2026-10-26 智能车选修课笔记。

## 1. 问题背景

在传统的 AURIX Development Studio（简称 ADS）开发流程中，通常需要：

1. 打开 ADS；
2. 导入工程；
3. 点击 Build 编译；
4. 点击 Debug 或 Download；
5. 通过调试器把程序下载到 TC264；
6. 点击运行。

这种方式直观，但每次编译和烧录都依赖图形界面。对于自动化构建、批量编译，就需要把整个过程拆成两个独立环节：

```text
编译：TASKING 工具链 + amk
烧录：AURIX Flasher + DAS/DAP 调试器
```

本项目最终实现了下面的流程：

```text
修改代码
    ↓
build_headless.bat
    ↓
E01_gpio_demo.hex
    ↓
flash.bat
    ↓
TC264 Flash
```

整个过程不需要打开 ADS 的图形界面。

> 当前电脑上的 TASKING 工具链和 AURIX Flasher 仍然随 AURIX Studio 一起安装。它们是独立的命令行/工具程序，并不是完全脱离英飞凌软件生态。

---

## 2. 原先为什么只能用 ADS？

### 2.1 工程文件本身不是编译器

工程中的 `.project`、`.cproject` 和 `Debug` 目录，主要记录：

- 工程名称；
- 源文件列表；
- 头文件搜索路径；
- 芯片型号；
- 编译选项；
- 链接脚本；
- 生成目标；
- 调试器配置。

它们本身不会编译 C 代码。真正执行编译的是 TASKING 工具链，例如：

```text
cctc    C/C++ 编译器和链接器
astc    汇编/目标文件处理工具
amk     TASKING 工程构建器
elfsize 统计 ELF 文件大小
```

ADS 的作用更像是一个集成控制台：它读取工程配置，调用这些工具，并把输出显示在图形界面中。

因此，“在 ADS 中编译”并不等于“编译只能由 ADS 完成”。

### 2.2 原工程包含图形化构建器

工程的 `.project` 文件中包含 Project Booster 构建器：

```xml
<name>com.infineon.aurix.buildsystem.builders.booster</name>
```

这个构建器依赖图形化工作台。直接使用 headless builder 时，它可能尝试加载界面相关配置，或者与命令行构建流程冲突。

`build_headless.bat` 的处理方式是：

1. 备份 `.project`；
2. 临时移除 Project Booster 构建器；
3. 使用标准的 TASKING managed builder 构建；
4. 构建结束后恢复原始 `.project`。

这样既保留了原工程文件，又避免了图形构建器阻塞命令行构建。

---

## 3. 不打开 ADS 编译的原理

当前的 `build_headless.bat` 使用的是：

```text
AURIX-studioc.exe
```

它是 AURIX Studio 的命令行启动程序，不会打开完整的图形工作台。启动时使用：

```text
-application com.tasking.managedbuilder.headlessbuild
```

这个参数告诉 Eclipse/CDT 直接执行 headless managed build。

核心过程可以简化为：

```text
AURIX-studioc.exe
    ↓
headless managed builder
    ↓
amk
    ↓
cctc / astc / linker
    ↓
E01_gpio_demo.elf
E01_gpio_demo.hex
E01_gpio_demo.map
```

### 3.1 为什么还需要 workspace？

Eclipse/CDT 的构建系统需要 workspace 保存工程注册信息和构建状态。当前脚本的策略是：

1. 使用项目父目录作为 workspace；
2. 将 `E01_gpio_demo` 作为 workspace 中的项目进行构建。

项目路径是：

```text
\TC264_Library-master\Example\E01_gpio_demo
```

因此项目父目录为：

```text
\TC264_Library-master\Example
```

把项目放在 workspace 目录中，可以避免 headless builder 报出：

```text
URI ... is not valid in the workspace
```

### 3.2 为什么要生成临时启动配置？

AURIX Studio 的默认启动配置中包含图形界面专用参数：

```text
-perspective
com.infineon.aurix.buildmanager.perspective.c
```

这个参数用于打开图形界面透视图，但 `AURIX-studioc.exe` 的 headless 启动过程不接受它。

因此脚本会临时生成一个启动配置，删除这两个参数，然后通过：

```bat
--launcher.ini "%HEADLESS_INI%"
```

启动命令行构建。构建结束后临时文件会被删除。

---

## 4. 编译产物分别有什么作用？

编译成功后，`Debug` 目录中会出现几个重要文件：

| 文件 | 用途 |
|---|---|
| `E01_gpio_demo.elf` | 包含调试信息和完整段信息，适合调试工具使用 |
| `E01_gpio_demo.hex` | Intel HEX 格式，适合独立烧录工具 |
| `E01_gpio_demo.map` | 记录链接后的地址和内存占用 |
| `E01_gpio_demo.siz` | 记录程序 ROM/RAM 大小 |

本项目的独立烧录脚本使用：

```text
Debug\E01_gpio_demo.hex
```

HEX 文件不是源代码，也不是可以直接运行的程序。它是一个描述“哪些地址写入哪些数据”的文本格式文件。

---

## 5. 不通过 ADS 烧录的原理

当前电脑中安装了独立烧录工具：

```text
C:\Infineon\AURIX-Studio-1.10.10\tools\AurixFlasherSoftwareTool_v3.0.4\AURIXFlasher.exe
```

它支持 `TC26x B step`，与本项目使用的 TC26XB 目标匹配。

当前的 `flash.bat` 实际执行的核心命令是：

```bat
AURIXFlasher.exe ^
  -hex "Debug\E01_gpio_demo.hex" ^
  -id 0 ^
  -erase on ^
  -prog on ^
  -ver on ^
  -connect 6 ^
  -start on
```

这些参数的含义是：

| 参数 | 含义 |
|---|---|
| `-hex` | 指定待烧录的 Intel HEX 文件 |
| `-id 0` | 使用第 0 个 DAS 下载器 |
| `-erase on` | 擦除需要写入的 Flash 区域 |
| `-prog on` | 执行 Flash 编程 |
| `-ver on` | 编程后读取并校验 |
| `-connect 6` | 复位并暂停后连接芯片 |
| `-start on` | 烧录后复位并运行 |
| `-log` | 保存烧录日志 |

所以烧录过程是：

```text
PC
 ↓ USB
DAS / DAP / miniWiggler
 ↓ 调试接口
TC264
 ↓
片上 Flash
```

这里的烧录器不需要 ADS 图形界面，它直接通过 DAS/DAP 调试链路连接 TriCore 芯片，并将 HEX 中的数据写入片上 Flash。

> 仍然需要硬件下载器和正确的驱动。单独双击 HEX 文件不会烧录。

---

## 6. 烧录后通过 TFT 判断

现在在 [app.c](./code/app.c) 的初始化阶段加入了 TFT180 启动提示：

```c
tft180_init();
tft180_set_color(RGB565_GREEN, RGB565_BLACK);
tft180_show_string(0, 0, "E01 GPIO DEMO");
tft180_show_string(0, 2, "BOOT OK");
```

启动过程变为：

```text
芯片复位
    ↓
clock_init()
    ↓
debug_init()
    ↓
tft180_init()
    ↓
TFT 显示 BOOT OK
    ↓
初始化按键和电机模块
```

看到：

```text
E01 GPIO DEMO

BOOT OK
```

可以说明：

1. 芯片已经从 Flash 启动；
2. CPU0 已经执行到 `app_init()`；
3. TFT180 的 SPI、控制引脚和显示初始化工作正常；
4. 程序不是只完成了下载，而是已经开始运行。

这是一种比“观察电机是否转动”更安全的烧录验证方式，因为电机默认不会启动，也不需要连接电机负载。

### TFT180 接线

当前工程默认使用：

| TFT180 接口 | TC264 引脚 |
|---|---|
| SCL | P15.3 |
| SDA | P15.5 |
| RES | P15.1 |
| DC | P15.0 |
| CS | P15.2 |
| BL | P15.4 |
| VCC | 3.3V |
| GND | GND |

这些定义位于：

```text
libraries\zf_device\zf_device_tft180.h
```

---

## 7. 完整使用流程

### 第一步：编译

在项目目录执行：

```bat
cd /d D:\Programs\TC264_Library-master\Example\E01_gpio_demo
build_headless.bat
```

成功标志：

```text
Build Finished. 0 errors, 0 warnings.
Build completed successfully.
```

### 第二步：连接硬件

连接：

- TC264 开发板；
- DAP/DEBUG/miniWiggler 下载接口；
- TFT180 屏幕；
- 开发板电源。

本测试不需要连接电机。

### 第三步：烧录

双击：

```text
flash.bat
```

或者执行：

```bat
cd /d D:\Programs\TC264_Library-master\Example\E01_gpio_demo
flash.bat
```

脚本会生成：

```text
Debug\flash.log
```

成功标志应包含烧录成功和校验成功信息。

### 第四步：观察 TFT

烧录完成后，程序会自动复位并启动。TFT180 应显示：

```text
E01 GPIO DEMO
BOOT OK
```

## 8. 这个方案的边界

这个方案解决的是：

- 不打开 ADS 图形界面进行编译；
- 不通过 ADS 图形界面进行烧录；
- 通过脚本重复构建；
- 通过独立工具烧录和校验；
- 使用 TFT 显示确认程序启动。

它不代表：

- 不需要 TASKING 编译器；
- 不需要 AURIX Flasher；
- 不需要 DAS/DAP 硬件；
- 不需要芯片对应的链接脚本；
- 可以使用任意芯片型号；
- 可以不安装下载器驱动。

换句话说，ADS 原来把很多独立工具隐藏在图形界面后面。现在只是把这些工具直接调用出来，并用批处理文件把它们串联起来：

```text
图形界面操作
        ↓ 拆解
命令行构建 + 独立烧录 + 硬件显示验证
```

这就是当前方案能够工作的核心原理。

---

## 脚本下载

- [下载 build_headless.bat](/downloads/build_headless.bat)
- [下载 flash.bat](/downloads/flash.bat)
