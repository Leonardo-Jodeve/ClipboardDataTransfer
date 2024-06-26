import base64
import pyperclip
import time
import re


def save_file(file_name, file_parts):
    full_content = "".join(file_parts)
    decoded_content = base64.b64decode(full_content)

    with open(file_name, "wb") as file:
        file.write(decoded_content)

    print(f"文件 {file_name} 已保存")
    pyperclip.copy("OK")


def listen_for_file():
    transfer_started = False
    file_name = "default"
    part_order = {}
    total_parts = 0

    while True:
        clipboard_content = pyperclip.paste()

        if clipboard_content.startswith("-----BEGIN FILE NAME TRANSFER-----"):
            file_name = clipboard_content.split("\n", 2)[1]
            print(f"接收到文件名为：{file_name}")
            pyperclip.copy("-----FILE NAME OK-----")
        elif clipboard_content == "-----BEGIN DATA TRANSFER-----":
            pyperclip.copy("OK")
            print("数据传输开始")
            transfer_started = True
            part_order = {}
        elif transfer_started and clipboard_content.startswith("-----BEGIN PART"):
            part_header, part_content, part_footer = clipboard_content.split("\n", 2)
            part_number_match = re.search(r'-----BEGIN PART (\d+) OF (\d+)-----', part_header)
            if part_number_match:
                part_number = int(part_number_match.group(1))
                total_parts = int(part_number_match.group(2))
                part_order[part_number] = part_content
                pyperclip.copy("OK")
                print(f"接收到片段 {part_number}，共 {total_parts} 个片段")
        elif clipboard_content == "-----CHECK-----" and transfer_started:
            if len(part_order) == total_parts:
                pyperclip.copy("ALL PARTS RECEIVED")
                print("所有片段接收完毕，准备重组文件")
            else:
                missing_parts = [i for i in range(1, total_parts + 1) if i not in part_order]
                if missing_parts:
                    print(f"丢失片段: {missing_parts}")
                    pyperclip.copy(f"RESEND PARTS {missing_parts}")
        elif clipboard_content == "-----END DATA TRANSFER-----" and transfer_started:
            pyperclip.copy("OK")
            print("数据传输完成")
            ordered_parts = [part_order[i] for i in sorted(part_order.keys())]
            save_file(file_name, ordered_parts)
            transfer_started = False
        time.sleep(1)


if __name__ == "__main__":
    print("开始监听剪贴板...")
    listen_for_file()
