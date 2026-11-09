# Lab 07 — DNSSEC (Domain Name System Security Extensions)

**Phụ trách:** Khoa · **Thời lượng:** ~100 phút · **Mức độ:** Khó nhất

> ⚠️ **Cảnh báo pháp lý.** Bài này chỉ được thực hiện trong **phòng lab cô lập** (máy ảo +
> network namespace trên chính máy của bạn). Phần "attacker" dựng một DNS server **giả mạo** để
> minh hoạ **phòng thủ**; dựng DNS giả hoặc đầu độc cache trên hệ thống/mạng không được phép là
> **vi phạm pháp luật** (Luật An ninh mạng 2018 — Luật số 24/2018/QH14, và Bộ luật Hình sự).

> 📌 Khác với các lab tấn công khác, Lab07 là lab **PHÒNG THỦ**: ta triển khai DNSSEC rồi chứng
> minh nó **phát hiện và từ chối** dữ liệu DNS bị giả mạo (trả `SERVFAIL`), trong khi DNS thường
> sẽ "tin" ngay dữ liệu giả.

---

## 1. Mục tiêu

- Hiểu vì sao **DNS thuần không được xác thực** → dễ bị **giả mạo / đầu độc cache** (Kaminsky).
- Triển khai một **zone được ký DNSSEC** trên máy chủ uy quyền (BIND9): khóa **KSK/ZSK**, bản ghi
  **DNSKEY / RRSIG / NSEC / DS**.
- Cấu hình **resolver xác thực** (unbound) với **trust anchor**, quan sát cờ **AD (Authenticated
  Data)** khi chuỗi chữ ký hợp lệ.
- Chứng minh DNSSEC **chặn tấn công MITM**: khi resolver bị trỏ sang DNS **giả mạo**, dữ liệu không
  có chữ ký hợp lệ ⇒ resolver trả **SERVFAIL (bogus)** thay vì chấp nhận IP giả.

## 2. Kiến thức nền

- **DNS thường**: resolver tin câu trả lời chỉ dựa vào IP nguồn + cổng + Query ID (16-bit) → kẻ
  tấn công đoán/đua được các giá trị này để **chèn câu trả lời giả** (tấn công Kaminsky 2008).
- **DNSSEC** thêm **chữ ký số** cho mỗi tập bản ghi:
  - **DNSKEY**: khóa công khai của zone. Gồm **ZSK** (ký dữ liệu) và **KSK** (ký DNSKEY).
  - **RRSIG**: chữ ký cho một RRset (vd `A`, `SOA`, `DNSKEY`).
  - **NSEC/NSEC3**: chứng minh một tên **không tồn tại** (authenticated denial).
  - **DS**: "dấu vân tay" của KSK đặt ở **zone cha** → tạo **chuỗi tin cậy** từ gốc (`.`) xuống.
- **Trust anchor**: điểm tin cậy khởi đầu (trong thực tế là KSK của gốc `.`). Resolver xác thực
  **từ trust anchor đi xuống**: DS(cha) → DNSKEY(con) → RRSIG(dữ liệu). Hỏng một mắt xích ⇒ **bogus**.
- Vì `.lab` không phải TLD thật (không có chuỗi từ gốc Internet), lab này **cấu hình trực tiếp KSK
  của `secure.lab` làm trust anchor** cho resolver — mô phỏng một delegation đã ký.

---

## 3. Môi trường (VMware Workstation)

- **1 máy ảo Kali Linux** trên VMware Workstation.
- Mô hình 4 máy mô phỏng bằng **bridge `br0` + network namespace *bên trong* VM** → **không cần cấu
  hình mạng VMware**.
- Cần **root** (`sudo`) và các gói:

```bash
sudo apt update && sudo apt install -y bind9 bind9-dnsutils dnsutils unbound
# bind9 cung cap: named, dnssec-keygen, dnssec-signzone, dnssec-dsfromkey
# dnsutils cung cap: dig, delv
```

> 🔧 **Về AppArmor.** Các script đặt file runtime vào đúng vùng mà profile mặc định cho phép
> (`named` → `/var/cache/bind/lab07`, `unbound` → `/etc/unbound/lab07`, pid `/run/unbound.pid`),
> nên **không bị "permission denied"** kể cả khi AppArmor đang enforce. Nếu bản phân phối của bạn
> dùng profile khác và vẫn bị chặn, có thể đặt sang chế độ cảnh báo:
> `sudo apt install -y apparmor-utils && sudo aa-complain /usr/sbin/named /usr/sbin/unbound`.

### Sơ đồ topo

```
            br0 (LAN 10.0.0.0/24)
   ┌──────────┬────────────┬────────────┐
 auth .10   resolver .20  client .30   attacker .40
 BIND9      unbound       dig/delv     BIND9 (rogue,
 (signed)   (validating)               forged, unsigned)
```

### Danh sách file

| File | Vai trò |
|------|---------|
| `setup_lan.sh`               | Dựng bridge + 4 namespace |
| `zones/secure.lab.zone`      | Zone thật (nguồn) để ký DNSSEC |
| `zones/secure.lab.forged.zone` | Zone giả (attacker phục vụ, không ký) |
| `sign_zone.sh`               | Sinh KSK/ZSK, ký zone, xuất trust anchor + DS |
| `run_auth.sh`                | Chạy BIND9 phục vụ zone đã ký (máy auth) |
| `run_resolver.sh`            | Chạy unbound xác thực DNSSEC (máy resolver) |
| `run_attacker.sh`            | Chạy BIND9 giả mạo phục vụ zone forged (máy attacker) |
| `demo.sh`                    | Bộ truy van kiểm chứng từ client |
| `cleanup.sh`                 | Xóa namespace, bridge, artifact runtime |

---

## 4. Các bước thực hiện

> Cần **4 terminal** trong VM (auth, resolver, client, + 1 để điều khiển). Mở "máy" bằng:
> `sudo ip netns exec <ns> bash`.

### Bước 0 — Cấp quyền chạy

```bash
cd lab07-dnssec
chmod +x *.sh
# Nếu lỗi CRLF: sudo apt install -y dos2unix && dos2unix *.sh zones/*
```

### Bước 1 — Dựng topo

```bash
sudo bash setup_lan.sh
sudo ip netns exec client ping -c2 10.0.0.10   # client thấy auth
```

### Bước 2 — Ký zone DNSSEC (tạo khóa + chữ ký + trust anchor)

```bash
sudo bash sign_zone.sh
```

**✔ Kết quả mong đợi:** in ra ZSK/KSK vừa tạo, sinh `secure.lab.zone.signed` và `trust-anchor.conf`
trong `/var/cache/bind/lab07/auth`, trust anchor trong `/etc/unbound/lab07`, kèm **bản ghi DS**.
Mở thử zone đã ký để thấy **RRSIG, DNSKEY, NSEC**:

```bash
sudo sed -n '1,40p' /var/cache/bind/lab07/auth/secure.lab.zone.signed
```

### Bước 3 — Khởi chạy máy chủ uy quyền thật *(Terminal "auth" — giữ chạy)*

```bash
sudo ip netns exec auth bash run_auth.sh
```

### Bước 4 — Khởi chạy resolver xác thực, trỏ tới auth thật *(Terminal "resolver" — giữ chạy)*

```bash
sudo ip netns exec resolver bash run_resolver.sh      # upstream mặc định = 10.0.0.10
```

### Bước 5 — Truy vấn hợp lệ: quan sát cờ **AD** *(Terminal "client")*

```bash
sudo ip netns exec client dig @10.0.0.20 bank.secure.lab A +dnssec +multiline
# hoặc chạy bộ kiểm chứng:
sudo ip netns exec client bash demo.sh
```

**✔ Kết quả mong đợi:** `status: NOERROR`, phần cờ có **`ad`** (Authenticated Data), và câu trả lời
kèm **RRSIG**. Nghĩa là resolver đã **xác thực chuỗi chữ ký tới trust anchor** → dữ liệu đáng tin.
`bank.secure.lab` trả đúng **10.0.0.101**.

### Bước 6 — Tấn công MITM: trỏ resolver sang DNS **giả mạo**

Mở máy chủ giả *(Terminal "attacker" — giữ chạy)*:

```bash
sudo ip netns exec attacker bash run_attacker.sh      # phục vụ bank -> 10.0.0.66 (giả), KHÔNG ký
```

Dừng resolver ở Terminal "resolver" (Ctrl+C) rồi chạy lại, lần này **upstream = attacker**:

```bash
sudo ip netns exec resolver env UPSTREAM=10.0.0.40 bash run_resolver.sh
```

Truy vấn lại từ client:

```bash
sudo ip netns exec client dig @10.0.0.20 bank.secure.lab A +dnssec
```

**✔ Kết quả mong đợi:** `status: SERVFAIL` (**không** có `ad`, **không** trả IP giả). Resolver đòi
chữ ký khớp trust anchor nhưng zone giả **không ký** → đánh dấu **bogus** và **từ chối**. DNSSEC đã
chặn việc đẩy `bank.secure.lab` sang `10.0.0.66`.

> 🔎 **Chứng minh dữ liệu giả vẫn "ở đó" nếu bỏ xác thực:** thêm cờ `+cd` (checking disabled) để
> buộc resolver **bỏ qua** DNSSEC — khi đó IP giả `10.0.0.66` lọt qua:
> ```bash
> sudo ip netns exec client dig @10.0.0.20 bank.secure.lab A +cd +short   # -> 10.0.0.66
> ```
> So sánh: **không `+cd`** ⇒ SERVFAIL (được bảo vệ); **có `+cd`** ⇒ nhận rác. Đó chính là giá trị
> của DNSSEC.

### Bước 7 — Dọn dẹp

```bash
# Ctrl+C ở các terminal auth/resolver/attacker, rồi:
sudo bash cleanup.sh
```

---

## 5. Phòng chống / Thực hành tốt (Mitigation & Best practices)

- **Ký DNSSEC cho zone** và **xuất bản DS** lên zone cha để có chuỗi tin cậy từ gốc.
- **Bật xác thực** (validating resolver) ở phía resolver và dùng **trust anchor của gốc** (cập nhật
  theo RFC 5011).
- Dùng **NSEC3** (thay NSEC) để chống **zone walking** (liệt kê toàn bộ tên).
- **Luân chuyển khóa** định kỳ (ZSK thường xuyên, KSK thưa hơn) và quản lý thời hạn RRSIG.
- Kết hợp **DNS Cookies (RFC 7873)**, nguồn cổng ngẫu nhiên, 0x20 encoding để chống đầu độc cache
  ở lớp vận chuyển; dùng **DoT/DoH** để bảo mật đường truyền resolver↔client.
- Giám sát **SERVFAIL do bogus** — dấu hiệu cấu hình sai hoặc đang bị tấn công.

## 6. Trả lời câu hỏi ôn tập

1. **Phân biệt KSK và ZSK. Vì sao tách hai khóa?**
   **ZSK** ký các RRset dữ liệu (A, MX, …); **KSK** chỉ ký RRset **DNSKEY**. Tách ra để: KSK (được
   tham chiếu bởi DS ở zone cha) có thể **ít thay đổi** và khóa dài/an toàn hơn, trong khi ZSK
   **luân chuyển thường xuyên** mà **không phải cập nhật DS** ở cha → vận hành linh hoạt, giảm rủi
   ro lộ khóa.

2. **Cờ AD trong câu trả lời nghĩa là gì? Ai đặt nó?**
   **AD = Authenticated Data**: **resolver xác thực** đặt cờ này khi nó đã kiểm chứng thành công
   chuỗi chữ ký (DS→DNSKEY→RRSIG) tới một trust anchor. Nó **không** do server uy quyền đặt, và chỉ
   đáng tin trên kênh resolver↔client được bảo vệ (vì cờ AD trong gói có thể bị sửa trên đường).

3. **Vì sao ở Bước 6 resolver trả SERVFAIL thay vì IP giả `10.0.0.66`?**
   Resolver có **trust anchor** cho `secure.lab` nên yêu cầu mọi RRset phải kèm **RRSIG hợp lệ** ký
   bằng DNSKEY khớp anchor. Zone giả của attacker **không ký** (thiếu RRSIG/DNSKEY khớp) → xác thực
   **thất bại → bogus** → resolver **từ chối trả về** (`SERVFAIL`), bảo vệ client khỏi IP giả.

4. **DNSSEC bảo vệ điều gì và KHÔNG bảo vệ điều gì?**
   **Bảo vệ**: tính **toàn vẹn & xác thực nguồn gốc** của dữ liệu DNS (chống giả mạo/sửa đổi/đầu
   độc cache, kể cả chứng minh "tên không tồn tại"). **Không bảo vệ**: **tính bí mật** (DNSSEC
   **không mã hóa**, truy vấn vẫn lộ — cần DoT/DoH), không chống DDoS, và không bảo đảm chặng
   resolver↔client nếu chặng đó không được bảo mật (phải tin resolver + kênh tới nó).

5. **NSEC khác NSEC3 ở điểm nào?**
   Cả hai **xác thực sự phủ định** (tên/kiểu không tồn tại). **NSEC** liệt kê tên kế tiếp dưới dạng
   **rõ** → cho phép **zone walking** (lần ra toàn bộ tên). **NSEC3** dùng **băm** tên (có salt) để
   che danh sách, chống liệt kê, đổi lại tốn tính toán hơn.

## 7. Tài liệu tham khảo

- **RFC 4033 / 4034 / 4035** — DNSSEC: giới thiệu, bản ghi (DNSKEY/RRSIG/NSEC/DS), giao thức.
- **RFC 5155** — DNSSEC Hashed Authenticated Denial of Existence (NSEC3).
- **RFC 6781** — DNSSEC Operational Practices (quản lý & luân chuyển khóa).
- **RFC 5011** — Automated Updates of DNSSEC Trust Anchors.
- **Kaminsky (2008)** — DNS cache poisoning; động lực triển khai DNSSEC.
