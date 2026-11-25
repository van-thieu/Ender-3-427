# 疑難排解

[English](TROUBLESHOOTING.md) | 繁體中文 | [Русский](TROUBLESHOOTING.ru.md)

## 韌體無法從 SD 卡燒錄

- SD 卡根目錄**只能有一個 `.bin`**，且每次都要使用**新的唯一檔名** —
  Creality 4.2.7 開機載入器會記住上一次的檔名並拒絕重複燒錄。
- 重試前請刪除失敗傳輸留下的不完整 `.bin`。
- 卡片必須為 FAT32。關閉電源、插入卡片、開機並等待畫面完成。
- 以 `M115` 驗證（應為 Marlin 2.1.2.10），以 `M211` 驗證
  （`Zmin -5.00`、`Zmax 350.00`）。

## CR-Touch 不作動

- 手動測試：`M280 P0 S10`（伸出）、`M280 P0 S90`（收回）。
- 檢查探針埠的棕／紅／橘色接線（4.2.7 板上的 PB1／PB0）。
- 若探針觸發但網格不正確，重新確認 `M851 X/Y`（目前為 X-30、Y0）。
- 若探測不穩定，增加 `BLTOUCH_DELAY` 或在
  `Marlin/Configuration_adv.h` 啟用 `BLTOUCH_FORCE_SW_MODE` 後重新建置。

## 噴頭碰不到床面

此問題已在韌體中以 `Z_MIN_POS -5` 修正。若再次發生：
- `M851 Z...` 必須足夠負（可從 `Z-1.38` 開始）。
- `M211` 應回報 `Zmin -5.00`；若為 `0.00`，表示新韌體未安裝。
- 使用 LCD 精靈：**Motion → Bed Leveling → Probe Offsets (Wizard)**。

## 遠端更新失敗

- 讀取盒子 SD 卡上的 `creality/bft/result.txt`。
- `no stream for sync <n>`：使用 `tools/gen_bft.py` 重新產生暫存檔案。
- `resend requested`：封包損毀。確認印表機上的 SD 卡已插入、
  沒有其他程序正在傳送 G-code，然後重試 — 上傳器會自動以新的 sync 重試。
- `quiet daemon unavailable`：將 `prt_com.quiet` 複製到盒子上的 `/mnt/creality/`。
- 若失敗後印表機不再回覆 ASCII 指令，表示卡在 BFT 模式。
  請電源循環重開印表機，或使用 `tools/gen_bft.py` 產生的
  `close_<sync>.bin` 傳送連線關閉封包。
- 完整傳輸約需 2 分鐘，期間請勿關閉印表機電源。

## 盒子無法連線

- 確認盒子的 IP，且與電腦在同一網路（預設 `192.168.1.126`）。
- HTTP 狀態 API：`http://<box>/protocal.csp?fname=Info&opt=main&function=get`。
- FTP 為匿名；telnet 憑證因裝置而異（不於此揭露）。
