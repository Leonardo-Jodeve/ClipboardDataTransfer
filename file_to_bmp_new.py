import struct
import math


def read_binary_file(file_path):
    with open(file_path, "rb") as f:
        data = f.read()
    return data


def calculate_image_dimensions(data_length):
    x = math.sqrt(data_length / 36)
    width = int(4 * x)
    height = int(3 * x)
    return width, height


def create_bmp(file_path, output_path):
    data = read_binary_file(file_path)
    data_length = len(data)
    width, height = calculate_image_dimensions(data_length)
    print(f"Image dimensions: {width} x {height}")

    row_padded = (width * 3 + 3) & ~3
    bmp_data = bytearray(row_padded * height)

    data_idx = 0
    for y in range(height):
        for x in range(width):
            if data_idx + 3 <= data_length:
                bmp_data[y * row_padded + x * 3: y * row_padded + x * 3 + 3] = data[data_idx:data_idx + 3]
                data_idx += 3
            else:
                break

    file_size = 54 + len(bmp_data)
    bmp_header = struct.pack('<2sIHHIIIIIIIIIIII',
                             b'BM',  # 文件类型
                             file_size,  # 文件大小
                             0, 0,  # 保留字段
                             54,  # 偏移量
                             40,  # 信息头大小
                             width,  # 图像宽度
                             height,  # 图像高度
                             1,  # 平面数
                             24,  # 位深度
                             0,  # 压缩方式
                             len(bmp_data),  # 图像数据大小
                             2835,  # 水平分辨率
                             2835,  # 垂直分辨率
                             0,  # 调色板颜色数
                             0)  # 重要颜色数

    with open(output_path, 'wb') as f:
        f.write(bmp_header)
        f.write(bmp_data)
        print(f"BMP file saved: {output_path}")


if __name__ == "__main__":
    input_file = "example.rar"
    output_file = "output.bmp"
    create_bmp(input_file, output_file)
