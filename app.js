require('dotenv').config();
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const archiver = require('archiver');
const os = require('os');
const nodemailer = require('nodemailer');

// Tạo interface để đọc input từ người dùng
const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

// Hàm để convert đường dẫn Windows sang Unix
function convertPath(inputPath) {
    inputPath = inputPath.replace(/["']/g, '');
    
    if (process.platform === 'win32') {
        // Chuyển đổi đường dẫn Windows sang Unix
        return inputPath.replace(/\\/g, '/');
    }
    return inputPath;
}

// Hàm chuẩn hóa đường dẫn
function normalizePath(inputPath) {
    if (inputPath.startsWith('~')) {
        inputPath = inputPath.replace('~', os.homedir());
    }
    
    if (!path.isAbsolute(inputPath)) {
        inputPath = path.join(process.cwd(), inputPath);
    }
    
    return inputPath;
}

// Hàm hiển thị tiến trình
function showProgress(folderName, current, total) {
    const width = 50;
    const progress = Math.floor((current * width) / total);
    const bar = '#'.repeat(progress) + ' '.repeat(width - progress);
    process.stdout.write(`\r[${bar}] ${current}/${total} - ${folderName}`);
}

// Hàm để lấy danh sách thư mục
function getFolders(sourceDir) {
    try {
        return fs.readdirSync(sourceDir)
            .filter(item => fs.statSync(path.join(sourceDir, item)).isDirectory());
    } catch (err) {
        console.error('Lỗi khi đọc thư mục:', err);
        return [];
    }
}

// Hàm nén một thư mục
function zipFolder(sourcePath, outputPath) {
    return new Promise((resolve, reject) => {
        const output = fs.createWriteStream(outputPath);
        const archive = archiver('zip', { zlib: { level: 9 } });
        
        output.on('close', async () => {
            // Gửi email thông báo ngay khi nén xong một folder
            await sendNotificationEmail(outputPath);
            resolve();
        });
        archive.on('error', reject);
        
        archive.pipe(output);
        archive.directory(sourcePath, path.basename(sourcePath));
        archive.finalize();
    });
}

// Hàm nén tất cả thư mục thành một file
async function zipAllToOne(sourceDir, folders) {
    const zipPath = path.join(sourceDir, 'total.zip');
    const output = fs.createWriteStream(zipPath);
    const archive = archiver('zip', { zlib: { level: 9 } });
    
    return new Promise((resolve, reject) => {
        output.on('close', async () => {
            await sendNotificationEmail(zipPath);
            resolve();
        });
        archive.on('error', reject);
        
        archive.pipe(output);
        
        folders.forEach((folder, index) => {
            const folderPath = path.join(sourceDir, folder);
            showProgress(folder, index + 1, folders.length);
            archive.directory(folderPath, folder);
        });
        
        archive.finalize();
    });
}

// Hàm nén từng thư mục riêng biệt
async function zipIndividual(sourceDir, folders) {
    for (let i = 0; i < folders.length; i++) {
        const folder = folders[i];
        const folderPath = path.join(sourceDir, folder);
        const zipPath = path.join(sourceDir, `${folder}.zip`);
        
        showProgress(folder, i + 1, folders.length);
        await zipFolder(folderPath, zipPath);
        // Đã chuyển việc gửi email vào trong hàm zipFolder
    }
}

// Hàm chọn thư mục
async function selectFolders(folders) {
    console.log('\nDanh sách các thư mục:');
    folders.forEach((folder, index) => {
        console.log(`[${index + 1}] ${folder}`);
    });
    
    return new Promise((resolve) => {
        rl.question('\nNhập số thứ tự các thư mục (cách nhau bởi dấu phẩy, ví dụ: 1,3,5): ', (answer) => {
            const selected = answer.split(',')
                .map(num => num.trim())
                .filter(num => !isNaN(num) && num > 0 && num <= folders.length)
                .map(num => folders[num - 1]);
            
            if (selected.length === 0) {
                console.log('Không có thư mục nào được chọn hợp lệ.');
                resolve([]);
                return;
            }
            
            console.log('\nCác thư mục đã chọn:');
            selected.forEach(folder => console.log(`  - ${folder}`));
            
            rl.question('Xác nhận chọn các thư mục trên? (y/n): ', (confirm) => {
                resolve(confirm.toLowerCase() === 'y' ? selected : []);
            });
        });
    });
}

// Hàm chuyển đổi dung lượng sang định dạng đọc được
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Cập nhật hàm gửi email
async function sendNotificationEmail(zipPath) {
    const folderName = path.basename(zipPath, '.zip');
    
    // Lấy dung lượng file zip
    const stats = fs.statSync(zipPath);
    const fileSize = formatFileSize(stats.size);
    
    const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
            user: process.env.EMAIL_USER || 'your-email@gmail.com',
            pass: process.env.EMAIL_PASS || 'your-app-password'
        }
    });

    const mailOptions = {
        from: process.env.EMAIL_USER || 'your-email@gmail.com',
        to: process.env.EMAIL_TO || 'recipient@email.com',
        subject: `Thông báo: Đã nén xong thư mục ${folderName}`,
        text: `Thư mục "${folderName}" đã được nén thành công.\nĐường dẫn file zip: ${zipPath}\nDung lượng: ${fileSize}`,
        html: `
            <h3>Thông báo nén file hoàn tất</h3>
            <p>Thư mục <strong>"${folderName}"</strong> đã được nén thành công.</p>
            <p>Đường dẫn file zip:</p>
            <p><strong>${zipPath}</strong></p>
            <p>Dung lượng: <strong>${fileSize}</strong></p>
        `
    };

    try {
        await transporter.sendMail(mailOptions);
        console.log(` - Đã gửi email thông báo cho thư mục ${folderName} (${fileSize})`);
    } catch (error) {
        console.error(' - Lỗi khi gửi email:', error);
    }
}

// Hàm chính
async function main() {
    try {
        const answer = await new Promise((resolve) => {
            rl.question('Vui lòng nhập đường dẫn đến thư mục cần nén: ', resolve);
        });
        
        let sourceDir = convertPath(answer);
        sourceDir = normalizePath(sourceDir);
        
        if (!fs.existsSync(sourceDir) || !fs.statSync(sourceDir).isDirectory()) {
            console.log('Thư mục không tồn tại!');
            rl.close();
            return;
        }
        
        const folders = getFolders(sourceDir);
        if (folders.length === 0) {
            console.log('Không tìm thấy thư mục nào!');
            rl.close();
            return;
        }
        
        while (true) {
            console.log('\nVui lòng chọn cách thức nén:');
            console.log('1. Nén tất cả thư mục thành một file zip duy nhất');
            console.log('2. Nén riêng từng thư mục thành các file zip riêng biệt');
            console.log('3. Chọn các thư mục để nén thành một file zip');
            console.log('4. Chọn các thư mục để nén thành các file zip riêng biệt');
            console.log('0. Thoát');
            
            const choice = await new Promise((resolve) => {
                rl.question('Lựa chọn của bạn (0-4): ', resolve);
            });
            
            switch (choice) {
                case '0':
                    console.log('Thoát chương trình.');
                    rl.close();
                    return;
                    
                case '1':
                    console.log('\nBắt đầu nén tất cả thư mục...');
                    await zipAllToOne(sourceDir, folders);
                    break;
                    
                case '2':
                    console.log('\nBắt đầu nén từng thư mục riêng biệt...');
                    await zipIndividual(sourceDir, folders);
                    break;
                    
                case '3':
                    const selectedFolders1 = await selectFolders(folders);
                    if (selectedFolders1.length > 0) {
                        await zipAllToOne(sourceDir, selectedFolders1);
                    }
                    break;
                    
                case '4':
                    const selectedFolders2 = await selectFolders(folders);
                    if (selectedFolders2.length > 0) {
                        await zipIndividual(sourceDir, selectedFolders2);
                    }
                    break;
                    
                default:
                    console.log('Lựa chọn không hợp lệ. Vui lòng chọn lại.');
                    continue;
            }
            
            const continueAnswer = await new Promise((resolve) => {
                rl.question('\nBạn có muốn tiếp tục không? (y/n): ', resolve);
            });
            
            if (continueAnswer.toLowerCase() !== 'y') {
                break;
            }
        }
        
        console.log('Cảm ơn bạn đã sử dụng chương trình!');
        rl.close();
        
    } catch (error) {
        console.error('Đã xảy ra lỗi:', error);
        rl.close();
    }
}

// Chạy chương trình
main(); 