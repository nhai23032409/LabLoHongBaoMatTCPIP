# Lab 04 — Smurf Attack (ICMP Broadcast Amplification DoS)

**Phụ trách:** Hạnh · **Thời lượng:** ~90 phút · **Mức độ:** Cơ bản–Trung bình

> ⚠️ **Cảnh báo pháp lý.** Bài này chỉ được thực hiện trong **phòng lab cô lập** (máy ảo +
> network namespace trên chính máy của bạn). Mọi kỹ thuật ở đây thuộc nhóm tấn công mạng; áp
> dụng lên hệ thống/mạng không thuộc quyền sở hữu hoặc không được cho phép bằng văn bản là **vi
> phạm pháp luật** (Luật An ninh mạng 2018 — Luật số 24/2018/QH14, và Bộ luật Hình sự). Mục tiêu
> học tập là hiểu cơ chế để **phòng thủ** (defensive security).

---

## 1. Mục tiêu

- Hiểu cơ chế **khuếch đại** (amplification): 1 gói ICMP echo gửi tới địa chỉ broadcast → nhiều host đồng loạt phản hồi về nạn nhân.
- Thấy vai trò của **giả mạo địa chỉ nguồn** (spoof = IP nạn nhân).
- Tái tạo điều kiện yếu (`icmp_echo_ignore_broadcasts=0`), **đo hệ số khuếch đại**, rồi bật phòng thủ và so sánh.

## 2. Vì sao Smurf vẫn khuếch đại? (kiến thức nền)

1. Attacker gửi **ICMP echo request** tới **địa chỉ broadcast** của LAN (10.0.0.255), đặt **địa chỉ nguồn = IP nạn nhân**.
2. Cầu (bridge) phát gói broadcast tới **mọi** host trong LAN.
3. Mỗi host "còn trả lời broadcast" sẽ gửi **echo-reply về nạn nhân** (vì nguồn bị giả mạo là nạn nhân).
4. N host trả lời ⇒ lưu lượng dội về nạn nhân nhân lên **×N**. Attacker không hề gửi gói nào trực tiếp tới nạn nhân.

Phòng thủ gốc: host **bỏ qua ping broadcast** (`icmp_echo_ignore_broadcasts=1`, mặc định Linux hiện đại) và router **không chuyển tiếp directed broadcast** (RFC 2644).

---

## 3. Môi trường (VMware Workstation)

- **1 máy ảo Kali Linux** (≥ 2 GB RAM) chạy trên VMware Workstation.
- **Toàn bộ "LAN 5 host" được mô phỏng bằng network namespace *bên trong* máy ảo** → **không cần cấu hình mạng VMware** (NAT hay Bridged đều được; lab không đụng tới nó).
- Cần quyền **root** (dùng `sudo`), và có sẵn `scapy` + `tcpdump`.

```bash
# Trong máy ảo Kali, cài công cụ nếu thiếu:
sudo apt update && sudo apt install -y python3-scapy tcpdump
```

> 💡 **Nên tạo Snapshot** máy ảo trước khi làm, để khôi phục nhanh. (Dù vậy, `cleanup.sh` đã dọn sạch mọi thứ lab tạo ra.)

### Sơ đồ topo

```
                         bridge br0 (LAN 10.0.0.0/24, broadcast .255)
        ┌───────────┬───────────┬───────────┬───────────┐
        │           │           │           │           │
     atk .100    vic .200    amp1 .11    amp2 .12    amp3 .13
   (attacker)   (victim)    └──── 3 máy "khuếch đại" ────┘
```

### Danh sách file

| File | Vai trò |
|------|---------|
| `setup_lan.sh` | Dựng bridge + 5 host namespace |
| `vuln_on.sh`   | Tái tạo điểm yếu (amp trả lời broadcast) |
| `smurf.py`     | Script tấn công Smurf bằng Scapy |
| `measure.sh`   | Đo hệ số khuếch đại tại nạn nhân |
| `vuln_off.sh`  | Bật phòng thủ (amp bỏ qua broadcast) |
| `cleanup.sh`   | Xóa namespace + bridge |

---

## 4. Các bước thực hiện

> Bạn sẽ cần **nhiều cửa sổ terminal** trong máy ảo Kali. Mở một namespace như một "máy" bằng:
> `sudo ip netns exec <tên_ns> bash` — ví dụ `sudo ip netns exec vic bash`.

### Bước 0 — Cấp quyền chạy cho script

```bash
cd lab04-smurf
chmod +x *.sh smurf.py
# Nếu copy từ Windows và gặp lỗi "bad interpreter" do ký tự xuống dòng CRLF:
#   sudo apt install -y dos2unix && dos2unix *.sh smurf.py
```

### Bước 1 — Dựng LAN mô phỏng

```bash
sudo bash setup_lan.sh
# Kiểm tra: attacker ping được máy amp
sudo ip netns exec atk ping -c2 10.0.0.11
```

### Bước 2 — Tái tạo điểm yếu

```bash
sudo bash vuln_on.sh        # amp1-3 bật trả lời ping broadcast
```

### Bước 3 — Mở quan sát tại nạn nhân *(Terminal A — giữ chạy)*

```bash
sudo ip netns exec vic tcpdump -i vic0 -nn -l icmp
```

> 💡 **Chú ý cờ `-l`** (line-buffered): nếu thiếu, tcpdump **gom kết quả trong bộ đệm và chỉ xổ ra
> màn hình khi bạn Ctrl+C** — dễ tưởng nhầm là "không bắt được gói". Với `-l`, từng dòng hiện ngay
> khi có gói. (Đề gốc không có `-l`, nên hay gặp hiện tượng phải Ctrl+C mới thấy.)

### Bước 4 — Phát động Smurf từ attacker *(Terminal B)*

```bash
sudo ip netns exec atk python3 smurf.py            # gửi 10 gói
# hoặc: sudo ip netns exec atk python3 smurf.py --count 20
```

**✔ Kết quả mong đợi (Terminal A):** mỗi gói broadcast gửi đi sinh ra **3 echo-reply** đến từ
`10.0.0.11`, `.12`, `.13` dội về nạn nhân → hệ số khuếch đại **×3**. Gửi 10 gói ⇒ ~30 reply dội
về, dù attacker chưa từng gửi gói nào trực tiếp cho nạn nhân.

> 📌 Tại victim bạn sẽ thấy **2 loại gói**: (a) gói *echo-request* broadcast đi tới `10.0.0.255` —
> victim nhận được vì nó cũng nằm trong LAN; (b) các *echo-reply* từ amp dội về `10.0.0.200`. Phần
> khuếch đại thực sự là nhóm (b). `measure.sh` chỉ đếm (b) để ra con số sạch.

### Bước 5 — Đo hệ số khuếch đại *(có thể tắt Terminal A trước)*

```bash
sudo bash measure.sh            # 5 giây, 10 gói
# In ra: requests gửi / echo-reply về victim / hệ số ~3x
```

### Bước 6 — Bật phòng thủ và so sánh

```bash
sudo bash vuln_off.sh           # amp1-3 bỏ qua ping broadcast (mặc định Linux)
sudo bash measure.sh            # chạy lại
```

**✔ Kết quả mong đợi:** sau khi các máy bỏ qua ping broadcast, **không còn echo-reply dội về nạn
nhân** (hệ số ~0x). Đây chính là cấu hình mặc định an toàn của hệ thống hiện đại.

### Bước 7 — Dọn dẹp

```bash
sudo bash cleanup.sh
```

### Xử lý sự cố: "attacker bắn xong nhưng Terminal A không thấy gì"

**Nguyên nhân thường gặp nhất là tcpdump buffering, KHÔNG phải mất gói.** tcpdump gom output trong
bộ đệm; với một loạt gói ngắn rồi im lặng, nó không xổ ra màn hình cho tới khi bạn **Ctrl+C**. Gói
vẫn được bắt real-time.

- **Khắc phục:** thêm cờ **`-l`** vào lệnh tcpdump (xem Bước 3) để in từng dòng ngay lập tức.
- **Kiểm chứng amp có trả lời broadcast không** (sau `vuln_on.sh`):
  ```bash
  sudo ip netns exec atk ping -b -c2 10.0.0.255
  ```
  Phải thấy reply từ `10.0.0.11/.12/.13` → topo & amp đều ổn.
- **`smurf.py` nằm trên Windows, chạy trong VM:** sau mỗi lần sửa file ở Windows, phải đồng bộ bản
  mới vào VM (shared folder / `git pull` / copy lại) rồi mới chạy — nếu không VM vẫn chạy bản cũ.

---

## 5. Phòng chống (Mitigation)

- `net.ipv4.icmp_echo_ignore_broadcasts = 1` trên **mọi host** (mặc định Linux hiện đại).
- Router **không chuyển tiếp directed broadcast** (`no ip directed-broadcast`) — RFC 2644 / BCP 34.
- **Lọc nguồn giả mạo** theo BCP 38 (ingress filtering) tại biên để chặn bước spoofing.
- Giám sát & **giới hạn tốc độ** (rate-limit) ICMP; dùng dịch vụ chống DDoS cho hệ thống công khai.

## 6. Trả lời câu hỏi ôn tập

1. **Hệ số khuếch đại phụ thuộc yếu tố nào? Thêm 10 máy amp thì sao?**
   Phụ thuộc **số host trả lời** ping broadcast trong LAN (và kích thước gói reply). Trong lab 3 máy ⇒ ×3; thêm 10 máy nữa (tổng 13) ⇒ ×13 — lưu lượng dội về nạn nhân tăng tuyến tính theo số máy khuếch đại.

2. **Vì sao phải giả mạo địa chỉ nguồn? Không giả mạo thì sao?**
   Vì đích của đòn DoS là **nạn nhân**. Đặt nguồn = IP nạn nhân khiến mọi echo-reply dội về nạn nhân. Nếu không giả mạo (để nguồn thật của attacker), các reply sẽ dội về **chính attacker** — tự gây DoS cho mình, vô nghĩa.

3. **So sánh "bỏ qua ping broadcast (host)" vs "chặn directed broadcast (router)".**
   - *Bỏ qua ping broadcast ở host*: ngăn **mỗi máy** tự biến thành bộ khuếch đại (chặn bước phản hồi).
   - *Chặn directed broadcast ở router*: ngăn gói broadcast từ **ngoài mạng** lọt vào để đến được các host (chặn bước phát tán). Hai lớp bổ trợ nhau: phòng thủ theo chiều sâu.

4. **Smurf thuộc nhóm tấn công nào? Biến thể dùng UDP?**
   Thuộc nhóm **DoS/DDoS khuếch đại phản xạ** (reflection/amplification DoS). Biến thể UDP tương tự: **Fraggle attack** (gửi UDP echo — cổng 7/19 — tới broadcast); các dạng amplification hiện đại: DNS, NTP, memcached reflection.

## 7. Tài liệu tham khảo

- CERT Advisory **CA-1998-01** — Smurf IP Denial-of-Service Attacks.
- **RFC 2644 (BCP 34)** — Changing the Default for Directed Broadcasts.
- **RFC 2827 (BCP 38)** — Network Ingress Filtering.
