# Session 10 – Bài 4: Custom Network & Named Volume bằng Docker CLI

## Mục tiêu
Kết nối Backend (Node.js) và PostgreSQL bằng Docker CLI thủ công:
- 2 container gọi nhau qua tên (DNS nội bộ của custom bridge network).
- Dữ liệu DB lưu bền vững trong named volume.

## Kiến trúc
- Network: `app-net` (custom bridge)
- `app-container` (node:20-alpine, cổng 3000) kết nối DB bằng `DB_HOST=db-server`
- `db-server` (postgres:15-alpine, cổng 5432) mount volume `db-data` vào `/var/lib/postgresql/data`

## Các bước trong commands.sh
1. `docker network create --driver bridge app-net`
2. `docker volume create db-data`
3. Chạy `db-server` trong `app-net`, mount `-v db-data:/var/lib/postgresql/data`
4. Chạy `app-container` trong `app-net`, truyền `-e DB_HOST=db-server`
5. `docker exec app-container ping -c 2 db-server`
6. Test persistence: INSERT → `docker rm -f db-server` → chạy lại DB với cùng `db-data` → SELECT, dữ liệu vẫn còn

## Chạy
`bash commands.sh`

## Kiểm tra
- `docker network ls | grep app-net`
- `docker volume ls | grep db-data`
- `docker network inspect app-net`
- `docker exec -it app-container ping -c 2 db-server`

## Kết quả
- `ping db-server` phân giải ra IP nội bộ của DB (172.x.x.x), 0% packet loss.
- Sau khi xóa cứng và tạo lại `db-server`, bảng `students` vẫn còn 2 bản ghi.
- `curl localhost:3005/students` trả về dữ liệu, tức là backend kết nối DB qua hostname `db-server`.

## Giải thích
- **Custom network:** mạng `bridge` mặc định không phân giải tên container. Custom bridge có DNS nhúng (127.0.0.11), nên tên `db-server` luôn trỏ đúng IP mới, kể cả khi container được tạo lại.
- **Named volume:** `db-data` tồn tại độc lập với container. `docker rm -f` chỉ xóa container, dữ liệu trong volume vẫn giữ nguyên.
- **Bảo mật:** DB không publish cổng ra host, chỉ truy cập được từ bên trong `app-net`.
