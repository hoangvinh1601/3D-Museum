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

## 3. Đẩy code mới lên GitHub (web tự cập nhật)

Máy đã cài sẵn tên, email và đăng nhập GitHub cho Git (tài khoản `hoangvinh1601`), nên không cần cài đặt gì thêm.

### Quy trình mỗi lần sửa

```
① git pull  →  ② sửa code + thử ở localhost  →  ③ tăng số phiên bản  →  ④ add + commit  →  ⑤ push  →  ⑥ kiểm tra web
```

**① Lấy bản mới nhất về máy, TRƯỚC khi sửa.** Việc này quan trọng khi có người khác (hoặc Claude trên cloud) vừa sửa:

```powershell
git pull
```

**② Sửa code**, nhấn `Ctrl+S` để lưu, rồi thử ở http://localhost:5173 (xem mục 2).

**③ Tăng số phiên bản** để ai đang mở web được nhắc *“Có bản cập nhật mới”*. Phải sửa **cả hai chỗ và giống hệt nhau**:
- `version.json`: ví dụ `{ "build": "2026-11-07.1" }`
- `index.html`: nhấn `Ctrl+F`, tìm `const BUILD =` và đổi thành `const BUILD = '2026-11-07.1';`

Cách đặt số: `năm-tháng-ngày.số lần`. Ví dụ hôm nay đưa lần thứ hai thì ghi `2026-11-07.2`.

**④ Xem đã sửa những gì, rồi đóng gói thay đổi.** Gõ **từng lệnh một**, vì PowerShell trên máy này không hiểu `&&`:

```powershell
git status
```

```powershell
git add -A
```

```powershell
git commit -m "Tivi to hơn, sửa lỗi menu trên điện thoại"
```

Câu trong ngoặc kép là mô tả ngắn điều bạn đã sửa, gõ tiếng Việt có dấu được.

**⑤ Đẩy lên GitHub:**

```powershell
git push
```

**⑥ Kiểm tra web đã lên bản mới chưa:**
- Vào https://github.com/hoangvinh1601/3D-Museum/actions. Dòng *pages build and deployment* mới nhất có **dấu tích xanh** là xong, thường mất 1–5 phút. **Dấu X đỏ** là GitHub bị lỗi: bấm vào dòng đó → **Re-run all jobs**.
- Hoặc mở https://hoangvinh1601.github.io/3D-Museum/version.json: thấy số phiên bản mới là web đã cập nhật.
- Mở web rồi nhấn `Ctrl+F5` để tải bản mới nhất.

### Làm bằng chuột trong VS Code (không cần gõ lệnh)

1. Nhấn `Ctrl+Shift+G` (hoặc biểu tượng nhánh cây ở thanh bên trái) để mở **Source Control**.
2. Bấm **⟳ Sync Changes** (hoặc biểu tượng **⋯ → Pull**) để lấy bản mới nhất về trước khi sửa.
3. Sửa xong, danh sách **Changes** hiện các file đã đổi. Bấm vào từng file để xem trước/sau: chữ đỏ là phần bỏ đi, chữ xanh là phần thêm vào.
4. Ghi mô tả vào ô **Message** phía trên, rồi bấm **✓ Commit**. Nếu VS Code hỏi *“There are no staged changes… stage all?”* thì chọn **Yes** (hoặc **Always**).
5. Bấm **⟳ Sync Changes** (hoặc **Publish / Push**) để đẩy lên GitHub.

### Khi gặp sự cố

| Thông báo | Cách xử lý |
|---|---|
| `rejected … fetch first` khi `git push` | Trên GitHub đã có thay đổi mới hơn. Chạy `git pull` rồi `git push` lại. |
| `CONFLICT (content): Merge conflict in index.html` | Hai nơi cùng sửa một chỗ. Mở file đó trong VS Code, bấm **Accept Current** (giữ bản của bạn), **Accept Incoming** (giữ bản trên GitHub) hoặc **Accept Both**. Lưu lại, rồi chạy `git add -A`, `git commit -m "Gộp thay đổi"` và `git push`. Không chắc thì nhờ Claude. |
| `nothing to commit, working tree clean` | Chưa có gì thay đổi: kiểm tra đã `Ctrl+S` lưu file chưa. |
| Lần đầu `git push` hiện cửa sổ đăng nhập GitHub | Chọn **Sign in with your browser** và đăng nhập tài khoản `hoangvinh1601`. |
| Lỡ sửa hỏng, muốn bỏ hết thay đổi **chưa commit** của một file | `git restore index.html` (thay tên file). ⚠️ Thay đổi chưa commit của file đó sẽ mất. |
| Muốn xem lịch sử các lần đẩy | `git log --oneline -10` (nhấn `q` để thoát). |

> Đừng đẩy lên mật khẩu hay khoá bí mật (ví dụ khoá *service_role* của Supabase). `config.js` chỉ được chứa khoá **anon public** và khoá YouTube đã giới hạn theo tên miền.

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
