---
title: ESP32 - Day 1：XMC Flash 启动失败
date: 2026-10-24 23:21:00
permalink: ESP32-XMC-Flash-Boot-Failure/
tags:
  - ESP32
  - Embedded Systems
  - Learning
---

## 一、问题背景

使用一块第三方 `ESP32-S3-N16R8` 开发板，通过 PlatformIO 上传 Arduino 程序，最初准备控制 WS2812B 16×16 LED 矩阵。

开发板信息：

- 主控：ESP32-S3
- Flash：16MB
- PSRAM：8MB
- 串口芯片：CH343
- 串口：COM5
- 板载 RGB LED：GPIO48
- 外接 LED 矩阵数据线：GPIO4

`N16R8` 的含义：

- `N16`：16MB Flash
- `R8`：8MB PSRAM

## 二、最初的 LED 测试

为了排除外接 LED 矩阵接线和供电问题，先使用 FastLED 测试板载 RGB LED：

```cpp
#include <Arduino.h>
#include <FastLED.h>

#define ONBOARD_RGB_PIN 48
#define NUM_LEDS 1

CRGB onboardLed[NUM_LEDS];

void showColor(const CRGB& color) {
    onboardLed[0] = color;
    FastLED.show();
    delay(500);

    onboardLed[0] = CRGB::Black;
    FastLED.show();
    delay(200);
}

void setup() {
    Serial.begin(115200);
    delay(500);

    FastLED.addLeds<WS2812B, ONBOARD_RGB_PIN, GRB>(onboardLed, NUM_LEDS);
    FastLED.setBrightness(30);
    FastLED.clear();
    FastLED.show();
}

void loop() {
    showColor(CRGB::Red);
    showColor(CRGB::Green);
    showColor(CRGB::Blue);
    showColor(CRGB::White);
}
```

程序预期让板载 RGB LED 按照以下顺序循环：

```text
红色 → 绿色 → 蓝色 → 白色
```

但是上传后 LED 没有按照程序运行，Device Monitor 中出现了启动错误。

## 三、PlatformIO 编译问题

最初编译时出现：

```text
bootloader_dio_40m.elf not found
```

检查 PlatformIO 的 ESP32-S3 框架包后发现，目录中只有：

```text
bootloader_dio_80m.elf
bootloader_opi_80m.elf
bootloader_qio_120m.elf
bootloader_qio_80m.elf
```

没有 `bootloader_dio_40m.elf`。

之后删除并重新安装了以下 PlatformIO 框架包：

```text
framework-arduinoespressif32
framework-arduinoespressif32-esp32s3-libs
```

重新安装后，工程可以正常编译。

## 四、发现板卡配置不匹配

PlatformIO 使用的板卡定义是：

```ini
board = esp32-s3-devkitc-1
```

该板卡定义对应：

```text
ESP32-S3-DevKitC-1-N8
8MB Flash
No PSRAM
```

但实际开发板是：

```text
ESP32-S3-N16R8
16MB Flash
8MB PSRAM
```

因此不能直接使用官方 N8 板卡的默认配置。

当前项目中使用的主要配置如下：

```ini
[env:esp32-s3-devkitc-1]
platform = espressif32
board = esp32-s3-devkitc-1
framework = arduino

monitor_speed = 115200

board_build.flash_mode = dio
board_build.f_flash = 80000000L
board_build.flash_size = 16MB
board_build.arduino.partitions = default_16MB.csv
board_build.arduino.memory_type = dio_opi
board_build.psram_type = opi

build_flags =
    -D ARDUINO_USB_CDC_ON_BOOT=1
    -D ARDUINO_USB_MODE=1
    -D BOARD_HAS_PSRAM

lib_deps =
    fastled/FastLED@^3.6.0
```

这些设置对应：

- DIO Flash 模式
- 80MHz Flash 频率
- 16MB Flash
- 8MB OPI PSRAM
- 16MB 分区表

## 五、上传显示成功，但设备无法启动

PlatformIO 上传过程中显示：

```text
Hash of data verified.
Hard resetting via RTS pin...
========================= [SUCCESS]
```

这说明：

- Bootloader 已写入
- 分区表已写入
- 应用固件已写入
- 写入后的数据校验通过
- ESP32 已自动复位

但是，上传成功并不代表用户程序已经成功启动。

打开 Device Monitor 后，反复看到：

```text
E (31) bootloader_flash: XMC flash startup fail
E (31) boot.esp32s3: failed when running XMC startup flow, reboot!
```

之后设备不断重复启动：

```text
ESP-ROM:esp32s3-20210327
rst:0x3 (RTC_SW_SYS_RST)
boot:0x8 (SPI_FAST_FLASH_BOOT)
```

启动过程可以理解为：

1. ESP32 ROM 启动正常
2. Bootloader 被读取
3. Bootloader 开始初始化 Flash
4. XMC Flash 初始化失败
5. 系统自动重启
6. 用户程序没有执行到 `setup()`

因此板载 RGB LED 不按程序闪烁是正常现象，因为程序根本没有开始执行。

## 六、读取实际 Flash 信息

关闭 Device Monitor 后，使用 PlatformIO 自带的 esptool 读取 Flash ID：

```powershell
& "C:\Users\32109\.platformio\packages\tool-esptool\esptool.exe" `
    --chip esp32s3 `
    --port COM5 `
    flash-id
```

读取结果：

```text
Chip type: ESP32-S3 (QFN56)
Embedded PSRAM 8MB
Manufacturer: 20
Device: 7018
Detected flash size: 16MB
```

结果确认：

- 主控是 ESP32-S3
- PSRAM 是 8MB
- Flash 是 16MB
- Flash 厂商是 XMC
- Flash 可以被 esptool 识别

同时 esptool 输出：

```text
WARNING: XMC flash chip boot-up failure detected!
WARNING: XMC flash boot-up fix failed.
XMC flash chip boot-up fix successful!
```

这里要注意：esptool 的修复是在下载工具的临时 Stub Flasher 中进行的，不代表写入设备的 bootloader 已经具备相同的修复逻辑。

## 七、完整擦除 Flash

执行完整擦除：

```powershell
& "C:\Users\32109\.platformio\packages\tool-esptool\esptool.exe" `
    --chip esp32s3 `
    --port COM5 `
    erase-flash
```

结果：

```text
XMC flash chip boot-up fix successful!
Flash memory erased successfully
```

这说明：

- ESP32 主控正常
- XMC Flash 可以通信
- Flash 可以擦除
- 硬件不是完全无法使用

但是重新上传程序后，启动时仍然出现：

```text
E (31) bootloader_flash: XMC flash startup fail
```

因此，单纯擦除 Flash 不能解决这个启动兼容性问题。

## 八、问题根因

最终确认的问题组合是：

```text
ESP32-S3
+ XMC 16MB Flash
+ 当前 Arduino/ESP-IDF bootloader
```

esptool 可以通过临时 Stub Flasher 识别、擦除和写入 XMC Flash，但设备重启后，固件中的 bootloader 无法正确初始化该 XMC Flash，于是产生启动循环。

这解释了为什么会同时出现：

```text
上传成功
Flash 校验成功
设备不断重启
程序没有执行
```

问题不在：

- FastLED 程序
- GPIO4 或 GPIO48
- WS2812B 矩阵接线
- USB 连接
- 串口驱动
- Flash 擦除操作

而在于：

```text
XMC Flash 与当前 ESP32-S3 bootloader 的兼容性
```

## 九、上传时 LED 闪烁的含义

上传过程中曾看到蓝色、绿色 LED 闪烁，上传结束后看到红色和绿色 LED 常亮。

这些灯光不一定是用户程序控制的 RGB LED，也可能是：

- USB 转串口芯片的通信指示灯
- 电源指示灯
- 下载状态灯
- 板载状态灯

只有在串口中不再出现 `XMC flash startup fail`，并且程序成功运行后，才能确认 RGB LED 测试程序真的执行了。
