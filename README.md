
## QR剪贴板同步项目更新

该更新旨在解决连剪贴板同步都被限制之后，堡垒机与主机之间的剪贴板同步问题，详细使用方法见 Release

### 敬赠某些老爷

不知道您能否意识到，您金口玉言下命令会影响到成千上万的一线员工

我们才是不得不使用这些垃圾系统的人

如果您不能信任您的员工，甚至需要限制堡垒机剪贴板同步来管理数据

那也许，您将要面对的问题就不是限制剪贴板能解决的了

---
# 文件传输项目

该项目旨在通过剪贴板在堡垒机和主机之间传输大文件，采用分片传输并支持断点续传。此项目包含两个主要部分：发送端 PowerShell 脚本和接收端 Python 脚本。

## 目录

- [文件传输项目](#文件传输项目)
  - [目录](#目录)
  - [功能](#功能)
  - [发送端 (PowerShell 脚本)](#发送端-powershell-脚本)
  - [接收端 (Python 脚本)](#接收端-python-脚本)
  - [使用方法](#使用方法)
    - [准备工作](#准备工作)
    - [发送文件](#发送文件)
    - [接收文件](#接收文件)
  - [常见问题](#常见问题)
  - [贡献](#贡献)
  - [许可证](#许可证)

## 功能

- 支持大文件传输，分片大小略小于 500KB
- 使用 Base64 编码文件内容
- 支持文件名传输
- 支持分片重传机制
- 异常处理和重试机制，确保传输稳定

## 发送端 (PowerShell 脚本)

`send_file.ps1` 负责在堡垒机上将指定文件分片并通过剪贴板传输到主机。它首先传输文件名，然后分片传输文件内容。


## 接收端 (Python 脚本)
`receive_file.py` 负责在主机上监听剪贴板内容并接收分片数据，最终合并并保存为原始文件。


## 使用方法
### 准备工作
确保主机和堡垒机上安装了必要的软件：
1. 主机需要安装 Python 及 pyperclip 库。
2. 堡垒机需要安装 PowerShell。

### 发送文件
1. 将 send_file.ps1 脚本复制到堡垒机上。
2. 创建一个快捷方式来指定文件路径参数：
3. 右键点击 send_file.ps1，选择“创建快捷方式”。
4. 右键点击创建的快捷方式，选择“属性”。
5. 在“目标”字段中输入以下内容：

```text
powershell.exe -ExecutionPolicy Bypass -File "C:\path\to\send_file.ps1" -FilePath "C:\path\to\your\file.txt"
```

### 接收文件
1. 将 receive_file.py 脚本复制到主机上。
2. 在命令行中运行脚本：

```text
python receive_file.py
```
脚本将会监听剪贴板并接收文件，接收完成后保存为原始文件。

## 常见问题

### 剪贴板访问失败：
如果遇到剪贴板访问失败的错误，脚本已包含重试机制，请稍等片刻。

### 文件不存在：
确保指定的文件路径正确，并且文件存在。

## 贡献
欢迎任何形式的贡献，您可以通过提交 Pull Request 或报告 Issue 来参与本项目。

## 许可证
该项目使用 MIT 许可证。