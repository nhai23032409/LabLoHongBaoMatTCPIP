# Lab 01 — TCP Sequence Number Prediction

**Phụ trách:** Khoa · **Thời lượng:** ~75 phút · **Mức độ:** Vừa

> ⚠️ **Cảnh báo pháp lý.** Bài này chỉ được thực hiện trong **phòng lab cô lập** (máy ảo +
> network namespace trên chính máy của bạn). Giả mạo TCP / đoán số thứ tự là kỹ thuật tấn công
> mạng; áp dụng lên hệ thống/mạng không thuộc quyền sở hữu hoặc không được phép bằng văn bản là
> **vi phạm pháp luật** (Luật An ninh mạng 2018 — Luật số 24/2018/QH14, và Bộ luật Hình sự). Mục
> tiêu là hiểu cơ chế để **phòng thủ** (defensive security).

---

## 1. Mục tiêu

- Hiểu vai trò của **Initial Sequence Number (ISN)** trong bắt tay 3 bước TCP và vì sao nó là
  "bí mật" chống giả mạo kết nối.
- **Đo** mức độ đoán-trước-được của ISN mà một máy chủ phát ra (`isn_sampler.py`), từ đó đánh giá
  nguy cơ **TCP Sequence Number Prediction** off-path.
- Minh hoạ **giả mạo TCP** dựa trên ISN (`spoof_sniff.py`): kẻ **on-path** đọc được ISN thì bắt tay
  thành công; kẻ **off-path** phải **đoán** ISN và **thất bại** trước kernel hiện đại (RFC 6528).

## 2. Kiến thức nền

- Bắt tay 3 bước: client gửi `SYN(seq=C)`; server trả `SYN-ACK(seq=S, ack=C+1)`; client gửi
  `ACK(seq=C+1, ack=S+1)`. Giá trị **S** chính là **ISN của server**.
- Để **giả mạo** một kết nối từ IP của "host tin cậy" (mà không nhận được gói trả về), kẻ tấn công
  phải gửi được ACK với **ack = S+1** đúng → **phải biết S**.
- **Hệ cũ** sinh ISN theo bộ đếm tăng đều (BSD: +64000/giây, +128000 mỗi kết nối…). Kẻ off-path
  lấy mẫu vài ISN rồi **ngoại suy** S kế tiếp ⇒ giả mạo được (tấn công Mitnick 1994).
- **Kernel hiện đại (RFC 6528)** sinh `ISN = M + MD5(IP nguồn, IP đích, cổng nguồn, cổng đích, khoá bí mật)`
  với `M` là đồng hồ 4µs. ISN **ngẫu nhiên theo từng 4-tuple** ⇒ đoán mù xác suất ~`1/2^32` ⇒
  **bất khả thi**.

> 📌 "Kết quả" của bài gồm **hai phần**: (a) **đo** và chứng minh ISN của Linux hiện đại là ngẫu
> nhiên; (b) cho thấy spoofing chỉ còn khả thi khi kẻ tấn công **on-path** (đọc trực tiếp ISN) —
> từ đó suy ra biện pháp phòng thủ.

---

## 3. Môi trường (VMware Workstation)

- **1 máy ảo Kali Linux** trên VMware Workstation.
- Mô hình 2 máy (attacker/victim) mô phỏng bằng **network namespace + veth *bên trong* VM** → **không cần cấu hình mạng VMware**.
- Cần **root** (`sudo`), có sẵn `scapy`, `tcpdump`, `netcat` (`nc`).

```bash
sudo apt update && sudo apt install -y python3-scapy tcpdump netcat-openbsd
```

### Sơ đồ topo

```
   h1 (attacker/observer)  veth1 ──────── veth2  h2 (victim/server)
   10.0.0.1                                       10.0.0.2
                                                  dịch vụ nghe ở cổng 8080
   (IP host tin cậy bị giả mạo: 10.0.0.9 — không thuộc máy nào)
```

### Danh sách file

| File | Vai trò |
|------|---------|
| `setup_pair.sh`  | Dựng 2 namespace h1/h2 nối bằng veth |
| `isn_sampler.py` | Lấy mẫu ISN của server và đánh giá độ ngẫu nhiên/đoán-trước |
| `spoof_sniff.py` | Giả mạo TCP dựa trên ISN: chế độ `sniff` (on-path) và `blind` (off-path) |
| `cleanup.sh`     | Xóa namespace |

---

## 4. Các bước thực hiện

> Cần **2–3 terminal** trong VM. Mở "máy" bằng: `sudo ip netns exec <ns> bash`.

### Bước 0 — Cấp quyền chạy

```bash
cd lab01-tcp-seq
chmod +x *.sh *.py
# Nếu lỗi "bad interpreter" do CRLF: sudo apt install -y dos2unix && dos2unix *.sh *.py
```

### Bước 1 — Dựng topo

```bash
sudo bash setup_pair.sh        # tự ping thử h1 -> h2
```

### Bước 2 — Mở dịch vụ nghe trên victim *(Terminal A — giữ chạy)*

```bash
sudo ip netns exec h2 nc -lk -p 8080
```

### Bước 3 — Đo độ đoán-trước-được của ISN *(Terminal B — attacker)*

```bash
sudo ip netns exec h1 python3 isn_sampler.py --dst 10.0.0.2 --dport 8080 -n 30
```

**✔ Kết quả mong đợi:** các ISN **trải rộng khắp không gian 32-bit**, delta giữa các ISN **lớn và
thất thường** → bản in kết luận *"ISN NGẪU NHIÊN hoá (RFC 6528)"*. (Trên hệ cũ, delta sẽ nhỏ/đều.)

### Bước 4 — Chuẩn bị ARP tĩnh cho IP giả mạo *(chạy ở root netns, 1 lần)*

Để victim gửi được `SYN-ACK` của IP giả `10.0.0.9` tới đúng card của attacker trên liên kết:

```bash
H1MAC=$(sudo ip netns exec h1 cat /sys/class/net/veth1/address)
sudo ip netns exec h2 ip neigh replace 10.0.0.9 lladdr "$H1MAC" dev veth2
```

### Bước 5 — Giả mạo TCP: kẻ tấn công **on-path** (đọc được ISN) *(Terminal B)*

```bash
sudo ip netns exec h1 python3 spoof_sniff.py --mode sniff
```

**✔ Kết quả mong đợi:** script **bắt được SYN-ACK**, đọc `server_isn`, hoàn tất bắt tay và **chèn
payload**. Trên Terminal A (`nc`) xuất hiện dòng `hijacked-by-spoofed-host` — chứng tỏ kết nối được
tạo **dưới danh nghĩa 10.0.0.9**. Dù ISN ngẫu nhiên, on-path vẫn thắng vì **nhìn thấy** ISN.

### Bước 6 — Giả mạo TCP: kẻ tấn công **off-path** (phải đoán ISN) *(Terminal B)*

```bash
sudo ip netns exec h1 python3 spoof_sniff.py --mode blind --guess 0
```

**✔ Kết quả mong đợi:** script **không nhìn SYN-ACK**, đoán `server_isn=0`. Vì ISN thật là ngẫu
nhiên nên ACK sai số thứ tự → **bắt tay thất bại**, payload **không** xuất hiện trên Terminal A.
Kết luận: ISN ngẫu nhiên chặn được **spoofing mù**.

> (Tuỳ chọn) Bắt gói để quan sát: `sudo ip netns exec h2 tcpdump -i veth2 -nn 'tcp port 8080'`.

### Bước 7 — Dọn dẹp

```bash
sudo bash cleanup.sh
```

---

## 5. Phòng chống (Mitigation)

- **Dùng ISN ngẫu nhiên hoá mạnh** (RFC 6528) — mặc định trên mọi OS hiện đại; không bao giờ dùng
  bộ đếm tăng đều.
- **Chống nghe lén đường truyền**: mã hoá (TLS/SSH/IPsec) khiến kẻ on-path không khai thác được nội
  dung; chống ARP/MAC spoofing để kẻ tấn công khó chen vào on-path.
- **Lọc chống giả mạo (anti-spoofing)**: BCP 38 / uRPF ở biên mạng loại gói có IP nguồn giả.
- **TCP-AO / MD5 signature** (RFC 5925) cho phiên quan trọng (vd BGP) để xác thực từng segment.
- IDS/IPS phát hiện SYN rời rạc nhiều cổng nguồn (hành vi lấy mẫu ISN).

## 6. Trả lời câu hỏi ôn tập

1. **Vì sao kẻ tấn công off-path cần biết ISN của server?**
   Vì để hoàn tất bắt tay (và mọi segment sau đó) phải đặt `ack = server_isn + 1` và `seq` nằm
   trong cửa sổ. Off-path **không nhận** được SYN-ACK nên không đọc được ISN; nếu đoán sai, victim
   coi ACK là ngoài cửa sổ và bỏ qua → không có kết nối.

2. **`isn_sampler.py` đo gì để kết luận ISN có đoán trước được hay không?**
   Nó lấy nhiều ISN liên tiếp rồi tính **delta** giữa chúng. Delta nhỏ/đều (vd hằng số) ⇒ bộ đếm
   tuyến tính ⇒ **đoán trước được**. Delta lớn, trải khắp `2^32`, độ lệch chuẩn cao ⇒ **ngẫu
   nhiên** (RFC 6528) ⇒ không đoán được.

3. **Vì sao chế độ `sniff` thành công còn `blind` thất bại trên cùng một kernel hiện đại?**
   `sniff` là **on-path**: dù ISN ngẫu nhiên, kẻ tấn công **đọc trực tiếp** ISN từ gói SYN-ACK đi
   qua liên kết. `blind` là **off-path**: không thấy gói, phải **đoán** 1 trong `2^32` giá trị →
   gần như chắc chắn sai. Kết luận: randomization chỉ chống được kẻ off-path, **không** chống được
   kẻ đã nghe được đường truyền → cần thêm mã hoá/chống MITM.

4. **Mô tả tấn công Mitnick 1994 và vì sao nó không còn khả thi.**
   Kẻ tấn công (a) làm tê liệt host tin cậy bằng SYN flood, (b) lấy mẫu ISN của máy đích qua các
   kết nối thật rồi **ngoại suy** ISN kế tiếp (bộ đếm BSD tăng đều), (c) gửi `SYN` giả nguồn là host
   tin cậy và `ACK` với ISN đã đoán để mạo danh dịch vụ `rsh`. Ngày nay **ISN ngẫu nhiên** (RFC 6528)
   làm bước (b) bất khả thi, và các dịch vụ dựa trên tin cậy IP (`r*` services) đã bị thay bằng SSH.

## 7. Tài liệu tham khảo

- **RFC 793** — Transmission Control Protocol (bắt tay 3 bước, số thứ tự).
- **RFC 6528** — Defending against Sequence Number Attacks (ISN ngẫu nhiên hoá).
- **RFC 5925** — The TCP Authentication Option (TCP-AO).
- **CA-1995-01 / CA-1996-21 (CERT)** — IP spoofing & TCP sequence prediction; tấn công Mitnick.
- **BCP 38 (RFC 2827)** — Network Ingress Filtering chống giả mạo IP nguồn.
