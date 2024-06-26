param (
    [string]$FilePath
)

function Read-File($filePath) {
    try {
        return [System.IO.File]::ReadAllBytes($filePath)
    } catch {
        Write-Output "��ȡ�ļ�����: $_"
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

function Send-File($filePath) {
    Write-Output "��ȡ�ļ�: $filePath"
    $fileContent = Read-File $filePath
    $encodedContent = Encode-File($fileContent)

    $chunkSize = 499 * 1000  # ÿƬ�δ�С��С��500KB
    $numChunks = [math]::Ceiling($encodedContent.Length / $chunkSize)

    $fileName = [System.IO.Path]::GetFileName($filePath)

    Set-Clipboard "-----BEGIN FILE NAME TRANSFER-----`n$fileName`n-----END FILE NAME TRANSFER-----"
    Write-Output "׼�������ļ���..."

    while ((Get-Clipboard) -ne "-----FILE NAME OK-----") {
        Start-Sleep -Seconds 1
        Write-Output "�ȴ�������Ӧ�ļ���..."
    }
    Write-Output "�ļ�������ɹ���׼�������ļ�����"

    Set-Clipboard "-----BEGIN DATA TRANSFER-----"
    Write-Output "�ȴ�������Ӧ��ʼ�ź�..."

    while ((Get-Clipboard) -ne "OK") {
        Start-Sleep -Seconds 1
        Write-Output "�ȴ���..."
    }

    for ($i = 0; $i -lt $numChunks; $i++) {
        $chunk = $encodedContent.Substring($i * $chunkSize, [math]::Min($chunkSize, $encodedContent.Length - ($i * $chunkSize)))
        Set-Clipboard "-----BEGIN PART $($i + 1) OF $numChunks-----`n$chunk`n-----END PART $($i + 1) OF $numChunks-----"
        Write-Output "����Ƭ�� $($i + 1)/$numChunks, �ȴ�������������ź�"

        while ((Get-Clipboard) -ne "OK") {
            Start-Sleep -Seconds 1
            Write-Output "�ȴ���..."
        }
    }
	
	Set-Clipboard "-----CHECK-----"
	Write-Output "�ļ����崫����ϣ��ȴ�������֤..."
	Start-Sleep -Seconds 1
	
    while ($true) {
        $clipboardContent = Get-Clipboard
        if ($clipboardContent -eq "ALL PARTS RECEIVED") {
            Write-Output "����Ƭ�γɹ����գ��������"
            break
        } elseif ($clipboardContent.StartsWith("RESEND PARTS")) {
            $missingParts = $clipboardContent.Substring(13) -split ","
            foreach ($partNumber in $missingParts) {
                $partNumber = [int]$partNumber
                $chunk = $encodedContent.Substring(($partNumber - 1) * $chunkSize, [math]::Min($chunkSize, $encodedContent.Length - (($partNumber - 1) * $chunkSize)))
                Set-Clipboard "-----BEGIN PART $partNumber OF $numChunks-----`n$chunk`n-----END PART $partNumber OF $numChunks-----"
                Write-Output "�ش�Ƭ�� $partNumber/$numChunks, �ȴ�������������ź�"

                while ((Get-Clipboard) -ne "OK") {
                    Start-Sleep -Seconds 1
                    Write-Output "�ȴ���..."
                }
            }
        }
    }
	for ($i = 0; $i -lt 3; $i++) {
		Set-Clipboard "-----END DATA TRANSFER-----"
		Write-Output "����������ȴ�����ȷ��"
		if($clipboardContent -eq "OK"){
			break
		}
		Start-Sleep -Seconds 1
	}

}

if (-not $FilePath) {
    Write-Output "�÷�: .\send_file.ps1 <�ļ�·��>"
    exit 1
}

if (-not (Test-Path $FilePath)) {
    Write-Output "�ļ� $FilePath ������"
    exit 1
}

Send-File -FilePath $FilePath
