# data_serving — dbt Project

Dự án dbt phục vụ tầng **Data Serving** của data warehouse, cung cấp các báo cáo
và tập dữ liệu đã được làm sạch cho BI và analytics.

---

## Kết nối Data Warehouse

| Thông số    | Giá trị          |
|-------------|------------------|
| Type        | PostgreSQL        |
| Host        | 10.10.10.214      |
| Port        | 5432              |
| Database    | new_product       |
| Schema      | public            |
| Profile     | data_serving      |

Cấu hình kết nối nằm tại `profiles.yml`.

---

## Cấu trúc thư mục

```
data_serving/
├── models/                          # Toàn bộ dbt models
│   ├── common/                      # Model dùng chung (ephemeral)
│   ├── data_dictionary/             # Bảng data dictionary của data warehouse
│   ├── master_data/                 # Dimension tables dùng chung
│   ├── func_report_marketing_ad_cost_kn/   # Báo cáo chi phí marketing Kangnam
│   ├── func_report_marketing_ad_cost_pr/   # Báo cáo chi phí marketing Paris
│   ├── func_report_operation_team_seeding/ # Báo cáo team vận hành seeding
│   ├── report_deposit/              # Báo cáo đặt cọc
│   ├── report_erp_source_change/    # Báo cáo thay đổi nguồn ERP
│   ├── report_hqcd_page/            # Báo cáo hiệu quả chi phí theo page
│   ├── report_kn_sale_online/       # Báo cáo bán hàng online Kangnam
│   ├── report_marketing_kn_dvda/    # Báo cáo marketing KN – dịch vụ da
│   ├── report_marketing_kn_dvda_tq/ # Báo cáo marketing KN – dịch vụ da tổng quát
│   ├── report_phone_call_after_service/    # Báo cáo cuộc gọi sau dịch vụ
│   ├── report_portal_usage/         # Báo cáo sử dụng portal
│   ├── report_pr_consultant/        # Báo cáo tư vấn Paris
│   ├── report_pt_dbds_paris/        # Báo cáo PT đổi bộ dịch sản Paris
│   ├── report_pt_dbds_paris_chinhanh/      # Báo cáo PT ĐBDS Paris theo chi nhánh
│   ├── report_tong_quan_ds_kn/      # Báo cáo tổng quan doanh số Kangnam
│   ├── report_tong_quan_ds_pr/      # Báo cáo tổng quan doanh số Paris
│   └── report_vong_doi_kh_kn/       # Báo cáo vòng đời khách hàng Kangnam
│
├── seeds/                           # File CSV tĩnh load vào database
│   ├── seeds.yml                    # Khai báo kiểu dữ liệu cho từng seed
│   ├── ucbt_country_continent.csv   # Mapping quốc gia – lục địa
│   └── import_stag_employee_null.csv
│
├── macros/                          # Jinja macros dùng chung
├── analyses/                        # SQL phân tích ad-hoc (không tạo bảng)
├── snapshots/                       # dbt snapshots – theo dõi thay đổi dữ liệu
├── tests/                           # Custom data tests
├── target/                          # Compiled artifacts (không commit)
├── dbt_project.yml                  # Cấu hình chính của dự án
└── profiles.yml                     # Cấu hình kết nối database
```

---

## Cấu trúc bên trong mỗi model domain

Hầu hết các report domain theo cấu trúc 3 lớp:

```
report_<ten_bao_cao>/
├── stg/           # Staging – làm sạch, đổi tên cột, ép kiểu từ source
│   └── sources.yml
├── int/           # Intermediate – join, tính toán, logic nghiệp vụ
└── mart/          # Mart – bảng cuối cùng phục vụ BI
    └── schema.yml
```

| Lớp   | Materialized | Vai trò |
|-------|-------------|---------|
| `stg` | ephemeral   | Chuẩn hóa dữ liệu thô từ source, không lưu vật lý |
| `int` | ephemeral   | Kết hợp nhiều stg, xử lý logic nghiệp vụ |
| `mart`| table       | Bảng kết quả cuối, lưu vật lý vào database |

---

## Quy ước đặt tên

| Tiền tố | Lớp | Ví dụ |
|---------|-----|-------|
| `stg_`  | Staging     | `stg_rpcas_crm_line_info` |
| `int_`  | Intermediate| `int_rpcas_ps` |
| `mart_` | Mart        | `mart_frots_operation_team_seeding` |
| `report_` | Mart (kết quả báo cáo) | `report_rpcas_phone_call_final` |
| `dim_`  | Dimension   | `dim_campaign`, `dim_region` |

Tên file SQL trong `stg/` và `int/` thường có mã viết tắt của domain:

- `rpcas` → report_phone_call_after_service
- `frmack` → func_report_marketing_ad_cost_kn
- `frmacpr` → func_report_marketing_ad_cost_pr
- `frots` → func_report_operation_team_seeding
- `resc` → report_erp_source_change
- `rhp` → report_hqcd_page
- `kso` → report_kn_sale_online
- `dps` → report_deposit

---

## Tags

Tags dùng để chạy từng nhóm model riêng biệt:

| Tag | Domain |
|-----|--------|
| `data_dictionary` | Bảng data dictionary |
| `master_data`     | Master / dimension tables |
| `report_kn`       | Marketing Kangnam |
| `report_pr`       | Marketing Paris |
| `report_kn_dvda`  | Marketing KN dịch vụ da |
| `report_rmkdt`    | Marketing KN dịch vụ da tổng quát |
| `report_hqcd_page`| Hiệu quả chi phí theo page |
| `report_portal_usage` | Portal usage |
| `report_erp_source_change` | Thay đổi nguồn ERP |
| `report_phone_call_after_service` | Cuộc gọi sau dịch vụ |
| `report_tong_quan_ds_kn` | Tổng quan DS Kangnam |
| `report_tong_quan_ds_pr` | Tổng quan DS Paris |
| `report_frots`    | Team vận hành seeding |
| `report_ptdbdsp`  | PT ĐBDS Paris |
| `report_ptdbdspc` | PT ĐBDS Paris chi nhánh |
| `report_kso`      | Bán hàng online Kangnam |
| `report_prs`      | Tư vấn Paris |
| `report_vong_doi_kh_kn` | Vòng đời khách hàng Kangnam |
| `report_dps`      | Đặt cọc |

---

## Biến dự án (vars)

Khai báo trong `dbt_project.yml`:

| Biến | Giá trị mặc định | Mô tả |
|------|-----------------|-------|
| `start_date` | `2025-08-01` | Ngày bắt đầu backfill dữ liệu |
| `all_brand_etl` | `(1,3,4,7)` | Danh sách brand_id đưa vào ETL |

---

## Các lệnh thường dùng

```bash
# Chạy toàn bộ dự án
dbt run

# Chạy một domain cụ thể theo tag
dbt run --select tag:report_kn

# Chạy một model cụ thể
dbt run --select data_dictionary

# Chạy model và toàn bộ upstream (source → mart)
dbt run --select +mart_frots_operation_team_seeding

# Compile SQL (kiểm tra trước khi chạy)
dbt compile --select data_dictionary

# Chạy data tests
dbt test

# Load seed files lên database
dbt seed

# Xem lineage (dùng với dbt docs)
dbt docs generate
dbt docs serve
```

---

## Data Dictionary

Bảng `data_dictionary` trong schema `public` tổng hợp metadata của toàn bộ
bảng/cột trong data warehouse. Chi tiết xem tại
[`models/data_dictionary/schema.yml`](models/data_dictionary/schema.yml).

Để thêm mô tả cho một cột, chạy trực tiếp trên PostgreSQL:

```sql
COMMENT ON COLUMN ten_bang.ten_cot IS 'Mô tả ý nghĩa';
```

Sau đó chạy lại `dbt run --select data_dictionary` để đồng bộ.
