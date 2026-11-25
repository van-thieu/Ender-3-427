# Creality WiFi 盒子筆記

[English](BOX-NOTES.md) | 繁體中文 | [Русский](BOX-NOTES.ru.md)

本文件記錄與印表機透過 USB 連接、與網路透過乙太網連接的 `CXSWBox`
（韌體 V3.04b06）相關的發現。工作電腦上保留了盒子完整快照
（二進位檔、腳本、設定）於 `/tmp/box_snapshot/`，可用於還原盒子。

## 存取方式

- 連接埠 81 的 HTTP 狀態 API：`/protocal.csp?fname=Info&opt=main&function=get`
- 對盒子 SD 卡的匿名 FTP（`/mmcblk0p1/`）
- telnet shell（憑證因裝置而異，故不揭露於此）

盒子執行 MediaTek RT2880 / Linux 2.6.36 SDK 版本。其 `prt_com` 守護程序
掌控 `/dev/ttyUSB0`（CH341 USB 序列埠，115200 baud），並以
`M105`／`M27`／`M31` 輪詢印表機。除非該守護程序正在執行，
否則直接寫入序列埠無法穩定運作。

## 韌體映像

`cxsw_update.tar.bz2` 是官方盒子韌體包：U-Boot 映像含核心與
加密／混淆過的根檔案系統（高熵、找不到可辨識的 squashfs/JFFS2 特徵）、
`install.sh`，以及可寫入的 `rw_dir/` 掛鉤。其中沒有 `prt_com` 原始碼，
且與執行中的盒子比對根檔案系統也無法取得可修補的原始碼樹。

## 內建 MCU OTA（在此主機板不可用）

盒子具有由 FIFO 指令 `mcu_ota` 觸發的 MCU OTA 程序：

1. 尋找其 SD 卡上的 `creality/mcu_ota.bin`。
2. 傳送 `M936 V2` 給印表機並等待 `mcu reset ok`。
3. 將韌體串流到開機載入器。

在 4.2.7 主機板上此做法失敗：Creality 原廠 4.2.7 韌體沒有 `M936` 處理器，
開機載入器也不會進入 OTA 模式。即使加入 `M936` 並修補盒子的等待迴圈，
串流的位元組仍會被 Marlin 當成無效 G-code。因此未使用此路徑。

## 可用的方案：Marlin BFT

Marlin 2.1.2.10 已啟用 `BINARY_FILE_TRANSFER`（`M28 B1 <file>`）。
盒子上的持久性上傳器負責驅動它：

- 開機掛鉤：`/mnt/creality/custom_start.sh`（註冊於 `_md5_app`），
  每次開機啟動 `bft_daemon.sh`。
- `creality/bft/` 存放針對 256 種 sync 值預先產生的
  `stream_<sync>.bin`、`packets_<sync>.txt`、`close_<sync>.bin` 與 `sync.bin`。
- 建立 `creality/bft/trigger` 即開始上傳。上傳器會切換到靜音 `prt_com`、
  進入二進位模式、每次只寫入一個完整封包並以約 30 ms 間隔傳送
  （BusyBox `sleep` 不支援小數，故使用 `awk`）、驗證 >1700 個 `okN` 回覆、
  傳送 CLOSE，最後送出 `M21` 與 `M997`，讓印表機重新開機並由開機載入器
  安裝韌體。完成後會還原原本的守護程序。
- 進度與錯誤寫入 `creality/bft/result.txt`。

讓它可靠運作的關鍵細節：

- 絕對不要將 BFT 封包拆成多次寫入 — Marlin 會等待剩餘位元組而逾時。
- 傳輸期間不要執行 `stty`：開啟／關閉連接埠會切換 DTR，導致 Creality 主機板重置。
- 守護程序的 `M105`／`M27`／`M79`／`M930`／`M115` 流量會污染二進位串流，
  因此傳輸期間會將其靜音。
- 請從新的位元組／行偏移解析日誌回覆；舊的 `ok`／`rs` 行會造成誤判。
