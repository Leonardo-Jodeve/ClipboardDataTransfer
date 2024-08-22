# �����Ҫ�� .NET ��
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
            Write-Output "���ü�����ʧ�ܣ�������... ($($i + 1)/$maxRetries)"
            Start-Sleep -Seconds $retryInterval
        }
    }
    Write-Output "���ü�����ʧ�ܣ��Ѵﵽ������Դ�����"
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
            Write-Output "��ȡ������ʧ�ܣ�������... ($($i + 1)/$maxRetries)"
            Start-Sleep -Seconds $retryInterval
        }
    }
    Write-Output "��ȡ������ʧ�ܣ��Ѵﵽ������Դ�����"
    exit 1
}

# ������ʱĿ¼·��
$baseDir = "qr_code_transfer_temp"
$outputDir = Join-Path -Path (Get-Location) -ChildPath $baseDir

# ������ʱĿ¼
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

# ��ȡ����������
$clipboard = [System.Windows.Forms.Clipboard]::GetDataObject()

if ($clipboard.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
    # ��������������ļ������˳�
    Write-Host "����������ļ����ű��˳���"
    exit
} elseif ($clipboard.GetDataPresent([System.Windows.Forms.DataFormats]::Text)) {
    # ��������������ı������������
    $text = [System.Windows.Forms.Clipboard]::GetText()

    # �����ı�����ʱ�ļ�
    $tempTxtFile = Join-Path -Path $outputDir -ChildPath "temp_text.txt"
    Set-Content -Path $tempTxtFile -Value $text
    Write-Host "�ı��ѱ��浽: $tempTxtFile"

    # ѹ���ı��ļ�
    $tempZipFile = Join-Path -Path $outputDir -ChildPath "temp_zip.zip"
    Compress-Archive -Path $tempTxtFile -DestinationPath $tempZipFile
    Write-Host "�ı���ѹ����ZIP�ļ�: $tempZipFile"

    # ��ZIP�ļ�ת��ΪBase64����
    $zipBytes = [System.IO.File]::ReadAllBytes($tempZipFile)
    $base64String = [Convert]::ToBase64String($zipBytes)
    Write-Host "ZIP�ļ��ѱ���ΪBase64��"

    # ����QR����С (������2KB)
    $maxChunkSize = 2300
    $numChunks = [math]::Ceiling($base64String.Length / $maxChunkSize)

    # �ָ�Base64�ַ��������� QR ��
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
        Write-Host "����QR��: $outputFile"
		Start-Sleep -Milliseconds 50
    }

    # ����ͼƬ�ļ���·��׼���򿪵�һ�� QR ��ͼƬ
    $firstQrCode = $qrCodePaths[0]
    # ȷ�� Windows ��Ƭ�鿴����·��
    $photoViewer = "$env:SystemRoot\System32\rundll32.exe"
    # ��ͼƬ
    Start-Process -FilePath $photoViewer -ArgumentList "`"$env:ProgramFiles\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen $firstQrCode"
    Write-Host "�򿪵�һ��QR��ͼƬ: $firstQrCode"

    Set-Clipboard "---START-SCAN---"

    # ��ʼ��������������
    while ($true) {
        Start-Sleep -Seconds 0.1

        $currentClipboardText = [System.Windows.Forms.Clipboard]::GetText()
        if ($currentClipboardText -eq "DELETE ALL") {
            Write-Host "�յ� DELETE ALL �����ʼɾ�� QR ��ͼƬ���رղ鿴�����"

            # �رղ鿴���
            Stop-Process -Name rundll32 -ErrorAction SilentlyContinue

            # ɾ����ʱĿ¼���������ɵ��ļ�
            Remove-Item -Path $outputDir -Recurse -Force
            Write-Host "��ʱĿ¼�������ļ���ɾ����"
            Set-Clipboard "DONE"
            break
        }
    }
} else {
    Write-Host "���������ݼȲ����ļ�Ҳ�����ı����ű��˳���"
    exit
}