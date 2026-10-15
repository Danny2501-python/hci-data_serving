-- Port 1:1 từ jupiter_sand_box/quentk_3_report_kpi_bonus_commission_New_sys.py,
-- hàm `step_report_kpi_commission()` (dòng 830-844) — bảng Doanh số/Thưởng chênh lệch cấp Payment
-- (1 dòng = 1 lần thanh toán, CHƯA "unpivot" theo Tư vấn viên — xem model
-- `report_kpi_bonus_commission_transpose` cho bảng theo Tư vấn viên).
--
-- ⚠ 3 điểm KHÁC BIỆT CHỦ ĐÍCH so với bản gốc — không phải port cơ học:
--   1. Bản gốc DELETE+INSERT vào bảng Postgres CÓ SẴN tại sandbox `staging_sci` (10.10.10.226) — DAG
--      Airflow `quentk_3_report_kpi_bonus_commission_New_sys` vẫn đang ghi bảng đó MỖI NGÀY (đã xác
--      nhận qua bao_cao_tableau/fix_bao_cao_ds_ban_co_so_20260830.md). Bảng dbt này nằm ở DB khác hẳn
--      (DB mà dbt project `data_serving` đang target — xem profiles.yml, KHÔNG PHẢI staging_sci) — chỉ
--      TRÙNG TÊN, chưa đụng/thay thế bảng production đang live. Vì là bảng MỚI nên được TỰ CHỌN
--      schema = toàn bộ cột của int_rkbc_step1_commission, không giới hạn theo "existing_columns" của
--      bảng đích như bản gốc phải làm (do bản gốc không biết trước schema bảng có sẵn).
--   2. Bản gốc chỉ ghi khi `dfc['id'].is_unique`, ngược lại chỉ `print` WARNING rồi ÂM THẦM BỎ QUA cả
--      batch (không raise lỗi, Airflow vẫn báo SUCCESS). Bản dbt này CỐ Ý đổi thành fail-loudly bằng
--      dbt test `unique`/`not_null` trên cột `id` (xem schema.yml cùng thư mục) — lỗi trùng `id` sẽ lộ
--      ra ngay ở `dbt test` thay vì bị nuốt im lặng.
--   3. Cơ chế DELETE (theo cửa sổ payment_date >= mốc rolling `rkbc_floor_date`, giống hệt
--      `int_rkbc_base_payment.sql`) + INSERT/append phần vừa tính lại — dùng đúng pattern
--      incremental + pre_hook đã có sẵn trong project (xem
--      models/stag_his_supply/mart/mart_shs_form_supply.sql) để KHÔNG mất lịch sử các lần chạy trước,
--      vì tầng int chỉ tính cửa sổ rolling, không có toàn bộ lịch sử từ 01/04/2024.
--
-- ⚠ CHƯA chạy thử qua `dbt run`/`dbt test` thật (chỉ soát tay so với int_rkbc_step1_commission) — cần
-- verify trước khi tin số liệu, đặc biệt lần build ĐẦU TIÊN sẽ CHỈ có dữ liệu từ `rkbc_floor_date`
-- trở đi (chưa backfill lịch sử cũ, theo đúng quyết định đã thống nhất).
{{ config(
    materialized='incremental',
    incremental_strategy='append',
    post_hook="{{ rkbc_update_info(this) }}",
    pre_hook="{% if is_incremental() %}delete from {{ this }} where brand_etl > 0 and payment_date >= (select greatest(date_trunc('month', current_date - interval '15 days')::date, '{{ var(\"rkbc_floor_date\", \"2026-08-01\") }}'::date)){% endif %}"
) }}

select * from {{ ref('int_rkbc_step1_commission') }}
