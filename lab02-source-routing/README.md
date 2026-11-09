# Lab 02 — IP Source Routing (LSRR/SSRR)

**Phụ trách:** Hải
**Mục tiêu:** quan sát IP source routing trong topology cô lập, so sánh trạng thái dễ bị tấn công với cấu hình phòng thủ.

> Chỉ chạy trong máy ảo/network namespace do bạn sở hữu hoặc được ủy quyền. Các script chỉ tạo namespace `h1` và `h2`, không cấu hình router hay mạng thật của máy chủ.

## Topology

```text
h1 / attacker                         h2 / victim
10.0.0.1  <==== veth1 <-> veth2 ====>  10.0.0.2
```

`h1` gửi ICMP với nguồn giả `10.0.0.77`. Gói có IP option LSRR/SSRR chứa tuyến `[10.0.0.1, 10.0.0.2]`. Khi kernel chấp nhận source route, phản hồi có thể quay lại `10.0.0.1` thay vì địa chỉ nguồn giả.

## Yêu cầu

- Linux VM (Kali/Ubuntu) có quyền root và `iproute2`.
- Python 3 và Scapy trong namespace `h1` (nếu thiếu: `python3 -m pip install scapy`).
- `tcpdump` là tùy chọn để quan sát IHL/IP options.

## Chạy lab

```bash
cd lab02-source-routing
sudo bash ./setup_pair.sh
sudo ip netns exec h1 python3 ./source_route.py --mode ssrr
sudo ip netns exec h1 python3 ./source_route.py --mode lsrr
```

Quan sát gói có IP options ở terminal khác:

```bash
sudo ip netns exec h2 tcpdump -i veth2 -nn -vv 'ip[0] & 0x0f > 5'
```

Kiểm thử tự động cả hai trạng thái:

```bash
sudo bash ./verify.sh
```

Kết thúc:

```bash
sudo bash ./cleanup.sh
```

## Kết quả mong đợi

Ở trạng thái mô phỏng dễ bị tấn công (`accept_source_route=1`), probe có thể tạo ICMP echo reply về `h1`. Sau khi đặt `net.ipv4.conf.all.accept_source_route=0` và `net.ipv4.conf.veth2.accept_source_route=0`, `h2` phải loại bỏ source-routed packet và không còn reply.

Kernel Linux hiện đại hoặc driver có thể vẫn loại gói source-routed dù sysctl đã bật. Khi đó ghi nhận giá trị sysctl và packet capture; không cố ép gói qua mạng thật. `verify.sh` không coi lần thử vulnerable thất bại là lỗi, nhưng bắt buộc trạng thái phòng thủ không được tạo reply.

## Phòng thủ

- Giữ `net.ipv4.conf.all.accept_source_route=0` và cấu hình tương ứng trên interface.
- Lọc LSRR/SSRR tại firewall/biên mạng; phát hiện nhanh bằng IHL > 5.
- Duy trì reverse-path filtering phù hợp (`rp_filter`) để giảm spoofing.

## Câu hỏi ôn tập

1. LSRR khác SSRR ở yêu cầu đối với các router trung gian như thế nào?
2. Vì sao IP header có source-route option có IHL lớn hơn 5?
3. Nếu không có source route, phản hồi tới nguồn giả `10.0.0.77` sẽ đi đâu?
4. Vì sao lọc IP options ở biên mạng hiệu quả hơn chỉ lọc tại victim?

## Tham khảo

- RFC 791 — Internet Protocol, IP Options.
- RFC 7126 — Recommendations on Filtering of IPv4 Packets Containing IPv4 Options.
