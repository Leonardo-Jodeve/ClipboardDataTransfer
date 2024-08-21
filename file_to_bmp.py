import struct
import math


def read_binary_file(file_path):
    with open(file_path, "rb") as f:
        data = f.read()
    return data


def calculate_image_dimensions(data_length):
    # 4:3 比例计算位图尺寸 (width, height)
    # width = 4 * x, height = 3 * x
    # width * height = 4 * 3 * x^2 = 12 * x^2
    # 所以 total_pixels = width * height = 12 * x^2
    # data_length = total_pixels * 3 (因为每个像素有 3 字节 RGB 数据)
    # x^2 = data_length / 36
    # width = 4 * sqrt(data_length / 36), height = 3 * sqrt(data_length / 36)

    x = math.sqrt(data_length / 36)
    width = int(4 * x)
    height = int(3 * x)

    return width, height


def create_bmp(file_path, output_path):
    # 读取二进制文件
    data = read_binary_file(file_path)
    data_length = len(data)

    # 计算位图尺寸
    width, height = calculate_image_dimensions(data_length)
    print(f"Image dimensions: {width} x {height}")

    # BMP 图像数据需要填充到4的倍数的行宽度
    row_padded = (width * 3 + 3) & ~3

    # 初始化 BMP 图像数据区
    bmp_data = bytearray(row_padded * height)

    # 填充 BMP 数据区
    data_idx = 0
    for y in range(height):
        for x in range(width):
            if data_idx + 3 <= data_length:
                bmp_data[y * row_padded + x * 3: y * row_padded + x * 3 + 3] = data[data_idx:data_idx + 3]
                data_idx += 3
            else:
                break

    # BMP 文件头
    file_size = 54 + len(bmp_data)  # 文件总大小 = 文件头 + 数据区
    bmp_header = struct.pack('<2sIHHIIIIIIIIIIII',
                             b'BM',  # 文件类型
                             file_size,  # 文件大小
                             0, 0,  # 保留位
                             54,  # 图像数据的起始偏移量（通常是54）
                             40,  # 信息头大小（通常是40）
                             width,  # 图像宽度
                             height,  # 图像高度
                             1,  # 颜色平面数
                             24,  # 每像素位数（24位，即RGB）
                             0,  # 压缩方式
                             len(bmp_data),  # 图像数据大小
                             2835,  # 水平分辨率
                             2835,  # 垂直分辨率
                             0,  # 调色板中的颜色数
                             0)  # 重要颜色数

    # 保存 BMP 文件
    with open(output_path, 'wb') as f:
        f.write(bmp_header)  # 写入文件头
        f.write(bmp_data)  # 写入图像数据
        print(f"BMP file saved: {output_path}")


if __name__ == "__main__":
    input_file = "example.rar"  # 需要转换的文件
    output_file = "output.bmp"  # 输出 BMP 文件路径

    create_bmp(input_file, output_file)
