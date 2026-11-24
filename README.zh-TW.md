# Ender-3 / Creality v4.2.7 + CR-Touch 韌體

[English](README.md) | 繁體中文 | [Русский](README.ru.md)

針對 **Ender-3** 的自訂 [Marlin 2.1.2.10](https://marlinfw.org/) 韌體，硬體包含：

- **Creality v4.2.7** 32 位元主機板（STM32F103RET6）
- **CR-Touch** 自動床面調平探針（與 BLTouch 相容的克隆品）
- **Z 軸延長套件** — Z 行程 350 mm（Creality「Z350」設定檔）
- 原廠 LCD／螢幕設定

目前開發分支為
[`upgrade-marlin-2.1.2.10-crtouch`](https://github.com/van-thieu/Ender-3-427/tree/upgrade-marlin-2.1.2.10-crtouch)；
`master` 是未經修改的上游原始匯入。

## 文件

- [CR-Touch 建置與校準說明](CR-TOUCH-BUILD.zh-TW.md) —
  [English](CR-TOUCH-BUILD.md) · [Русский](CR-TOUCH-BUILD.ru.md)
- Marlin 上游官方文件：<https://marlinfw.org/docs/>

## 主要韌體設定

| 設定 | 值 | 說明 |
|---|---|---|
| `MOTHERBOARD` | `BOARD_CREALITY_V427` | 32 位元 Creality 4.2.7 主機板 |
| `BLTOUCH` | 啟用 | CR-Touch 為 BLTouch 相容探針，訊號 PB1／伺服 PB0 |
| `BLTOUCH_DELAY` | `500` | 為克隆探針增加指令延遲 |
| `NOZZLE_TO_PROBE_OFFSET` | `{ -30, 0, 0 }` | 由印表機即時 `M851` 測得（X-30、Y0）；Z 於執行時校準 |
| `AUTO_BED_LEVELING_BILINEAR` | 啟用，5×5 網格 | 雙線性床面網格調平 |
| `Z_SAFE_HOMING` | 啟用 | 在床面中央以探針進行 Z 軸歸零 |
| `Z_MIN_POS` | `-5` | 讓噴頭能移動到 Z=0 以下，才能在負 Z 偏移時真正碰到床面 |
| `Z_MAX_POS` | `350` | 實體 Z 軸延長（「Z350」）——請**不要**改回原廠的 250 |
| `PROBING_MARGIN_LEFT/RIGHT` | `35` | 確保偏移的探針仍停留在床面範圍內 |
| `BABYSTEP_ZPROBE_OFFSET` | 啟用 | 列印中即時微調 Z 偏移 |
| `PROBE_OFFSET_WIZARD` | 啟用 | 透過 LCD 精靈校準 Z 偏移 |
| `BINARY_FILE_TRANSFER`、`CUSTOM_FIRMWARE_UPLOAD` | 啟用 | Marlin 二進位檔案傳輸功能（限制見下） |
| `M936` | 啟用 | Creality MCU-OTA 指令處理器（適用於相容機板） |

## 建置

需要 Python 3 與 PlatformIO：

```bash
python3 -m venv .venv
.venv/bin/pip install platformio
.venv/bin/pio run -e STM32F103RE_creality
```

輸出檔案位於 `.pio/build/STM32F103RE_creality/firmware.bin`。
可直接燒錄的副本存放於 [`firmware/`](firmware/)。

## 燒錄（必須使用 SD 卡）

1. 將**一個**韌體 `.bin` 複製到 FAT32 格式 SD 卡的根目錄。
2. 重新命名為**全新的唯一名稱** — Creality 4.2.7 開機載入器會記住舊檔名，
   同一檔名不會再次燒錄。
3. 確認卡上**只有一個 `.bin` 檔案**。
4. 關閉印表機電源，插入 SD 卡，開機並等待更新完成（螢幕可能短暫空白）。
5. 取出 SD 卡並重新電源循環。

以 `M115` 驗證：應回報 **Marlin 2.1.2.10** 及建置日期。

## 首次開機校準

1. `M502` 接著 `M500` — 將設定重設為韌體預設值。
2. `G28` — 所有軸歸零；`M401`／`M402` — 伸出／收回 CR-Touch。
3. 設定 Z 偏移，例如 `M851 Z-1.38`，接著 `M500`。
   也可以使用 LCD 精靈：**Motion → Bed Leveling → Probe Offsets (Wizard)**。
4. `G29` — 探測網格，接著 `M500` 儲存。
5. 列印時以 babystepping 微調第一層。

疑難排解請參閱 [CR-TOUCH-BUILD.zh-TW.md](CR-TOUCH-BUILD.zh-TW.md)。

## Creality WiFi 盒子

網路上的盒子可用於**監控與 G-code 控制**（連接埠 81 的 HTTP 狀態 API、
對其 SD 卡的匿名 FTP、telnet shell）。裝置憑證基於安全考量不在此文件中揭露。

**在此硬體上透過盒子更新韌體並不可靠：**

- 盒子內建的 MCU OTA 會傳送 `M936 V2` 並等待 `mcu reset ok`，然後串流韌體。
  但 4.2.7 的開機載入器不會進入 OTA 模式，串流位元組會被 Marlin 當成無效指令。
  Creality 原廠 4.2.7 韌體沒有 `M936` 處理器。
- Marlin 的二進位檔案傳輸（`M28 B1`）已實作重傳原型。雖然大部分封包可通過，
  但盒子的 `prt_com` 守護程序會把自身的 `M105`／`M27` 輪詢插入序列串流，
  造成封包損毀；目前尚無可靠的上傳器。

因此**請使用 SD 卡更新韌體**。盒子用於監控與校準則沒有問題。

## 授權

Marlin 韌體採用 GPL-3.0，詳情請見 [LICENSE](LICENSE)。
