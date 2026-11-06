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

- **Đèn từng tác phẩm:** nhấn vào tranh hoặc tủ kính, ở mục *Đèn chiếu tác phẩm* có thể bật/tắt, chỉnh độ sáng và màu ánh sáng (ấm 2700K đến ánh ngày 5000K). Công tắc **ĐÈN TRANH** trên tường trái, cạnh cửa vào, bật/tắt đèn của cả gian.
- **Xem mô hình:** nhấn vào tủ kính, chọn *Xem cận cảnh*, rồi kéo chuột để xoay mô hình và cuộn chuột để lại gần. Mô hình có chuyển động thì bật/tắt được.
- **Cửa hàng:** bấm *Cửa hàng* để mua cây cảnh, tượng, nội thất và mô hình 3D bằng **xu ảo** (mỗi người có 2.000 xu để dùng thử, chưa thanh toán thật). Mua xong thì kéo đồ vật đến chỗ muốn đặt.

- **Tham quan cùng nhau:** mỗi người vào phòng là một nhân vật LEGO. Bấm *Nhân vật* để chọn áo, quần, tóc và nét mặt. Phím **V** đổi sang góc nhìn thứ ba, **Enter** để trò chuyện, **1 / 2 / 3** để vẫy tay, nhảy, nhảy múa. Bấm vào người khác để tặng hoa, thả tim hoặc vẫy tay chào.
- **Cảm nhận:** dưới mỗi tác phẩm và ở nút *Gian này* (góc phải) có 5 cảm xúc, chấm 1–5 sao và nút *Ủng hộ* bằng xu. Khách không cần tài khoản vẫn thả tim và chấm sao được; muốn ủng hộ xu thì cần đăng nhập.
- **Ví xu:** mỗi tài khoản có 2.000 xu ảo lúc bắt đầu (lưu trên Supabase). Xu dùng để mua đồ và giao diện trong cửa hàng, mua vé vào phòng thu phí, và ủng hộ chủ phòng. Chưa có thanh toán bằng tiền thật.
- **Giao diện theo mùa và lễ hội:** Halloween, Giáng sinh, Mùa xuân, Mùa thu, Mùa đông, Trung thu, Sinh nhật, Diwali, Holi, Hanami, Día de Muertos, Ramadan & Eid, Hanukkah, Phục sinh, Carnival Rio, Đêm Giao thừa, Thánh Patrick, Songkran, Yi Peng được bán trong cửa hàng. Mỗi giao diện mua một lần, dùng cho mọi gian. Tám giao diện gốc vẫn miễn phí.
- **Ai được xem:** trong *Chia sẻ*, chủ phòng chọn *Ai có link*, *Có mật khẩu*, *Thu phí* (khách trả xu một lần để vào, xu chuyển cho chủ phòng) hoặc *Thành viên*.
- **Mô hình nặng:** web tự nén `.glb` lớn hơn 2,5 MB trước khi tải lên (ví dụ 23 MB còn 2,4 MB). Mô hình đã lưu từ trước mà nặng thì nhấn vào nó rồi chọn *Tối ưu mô hình*.

- **Kho đồ:** đồ mua trong cửa hàng được cất vào *Kho đồ*. Từ kho có thể đặt đồ vào gian, cho mô hình vào tủ kính (hoặc nhấn vào tủ kính rồi chọn *Từ Kho đồ*), hay tặng cho người khác bằng tên đăng nhập. Tủ kính trong kho luôn miễn phí, không giới hạn số lượng.
- **Sắp xếp:** đồ vật không chồng lên nhau, không lọt vào tường; đồ nhỏ đặt được lên quầy hoa. Bấm vào đồ đã đặt để chỉnh lại; *Cất vào kho* để thu hồi, *Bỏ* để xoá. Tủ kính mặc định cũng di chuyển, thu hồi hoặc bỏ được (đồ bên trong về kho).
- **Lì xì:** chủ phòng bấm *Lì xì*, chọn tổng xu, số bao (1–50) và thời gian nhận (1 phút đến 1 ngày). Bao lì xì đỏ bay khắp gian; khách đăng nhập bấm vào để bắt, mỗi người một bao, số xu ngẫu nhiên. Chủ phòng xem các đợt đang phát và bấm *Thu hồi* bất cứ lúc nào; hết giờ, xu chưa ai bắt tự về lại ví chủ phòng.

## Thêm mô hình vào cửa hàng (ví dụ từ Pixabay)

1. Vào https://pixabay.com/3d-models/search/glb/, chọn mô hình rồi tải về định dạng **GLB**.
2. Chép tệp `.glb` vào thư mục `assets/shop/`. Nên đặt tên không dấu, không khoảng trắng, ví dụ `ghe-go.glb`.
3. Mở `assets/shop/catalog.json` và thêm một mục:

```json
{ "file": "ghe-go.glb", "name": "Ghế gỗ cổ điển", "desc": "Ghế gỗ chạm khắc", "price": 300, "height": 0.9 }
```

`height` là chiều cao thật của đồ vật, tính bằng mét. Muốn có ảnh minh hoạ thì thêm `"thumb": "ghe-go.jpg"` và chép ảnh vào cùng thư mục.

4. Đưa thay đổi lên GitHub. Web tự cập nhật.

> Giấy phép Pixabay cho phép dùng mô hình miễn phí trong dự án, nhưng **không** cho bán lại chính tệp mô hình. Khi làm thanh toán thật, chỉ nên thu tiền cho dịch vụ trưng bày, không bán tệp gốc. Ghi nguồn tác giả là việc nên làm.
> Mô hình nên nhỏ hơn 10 MB để khách tải nhanh.

## Cập nhật cơ sở dữ liệu

Bản này thêm cột `lights` để lưu cài đặt đèn. Mở Supabase, vào **SQL Editor**, chạy lại toàn bộ tệp `supabase/schema.sql`. Chạy lại không làm mất dữ liệu.

## Lưu ý

- **Quên mật khẩu:** vì không dùng email, người dùng không tự đặt lại được. Chủ dự án vào Supabase, mục **Authentication → Users**, chọn người dùng rồi chọn **Send password recovery** hoặc đặt mật khẩu mới.
- **Giới hạn gói miễn phí của Supabase:** 1 GB lưu trữ ảnh/video, mỗi tệp tối đa 50 MB, cơ sở dữ liệu 500 MB. Video dài nên nén trước khi tải lên.
- **Mô hình 3D:** dùng tệp `.glb`, tối đa 50 MB. Hỗ trợ cả mô hình nén *Draco* và *Meshopt*. Trong lúc web báo "Đang tải lên…", đừng đóng trang. Nếu đóng sớm, tệp chưa kịp lưu sẽ mất (web sẽ hỏi lại trước khi đóng).
- **Tạm dừng:** dự án Supabase miễn phí tự tạm dừng sau 7 ngày không có ai truy cập. Vào trang Supabase bấm *Restore* là chạy lại, dữ liệu vẫn còn.
- **Chế độ dùng thử:** để trống `config.js` thì trang chạy ở chế độ dùng thử. Không cần đăng nhập, nhưng ảnh chỉ tồn tại trong tab đang mở.

## Nguồn tài nguyên

Vân tường, sàn (White Plaster 02, Marble 01, Concrete Floor 02, Herringbone Parquet) và ảnh HDRI *Museum of Ethnography* lấy từ [Poly Haven](https://polyhaven.com), giấy phép CC0 (dùng tự do). Các tệp nằm trong `assets/polyhaven/`.

Mô hình cây cảnh, sofa, ghế bành, tượng, bình gốm, đèn chùm… trong `assets/polyhaven/models/` cũng lấy từ Poly Haven (CC0), đã nén lại bằng gltf-transform. Vân đá cẩm thạch, travertine, gỗ óc chó trong `assets/ambientcg/` lấy từ [ambientCG](https://ambientcg.com) (Marble012, Marble016, Travertine009, Wood066), giấy phép CC0.

## Tính năng mới (06/11/2026)

- **Thanh menu:** luôn hiện đủ nút (máy tính: xuống hàng khi chật; điện thoại: dạng lưới). Bấm nút đầu tiên (hoặc phím **H**) để thu gọn thành một nút nhỏ. Điện thoại mặc định thu gọn.
- **Tivi và radio có sẵn trong mỗi gian:** tivi trên tường bên phải giữa hai bức tranh, radio trên quầy hoa. Chủ phòng di chuyển hoặc cất vào kho trong *Sắp xếp*.
- **Điện thoại:** Cài đặt → *Điện thoại* thay cho phím tắt: đổi bên đặt cần điều khiển, tốc độ vuốt nhìn.
- **Cài đặt (nút bánh răng ⚙ góc trên):** thẻ *Hướng dẫn* giải thích mọi thao tác và nút; thẻ *Phím tắt* cho đổi phím (lưu trên từng trình duyệt); thẻ *Tài khoản & bảo mật* để đổi mật khẩu, gắn email, đăng xuất các thiết bị khác.
- **Một tài khoản, một nhân vật:** khi cùng tài khoản vào phòng từ nơi khác, nhân vật ở thiết bị cũ rời phòng và hiện thông báo.
- **Tivi treo tường:** thêm trong *Sắp xếp* hoặc mua trong *Cửa hàng*. Nhấn vào tivi, dán link YouTube, chọn *Loa tivi* (gần to, xa nhỏ) hoặc *Loa cả phòng*. Mỗi người xem tự phát trên máy mình.
- **Radio cổ:** nhấn vào radio, tải lên bài nhạc mp3/m4a/wav hoặc video mp4 (tối đa 50 MB), chỉnh âm lượng, loa và lặp lại.
- **Giao diện theo mùa** giờ chỉ bán trong nút *Giao diện*, không lặp lại trong *Cửa hàng*.

### Về xác nhận email

- Đổi mật khẩu, quên mật khẩu (với tài khoản đã có email) và đăng xuất thiết bị khác dùng được ngay.
- Supabase của dự án đang **tắt** *Confirm email* (vì tài khoản đăng ký bằng tên đăng nhập dùng email ảo). Khi tắt, email gắn vào tài khoản được ghi nhận ngay mà **không** qua bước bấm liên kết trong thư; web sẽ báo rõ điều này.
- Muốn xác nhận email thật cần: (1) gắn dịch vụ gửi thư ở **Authentication → Emails → SMTP Settings** (Resend, Brevo… có gói miễn phí; máy chủ thư mặc định của Supabase chỉ gửi cho thành viên dự án), (2) đặt *Site URL* ở **Authentication → URL Configuration** là địa chỉ web, (3) đổi cách đăng ký sang dùng email thật, rồi mới bật *Confirm email* và tắt *Secure email change*. Đừng bật *Confirm email* trước bước (3), nếu không người mới sẽ không đăng ký được.
