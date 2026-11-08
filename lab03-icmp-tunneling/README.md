# Lab 03 — ICMP Tunneling

**Phụ trách:** Hải

> Chỉ chạy trong máy ảo hoặc network namespace do bạn sở hữu/được ủy quyền. Các script chỉ tạo `h1` và `h2` trong môi trường lab cô lập.

## Mục tiêu

- Nhúng dữ liệu có kiểm soát vào payload ICMP echo request/reply.
- Xây dựng client/server Scapy tối giản và ACK từng chunk.
- Chứng minh rule chỉ chặn TCP không ngăn được ICMP.
- Quan sát dấu hiệu nhận biết ICMP tunnel.

## Topology

```text
h1 / client 10.0.0.1  <==== veth1 <-> veth2 ====>  h2 / server 10.0.0.2
```

## Yêu cầu

Linux VM (Kali/Ubuntu), quyền root, `iproute2`, `iptables`, `tcpdump`, Python 3 và Scapy. Cài Scapy nếu thiếu:

```bash
sudo apt install -y iproute2 iputils-ping iptables tcpdump python3-scapy
```

## Chạy thủ công

```bash
cd lab03-icmp-tunneling
sudo bash ./setup_pair.sh
```

Terminal server:

```bash
sudo ip netns exec h2 python3 ./icmp_server.py --count 3
```

Terminal client:

```bash
sudo ip netns exec h1 python3 ./icmp_client.py --text 'secret-token-ABC123' --chunk 8
```

Gửi nội dung file mẫu trong namespace client:

```bash
# Khởi động lại server cho số chunk không xác định; dừng bằng Ctrl-C sau khi xong.
sudo ip netns exec h2 python3 ./icmp_server.py --count 0
sudo ip netns exec h1 python3 ./icmp_client.py --file /etc/hostname
```

Quan sát payload dạng ASCII:

```bash
sudo ip netns exec h2 tcpdump -i veth2 -nn -A icmp
```

## Kiểm tra firewall

Thêm rule chỉ drop TCP trên server namespace:

```bash
sudo ip netns exec h2 iptables -A INPUT -p tcp -j DROP
sudo ip netns exec h1 python3 ./icmp_client.py --text 'icmp-is-still-allowed'
```

ICMP vẫn phải nhận ACK. Xóa rule và namespace:

```bash
sudo bash ./cleanup.sh
```

## Kiểm thử tự động

```bash
sudo bash ./verify.sh
```

`verify.sh` dựng không tự động topology; hãy chạy `setup_pair.sh` trước. Script gửi payload qua ICMP, thêm TCP DROP trong `h2`, gửi tiếp ICMP và kiểm tra server log nhận đủ cả hai payload.

## Kết quả và phòng thủ

Payload tùy ý trong ICMP echo có thể vượt qua bộ lọc chỉ quan tâm TCP/UDP port. Dấu hiệu phát hiện gồm payload lớn hoặc có entropy bất thường, tần suất echo cao, chu kỳ đều, và tỷ lệ request/reply bất thường.

Phòng thủ nên kết hợp egress filtering, giới hạn/chặn ICMP echo khi không cần, IDS/IPS phân tích ICMP payload và giám sát hành vi. Không nên chỉ dựa vào firewall lọc TCP/UDP.

## Câu hỏi ôn tập

1. Vì sao payload ICMP phù hợp để giấu dữ liệu? Ping hợp lệ thường có payload khoảng bao nhiêu byte?
2. Vì sao firewall lọc theo port không chặn được ICMP tunnel?
3. Nêu ba đặc trưng giúp IDS phát hiện ICMP tunnel.
4. Nếu payload được mã hóa, phương pháp phát hiện nào vẫn còn hiệu lực?

## Tham khảo

- RFC 792 — Internet Control Message Protocol.
- Loki project — ICMP covert channel.
- ptunnel và icmptunnel — công cụ tham khảo.
