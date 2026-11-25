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

## Creality WiFi 盒子與遠端更新

盒子提供監控、G-code 控制，以及**遠端韌體更新**。

- 狀態 API：`http://<box>/protocal.csp?fname=Info&opt=main&function=get`
- FTP：匿名存取盒子的 SD 卡
- telnet shell：裝置憑證因安全考量不於此揭露

### 遠端韌體更新

盒子上已安裝持久性上傳器，並在每次開機時啟動：

- `/mnt/creality/custom_start.sh`（註冊於 `/mnt/creality/_md5_app`）
- `/mnt/creality/bft_daemon.sh`，監看 `creality/bft/trigger`
- `creality/bft/result.txt` 記錄每次上傳結果

準備更新時，在 PC 上執行 `python3 tools/gen_bft.py <firmware.bin>`（需設定
`BOX_PASS`），它會將預先產生的 BFT 封包（涵蓋 256 種 sync 值）放到盒子的 SD 卡。
然後在盒子上建立 `creality/bft/trigger`。上傳器會暫時停止盒子的輪詢守護程序、
進入 `M28 B1` 模式、逐封包傳送、驗證回覆，最後送出 `M21` 與 `M997`，
讓印表機重新開機並由開機載入器安裝新韌體。

注意：SD 卡必須插在印表機上（韌體會寫入該卡）、每次必须使用新的唯一 8.3 檔名
（目前工具使用 `FW.BIN`），且約 2 分鐘的傳輸期間不可關閉印表機電源。

## 授權

Marlin 韌體採用 GPL-3.0，詳情請見 [LICENSE](LICENSE)。

## 更多文件

- [文件索引](docs/README.zh-TW.md)
- [疑難排解](docs/TROUBLESHOOTING.zh-TW.md)
- [Creality WiFi 盒子筆記](docs/BOX-NOTES.zh-TW.md)
