import cv2
import numpy as np
import pyzbar.pyzbar
import pyperclip
from pyzbar.pyzbar import decode
from PIL import ImageGrab
import re
import pyautogui
import base64
import io
import zipfile


def find_qr_code(image):
    # 使用 pyzbar 库检测二维码
    decoded_objects = decode(image)
    if decoded_objects:
        for obj in decoded_objects:
            points = obj.polygon
            # 将二维码的四个顶点坐标转换为矩形
            rect = cv2.boundingRect(np.array([points]))
            x, y, w, h = rect
            return x, y, w, h
    return None


def capture_screen():
    # 捕获整个屏幕
    screen = ImageGrab.grab()
    screen_np = np.array(screen)
    screen_rgb = cv2.cvtColor(screen_np, cv2.COLOR_BGR2RGB)
    return screen_rgb


def main():
    while True:
        part_order = {}
        total_parts = -1

        while pyperclip.paste() == "---START-SCAN---":
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
                    print(f"QR code found at: x={x}, y={y}, width={w}, height={h}")

                    # 截取二维码区域
                    qr_code_image = screen_image[y:y + h, x:x + w]
                    try:
                        results = pyzbar.pyzbar.decode(qr_code_image)
                    except Exception:
                        print("DECODE ERROR!")
                    for result in results:
                        decoded_codes = result.data.decode("utf-8")
                        if decoded_codes.startswith("-----BEGIN PART"):
                            part_header, part_content, part_footer = decoded_codes.split("\n", 2)
                            part_number_match = re.search(r'-----BEGIN PART (\d+) OF (\d+)-----', part_header)
                            if part_number_match:
                                part_number = int(part_number_match.group(1))
                                total_parts = int(part_number_match.group(2))
                                part_order[part_number] = part_content
                                if len(part_order) == total_parts:
                                    pyperclip.copy("DELETE ALL")
                                    ordered_parts = [part_order[i] for i in sorted(part_order.keys())]
                                    decoded_binary_content = base64.b64decode("".join(ordered_parts))
                                    memory_file = io.BytesIO(decoded_binary_content)
                                    # 延时0.5秒让堡垒机程序退出
                                    cv2.waitKey(500)
                                    # 使用 zipfile 模块解压缩内存中的文件
                                    with zipfile.ZipFile(memory_file, 'r') as zip_ref:
                                        # 获取压缩文件中的所有文件名
                                        file_names = zip_ref.namelist()
                                        # 假设压缩包内只有一个文件，读取文件内容
                                        extracted_text = zip_ref.read(file_names[0]).decode('gbk')
                                        pyperclip.copy(extracted_text)
                                    break
                                else:
                                    pyautogui.press("right")
                cv2.waitKey(100)
            else:
                print("扫描结束！休眠5秒")
                del part_order
                break

        # 如果需要持续扫描，可以设置一个短暂的延迟
        cv2.waitKey(5000)


if __name__ == "__main__":
    main()
