# Công Cụ Nén Thư Mục

Đây là một script bash giúp nén thư mục với nhiều tùy chọn linh hoạt. Script hỗ trợ nhiều hệ điều hành khác nhau bao gồm Linux, WSL và Windows (thông qua Git Bash).

## Tính năng

- Tự động nhận diện và chuyển đổi đường dẫn giữa Windows và Unix
- Hỗ trợ đường dẫn tương đối và tuyệt đối
- Tự động kiểm tra và hướng dẫn cài đặt công cụ zip nếu chưa có
- Nhiều tùy chọn nén:
  1. Nén tất cả thư mục thành một file zip duy nhất
  2. Nén riêng từng thư mục thành các file zip riêng biệt
  3. Chọn các thư mục cụ thể để nén thành một file zip
  4. Chọn các thư mục cụ thể để nén thành các file zip riêng biệt
- Hiển thị thanh tiến trình khi nén
- Hỗ trợ nén song song để tăng tốc độ xử lý

## Yêu cầu hệ thống

- Bash shell
- Công cụ zip (sẽ được hướng dẫn cài đặt nếu chưa có)

## Cách sử dụng

1. Chạy script:
```bash
./app.sh
```

2. Nhập đường dẫn đến thư mục chứa các thư mục cần nén

3. Chọn một trong các tùy chọn sau:
   - `1`: Nén tất cả thư mục thành một file zip duy nhất (total.zip)
   - `2`: Nén từng thư mục thành các file zip riêng biệt
   - `3`: Chọn các thư mục cụ thể để nén thành một file zip (selected.zip)
   - `4`: Chọn các thư mục cụ thể để nén thành các file zip riêng biệt
   - `0`: Thoát chương trình

## Hỗ trợ đa nền tảng

### Linux
- Hoạt động trực tiếp trên các bản phân phối Linux
- Tự động cài đặt công cụ zip thông qua apt hoặc yum

### Windows
- Hoạt động thông qua Git Bash
- Hỗ trợ WSL (Windows Subsystem for Linux)
- Tự động chuyển đổi đường dẫn Windows sang định dạng Unix

## Lưu ý

- Đảm bảo có đủ quyền truy cập vào thư mục cần nén
- Trên Windows, nên sử dụng Git Bash để chạy script
- Đường dẫn có thể nhập theo định dạng Windows hoặc Unix

