# Lab 06 — Teardrop Attack (Overlapping IP Fragments)

**Phụ trách:** Hạnh · **Thời lượng:** ~75 phút · **Mức độ:** Trung bình

> ⚠️ **Cảnh báo pháp lý.** Bài này chỉ được thực hiện trong **phòng lab cô lập** (máy ảo +
> network namespace trên chính máy của bạn). Mọi kỹ thuật ở đây thuộc nhóm tấn công mạng; áp dụng
> lên hệ thống/mạng không thuộc quyền sở hữu hoặc không được phép bằng văn bản là **vi phạm pháp
> luật** (Luật An ninh mạng 2018 — Luật số 24/2018/QH14, và Bộ luật Hình sự). Mục tiêu là hiểu cơ
> chế để **phòng thủ** (defensive security).

---

## 1. Mục tiêu

- Hiểu cơ chế **phân mảnh & tái hợp IP** (fragmentation/reassembly) và trường **fragment offset**.
- Chế tạo các **mảnh IP chồng lấn** (overlapping fragments) đặc trưng của Teardrop bằng Scapy.
- Quan sát **kernel hiện đại xử lý an toàn — không crash**, chứng minh vì sao hệ thống đã miễn nhiễm.

## 2. Kiến thức nền

- Gói IP lớn bị chia thành nhiều mảnh; mỗi mảnh mang **fragment offset** (đơn vị **8 byte**) để bên nhận ghép lại đúng thứ tự.
- **Teardrop** gửi các mảnh có offset **chồng lấn/sai lệch**. Code tái hợp lỗi của hệ cũ tính ra **độ dài âm** ⇒ crash (Windows 3.1/95/NT, Linux < 2.0.32).
- Kernel hiện đại **kiểm tra biên chặt** (vá từ ~1998) nên **không còn crash** — đây chính là điều lab muốn kiểm chứng.

> 📌 Khác với một số lab khác, Teardrop **không còn gây hại** trên hệ thống cập nhật. "Kết quả" của
> bài là **chứng minh sự miễn nhiễm**: victim vẫn sống, kernel chỉ loại bỏ mảnh xấu.

---

## 3. Môi trường (VMware Workstation)

- **1 máy ảo Kali Linux** trên VMware Workstation.
- Mô hình 2 máy (attacker/victim) mô phỏng bằng **network namespace + veth *bên trong* VM** → **không cần cấu hình mạng VMware**.
- Cần **root** (`sudo`), có sẵn `scapy`, `tcpdump`.

```bash
sudo apt update && sudo apt install -y python3-scapy tcpdump
```

### Sơ đồ topo

```
   h1 (attacker)  veth1 ──────── veth2  h2 (victim)
   10.0.0.1                             10.0.0.2
```

### Danh sách file

| File | Vai trò |
|------|---------|
| `setup_pair.sh`  | Dựng 2 namespace h1/h2 nối bằng veth |
| `health_check.sh`| In bộ đếm tái hợp mảnh (ReasmReqds/OKs/Fails) của victim |
| `teardrop.py`    | Gửi các cặp mảnh IP chồng lấn (Scapy) |
| `cleanup.sh`     | Xóa namespace |

---

## 4. Các bước thực hiện

> Cần **2–3 terminal** trong VM. Mở "máy" bằng: `sudo ip netns exec <ns> bash`.

### Bước 0 — Cấp quyền chạy

```bash
cd lab06-teardrop
chmod +x *.sh teardrop.py
# Nếu lỗi "bad interpreter" do CRLF: sudo apt install -y dos2unix && dos2unix *.sh teardrop.py
```

### Bước 1 — Dựng topo

```bash
sudo bash setup_pair.sh        # tự ping thử h1 -> h2
```

### Bước 2 — Ghi nhận "sức khỏe" victim trước tấn công

```bash
sudo bash health_check.sh      # ghi lại con số ReasmFails hiện tại
```

### Bước 3 — Mở ping nền để theo dõi victim còn "sống" *(Terminal A — giữ chạy)*

```bash
sudo ip netns exec h2 ping -i 0.3 10.0.0.1
```

### Bước 4 — Gửi mảnh IP chồng lấn *(Terminal B — attacker)*

```bash
sudo ip netns exec h1 python3 teardrop.py            # gửi 1 cặp mảnh
# Gây "áp lực" hơn (vẫn an toàn) để thấy ReasmFails tăng rõ:
sudo ip netns exec h1 python3 teardrop.py --rounds 100
```

### Bước 5 — Quan sát & kết luận

```bash
# (tuỳ chọn) Bắt gói tại victim để thấy các mảnh IP (flag MF, offset):
sudo ip netns exec h2 tcpdump -i veth2 -nn -v ip

# Thống kê lại sau tấn công — ReasmFails thường TĂNG:
sudo bash health_check.sh

# Kiểm tra nhật ký kernel — KHÔNG có crash/panic:
sudo ip netns exec h2 dmesg | tail
```

**✔ Kết quả mong đợi:** Terminal A (ping nền) cho thấy victim **vẫn phản hồi bình thường** suốt quá
trình. Thống kê có thể ghi nhận **ReasmFails tăng** (kernel phát hiện mảnh xấu và loại bỏ), nhưng
**không có crash**. Kết luận: kernel hiện đại miễn nhiễm Teardrop nhờ kiểm tra biên khi tái hợp.

### Bước 6 — Dọn dẹp

```bash
sudo bash cleanup.sh
```

---

## 5. Phòng chống (Mitigation)

- **Cập nhật kernel/OS**: lỗ hổng Teardrop đã được vá từ cuối thập niên 1990 (kiểm tra biên khi reassembly).
- Firewall **loại bỏ/chuẩn hóa** các mảnh IP dị thường (fragment scrubbing) — RFC 1858.
- **Giới hạn tài nguyên** hàng đợi tái hợp để chống cạn kiệt bộ nhớ bởi mảnh rác.
- IDS/IPS phát hiện chuỗi mảnh chồng lấn bất thường.

## 6. Trả lời câu hỏi ôn tập

1. **Fragment offset tính theo đơn vị nào? Hai mảnh ở Bước 2.3 chồng lấn khoảng byte nào?**
   Đơn vị **8 byte**. Mảnh 1 (`frag=0`, 24 byte) phủ **byte 0–23**; mảnh 2 (`frag=1` = offset 8 byte, 24 byte) phủ **byte 8–31**. Chúng **chồng lấn ở byte 8–23** (16 byte).

2. **Vì sao mảnh chồng lấn từng làm hệ cũ crash? Kernel hiện đại xử lý khác ra sao?**
   Code tái hợp cũ tính độ dài phần cần copy bằng `end - offset` mà **không kiểm tra biên**; với offset chồng lấn, kết quả ra **số âm/khổng lồ** → `memcpy` tràn bộ nhớ → kernel panic. Kernel hiện đại **kẹp (clamp) và kiểm tra biên**: cắt bớt phần chồng lấn hoặc **loại cả chùm mảnh xấu**, tăng `ReasmFails`, không bao giờ copy với độ dài âm.

3. **ReasmFails thay đổi thế nào trước/sau tấn công? Cho biết điều gì?**
   Trước: một giá trị nền; sau khi gửi mảnh chồng lấn: **tăng lên** (tăng mạnh nếu dùng `--rounds` lớn). Nó cho biết kernel đã **thử tái hợp và chủ động loại bỏ** các chùm mảnh không hợp lệ — tức cơ chế phòng thủ đang hoạt động.

4. **Một tấn công khác lợi dụng phân mảnh IP + cách phòng chống.**
   **Ping of Death**: gửi các mảnh mà khi ghép lại vượt quá 65.535 byte → tràn bộ đệm ở hệ cũ. Các ví dụ khác: *Rose attack*, *nestea*, và **dùng phân mảnh chồng lấn để né IDS** (IDS và host ghép mảnh khác nhau). Phòng chống: cập nhật OS, **chuẩn hóa/khước từ mảnh dị thường** tại firewall (RFC 1858), giới hạn kích thước gói sau tái hợp, giới hạn tài nguyên hàng đợi reassembly.

## 7. Tài liệu tham khảo

- **CVE-1999-0015** — Teardrop IP fragment overlap.
- **RFC 791** — IP Fragmentation and Reassembly.
- **RFC 1858** — Security Considerations for IP Fragment Filtering.
