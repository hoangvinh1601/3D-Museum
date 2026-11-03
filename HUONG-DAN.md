# Phòng Trưng Bày 3D: hướng dẫn đưa lên mạng

Bộ mã này là một trang web tĩnh, gồm 3 tệp chính: `index.html`, `config.js` và `supabase/schema.sql`. Tài khoản, dữ liệu và ảnh được lưu trên **Supabase** (gói miễn phí). Trang web được đưa lên **Netlify** (miễn phí).

Làm một lần, mất khoảng 15 phút.

---

## Bước 1: Tạo dự án Supabase

1. Vào https://supabase.com, đăng nhập (dùng tài khoản GitHub hoặc Google) rồi bấm **New project**.
2. Đặt tên, ví dụ `phong-trung-bay`. Đặt mật khẩu cơ sở dữ liệu (lưu lại ở đâu đó). Chọn vùng **Southeast Asia (Singapore)**.
3. Chờ khoảng 1–2 phút để dự án khởi tạo xong.

## Bước 2: Tạo cơ sở dữ liệu

1. Mở menu trái, chọn **SQL Editor**, rồi bấm **New query**.
2. Mở tệp `supabase/schema.sql`, chép toàn bộ nội dung, dán vào ô soạn thảo và bấm **Run**.
3. Thấy dòng *Success. No rows returned* là xong.

Lệnh này tạo các bảng tài khoản, phòng trưng bày, thành viên, gian và tác phẩm. Nó cũng tạo kho ảnh `media` và cài sẵn quy tắc bảo mật: chỉ thành viên mới sửa được; khách chỉ xem được khi có link.

## Bước 3: Cho phép đăng nhập bằng tên + mật khẩu

1. Mở **Authentication → Sign In / Providers → Email**.
2. **Tắt** mục **Confirm email** rồi bấm **Save**. Bắt buộc phải tắt, vì người dùng đăng ký bằng tên đăng nhập chứ không cần email thật.
3. Kiểm tra mục **Allow new users to sign up** đang bật.

## Bước 4: Điền khoá kết nối vào `config.js`

1. Mở **Project Settings → Data API** (hoặc **API Keys**).
2. Chép **Project URL** và khoá **anon public**.
3. Mở `config.js` và điền vào hai dòng như sau:

```js
window.GALLERY_CONFIG = {
  supabaseUrl: 'https://xxxxxxxx.supabase.co',
  supabaseAnonKey: 'eyJhbGciOi...'
};
```

> Khoá *anon public* được phép để lộ trên trang web, dữ liệu vẫn được bảo vệ bằng các quy tắc ở Bước 2.
> **Tuyệt đối không** dán khoá *service_role* vào đây.

## Bước 5: Đưa trang lên mạng

**Cách nhanh nhất: Netlify Drop**

1. Vào https://app.netlify.com/drop.
2. Kéo thả **cả thư mục** chứa `index.html` và `config.js` vào trang.
3. Netlify cấp ngay một địa chỉ dạng `https://ten-ngau-nhien.netlify.app`. Bạn có thể đổi tên trong **Site settings**.

Mỗi lần sửa `config.js` hoặc cập nhật bản mới, chỉ cần kéo thả lại thư mục vào mục **Deploys** của site đó.

Dùng Vercel hoặc GitHub Pages cũng được, vì đây chỉ là các tệp tĩnh.

---

## Cách dùng

- **Tạo tài khoản:** mở trang web, chọn *Tạo tài khoản*, nhập tên đăng nhập và mật khẩu. Một phòng trưng bày được tạo sẵn cho bạn.
- **Trưng bày:** bấm *Tải lên* để chọn ảnh, video (treo tường), ảnh chụp hoặc mô hình `.glb` (tủ kính) hay ảnh bìa (kệ sách). Nhấn vào từng tác phẩm để điền **tên, tác giả, năm và câu chuyện**.
- **Sắp xếp:** bấm *Sắp xếp* để kéo cây, ghế, tủ kính trên sàn. Có thể xoay, phóng to, nhân bản, xoá hoặc thêm đồ vật mới (cây mai, đào, đèn cây, tượng, thảm…).
- **Nhiều gian:** khi hết chỗ, trang hỏi để *mở gian mới*. Đi qua cửa cuối gian để sang gian tiếp theo.
- **Cùng quản lý:** chủ phòng bấm *Chia sẻ* rồi *Mời* bằng **tên đăng nhập** của người kia (người đó cần tạo tài khoản trước). Thành viên được tải lên, sửa thông tin, sắp xếp và mở gian mới; thay đổi hiện ngay trên máy của mọi người.
- **Chia sẻ cho khách:** bấm *Chia sẻ*, rồi *Sao chép* link. Khách mở link là xem được, không cần tài khoản. Chọn *Chỉ thành viên* nếu muốn để riêng tư.

## Lưu ý

- **Quên mật khẩu:** vì không dùng email, người dùng không tự đặt lại được. Chủ dự án vào Supabase, mục **Authentication → Users**, chọn người dùng rồi chọn **Send password recovery** hoặc đặt mật khẩu mới.
- **Giới hạn gói miễn phí của Supabase:** 1 GB lưu trữ ảnh/video, mỗi tệp tối đa 50 MB, cơ sở dữ liệu 500 MB. Video dài nên nén trước khi tải lên.
- **Mô hình 3D:** dùng tệp `.glb`. Khi xuất từ Blender, hãy tắt nén *Draco*.
- **Tạm dừng:** dự án Supabase miễn phí tự tạm dừng sau 7 ngày không có ai truy cập. Vào trang Supabase bấm *Restore* là chạy lại, dữ liệu vẫn còn.
- **Chế độ dùng thử:** để trống `config.js` thì trang chạy ở chế độ dùng thử. Không cần đăng nhập, nhưng ảnh chỉ tồn tại trong tab đang mở.

## Nguồn tài nguyên

Vân tường, sàn (White Plaster 02, Marble 01, Concrete Floor 02, Herringbone Parquet) và ảnh HDRI *Museum of Ethnography* lấy từ [Poly Haven](https://polyhaven.com), giấy phép CC0 (dùng tự do). Các tệp nằm trong `assets/polyhaven/`.
