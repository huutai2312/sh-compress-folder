#!/bin/bash

# Xác định hệ điều hành
OS_TYPE=$(uname)

# Hàm chuyển đổi đường dẫn Windows sang định dạng Unix
convert_path() {
    local input_path="$1"
    # Loại bỏ dấu ngoặc kép nếu có
    input_path="${input_path%\"}"
    input_path="${input_path#\"}"
    case "$OS_TYPE" in
        "Linux")
            if grep -q Microsoft /proc/version; then
                # Chuyển đổi đường dẫn Windows sang WSL
                input_path=$(echo "$input_path" | sed -E 's/^([A-Za-z]):/\/mnt\/\L\1/')
                input_path=$(echo "$input_path" | tr '\\' '/')
            fi
            ;;
        "MINGW"*|"MSYS"*|"CYGWIN"*)
            # Chuyển đổi đường dẫn Windows sang Git Bash
            input_path=$(echo "$input_path" | sed -E 's/^([A-Za-z]):/\/\L\1/')
            input_path=$(echo "$input_path" | tr '\\' '/')
            ;;
    esac
    
    echo "$input_path"
}

# Hàm chuẩn hóa đường dẫn
normalize_path() {
    local path="$1"
    
    # Thay thế ~ bằng $HOME
    path="${path/#\~/$HOME}"
    
    # Chỉ xử lý đường dẫn tương đối
    if [[ ! "$path" =~ ^/ ]] && [[ ! "$path" =~ ^[A-Za-z]: ]]; then
        path="$PWD/$path"
    fi
    
    echo "$path"
}

# Nhập đường dẫn từ người dùng
echo "Vui lòng nhập đường dẫn đến thư mục cần nén:"
read -r SOURCE_DIR

# Đổi thứ tự xử lý: chuyển đổi đường dẫn Windows trước
SOURCE_DIR=$(convert_path "$SOURCE_DIR")

# Debug
echo "Đường dẫn sau khi chuyển đổi: $SOURCE_DIR"

# Kiểm tra xem thư mục nguồn có tồn tại không
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Thư mục $SOURCE_DIR không tồn tại!"
    exit 1
fi

# Đếm và hiển thị danh sách thư mục
echo -e "\nDanh sách các thư mục trong $SOURCE_DIR:"
folder_count=0
i=1
for folder in "$SOURCE_DIR"/*/; do
    if [ -d "$folder" ]; then
        folder_name=$(basename "$folder")
        echo "[$i] $folder_name"
        ((folder_count++))
        ((i++))
    fi
done

if [ $folder_count -eq 0 ]; then
    echo "Không tìm thấy thư mục nào trong $SOURCE_DIR"
    exit 1
fi

# Hiển thị menu lựa chọn
show_menu() {
    echo -e "\nVui lòng chọn cách thức nén:"
    echo "1. Nén tất cả thư mục thành một file zip duy nhất"
    echo "2. Nén riêng từng thư mục thành các file zip riêng biệt"
    echo "3. Chọn các thư mục để nén thành một file zip"
    echo "4. Chọn các thư mục để nén thành các file zip riêng biệt"
    echo "0. Thoát"
    echo -n "Lựa chọn của bạn (0-4): "
}

# Hàm để chọn nhiều thư mục
select_folders() {
    local -a folders=()
    local -A selected=()
    
    # Lưu danh sách thư mục vào mảng
    local i=1
    for folder in "$SOURCE_DIR"/*/; do
        if [ -d "$folder" ]; then
            local folder_name=$(basename "$folder")
            folders[$i]=$folder_name
            ((i++))
        fi
    done
    
    # Nhập các số thư mục muốn chọn
    echo -e "\nNhập số thứ tự các thư mục (cách nhau bởi dấu phẩy, ví dụ: 1,3,5): "
    read -r choices
    
    # Kiểm tra nếu người dùng không nhập gì
    if [[ -z "$choices" ]]; then
        echo "Không có thư mục nào được chọn."
        return 1
    fi
    
    # Xử lý input
    IFS=',' read -ra selected_numbers <<< "$choices"
    for num in "${selected_numbers[@]}"; do
        # Loại bỏ khoảng trắng
        num=$(echo "$num" | tr -d ' ')
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$i" ]; then
            selected[${folders[$num]}]=1
        fi
    done
    
    # Kiểm tra nếu không có thư mục nào được chọn hợp lệ
    if [ ${#selected[@]} -eq 0 ]; then
        echo "Không có thư mục nào được chọn hợp lệ."
        return 1
    fi
    
    # Hiển thị các thư mục đã chọn
    echo -e "\nCác thư mục đã chọn:"
    for folder in "${!selected[@]}"; do
        echo "  - $folder"
    done
    
    # Xác nhận lựa chọn
    echo -n "Xác nhận chọn các thư mục trên? (y/n): "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Đã hủy lựa chọn."
        return 1
    fi
    
    echo -e "\nBắt đầu quá trình nén..."
    echo "----------------------------------------"
    
    # Trả về danh sách thư mục đã chọn
    echo "${!selected[@]}"
    return 0
}

# Hàm hiển thị thanh tiến trình
show_progress() {
    local folder_name="$1"
    local current="$2"
    local total="$3"
    local width=50
    local progress=$((current * width / total))
    
    # Tạo thanh tiến trình
    printf "\r[%-${width}s] %d/%d - %s" \
           "$(printf '#%.0s' $(seq 1 $progress))" \
           "$current" "$total" "$folder_name"
}

# Sửa lại hàm nén tất cả thư mục thành một file
zip_all_to_one() {
    local zip_name="total.zip"
    local total_folders=0
    local current=0
    
    # Đếm tổng số thư mục
    for folder in "$SOURCE_DIR"/*/; do
        if [ -d "$folder" ]; then
            ((total_folders++))
        fi
    done
    
    echo -e "\nĐang nén tất cả thư mục thành $zip_name..."
    cd "$SOURCE_DIR" || exit 1
    
    # Nén từng thư mục và hiển thị tiến trình
    for folder in */; do
        if [ -d "$folder" ]; then
            ((current++))
            folder_name="${folder%/}"
            show_progress "$folder_name" "$current" "$total_folders"
            zip -q -r "$zip_name" "$folder" -x "*.zip"
        fi
    done
    
    echo -e "\nHoàn thành! File zip được lưu tại: $SOURCE_DIR/$zip_name"
    cd - > /dev/null || exit 1
}

# Sửa lại hàm nén từng thư mục riêng biệt
zip_individual() {
    local total_folders=0
    local current=0
    
    # Đếm tổng số thư mục
    for folder in "$SOURCE_DIR"/*/; do
        if [ -d "$folder" ]; then
            ((total_folders++))
        fi
    done
    
    echo -e "\nĐang nén từng thư mục riêng biệt..."
    
    for folder in "$SOURCE_DIR"/*/; do
        if [ -d "$folder" ]; then
            ((current++))
            folder_name=$(basename "$folder")
            show_progress "$folder_name" "$current" "$total_folders"
            zip -q -r "$SOURCE_DIR/$folder_name.zip" "$folder"
        fi
    done
    
    echo -e "\nHoàn thành! Các file zip được lưu tại: $SOURCE_DIR"
}

# Sửa lại hàm nén các thư mục đã chọn thành một file
zip_selected_to_one() {
    local selected_folders
    if ! selected_folders=$(select_folders); then
        return 1
    fi
    
    read -r -a folders_array <<< "$selected_folders"
    if [ ${#folders_array[@]} -eq 0 ]; then
        return 1
    fi
    
    local total_folders=${#folders_array[@]}
    echo -e "\nĐang nén ${total_folders} thư mục đã chọn..."
    
    # Xóa file zip cũ nếu tồn tại
    if [ -f "$SOURCE_DIR/selected.zip" ]; then
        rm "$SOURCE_DIR/selected.zip"
    fi
    
    # Nén trực tiếp các thư mục đã chọn
    cd "$SOURCE_DIR" || exit 1
    zip -q -r "selected.zip" "${folders_array[@]}"
    cd - > /dev/null || exit 1
    
    echo "Hoàn thành! File selected.zip đã được tạo tại: $SOURCE_DIR"
    return 0
}

# Sửa lại hàm nén các thư mục đã chọn thành các file riêng
zip_selected_individual() {
    local selected_folders
    if ! selected_folders=$(select_folders); then
        return 1
    fi
    
    read -r -a folders_array <<< "$selected_folders"
    if [ ${#folders_array[@]} -eq 0 ]; then
        return 1
    fi
    
    local total_folders=${#folders_array[@]}
    echo -e "\nĐang nén ${total_folders} thư mục thành các file zip riêng..."
    
    # Nén song song các thư mục
    for folder in "${folders_array[@]}"; do
        (cd "$SOURCE_DIR" && zip -q -r "$folder.zip" "$folder") &
    done
    
    # Đợi tất cả các tiến trình nén hoàn thành
    wait
    
    echo -e "\nHoàn thành! Các file zip đã được tạo:"
    for folder in "${folders_array[@]}"; do
        echo "  - $SOURCE_DIR/$folder.zip"
    done
    return 0
}

# Hàm kiểm tra và cài đặt zip
check_and_install_zip() {
    if ! command -v zip &> /dev/null; then
        echo "Lệnh 'zip' chưa được cài đặt."
        echo -n "Bạn có muốn cài đặt không? (y/n): "
        read -r install_choice
        
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            case "$OS_TYPE" in
                "Linux")
                    if command -v apt &> /dev/null; then
                        sudo apt update && sudo apt install -y zip
                    elif command -v yum &> /dev/null; then
                        sudo yum install -y zip
                    else
                        echo "Không thể tự động cài đặt. Vui lòng cài đặt 'zip' thủ công."
                        exit 1
                    fi
                    ;;
                "MINGW"*|"MSYS"*|"CYGWIN"*)
                    echo "Vui lòng cài đặt 'zip' bằng một trong các cách sau:"
                    echo ""
                    echo "=== Cách 1: Tải và cài đặt GnuWin32 Zip ==="
                    echo "1. Truy cập: https://sourceforge.net/projects/gnuwin32/files/zip/3.0/zip-3.0-setup.exe/download"
                    echo "2. Tải và cài đặt file zip-3.0-setup.exe"
                    echo "3. Thêm đường dẫn vào PATH:"
                    echo "   a. Nhấn Windows + R, gõ 'sysdm.cpl' và nhấn Enter"
                    echo "   b. Chọn tab 'Advanced' (Nâng cao)"
                    echo "   c. Click 'Environment Variables' (Biến môi trường)"
                    echo "   d. Trong phần 'System variables', tìm và chọn 'Path'"
                    echo "   e. Click 'Edit' (Chỉnh sửa)"
                    echo "   f. Click 'New' (Mới)"
                    echo "   g. Thêm đường dẫn: C:\\Program Files (x86)\\GnuWin32\\bin"
                    echo "   h. Nhấn OK để lưu tất cả các cửa sổ"
                    echo ""
                    echo "=== Cách 2: Tải trực tiếp file thực thi ==="
                    echo "1. Tạo thư mục:"
                    echo "   - Mở Command Prompt với quyền Administrator"
                    echo "   - Chạy lệnh: mkdir \"C:\\Program Files\\Git\\usr\\bin\""
                    echo ""
                    echo "2. Tải file zip.exe và unzip.exe:"
                    echo "   a. Truy cập: https://sourceforge.net/projects/gnuwin32/files/zip/3.0/zip-3.0-bin.zip/download"
                    echo "   b. Giải nén file zip-3.0-bin.zip"
                    echo "   c. Copy file zip.exe từ thư mục bin vào C:\\Program Files\\Git\\usr\\bin"
                    echo ""
                    echo "   d. Truy cập: https://sourceforge.net/projects/gnuwin32/files/unzip/5.51-1/unzip-5.51-1-bin.zip/download"
                    echo "   e. Giải nén file unzip-5.51-1-bin.zip"
                    echo "   f. Copy file unzip.exe từ thư mục bin vào C:\\Program Files\\Git\\usr\\bin"
                    echo ""
                    echo "=== Sau khi cài đặt ==="
                    echo "1. Đóng tất cả cửa sổ Git Bash đang mở"
                    echo "2. Mở Git Bash mới"
                    echo "3. Kiểm tra cài đặt bằng lệnh: zip --version"
                    echo "4. Nếu thấy thông tin phiên bản là đã cài đặt thành công"
                    echo "5. Chạy lại script này"
                    echo ""
                    exit 1
                    ;;
                *)
                    echo "Hệ điều hành không được hỗ trợ. Vui lòng cài đặt 'zip' thủ công."
                    exit 1
                    ;;
            esac
            
            if ! command -v zip &> /dev/null; then
                echo "Cài đặt không thành công. Vui lòng cài đặt 'zip' thủ công."
                exit 1
            else
                echo "Đã cài đặt 'zip' thành công!"
            fi
        else
            echo "Đã hủy. Script cần lệnh 'zip' để hoạt động."
            exit 1
        fi
    fi
}

# Thay thế đoạn kiểm tra zip cũ bằng hàm mới
check_and_install_zip

# Hiển thị menu và xử lý lựa chọn
while true; do
    show_menu
    read -r choice
    
    case $choice in
        0)
            echo "Thoát chương trình."
            exit 0
            ;;
        1)
            echo "Bắt đầu nén tất cả thư mục thành một file zip..."
            zip_all_to_one
            ;;
        2)
            echo "Bắt đầu nén từng thư mục thành các file zip riêng..."
            zip_individual
            ;;
        3)
            echo -e "\n=== Chọn các thư mục để nén thành một file zip ==="
            echo "- Bạn có thể nhập nhiều số, cách nhau bởi dấu phẩy (ví dụ: 1,3,5)"
            echo "- Nhấn Enter sau khi nhập xong"
            echo "- File zip sẽ được lưu với tên selected.zip"
            echo "----------------------------------------"
            zip_selected_to_one
            ;;
        4)
            echo -e "\n=== Chọn các thư mục để nén thành các file zip riêng ==="
            echo "- Bạn có thể nhập nhiều số, cách nhau bởi dấu phẩy (ví dụ: 1,3,5)"
            echo "- Nhấn Enter sau khi nhập xong"
            echo "- Mỗi thư mục sẽ được nén thành một file zip riêng"
            echo "----------------------------------------"
            zip_selected_individual
            ;;
        *)
            echo "Lựa chọn không hợp lệ. Vui lòng chọn lại."
            continue
            ;;
    esac
    
    # Nếu lựa chọn thành công và có nén file
    if [[ $choice =~ ^[1-4]$ ]]; then
        if [[ $? -eq 0 ]]; then
            echo -e "\nThao tác nén hoàn tất!"
            echo -n "Bạn có muốn tiếp tục không? (y/n): "
            read -r continue_choice
            [[ ! "$continue_choice" =~ ^[Yy]$ ]] && break
        else
            echo -e "\nĐã hủy thao tác nén."
            echo -n "Bạn có muốn thử lại không? (y/n): "
            read -r retry_choice
            [[ ! "$retry_choice" =~ ^[Yy]$ ]] && break
        fi
    fi
done

echo "Cảm ơn bạn đã sử dụng chương trình!"
