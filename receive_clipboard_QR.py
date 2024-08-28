from cv2 import boundingRect, cvtColor, COLOR_BGR2RGB
import time
import numpy as np
import pyzbar.pyzbar
import pyperclip
from pyzbar.pyzbar import decode
from PIL import ImageGrab
import re
from pyautogui import press as pyautogui_press
import base64
import io
import zipfile
import winsound


def find_qr_code(image):
    # 使用 pyzbar 库检测二维码
    decoded_objects = decode(image)
    if decoded_objects:
        for obj in decoded_objects:
            points = obj.polygon
            # 将二维码的四个顶点坐标转换为矩形
            rect = boundingRect(np.array([points]))
            x, y, w, h = rect
            return x, y, w, h
    return None


def capture_screen():
    # 捕获整个屏幕
    screen = ImageGrab.grab()
    screen_np = np.array(screen)
    screen_rgb = cvtColor(screen_np, COLOR_BGR2RGB)
    return screen_rgb


def alarm_sound():
    winsound.Beep(2200, 100)
    time.sleep(0.01)
    winsound.Beep(2200, 100)


def success_sound():
    for freq in range(600, 1001, 200):
        winsound.Beep(freq, 50)


def main():
    while True:
        part_order = {}
        total_parts = -1
        # 用于切换图片后图片未正确显示，或者图片没有正确生成的计数位
        fail_to_find_count = 0
        # 用于缺少图片素材重复扫描的标志位，如果上一个变量发挥作用，那这一个也不远了
        repeat_scan_count = 0
        # 最后一次重复扫描区块
        last_repeat_scan_chunk = -1

        while pyperclip.paste() == "START-SCAN" or pyperclip.paste().startswith("REQ"):
            # 如果处于正在生成纠错码的阶段则循环等待
            while pyperclip.paste().startswith("REQ"):
                print("Waiting for error handling QR...")
                time.sleep(1)

            if len(part_order) != total_parts:
                # 捕获屏幕图像
                screen_image = capture_screen()
                # 查找二维码
                try:
                    qr_location = find_qr_code(screen_image)
                except Exception:
                    print("FIND QR CODE ERROR!")

                if qr_location:
                    x, y, w, h = qr_location
                    # print(f"QR code found at: x={x}, y={y}, width={w}, height={h}")

                    # 截取二维码区域
                    qr_code_image = screen_image[y - 20:y + h + 20, x - 20:x + w + 20]
                    try:
                        results = pyzbar.pyzbar.decode(qr_code_image)
                    except Exception:
                        print("QR DECODE ERROR!")
                    for result in results:
                        try:
                            decoded_codes = result.data.decode("utf-8")
                        except Exception:
                            print("QR RESULT DECODE ERROR!")
                        if decoded_codes and decoded_codes.startswith("-----BEGIN PART"):
                            # 扫描失败计数器清零
                            fail_to_find_count = 0
                            part_header, part_content, part_footer = decoded_codes.split("\n", 2)
                            part_number_match = re.search(r'-----BEGIN PART (\d+) OF (\d+)-----', part_header)
                            if part_number_match:
                                part_number = int(part_number_match.group(1))
                                total_parts = int(part_number_match.group(2))
                                # 判断是否为重复扫描
                                if part_number not in part_order:
                                    part_order[part_number] = part_content
                                    repeat_scan_count = 0
                                    last_repeat_scan_chunk = -1
                                    print(f"Part {part_number} of {total_parts} scanned successfully")
                                else:
                                    repeat_scan_count += 1
                                    print(f"Repeated scan of {part_number}")
                                    if (repeat_scan_count >= 3 and
                                            (part_number != last_repeat_scan_chunk or total_parts <= 2)):
                                        # 当重复扫描计数大于等于 3 ，并且和上一次扫描的图片一致时可以判定已经进入下一个循环
                                        # 所以没有必要继续循环下去，直接进入异常处理模式
                                        full_set = set(range(1, total_parts + 1))
                                        current_key_set = set(part_order.keys())
                                        print("Repeat scan detected, start error handling...")

                                        # 找到缺少的片段
                                        missed_key_list_int = list(full_set.difference(current_key_set))
                                        missed_key_list_str = [str(element) for element in missed_key_list_int]
                                        missed_key_str = ",".join(missed_key_list_str)
                                        pyperclip.copy(f"REQ {missed_key_str}")
                                        print(f"Missing part {missed_key_str}, regenerating...")
                                        alarm_sound()
                                        continue
                                    else:
                                        last_repeat_scan_chunk = part_number
                                if len(part_order) == total_parts:
                                    pyperclip.copy("DELETE ALL")
                                    ordered_parts = [part_order[i] for i in sorted(part_order.keys())]
                                    decoded_binary_content = base64.b64decode("".join(ordered_parts))
                                    memory_file = io.BytesIO(decoded_binary_content)
                                    # 不使用无限循环判断，为了后续发布做准备
                                    for i in range(10):
                                        if pyperclip.paste() == "DONE":
                                            break
                                        else:
                                            time.sleep(0.2)
                                    # 使用 zipfile 模块解压缩内存中的文件
                                    with zipfile.ZipFile(memory_file, 'r') as zip_ref:
                                        # 获取压缩文件中的所有文件名
                                        file_names = zip_ref.namelist()
                                        # 假设压缩包内只有一个文件，读取文件内容
                                        extracted_text = zip_ref.read(file_names[0]).decode('gbk')
                                        pyperclip.copy(extracted_text)
                                        success_sound()
                                    break
                                else:
                                    pyautogui_press("right")
                else:
                    # 在扫描状态下一个周期内没有找到二维码，也许是因为二维码生成失败，计数 + 1
                    fail_to_find_count += 1
                    if fail_to_find_count > 3 and not pyperclip.paste().startswith("REQ"):
                        pyautogui_press("right")
                        fail_to_find_count = 0
                time.sleep(0.15)
            else:
                print("扫描结束！")
                del part_order
                break

        # 设置下一次判断的延迟，避免无限循环过快
        time.sleep(1)


if __name__ == "__main__":
    main()
