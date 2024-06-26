param (
    [string]$FilePath
)

function Read-File($filePath) {
    try {
        return [System.IO.File]::ReadAllBytes($filePath)
    } catch {
        Write-Output "读取文件错误: $_"
        exit 1
    }
}

function Encode-File($fileContent) {
    return [System.Convert]::ToBase64String($fileContent)
}

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

function Send-File($filePath) {
    Write-Output "读取文件: $filePath"
    $fileContent = Read-File $filePath
    $encodedContent = Encode-File($fileContent)

    $chunkSize = 499 * 1000  # 每片段大小略小于500KB
    $numChunks = [math]::Ceiling($encodedContent.Length / $chunkSize)

    $fileName = [System.IO.Path]::GetFileName($filePath)

    Set-Clipboard "-----BEGIN FILE NAME TRANSFER-----`n$fileName`n-----END FILE NAME TRANSFER-----"
    Write-Output "准备传输文件名..."

    while ((Get-Clipboard) -ne "-----FILE NAME OK-----") {
        Start-Sleep -Seconds 1
        Write-Output "等待主机响应文件名..."
    }
    Write-Output "文件名传输成功，准备传输文件数据"

    Set-Clipboard "-----BEGIN DATA TRANSFER-----"
    Write-Output "等待主机响应开始信号..."

    while ((Get-Clipboard) -ne "OK") {
        Start-Sleep -Seconds 1
        Write-Output "等待中..."
    }

    for ($i = 0; $i -lt $numChunks; $i++) {
        $chunk = $encodedContent.Substring($i * $chunkSize, [math]::Min($chunkSize, $encodedContent.Length - ($i * $chunkSize)))
        Set-Clipboard "-----BEGIN PART $($i + 1) OF $numChunks-----`n$chunk`n-----END PART $($i + 1) OF $numChunks-----"
        Write-Output "发送片段 $($i + 1)/$numChunks, 等待主机下载完成信号"

        while ((Get-Clipboard) -ne "OK") {
            Start-Sleep -Seconds 1
            Write-Output "等待中..."
        }
    }
	
	Set-Clipboard "-----CHECK-----"
	Write-Output "文件主体传输完毕，等待主机验证..."
	Start-Sleep -Seconds 1
	
    while ($true) {
        $clipboardContent = Get-Clipboard
        if ($clipboardContent -eq "ALL PARTS RECEIVED") {
            Write-Output "所有片段成功接收，传输完成"
            break
        } elseif ($clipboardContent.StartsWith("RESEND PARTS")) {
            $missingParts = $clipboardContent.Substring(13) -split ","
            foreach ($partNumber in $missingParts) {
                $partNumber = [int]$partNumber
                $chunk = $encodedContent.Substring(($partNumber - 1) * $chunkSize, [math]::Min($chunkSize, $encodedContent.Length - (($partNumber - 1) * $chunkSize)))
                Set-Clipboard "-----BEGIN PART $partNumber OF $numChunks-----`n$chunk`n-----END PART $partNumber OF $numChunks-----"
                Write-Output "重传片段 $partNumber/$numChunks, 等待主机下载完成信号"

                while ((Get-Clipboard) -ne "OK") {
                    Start-Sleep -Seconds 1
                    Write-Output "等待中..."
                }
            }
        }
    }
	for ($i = 0; $i -lt 3; $i++) {
		Set-Clipboard "-----END DATA TRANSFER-----"
		Write-Output "传输结束，等待最终确认"
		if($clipboardContent -eq "OK"){
			break
		}
		Start-Sleep -Seconds 1
	}

}

if (-not $FilePath) {
    Write-Output "用法: .\send_file.ps1 <文件路径>"
    exit 1
}

if (-not (Test-Path $FilePath)) {
    Write-Output "文件 $FilePath 不存在"
    exit 1
}

Send-File -FilePath $FilePath
