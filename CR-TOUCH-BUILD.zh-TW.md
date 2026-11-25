# Ender-3 / Creality v4.2.7 + CR-Touch 建置與校準說明

[English](CR-TOUCH-BUILD.md) | 繁體中文 | [Русский](CR-TOUCH-BUILD.ru.md)

本韌體以 **Marlin 2.1.2.10** 為基礎，使用官方
`Creality/Ender-3/CrealityV427` 範例設定，並沿用先前設定中的 CR-Touch 參數。

## 建置

```bash
python3 -m venv .venv
.venv/bin/pip install platformio
.venv/bin/pio run -e STM32F103RE_creality
```

輸出檔案：`.pio/build/STM32F103RE_creality/firmware.bin`。
可直接燒錄的副本存放於 [`firmware/`](firmware/)。

## 主機板與探針設定

- `MOTHERBOARD BOARD_CREALITY_V427` — 32 位元 Creality 4.2.7 主機板
- `#define BLTOUCH` — CR-Touch 為 BLTouch 相容克隆品
  - 探針訊號：`PB1`（`Z_MIN_PROBE_PIN`，5-pin 探針埠）
  - 伺服／致動：`PB0`（`SERVO0_PIN`）
- `#define BLTOUCH_DELAY 500` — 為克隆探針增加指令延遲
- `NOZZLE_TO_PROBE_OFFSET { -30, 0, 0 }` — 由印表機即時 `M851` 測得
  （`X-30.00 Y0.00 Z-1.38`）；X/Y 與實體支架一致，Z 於燒錄後重新校準
- `#define AUTO_BED_LEVELING_BILINEAR`，5×5 網格
- `#define Z_SAFE_HOMING`
- `PROBING_MARGIN_LEFT/RIGHT 35`、`FRONT/BACK 15`，確保偏移的探針停留在床面上
- `#define BABYSTEP_ZPROBE_OFFSET` — 列印中可即時微調 Z 偏移
- `#define PROBE_OFFSET_WIZARD` — 透過 LCD 精靈校準 Z 偏移
  （`PROBE_OFFSET_WIZARD_START_Z -1.0`）
- `Z_MIN_POS -5` — 解決「噴頭碰不到床面」的問題：當探針 Z 偏移為負值
  （`M851 Z-1.38`）時，噴頭必須移動到 Z=0 以下才能碰到床面，
  而原廠 `Z_MIN_POS 0` 的軟體極限會阻止這個動作
- `Z_MAX_POS 350` — 刻意設定：印表機裝有 Creality 實體 **Z 軸延長套件**
  （「Z350」設定檔，官方韌體名稱為 `Ender-3 HD4.2.7-Z350-...`）。
  請勿改回原廠的 250。
- `BINARY_FILE_TRANSFER` + `CUSTOM_FIRMWARE_UPLOAD` — Marlin 二進位傳輸功能
  （實際限制見下方「遠端更新」）
- `OTA_FIRMWARE_UPDATE` + `M936` — Creality MCU-OTA 指令處理器。
  `M936 V2` 現在會在重開機前回覆 `mcu reset ok`，符合盒子的預期。

## 燒錄

4.2.7 主机板會從 FAT32 SD 卡根目錄中的 `.bin` 檔案開機。

1. 複製**一個**韌體 `.bin` 到卡的根目錄。
2. 使用**全新的唯一檔名** — Creality 開機載入器會記住上一次的檔名，
   相同檔名不會再次燒錄。
3. 確認卡上**沒有其他 `.bin` 檔案**（失敗傳輸留下的不完整 `.bin` 可能被誤燒）。
4. 關閉電源、插入卡片、開機並等待更新完成。
5. 取出卡片並重新電源循環。

以 `M115` 驗證（應為 Marlin 2.1.2.10），以 `M211` 驗證
（應為 `Zmin -5.00`、`Zmax 350.00`）。

## 燒錄後（重要）

1. `M502` 接著 `M500` — 重設為韌體預設值。
2. `G28` 全部軸歸零；`M401`／`M402` 伸出／收回探針，確認 CR-Touch 動作正常。
3. 設定 Z 偏移，例如 `M851 Z-1.38`，接著 `M500`。
   也可使用 LCD 精靈：**Motion → Bed Leveling → Probe Offsets (Wizard)**。
   （`NOZZLE_TO_PROBE_OFFSET` 中的 `Z` 只是起始值。）
4. 執行 `G29` 建立網格，接著 `M500` 儲存。
5. 列印時以 babystepping 微調第一層。

### 探針疑難排解

- 探針不作動：`M280 P0 S10`（伸出）／`M280 P0 S90`（收回），
  並檢查棕／紅／橘色接線。
- 偵測不到觸發：檢查黑／白接線。
- 探測不穩定：增加 `BLTOUCH_DELAY`，或在
  `Marlin/Configuration_adv.h` 啟用 `BLTOUCH_FORCE_SW_MODE` 後重新建置。

## 透過 Creality WiFi 盒子遠端更新

現在可透過盒子使用 Marlin 的 BFT 協定進行遠端韌體更新。
程序請見 [README.zh-TW.md](README.zh-TW.md#creality-wifi-盒子與遠端更新)。
工具位於 [`tools/`](tools/)：`gen_bft.py` 產生並放置封包、
`bft_daemon.sh` 在盒子上執行，`box_telnet.py` / `printer_gcode.py`
則用於盒子 shell 與 G-code 控制。

## 選用

若您的 CR-Touch 支架有不同的 X/Y 偏移，請修改
`Marlin/Configuration.h` 中的 `NOZZLE_TO_PROBE_OFFSET`，重新建置並重新校準。
