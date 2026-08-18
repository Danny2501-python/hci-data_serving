# knowledge.md — Cách benchmark hiệu năng SQL trong dbt (Postgres)

Ghi lại phương pháp đã dùng để so sánh hiệu năng/độ đúng giữa các cách viết SQL
khác nhau (case cụ thể: tách `nhom_dv_chinh_cs` từ `custom_fields` — JSON parse
`::jsonb` vs. regex) khi không có sẵn công cụ benchmark trong dbt CLI.

## 1. Vấn đề: `dbt show`/`dbt compile` không chạy được `EXPLAIN`

`dbt show --inline "..."` tự động bọc câu query trong
`SELECT * FROM (<query>) AS x LIMIT N`, nên không thể dùng để chạy
`EXPLAIN (ANALYZE, ...)` (không phải câu lệnh trả bảng, bị lỗi cú pháp
`syntax error at or near "limit"`). `dbt compile` chỉ dịch Jinja → SQL, không
chạy được trên database.

**Cách vượt qua:** viết một **macro tạm** (`macros/_tmp_*.sql`) dùng
Jinja `{% set query %}...{% endset %}` để build câu SQL thô (có thể dùng
`{{ source(...) }}`/`{{ ref(...) }}` để tự resolve tên bảng thật), rồi gọi
`run_query()` — API nội bộ của dbt để execute SQL trực tiếp qua adapter và trả
về `agate.Table`:

```sql
{% macro tmp_explain_xxx() %}
{% set query %}
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ...
FROM {{ source('kangnam', 'cs_ticket_api') }} cta
WHERE ...
{% endset %}
{% set result = run_query(query) %}
{% do result.print_table(max_column_width=200, max_rows=200) %}
{% endmacro %}
```

Chạy bằng:

```
dbt run-operation tmp_explain_xxx --quiet
```

**Luôn xoá file macro tạm này sau khi dùng xong** (`rm macros/_tmp_*.sql`) —
nó không thuộc về model nào, để sót lại dbt vẫn sẽ compile nó như một macro
thật của project.

## 2. Lỗi encoding trên Windows console

Khi output SQL compile/log chứa tiếng Việt có dấu, `dbt compile`/`dbt
run-operation` chạy trên PowerShell/Git Bash mặc định có thể crash với
`UnicodeEncodeError: 'charmap' codec can't encode character ...` (console
Windows dùng code page cp1252, không encode được ký tự Unicode ngoài
Latin-1). Đây **không phải lỗi SQL** — chỉ là lỗi in log ra console.

**Cách vượt qua:** set `PYTHONIOENCODING=utf-8` trước khi chạy:

```
PYTHONIOENCODING=utf-8 dbt run-operation tmp_explain_xxx --quiet
```

## 3. Đo hiệu năng: `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` trên dữ liệu thật

Không suy đoán "cách này chắc nhanh hơn" — luôn đo trên **đúng tập dữ liệu đã
filter** (cùng `WHERE` như trong model thật), không đo trên bảng rỗng/dev nhỏ.
Đọc 3 chỉ số chính trong plan:

- **`Execution Time`** — tổng thời gian thực thi (số đáng tin nhất để so sánh).
- **`Buffers: shared hit=... read=...`** — số block đọc từ disk/cache; đọc
  nhiều thường là nguyên nhân chính (I/O-bound), không phải CPU.
- **Loại node & `loops=N`** — ví dụ `Nested Loop` với
  `Function Scan on jsonb_array_elements ... loops=446577` cho biết chi phí bị
  nhân lên theo từng dòng nguồn (LATERAL chạy lại 1 lần/dòng).

Ví dụ kết quả đo thực tế (case `nhom_dv_chinh_cs`, ~446K dòng sau filter):

| Cách | Execution Time | Ghi chú |
|---|---|---|
| Không tách `custom_fields` (baseline) | ~6.1s | Chỉ có 2 regex đơn giản (`sdt`, `ad_id`) |
| `::jsonb` + `LATERAL jsonb_array_elements(...) LIMIT 1` | ~44.2s | Đúng, nhưng cast+parse JSON tốn CPU |
| Regex `.*?"value":...` (không giới hạn) | ~230s | **Chậm nhất** — xem mục 4 vì sao |
| Regex `[^}]*?"value":...` (giới hạn theo object) | ~42.0s | Đúng, ngang JSON — không có lợi thế tốc độ |

## 4. Đo độ đúng: so sánh chéo trên toàn bộ tập dữ liệu, không chỉ xem mẫu

Một cách viết "nhìn có vẻ đúng" trên vài dòng mẫu (`LIMIT 10`) vẫn có thể sai
hệ thống ở quy mô lớn. Cách kiểm chứng đáng tin: build 1 CTE tính cả 2 phương
án song song rồi đếm số dòng lệch nhau trên **toàn bộ tập dữ liệu đã filter**:

```sql
WITH cmp AS (
    SELECT
        cta.ticket_id,
        (<cách A>) AS via_a,
        (<cách B>) AS via_b
    FROM ... WHERE <đúng filter của model thật>
)
SELECT
    count(*) AS total_rows,
    count(*) FILTER (WHERE via_a IS DISTINCT FROM via_b) AS mismatch_count
FROM cmp
```

Case thực tế: regex `.*?"value":...` nhìn qua tưởng đúng, nhưng so trên toàn
bộ 446,577 dòng thì **167,999 dòng (~38%) bị sai** — có dòng trả về giá trị
`"161646"` hoàn toàn không liên quan thay vì `"151866"` đúng.

**Nguyên nhân (bài học quan trọng về regex trong Postgres):** Postgres dùng
ngữ nghĩa **leftmost-longest**, khác với PCRE/Perl. Khi pattern có dấu ngoặc
(capturing group), engine luôn tìm **match tổng thể dài nhất có thể** bắt đầu
từ vị trí sớm nhất — quantifier non-greedy (`.*?`) chỉ ảnh hưởng đến cách chọn
subexpression *trong số các match có cùng độ dài tổng*, **không** làm match
tổng thể ngắn lại như kỳ vọng kiểu Perl. Vì `custom_fields` là JSON array có
nhiều phần tử với nhiều key `"value"` lặp lại, `.*?"value":...` bị kéo dài
xuyên qua nhiều phần tử phía sau thay vì dừng ở `"value"` gần nhất sau
`"id": 9794`.

**Cách sửa:** giới hạn phần "nhảy" bằng character class phủ định gắn với ranh
giới cấu trúc thật (ở đây là `}` đóng JSON object), để engine **không thể**
vượt qua ranh giới đó bất kể ngữ nghĩa leftmost-longest:

```sql
-- Sai (leftmost-longest kéo dài qua nhiều object):
SUBSTRING(custom_fields FROM '"id":\s*9794,.*?"value":\s*(?:"([^"]*)"|null)')

-- Đúng (bị chặn cứng bởi '}' đóng object hiện tại):
SUBSTRING(custom_fields FROM '"id":\s*9794,[^}]*?"value":\s*(?:"([^"]*)"|null)')
```

Bài học tổng quát: **không dùng `.*?` (hoặc bất kỳ quantifier không giới hạn
nào) để "nhảy" tới một key lặp lại nhiều lần trong text** (JSON, XML, CSV
nhiều dòng...) nếu không bound được nó bằng một ranh giới cấu trúc rõ ràng. An
toàn nhất vẫn là parse đúng định dạng (`::jsonb`) thay vì regex khi dữ liệu có
cấu trúc lặp/nested.

## 5. Câu hỏi nên trả lời trước khi đổi 1 cách viết SQL "để nhanh hơn"

1. Đã đo trên **dữ liệu thật, đúng filter, đúng scale** chưa — hay chỉ đoán?
2. Đã so kết quả 2 cách **trên toàn bộ tập dữ liệu** (không chỉ vài dòng mẫu)
   chưa?
3. Chi phí này được trả **bao nhiêu lần**? (model `ephemeral`/`view` → trả mỗi
   lần query; model `table`/`incremental` → trả 1 lần lúc build — ảnh hưởng
   trực tiếp đến việc có đáng tối ưu hay không.)
4. Cách "nhanh hơn" có đánh đổi gì về **độ chắc chắn/độ bền trước thay đổi cấu
   trúc dữ liệu nguồn** không? (Case này: JSON đúng bất kể thứ tự key, regex
   dù đã bound đúng vẫn ngầm giả định `"value"` luôn là key cuối trong object —
   giả định đúng với dữ liệu hiện tại nhưng dễ vỡ nếu form Caresoft đổi cấu
   trúc.)

Nếu câu trả lời cho (3) là "chỉ 1 lần lúc build" và mức chênh lệch hiệu năng
đo được không lớn, ưu tiên cách **an toàn/dễ đọc hơn** thay vì cách "trông có
vẻ nhanh hơn" nhưng không đo được lợi ích rõ ràng.

## 6. Điều kiện `column IS NOT NULL` trong mệnh đề `ON` của INNER JOIN âm thầm loại cả 1 nhóm dữ liệu

Case thực tế (xem README.md mục 19): `stg_frmack_crm_base.sql` JOIN
`crm_lead` với `ON cl.id = stks.id AND cl.brand_etl = 1 AND
cl.create_by_department IS NOT NULL`. Điều kiện `create_by_department IS NOT
NULL` nhìn tưởng là lọc rác vô hại, nhưng vì nằm trong `ON` của **INNER
JOIN** nên hoạt động y hệt một `WHERE` — bất kỳ dòng nào không thỏa bị loại
thẳng, không có cách nào phát hiện qua đọc code tĩnh nếu không biết trước
phân bố NULL thực tế của cột đó.

Hậu quả: **toàn bộ 1 nhóm nghiệp vụ hợp lệ** (lead nguồn "Tái khai thác",
được tạo qua quy trình không gán `create_by_department`) bị mất khỏi model —
không phải noise ngẫu nhiên, mà là **thiên lệch có hệ thống theo đúng 1
segment dữ liệu**, rất khó phát hiện bằng cách nhìn tổng số dòng (giảm không
nhiều so với tổng) mà chỉ lộ ra khi đối chiếu chéo với 1 nguồn tính độc lập
theo từng nhóm nhỏ (ở đây là đối chiếu 2 báo cáo Tableau, soi tới từng khách
hàng lệch, xem "Nguồn" của case lệch).

**Bài học:**
1. Với bất kỳ điều kiện `X IS NOT NULL` (hoặc bất kỳ điều kiện lọc business
   rule nào) đặt trong `ON` của `JOIN` (không phải `LEFT JOIN ... WHERE`),
   luôn tự hỏi: điều kiện này có ý định loại **rác/edge-case hiếm**, hay có
   thể trùng với đặc điểm của **1 segment nghiệp vụ hợp lệ nào đó**? Nếu
   không chắc, kiểm tra phân bố NULL của cột đó theo từng nhóm nguồn/loại dữ
   liệu (`GROUP BY nguon, (col IS NULL)`) trước khi chấp nhận điều kiện.
2. Cách phát hiện hiệu quả nhất không phải đọc lại SQL, mà là **đối chiếu
   chéo kết quả với 1 nguồn tính độc lập, ở mức chi tiết đủ nhỏ** (từng
   khách hàng/từng dòng, không chỉ tổng số) — tổng số liệu tổng hợp có thể
   trông "gần đúng" (lệch <1.5%) trong khi thực chất đang mất sạch 1 nhóm cụ
   thể, chỉ là nhóm đó chiếm tỷ trọng nhỏ trên tổng.
