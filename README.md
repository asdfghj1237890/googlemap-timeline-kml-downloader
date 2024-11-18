# googlemap-timeline-kml-downloader

A tool for downloading your Google Maps Timeline data in KML format.
Based on https://gist.github.com/tokland/1bfbbdf495576cf6253d8153d7168de4

## Prerequisites

- Google account with Location History enabled
- Browser cookies from timeline.google.com (saved as `timeline.google.com_cookies.txt`)
- curl and bc installed on your system

## Installation

```bash
git clone https://github.com/yourusername/googlemap-timeline-kml-downloader.git
cd googlemap-timeline-kml-downloader
chmod +x google-timeline-download.sh
```

## Usage

1. Export your timeline.google.com cookies to `timeline.google.com_cookies.txt`:
   - Install a browser extension like "Get cookies.txt" for Chrome/Firefox
   - Log into your Google Account and visit timeline.google.com
   - Use the extension to export cookies to `timeline.google.com_cookies.txt`

2. Run the script:
```bash
./google-timeline-download.sh timeline.google.com_cookies.txt 2024-01-01 2024-01-31
```

### Parameters

- `COOKIES.txt`: Path to your exported cookies file
- `FROM`: Start date in YYYY-MM-DD format
- `TO`: End date in YYYY-MM-DD format

### Output

- The script creates KML files organized in year-based directories (e.g., `kml/2024/2024-01-01.kml`)
- Each file contains your location history for that specific day
- Empty or invalid KML files are automatically removed

## Advanced Features

- Sophisticated rate limiting protection:
  - Base delay of 2-7 minutes between requests
  - 33% chance of additional 50% delay
  - Batch processing (pauses for 33-63 minutes after every 300 requests)
  - Automatic retry with exponential backoff for rate-limited requests
- Robust error handling:
  - Validates KML content before saving
  - Detects and handles expired cookies
  - Removes invalid or empty KML files
  - Retries on rate limits with exponential backoff
- Modern browser emulation with complete headers

## Troubleshooting

- If you get permission errors, ensure the script is executable: `chmod +x google-timeline-download.sh`
- If downloads fail, verify that:
  - Your cookies file is valid and recent (you may need to re-export if redirected to login)
  - You have Location History enabled in your Google Account
  - You have a stable internet connection
  - You haven't exceeded Google's rate limits (script will automatically pause if needed)

## Note

- The exported KML files can be opened with:
  - Google Earth
  - Google My Maps
  - Other GIS applications
- Cookie file must follow the Netscape HTTP Cookie File format


# googlemap-timeline-kml-downloader

一個用於下載 Google Maps 時間軸資料為 KML 格式的工具。
基於 https://gist.github.com/tokland/1bfbbdf495576cf6253d8153d7168de4

## 前置需求

- 已啟用位置記錄的 Google 帳戶
- 來自 timeline.google.com 的瀏覽器 cookies（儲存為 `timeline.google.com_cookies.txt`）
- 系統已安裝 curl 和 bc

## 安裝

```bash
git clone https://github.com/yourusername/googlemap-timeline-kml-downloader.git
cd googlemap-timeline-kml-downloader
chmod +x google-timeline-download.sh
```

## 使用方式

1. 將您的 timeline.google.com cookies 匯出為 `timeline.google.com_cookies.txt`：
   - 安裝瀏覽器擴充功能，如 Chrome/Firefox 的 "Get cookies.txt"
   - 登入您的 Google 帳戶並造訪 timeline.google.com
   - 使用擴充功能將 cookies 匯出為 `timeline.google.com_cookies.txt`

2. 執行腳本：
```bash
./google-timeline-download.sh timeline.google.com_cookies.txt 2024-01-01 2024-01-31
```

### 參數說明

- `COOKIES.txt`：您匯出的 cookies 檔案路徑
- `FROM`：開始日期，格式為 YYYY-MM-DD
- `TO`：結束日期，格式為 YYYY-MM-DD

### 輸出結果

- 腳本會依年份建立目錄結構（例如：`kml/2024/2024-01-01.kml`）
- 每個檔案包含該特定日期的位置記錄
- 空白或無效的 KML 檔案會自動移除

## 進階功能

- 複雜的速率限制保護：
  - 請求之間的基本延遲為2-7分鐘
  - 33%機率增加50%額外延遲
  - 批次處理（每300個請求後暫停33-63分鐘）
  - 遇到速率限制時自動重試並指數退避
- 強大的錯誤處理：
  - 儲存前驗證KML內容
  - 檢測並處理過期的cookies
  - 移除無效或空白的KML檔案
  - 遇到速率限制時以指數退避方式重試
- 模擬現代瀏覽器的完整標頭

## 疑難排解

- 如果遇到權限錯誤，請確保腳本具有執行權限：`chmod +x google-timeline-download.sh`
- 如果下載失敗，請確認：
  - 您的 cookies 檔案有效且為最新（如果被重新導向到登入頁面，可能需要重新匯出）
  - 您的 Google 帳戶已啟用位置記錄
  - 您有穩定的網路連線
  - 未超過 Google 的速率限制（腳本會自動暫停如有需要）

## 注意事項

- 匯出的 KML 檔案可以使用以下工具開啟：
  - Google Earth
  - Google My Maps
  - 其他 GIS 應用程式
- Cookie 檔案必須遵循 Netscape HTTP Cookie File 格式