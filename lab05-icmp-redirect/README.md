# Lab 05 — ICMP Redirect Attack (Route Hijacking / MITM)

**Phụ trách:** Hạnh · **Thời lượng:** ~100 phút · **Mức độ:** Trung bình

> ⚠️ **Cảnh báo pháp lý.** Bài này chỉ được thực hiện trong **phòng lab cô lập** (máy ảo +
> network namespace trên chính máy của bạn). Mọi kỹ thuật ở đây thuộc nhóm tấn công mạng; áp dụng
> lên hệ thống/mạng không thuộc quyền sở hữu hoặc không được phép bằng văn bản là **vi phạm pháp
> luật** (Luật An ninh mạng 2018 — Luật số 24/2018/QH14, và Bộ luật Hình sự). Mục tiêu là hiểu cơ
> chế để **phòng thủ** (defensive security).

---

## 1. Mục tiêu

- Hiểu thông điệp **ICMP Redirect (type 5)** và cách host cập nhật bảng định tuyến khi nhận nó.
- **Giả mạo** ICMP Redirect để ép nạn nhân định tuyến qua máy tấn công → **man-in-the-middle (MITM)**.
- Quan sát route của nạn nhân thay đổi; sau đó bật phòng thủ `accept_redirects=0` và so sánh.

## 2. Kiến thức nền

- Router hợp pháp dùng **ICMP Redirect** để báo host "có đường tốt hơn tới đích X, hãy đi qua gateway Y". Host nhận được sẽ cập nhật route tới X.
- Nếu host **chấp nhận redirect giả**, attacker có thể tự đặt mình thành "gateway Y" → chèn vào đường đi (MITM).
- Để được chấp nhận, gói redirect phải **(giả) xuất phát từ gateway hiện tại** của đích đó (ở đây là GW `10.0.0.1`), và gateway mới phải **cùng mạng** (on-link). Đó là lý do attacker đặt `src = 10.0.0.1`.

---

## 3. Môi trường (VMware Workstation)

- **1 máy ảo Kali Linux** (≥ 2 GB RAM) trên VMware Workstation.
- Toàn bộ mô hình (3 host + 1 router + 1 máy đích) được mô phỏng bằng **network namespace *bên trong* VM** → **không cần cấu hình mạng VMware**.
- Cần **root** (`sudo`) và có sẵn `scapy`, `tcpdump`, `iproute2`.

```bash
sudo apt update && sudo apt install -y python3-scapy tcpdump iproute2
```

> 💡 Nên **Snapshot** VM trước khi làm. `cleanup.sh` cũng dọn sạch mọi thứ lab tạo ra.

### Sơ đồ topo

```
        LAN 10.0.0.0/24 (bridge br0)                 mạng xa 10.0.1.0/24
   ┌──────────┬──────────┬──────────┐
   │          │          │          │                  ┌──────────────┐
 vic .2    atk .66     gw .1 ────────┼── gw-d .254 ─────┤  dst 10.0.1.5 │
(victim)  (attacker)  (router, ip_forward=1)            └──────────────┘
                        │
   victim default route ──► 10.0.0.1 (gw)   [đường hợp pháp tới 10.0.1.5]
   mục tiêu tấn công:   ép victim đi qua 10.0.0.66 (atk) thay vì 10.0.0.1
```

### Danh sách file

| File | Vai trò |
|------|---------|
| `setup_redirect.sh` | Dựng LAN + router + mạng xa, tái tạo điểm yếu (victim `accept_redirects=1`) |
| `check_route.sh`    | Xem đường đi hiện tại của victim tới `10.0.1.5` |
| `redirect_attack.py`| Gửi gói ICMP Redirect giả mạo (Scapy) |
| `mitm_forward.sh`   | *(tùy chọn)* Biến attacker thành MITM thực sự có chuyển tiếp gói |
| `defense.sh`        | Bật phòng thủ: victim bỏ qua redirect + xóa cache |
| `cleanup.sh`        | Xóa namespace + bridge |

---

## 4. Các bước thực hiện

> Dùng **nhiều terminal** trong VM. Mở "máy" bằng: `sudo ip netns exec <ns> bash`.

### Bước 0 — Cấp quyền chạy

```bash
cd lab05-icmp-redirect
chmod +x *.sh redirect_attack.py
# Nếu lỗi "bad interpreter" do xuống dòng CRLF: sudo apt install -y dos2unix && dos2unix *.sh redirect_attack.py
```

### Bước 1 — Dựng mô hình

```bash
sudo bash setup_redirect.sh      # cuối lệnh sẽ tự ping thử victim -> 10.0.1.5 (phải thành công)
```

### Bước 2 — Ghi nhận đường đi ban đầu (baseline)

```bash
sudo bash check_route.sh
# ✔ Mong đợi: "10.0.1.5 via 10.0.0.1 dev vic0" — đi qua GW hợp pháp.
```

### Bước 3 — *(Khuyến nghị)* Bật chuyển tiếp để MITM "sạch"

```bash
sudo bash mitm_forward.sh
```

Nếu **bỏ qua** bước này, sau tấn công victim sẽ **mất kết nối** tới `10.0.1.5` (attacker nhận gói
nhưng không chuyển tiếp) — vẫn chứng minh được route bị đổi, nhưng không phải MITM "trong suốt".

> ⚠️ **Quan trọng — kernel hiện đại (Ubuntu 24.04, kernel 6.x) rất "khó tính":** nó chỉ chịu nhận
> redirect khi (a) victim **đang có luồng chạy liên tục** tới đích, và (b) redirect được gửi **lặp
> vài lần**. Vì vậy các bước dưới dùng **`ping` liên tục (không `-c1`)** và `redirect_attack.py` đã
> được chỉnh để **tự bắn 10 lần** (`--repeat 10`). Cách "ping 1 phát + bắn 1 redirect" như đề gốc
> thường **không ăn** trên kernel mới.

### Bước 4 — Mở 2 cửa sổ "giữ chạy"

```bash
# Terminal A (attacker) — quan sát lưu lượng bị chuyển hướng:
sudo ip netns exec atk tcpdump -i atk0 -nn host 10.0.1.5

# Terminal B (victim) — tạo luồng LIÊN TỤC tới đích (ĐỪNG -c1, cứ để chạy):
sudo ip netns exec vic ping 10.0.1.5
```

### Bước 5 — Tung đòn ICMP Redirect *(Terminal C)*

```bash
# Trong khi Terminal B vẫn đang ping, attacker bắn redirect lặp 10 lần:
sudo ip netns exec atk python3 redirect_attack.py
# (muốn bắn nhiều hơn: ... redirect_attack.py --repeat 20)
```

### Bước 6 — Kiểm chứng route đã bị sửa

```bash
sudo bash check_route.sh
```

**✔ Kết quả:** `ip route get 10.0.1.5` hiển thị **`via 10.0.0.66 dev vic0 ... cache <redirected>
expires ...sec`** — route đã trỏ qua ATTACKER. Đồng thời **Terminal A** (tcpdump) bắt được cả
echo-request lẫn echo-reply của victim đi xuyên `atk0`, và **Terminal B vẫn ping được** (ttl=63)
⇒ attacker đã chèn vào đường đi mà victim không mất kết nối (MITM trong suốt).

> 📌 **Lưu ý kernel mới:** `ip route show cache` thường **rỗng** trên kernel hiện đại (route cache đã
> bị bỏ từ ~3.6). Phép kiểm tra tin cậy là **`ip route get 10.0.1.5`** — nó phản ánh "exception" do
> redirect tạo ra (`cache <redirected>`). Vì vậy `check_route.sh` dựa chủ yếu vào `ip route get`.

### Bước 7 — Bật phòng thủ và so sánh

```bash
sudo bash defense.sh          # victim: accept_redirects=0 + flush cache (xoá exception cũ)

# Terminal B vẫn đang ping; bắn lại redirect đúng kiểu như Bước 5:
sudo ip netns exec atk python3 redirect_attack.py
sudo bash check_route.sh
# ✔ Mong đợi: vẫn "via 10.0.0.1" — redirect giả bị bỏ qua, route KHÔNG đổi.
```

> 💡 Nếu Terminal B (ping liên tục) đã tắt sau Bước 6, hãy bật lại trước khi làm Bước 7 để test
> công bằng (vẫn phải có luồng chạy thì mới biết kernel có "cắn câu" redirect hay không).

### Bước 8 — Dọn dẹp

```bash
sudo bash cleanup.sh
```

---

## 5. Phòng chống (Mitigation)

- `net.ipv4.conf.all.accept_redirects = 0` trên host (và `send_redirects = 0` trên router không cần phát redirect).
- `secure_redirects = 1`: chỉ chấp nhận redirect trỏ tới **gateway đã biết** (giảm rủi ro redirect bừa).
- Dùng **định tuyến tĩnh / được xác thực**; phân đoạn mạng (VLAN) để attacker không cùng broadcast domain với nạn nhân.
- Giám sát ARP/ICMP bất thường; IDS phát hiện redirect giả mạo.

## 6. Trả lời câu hỏi ôn tập

1. **Điều kiện để Linux chấp nhận một ICMP Redirect? Vì sao attacker đặt `src = GW`?**
   `accept_redirects=1`; gói redirect phải đến từ **đúng gateway hiện tại** của đích; gateway mới phải **on-link** (cùng mạng); và nếu `secure_redirects=1` thì gateway mới phải nằm trong danh sách gateway đã biết. Attacker đặt `src=10.0.0.1` (GW) vì kernel chỉ tin redirect đến từ chính router mà host đang dùng cho đích đó — giả danh nguồn là bắt buộc.

2. **Vai trò của phần "gói gốc" đính kèm trong redirect?**
   RFC 792 yêu cầu thông điệp redirect mang theo IP header + 8 byte đầu của gói đã kích hoạt. Nó cho host biết redirect áp cho **đích nào** (ở đây `10.0.1.5`) để cập nhật đúng route; đồng thời giúp host đối chiếu redirect với luồng thật sự của mình.

3. **So sánh ICMP Redirect attack với ARP spoofing.**
   Cùng mục tiêu MITM nhưng khác tầng: **ARP spoofing** ở **tầng 2** (bơm ánh xạ IP→MAC giả, chiếm mọi lưu lượng trong LAN). **ICMP Redirect** ở **tầng 3** (sửa bảng định tuyến của nạn nhân cho một đích cụ thể). ARP spoofing phổ biến/mạnh hơn; ICMP Redirect hẹp hơn và dễ bị vô hiệu bằng `accept_redirects=0`.

4. **Khác biệt `accept_redirects=0` vs `secure_redirects=1`? Dùng cái nào cho máy trạm?**
   `accept_redirects=0`: **từ chối mọi** redirect. `secure_redirects=1`: vẫn nhận redirect nhưng **chỉ khi** gateway mới nằm trong danh sách gateway đã biết. Với **máy trạm** thông thường (ít khi cần redirect), nên đặt thẳng `accept_redirects=0` cho chắc; `secure_redirects` chỉ hữu ích khi vẫn muốn dùng redirect hợp pháp mà giảm rủi ro.

## 7. Tài liệu tham khảo

- **RFC 792** — ICMP (Redirect Message).
- **RFC 1122** — Requirements for Internet Hosts (xử lý redirect).
- Tài liệu kernel: `Documentation/networking/ip-sysctl.txt`.
