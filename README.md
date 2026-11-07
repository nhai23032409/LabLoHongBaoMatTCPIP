# Lab Lỗ hổng Bảo mật TCP/IP

Repository thực hành các lỗ hổng cơ bản trong protocol stack TCP/IP.

## Phân công

| Lab | Chủ đề | Phụ trách |
|---|---|---|
| 01 | TCP Sequence Number Prediction | Hải |
| 02 | IP Source Routing (LSRR/SSRR) | Khoa |
| 03 | ICMP Tunneling | Khoa |
| 04 | Smurf Attack | Hạnh |
| 05 | ICMP Redirect (MITM) | Hạnh |
| 06 | Teardrop | Hạnh |
| 07 | DNSSEC | Hải |

## Môi trường

Các bài thực hành sử dụng Linux network namespace, veth pair, Python/Scapy,
tcpdump, iproute2, iptables và các công cụ được nêu trong README của từng lab.

## An toàn

Chỉ thực hiện các bài lab trong máy ảo, network namespace hoặc môi trường
được ủy quyền. Không chạy các kỹ thuật này trên hệ thống hay mạng bên ngoài
phạm vi cho phép.

## Cấu trúc

- `lab01-tcp-seq/` — Hải
- `lab02-source-routing/` — Khoa
- `lab03-icmp-tunneling/` — Khoa
- `lab04-smurf/` — Hạnh
- `lab05-icmp-redirect/` — Hạnh
- `lab06-teardrop/` — Hạnh
- `lab07-dnssec/` — Hải

Mỗi thành viên chỉ sửa thư mục lab được phân công. Nhánh `main` dùng để tích
hợp; công việc mới thực hiện trên nhánh riêng và mở Pull Request vào `main`.
