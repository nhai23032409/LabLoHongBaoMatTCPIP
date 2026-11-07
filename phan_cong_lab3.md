# Phân công Đồ án 3 — Lab Lỗ hổng Bảo mật TCP/IP

## Tóm tắt 7 lab

| Lab | Chủ đề | Công cụ chính | Topo | Độ nặng |
|-----|--------|---------------|------|---------|
| 01 | TCP Sequence Number Prediction | Scapy (2 script: `isn_sampler.py`, `spoof_sniff.py`) | veth pair | Vừa (3) |
| 02 | IP Source Routing (LSRR/SSRR) | Scapy (`ssrr.py`) | veth pair | Vừa (2.5) |
| 03 | ICMP Tunneling | Scapy (client + server) + iptables | veth pair | Vừa (3) |
| 04 | Smurf Attack | Scapy inline | bridge 5 host | Dễ (2) |
| 05 | ICMP Redirect (MITM) | Scapy inline + iproute2 | bridge + router ảo | Khó (4) |
| 06 | Teardrop | Scapy inline | veth pair | Dễ (2) |
| 07 | DNSSEC | BIND9 + unbound + dig | bridge 4 host | Khó nhất (5) |

## 1) Phân công (khối lượng ~ cân bằng: 7.5 / 8 / 8)

| Người | Nhiệm vụ | Khối lượng |
|-------|----------|-----------|
| **Khoa** | **Dựng repo** + Lab02 + Lab03 | ~7.5 |
| **Hải**  | Lab01 + Lab07 | ~8 |
| **Hạnh** | Lab04 + Lab05 + Lab06 | ~8 |

Khoa nhận ít lab hơn một chút vì gánh thêm phần dựng repo (việc một lần, nhưng tốn công). Hai lab Khoa giữ
(02, 03) đều dùng chung topo `veth pair` + Scapy, làm liền mạch nên hiệu quả. Hải ôm Lab07 (DNSSEC — nặng nhất)
kèm Lab01 (nhẹ hơn). Hạnh gom 3 lab nhưng gồm 2 lab dễ (04, 06) + 1 lab khó (05).

## 2) Chống đụng code của nhau

**Nguyên tắc: mỗi người sở hữu trọn vẹn từng lab → mỗi lab một thư mục riêng → không ai sửa file của người khác.**

Cấu trúc repo Khoa dựng:

```
LabLoHongBaoMatTCPIP/
├─ README.md               (Khoa)
├─ .gitignore              (bỏ *.pid, *.key, /tmp artifacts)
├─ lab01-tcp-seq/          → Hải
├─ lab02-source-routing/   → Khoa
├─ lab03-icmp-tunneling/   → Khoa
├─ lab04-smurf/            → Hạnh
├─ lab05-icmp-redirect/    → Hạnh
├─ lab06-teardrop/         → Hạnh
└─ lab07-dnssec/           → Hải
```

- **Mỗi lab tự chứa bản `setup_*.sh` riêng** (không tạo file dùng chung). Lab 01/02/03/06 cùng dùng
  `setup_pair.sh` giống nhau, nhưng để *mỗi thư mục một bản copy* — tránh file chung bị nhiều người sửa cùng lúc.
- **Git workflow**: `main` chỉ để gộp; mỗi người làm trên nhánh riêng theo lab, ví dụ `hai/lab07`,
  `hanh/lab05`, mở PR vào `main`. Vì không trùng thư mục nên PR gần như không bao giờ conflict.
- Khoa làm **README gốc** (mục lục + hướng dẫn chạy chung); mỗi người tự viết `README.md` trong thư mục lab
  của mình.

**Việc đầu tiên của Khoa**: tạo repo, đẩy khung thư mục rỗng (7 folder + README + .gitignore) lên `main`,
mời Hạnh & Hải làm collaborator. Xong là hai bạn kia clone và bắt tay vào lab của mình ngay.
