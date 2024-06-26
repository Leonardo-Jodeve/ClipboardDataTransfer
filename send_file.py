import base64
import pyperclip
import time
import os
import sys


def read_file(file_path):
    try:
        with open(file_path, "rb") as file:
            return file.read()
    except Exception as e:
        print(f"读取文件错误: {e}")
        sys.exit(1)


def send_file(file_path):
    print(f"读取文件: {file_path}")
    file_content = read_file(file_path)
    encoded_content = base64.b64encode(file_content).decode("utf-8")

    chunk_size = 499 * 1000  # 每片段大小略小于500KB
    num_chunks = len(encoded_content) // chunk_size + (1 if len(encoded_content) % chunk_size != 0 else 0)

    file_name = file_path.split(".\\")[-1]

    pyperclip.copy(f"-----BEGIN FILE NAME TRANSFER-----\n{file_name}\n-----END FILE NAME TRANSFER-----")
    print("准备传输文件名...")

    while pyperclip.paste() != "FILE NAME OK":
        time.sleep(1)
        print("等待主机响应中...")
    print("文件名传输成功，准备传输文件数据")

    pyperclip.copy("-----BEGIN DATA TRANSFER-----")
    print("开始信号已发送，等待主机响应信号...")

    while pyperclip.paste() != "OK":
        time.sleep(1)
        print("等待中...")

    for i in range(num_chunks):
        chunk = encoded_content[i * chunk_size: (i + 1) * chunk_size]
        pyperclip.copy(f"-----BEGIN PART {i + 1:04d} OF {num_chunks}-----\n{chunk}\n-----END PART {i + 1:04d} OF {num_chunks}-----")
        print(f"发送片段 {i + 1}/{num_chunks}, 等待主机下载完成信号")
        while pyperclip.paste() != "OK":
            time.sleep(1)
            print("等待中...")

    pyperclip.copy("-----END DATA TRANSFER-----")
    print("传输结束，等待最终确认")


if __name__ == "__main__":
    print("开始运行！")
    print("目前的参数列表")
    print(sys.argv)
    if len(sys.argv) != 2:
        print("用法: python send_file.py <文件路径>")
        sys.exit(1)

    file_path = sys.argv[1]
    if not os.path.isfile(file_path):
        print(f"文件 {file_path} 不存在")
        sys.exit(1)

    send_file(file_path)
