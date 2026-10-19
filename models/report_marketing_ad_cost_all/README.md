# report_marketing_ad_cost_all — Báo cáo marketing tổng hợp nhiều brand

Gom báo cáo marketing của các brand **trong nước** vào 1 bảng để làm dashboard tổng.

**Bảng:** `public_sandbox_mkt.report_marketing_ad_cost_all` (khai báo schema `sandbox_mkt`; dbt mặc định
thêm tiền tố `public_` – giữ nguyên, không sửa macro `generate_schema_name` dùng chung).
Nguyên tắc: **cái gì các brand đã có chung thì gom ngay, cái gì chưa khớp thì giữ nguyên / để trống, map sau.**

Model **chỉ đọc kết quả** của các model marketing sẵn có, không sửa logic từng brand
→ số mỗi brand trong bảng tổng **luôn khớp** báo cáo riêng của brand đó.

| Brand | Model nguồn | Bảng nguồn |
|---|---|---|
| Kangnam | `mart_report_marketing_ad_cost_kn` | `public.report_marketing_ad_cost_kn_v2` |
| Paris | `mart_report_marketing_ad_cost_pr` | `public.report_marketing_ad_cost_pr_v2` |

## Cột

26 cột **giống hệt** `report_marketing_ad_cost_kn_v2` (tên, thứ tự) + cột `brand` ở cuối
→ dashboard Tableau Kangnam chỉ cần đổi nguồn bảng và thêm bộ lọc `brand`.

Chuẩn hoá phía Paris:

| Paris | Bảng tổng |
|---|---|
| `dt` | `Metric` |
| `date` (timestamp) | `date` (date) |
| `nguon`, `nhom_nguon` | `Nguon`, `Nhom_nguon` |
| (không có) | `nhom_dv_kh_quan_tam_goc` = NULL — map sau |

## Chỉ số (`type_data`)

| Loại | Xử lý |
|---|---|
| Cost_fb_cd, Cost_fb_th, Lead, BKHL, HL, DC, TC, DS | Cùng tên → gom luôn |
| Paris `ib` / `google` / `Deal_cs` | Cùng ý nghĩa → đổi về `inbox` / `Google_cd` / `DealCS` |
| Paris `BK`, `tiktok` | Chỉ Paris có → giữ nguyên tên, map sau |

Cách đếm giữ như báo cáo riêng: chi phí / inbox / doanh số → SUM(`Metric`);
Lead / booking / đến cửa / thành công → COUNTD(`Metric`) (SĐT). Luôn lọc theo `brand` + `type_data`.

## Chưa gom (làm sau)

- **Sunwoo** (Philippines): dự án nước ngoài, khác thị trường / tiền tệ → để riêng (`sandbox_ph`).
- **Hồng Hà, Tiêu Hóa Việt**: chưa có model marketing (chi phí FB, khách CRM, doanh số EHC).
- Cột riêng Paris: `product_type`, `product_category`.
- Chi phí FB: một số tài khoản quảng cáo xuất hiện ở cả `brand_etl` 1 và 3 trong `cs_facebook_insight`
  → kiểm tra không tính trùng giữa Kangnam và Paris khi xem tổng.

## Build

```bash
dbt build --select report_marketing_ad_cost_all --profiles-dir .
```
Chỉ build bảng tổng (đọc bảng Kangnam / Paris đã có). **Không** dùng `+` (sẽ build lại toàn bộ model Kangnam / Paris).
Lịch chạy: đặt **sau** job Kangnam và Paris.
