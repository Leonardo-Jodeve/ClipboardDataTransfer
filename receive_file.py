import base64
import pyperclip
import time
import re


def listen_for_file():
    transfer_started = False
    file_parts = []
    file_name = "default"

    while True:
        clipboard_content = pyperclip.paste()

        if clipboard_content.startswith("-----BEGIN FILE NAME TRANSFER-----"):
            file_name = clipboard_content.split("\n", 2)[1]
            print(f"接收到文件名为：{file_name}")
            pyperclip.copy("FILE NAME OK")
        elif clipboard_content == "-----BEGIN DATA TRANSFER-----":
            pyperclip.copy("OK")
            print("数据传输开始")
            transfer_started = True
            file_parts = []
        elif clipboard_content == "-----END DATA TRANSFER-----" and transfer_started:
            pyperclip.copy("OK")
            print("数据传输完成")
            save_file(file_name, file_parts)
            transfer_started = False
        elif transfer_started and clipboard_content.startswith("-----BEGIN PART"):
            part_content = clipboard_content.split("\n", 2)[1]
            part_number_match = re.search(r'-----BEGIN PART (\d+)', clipboard_content.split("\n", 2)[0])
            part_number = part_number_match.group(1)
            file_parts.append(part_content)
            pyperclip.copy("OK")
            print(f"接收到片段{part_number}")

        time.sleep(1)


def save_file(file_name, file_parts):
    full_content = "".join(file_parts)
    decoded_content = base64.b64decode(full_content)

    with open(file_name, "wb") as file:
        file.write(decoded_content)

    print("文件已保存")


if __name__ == "__main__":
    print("监听剪贴板...")
    listen_for_file()
