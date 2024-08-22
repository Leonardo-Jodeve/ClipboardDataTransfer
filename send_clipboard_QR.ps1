# 导入必要的 .NET 类
Add-Type -AssemblyName PresentationCore, WindowsBase, System.Windows.Forms

function Set-Clipboard($text) {
    Add-Type -AssemblyName PresentationCore
    $maxRetries = 10
    $retryInterval = 0.5 # seconds
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            [System.Windows.Clipboard]::SetText($text)
            return
        } catch {
            Write-Output "设置剪贴板失败，重试中... ($($i + 1)/$maxRetries)"
            Start-Sleep -Seconds $retryInterval
        }
    }
    Write-Output "设置剪贴板失败，已达到最大重试次数。"
    exit 1
}

function Get-Clipboard() {
    Add-Type -AssemblyName PresentationCore
    $maxRetries = 10
    $retryInterval = 0.5 # seconds
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            return [System.Windows.Clipboard]::GetText()
        } catch {
            Write-Output "获取剪贴板失败，重试中... ($($i + 1)/$maxRetries)"
            Start-Sleep -Seconds $retryInterval
        }
    }
    Write-Output "获取剪贴板失败，已达到最大重试次数。"
    exit 1
}

# 定义临时目录路径
$baseDir = "qr_code_transfer_temp"
$outputDir = Join-Path -Path (Get-Location) -ChildPath $baseDir

# 创建临时目录
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

# 获取剪贴板内容
$clipboard = [System.Windows.Forms.Clipboard]::GetDataObject()

if ($clipboard.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
    # 如果剪贴板中是文件，则退出
    Write-Host "剪贴板包含文件，脚本退出。"
    exit
} elseif ($clipboard.GetDataPresent([System.Windows.Forms.DataFormats]::Text)) {
    # 如果剪贴板中是文本，则继续处理
    $text = [System.Windows.Forms.Clipboard]::GetText()

    # 保存文本到临时文件
    $tempTxtFile = Join-Path -Path $outputDir -ChildPath "temp_text.txt"
    Set-Content -Path $tempTxtFile -Value $text
    Write-Host "文本已保存到: $tempTxtFile"

    # 压缩文本文件
    $tempZipFile = Join-Path -Path $outputDir -ChildPath "temp_zip.zip"
    Compress-Archive -Path $tempTxtFile -DestinationPath $tempZipFile
    Write-Host "文本已压缩到ZIP文件: $tempZipFile"

    # 将ZIP文件转化为Base64编码
    $zipBytes = [System.IO.File]::ReadAllBytes($tempZipFile)
    $base64String = [Convert]::ToBase64String($zipBytes)
    Write-Host "ZIP文件已编码为Base64。"

    # 定义QR码块大小 (略少于2KB)
    $maxChunkSize = 2300
    $numChunks = [math]::Ceiling($base64String.Length / $maxChunkSize)

    # 分割Base64字符串并生成 QR 码
    $chunks = @()
    $chunk_index = 1
    for ($i = 0; $i -lt $base64String.Length; $i += $maxChunkSize) {
        $chunk = $base64String.Substring($i, [System.Math]::Min($maxChunkSize, $base64String.Length - $i))
        $chunk = "-----BEGIN PART $chunk_index OF $numChunks-----`n$chunk`n-----END PART $chunk_index OF $numChunks-----"
        $chunks += $chunk
        $chunk_index++
    }

    $qrCodePaths = @()
    for ($j = 0; $j -lt $chunks.Length; $j++) {
        $outputFile = Join-Path $outputDir "QR_Code_$($j + 1).png"
        $chunks[$j] | .\qrencode.exe -o $outputFile -s 2 -l L
        $qrCodePaths += $outputFile
        Write-Host "生成QR码: $outputFile"
		Start-Sleep -Milliseconds 50
    }

    # 设置图片文件的路径准备打开第一个 QR 码图片
    $firstQrCode = $qrCodePaths[0]
    # 确定 Windows 照片查看器的路径
    $photoViewer = "$env:SystemRoot\System32\rundll32.exe"
    # 打开图片
    Start-Process -FilePath $photoViewer -ArgumentList "`"$env:ProgramFiles\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen $firstQrCode"
    Write-Host "打开第一个QR码图片: $firstQrCode"

    Set-Clipboard "---START-SCAN---"

    # 开始监听剪贴板内容
    while ($true) {
        Start-Sleep -Seconds 0.1

        $currentClipboardText = [System.Windows.Forms.Clipboard]::GetText()
        if ($currentClipboardText -eq "DELETE ALL") {
            Write-Host "收到 DELETE ALL 命令，开始删除 QR 码图片并关闭查看软件。"

            # 关闭查看软件
            Stop-Process -Name rundll32 -ErrorAction SilentlyContinue

            # 删除临时目录及所有生成的文件
            Remove-Item -Path $outputDir -Recurse -Force
            Write-Host "临时目录及所有文件已删除。"
            Set-Clipboard "DONE"
            break
        }
    }
} else {
    Write-Host "剪贴板内容既不是文件也不是文本，脚本退出。"
    exit
}