# FTP Phone Photo Backup Tool

A robust Windows tool to automatically backup photos and videos from your phone's FTP server, organized by year-month folders.

## Features

- **Auto-download** photos and videos via FTP
- **Smart organization** into `YYYYMM` folders (e.g., `202407`, `202508`)
- **Skip duplicates** - won't re-download existing files
- **Adaptive throttling** - automatically slows down if phone FTP becomes unstable
- **Auto-retry** - retries failed files up to 3 times
- **Priority queue** - failed files from last run are retried first
- **File size validation** - verifies downloaded files are complete
- **Interactive** - prompts for FTP address each run (useful when phone IP changes)
- **Configurable** - edit `config.json` to set defaults

## Quick Start

### 1. Enable FTP on Your Phone

**Recommended:** Use **ES File Explorer** app (free, widely available):
1. Open ES File Explorer on your phone
2. Tap the menu (☰) → **"View on PC"**
3. Tap **"Turn on"** to start the FTP server
4. Note the FTP address shown (e.g., `ftp://192.168.1.243:3721/`)

**Alternative:** Any FTP server app works (e.g., FTP Server, WiFi FTP Server, Solid Explorer)

### 2. Run the Backup Tool

1. Connect phone and PC to the **same WiFi**
2. Double-click `run.bat` on your PC
3. Press Enter to use default FTP, or type your phone's FTP address
4. Wait for backup to complete

## Requirements

- Windows 10/11 with PowerShell 5.1+
- Phone with FTP server app
- Same WiFi network

## File Structure

```
FTP-Phone-Photo-Backup/
├── run.bat                   # Double-click to run
├── backup_phone_album.ps1   # Main script
├── config.json              # Default settings (optional)
└── README.md                # This file
```

## Configuration

Edit `config.json` to set your defaults:

```json
{
  "ftpUrl": "ftp://192.168.1.243:3721/DCIM/Camera/",
  "baseDir": "D:\\PhoneAlbum\\Backup"
}
```

If `config.json` exists, the script uses it. Otherwise it uses the built-in defaults.

## How It Works

1. Lists all files from the phone's FTP `DCIM/Camera` folder
2. Filters for photo/video extensions (`.jpg`, `.png`, `.heic`, `.mp4`, `.mov`, etc.)
3. Extracts date from filenames like `IMG_20240728_115321.jpg`
4. Only accepts years `2024`, `2025`, `2026` and months `01-12`
5. Files without valid dates go to `Unknown` folder
6. Downloads missing files, skips existing ones
7. If phone FTP becomes unstable, automatically throttles to avoid crashing it

## License

MIT License - feel free to use, modify, and share.

---

# 手机相册FTP自动备份工具

一个稳健的 Windows 工具，通过 FTP 自动从手机备份照片和视频，按年月自动分类存放。

## 功能特点

- **自动下载**手机FTP上的照片和视频
- **智能分类**到 `年月` 文件夹（如 `202407`、`202508`）
- **跳过重复** - 已存在的文件不会重复下载
- **自适应节流** - 手机FTP不稳定时自动降速保护
- **自动重试** - 单个文件失败自动重试3次
- **优先队列** - 上次失败的文件下次优先重试
- **文件完整性校验** - 下载完成后验证文件大小
- **交互式** - 每次运行前可修改FTP地址（手机IP变化时很有用）
- **可配置** - 编辑 `config.json` 设置默认值

## 快速开始

### 1. 在手机上开启FTP

**推荐使用：** **ES 文件浏览器**（免费，应用商店可下载）
1. 打开手机的 ES 文件浏览器
2. 点击左上角菜单（☰）→ **"从PC访问"**
3. 点击 **"打开"** 启动FTP服务
4. 记录显示的FTP地址（如 `ftp://192.168.1.243:3721/`）

**其他选择：** 任何FTP服务端应用均可（如 FTP Server、WiFi FTP Server、Solid Explorer）

### 2. 运行备份工具

1. 手机和电脑连接**同一WiFi**
2. 在电脑上双击 `run.bat`
3. 按回车使用默认地址，或输入手机的FTP地址
4. 等待备份完成

## 系统要求

- Windows 10/11，PowerShell 5.1+
- 手机安装FTP服务端应用
- 同一WiFi网络

## 文件结构

```
FTP-Phone-Photo-Backup/
├── run.bat                   # 双击运行
├── backup_phone_album.ps1   # 主脚本
├── config.json              # 默认配置（可选）
└── README.md                # 说明文档
```

## 配置方法

编辑 `config.json` 设置默认值：

```json
{
  "ftpUrl": "ftp://192.168.1.243:3721/DCIM/Camera/",
  "baseDir": "D:\\手机相册\\2025-0221-20260316"
}
```

如果 `config.json` 存在，脚本会使用它。否则使用内置默认值。

## 工作原理

1. 从手机FTP的 `DCIM/Camera` 目录获取文件列表
2. 过滤照片和视频格式（`.jpg`、`.png`、`.heic`、`.mp4`、`.mov` 等）
3. 从文件名提取日期，如 `IMG_20240728_115321.jpg`
4. 只接受 `2024`、`2025`、`2026` 年份和 `01-12` 月份
5. 日期无法识别的放入 `Unknown` 文件夹
6. 下载缺失文件，跳过已有文件
7. 手机FTP不稳定时自动节流，防止崩溃

## 许可证

MIT License - 可自由使用、修改和分享。
