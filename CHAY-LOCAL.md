# Chạy dự án trên laptop bằng Visual Studio Code

Máy đã có sẵn: **VS Code**, **Node.js** (có `npx`) và **Git**. Không cần cài thêm gì.

---

## 1. Mở dự án trong VS Code

Chọn một trong ba cách:

- **Cách 1 (dễ nhất):** mở thư mục `C:\Users\hi\OneDrive\Desktop\Online Museum\3D Museum` trong File Explorer, chuột phải vào chỗ trống, chọn **Open with Code** (Windows 11: *Show more options → Open with Code*).
- **Cách 2:** mở VS Code từ menu Start, chọn **File → Open Folder…** (`Ctrl+K` rồi `Ctrl+O`) và chọn thư mục `3D Museum`.
- **Cách 3 (bằng lệnh):** mở PowerShell và gõ:

```powershell
code "C:\Users\hi\OneDrive\Desktop\Online Museum\3D Museum"
```

Lần đầu mở, nếu VS Code hỏi *Do you trust the authors…* thì chọn **Yes, I trust the authors**.

## 2. Chạy web trên máy (localhost)

Không mở thẳng `index.html` bằng cách nhấp đúp, vì trình duyệt sẽ chặn việc tải mô hình 3D và ảnh. Cần chạy một máy chủ nhỏ:

1. Trong VS Code, mở Terminal: nhấn **Ctrl + `** (phím ` nằm dưới phím Esc), hoặc chọn menu **Terminal → New Terminal**.
2. Gõ lệnh sau rồi nhấn Enter:

```powershell
npx http-server -p 5173 -c-1
```

   Lần đầu, máy hỏi `Ok to proceed? (y)`: gõ `y` rồi nhấn Enter.
3. Mở trình duyệt và vào **http://localhost:5173**
4. Sửa code xong thì nhấn **Ctrl+S** để lưu, rồi bấm **F5** trên trình duyệt để xem thay đổi.
5. Tắt máy chủ: bấm vào Terminal rồi nhấn **Ctrl+C** (hỏi *Terminate batch job* thì gõ `Y`).

> `-c-1` tắt bộ nhớ đệm, nên mỗi lần F5 luôn thấy bản mới nhất.
> Cổng 5173 đang bận thì đổi số khác, ví dụ `-p 8080`, và vào http://localhost:8080.

**Cách khác: tiện ích Live Server.** Nhấn `Ctrl+Shift+X`, tìm **Live Server** (tác giả Ritwick Dey) và bấm *Install*. Sau đó mở `index.html`, bấm **Go Live** ở góc phải dưới (hoặc `Alt+L` rồi `Alt+O`). Trang tự tải lại mỗi khi bạn lưu.

> ⚠️ Bản chạy trên máy dùng **dữ liệu thật** trên Supabase (lấy từ `config.js`). Thứ gì bạn tạo hoặc xoá ở localhost đều thay đổi trên web thật.

## 3. Đưa thay đổi lên GitHub (web tự cập nhật)

Gõ trong Terminal của VS Code, **từng lệnh một**. PowerShell trên máy này không hiểu `&&`.

```powershell
git pull
```

```powershell
git status
```

```powershell
git add -A
```

```powershell
git commit -m "Mô tả ngắn điều bạn đã sửa"
```

```powershell
git push
```

- `git pull`: lấy bản mới nhất về máy (nên chạy **trước khi** sửa, nhất là khi có sửa ở nơi khác, ví dụ Claude trên cloud).
- `git status`: xem những file đã thay đổi.
- `git add -A` rồi `git commit`: đóng gói thay đổi kèm một dòng mô tả.
- `git push`: đẩy lên GitHub. Vài phút sau web tự cập nhật.

Làm bằng chuột cũng được: nhấn `Ctrl+Shift+G` để mở **Source Control**, ghi mô tả vào ô *Message*, bấm **Commit**, rồi bấm **Sync Changes**.

## 4. Phím tắt VS Code hay dùng

| Phím | Việc |
|---|---|
| `Ctrl+P` | Mở nhanh file theo tên |
| `Ctrl+Shift+P` | Bảng lệnh: gõ tên lệnh bất kỳ |
| `Ctrl+S` | Lưu file |
| `Ctrl+Z` / `Ctrl+Y` | Hoàn tác / làm lại |
| `Ctrl+F` / `Ctrl+H` | Tìm / thay thế trong file |
| `Ctrl+Shift+F` | Tìm trong cả dự án |
| `Ctrl+G` | Nhảy tới dòng số… |
| `Ctrl+Shift+O` | Nhảy tới hàm trong file |
| `F12` | Nhảy tới chỗ khai báo hàm hoặc biến |
| `Ctrl+/` | Bật / tắt chú thích dòng |
| `Alt+↑` / `Alt+↓` | Đưa dòng lên / xuống |
| `Shift+Alt+↓` | Nhân bản dòng |
| `Ctrl+D` | Chọn thêm chữ giống nhau tiếp theo (sửa nhiều chỗ một lúc) |
| `Alt+Click` | Đặt nhiều con trỏ |
| `Shift+Alt+F` | Căn chỉnh lại code cho đẹp |
| `Ctrl+B` | Ẩn / hiện thanh bên |
| `Ctrl+Shift+E` | Danh sách file (Explorer) |
| `Ctrl+Shift+G` | Git (Source Control) |
| `Ctrl+Shift+X` | Cài tiện ích (Extensions) |
| `` Ctrl+` `` | Ẩn / hiện Terminal |
| ``Ctrl+Shift+` `` | Mở Terminal mới |
| `Ctrl+Shift+V` | Xem trước file Markdown (như file này) |
| `Ctrl+K` rồi `Ctrl+S` | Xem và đổi toàn bộ phím tắt |

## 5. Phím tắt trình duyệt khi kiểm tra web

| Phím | Việc |
|---|---|
| `F5` | Tải lại trang |
| `Ctrl+Shift+R` (hoặc `Ctrl+F5`) | Tải lại, bỏ qua bộ nhớ đệm |
| `F12` | Mở DevTools: xem lỗi ở thẻ *Console* |
| `Ctrl+Shift+M` (khi đang mở DevTools) | Giả lập màn hình điện thoại |

## 6. Các file chính

| File / thư mục | Nội dung |
|---|---|
| `index.html` | Toàn bộ web: giao diện, phòng 3D, tivi, radio… (dùng `Ctrl+Shift+O` để tìm hàm) |
| `config.js` | Địa chỉ Supabase, khoá anon, khoá YouTube (tuỳ chọn) |
| `supabase/schema.sql` | Cơ sở dữ liệu: chạy lại trong Supabase SQL Editor khi có thay đổi |
| `assets/` | Vân tường/sàn, mô hình 3D, đồ trong cửa hàng (`assets/shop/catalog.json`) |
| `version.json` | Số phiên bản: tăng lên khi đưa bản mới để người dùng được nhắc tải lại |
| `.github/workflows/` | Tác vụ tự động: “gõ cửa” Supabase 3 ngày một lần |
| `HUONG-DAN.md` | Hướng dẫn sử dụng và cài đặt |

## 7. Gặp lỗi thường gặp

- **`npx` không chạy / “not recognized”:** đóng hẳn VS Code rồi mở lại (để nhận Node.js). Vẫn lỗi thì cài Node.js LTS từ https://nodejs.org.
- **PowerShell báo “running scripts is disabled”:** chạy lệnh này một lần rồi thử lại:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

- **Trang trắng hoặc lỗi:** nhấn `F12`, mở thẻ **Console** và chụp dòng chữ đỏ gửi Claude.
- **`git push` bị từ chối (rejected):** chạy `git pull` trước rồi `git push` lại.
