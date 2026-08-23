{{
  config(
    materialized = 'view'
  )
}}

-- [ĐỔI 2026-08-22] Đổi tên từ stg_booking_xet_ban_cheo.sql -> stg_crm_line_ecosystem.sql, đồng bộ
-- lại main_bl_customer + is_cross_sale cho khớp logic mới nhất của stored procedure
-- func_stag_crm_line_ecosystem() (ghi bảng vật lý public.stag_crm_line_ecosystem, không nằm trong
-- dbt project — xem func_stag_crm_line_ecosystem.md). Các CTE ctg_service_type_map/uu_tien_1/
-- uu_tien_2/uu_tien_3/nhom_dich_vu_chinh CỐ TÌNH port y hệt procedure (kể cả các nghi vấn logic đã
-- ghi trong func_stag_crm_line_ecosystem.md — thiếu brand_etl ở ctg_service_type_map, thiếu dedup
-- ở uu_tien_2) để khớp 100% với bảng vật lý, KHÔNG tự sửa. KHÔNG đụng/không revert
-- stg_booking_nhom_dich_vu_chinh.sql (model đó đã chủ động đơn giản hóa bỏ 3 tầng, đang dùng chung
-- với stg_dv_khach_hang_quan_tam) — 3 tầng ưu tiên ở đây là bản viết riêng, độc lập.

WITH cline as (
    SELECT
        cl.id as crm_id,
        cl.name as code_booking,
        cl.code_customer,
        cln.brand_etl,
        cln.id as cline_id,
        cln.stage,
        cln.product_id as product_id,
        sp.product as cline_service_name,
        sp.product_category as cline_product_category,
        sp.product_ctg_id as cline_product_category_id,
        CASE
            WHEN cl.customer_come = 'yes' then cl.arrival_date + interval '7 hours'
            else cl.booking_date + interval '7 hours'
        END as booking_report_date,
        cln.create_date + interval '7 hours' as cline_created_date,
        spt.payment_date as cline_payment_date,
        spt.total_payment as cline_total_payment,
        CASE
            WHEN sp.his_service_type = 'Surgery' then 'PTTM'
            WHEN sp.his_service_type IN ('Spa','Laser','Card') then 'Beauty & Spa'
            WHEN sp.his_service_type = 'Odontology' then 'Nha khoa'
            WHEN sp.his_service_type = 'wellness' then 'Wellness'
            WHEN sp.his_service_type = 'weight_loss' then 'Weight Loss'
            ELSE 'Khác'
        END as business_line,
        rp.create_date + interval '7 hours' as partner_create_date
    FROM {{ source('crm_base', 'crm_line') }} cln
        left join {{ source('crm_base', 'crm_lead') }} cl on cl.id = cln.crm_id and cl.brand_etl = cln.brand_etl
        left join (
            SELECT clineid, brand_etl, MIN(payment_date) as payment_date, SUM(payment) as total_payment
            FROM {{ source('crm_base', 'stag_payment_transfer') }}
            GROUP BY clineid, brand_etl
        ) spt on spt.clineid = cln.id and spt.brand_etl = cln.brand_etl
        left join {{ source('crm_base', 'view_stag_products') }} sp on sp.product_id = cln.product_id and sp.brand_etl = cln.brand_etl
        left join {{ source('crm_base', 'res_partner') }} rp on cl.partner_id = rp.id and cl.brand_etl = rp.brand_etl
    WHERE cl.id in (SELECT crm_id FROM {{ ref('stg_booking_id_co_tien_tc') }})
        AND cl.type = 'opportunity'
), rnk_bl_cline as (
    -- LƯU Ý: nhiều cline trong cùng 1 booking có thể có cline_created_date GIỐNG HỆT NHAU (tạo
    -- cùng 1 batch) -> mọi ORDER BY cline_created_date đều phải kèm cline_id làm tiêu chí phụ để
    -- thứ tự ổn định, tái lập được giữa các lần chạy (nếu không, ROW_NUMBER()/FIRST_VALUE() sẽ
    -- chọn ngẫu nhiên dòng "đầu tiên" trong nhóm trùng giờ, gây sai lệch main_bl_customer/main_bl_bk).
    select cln.*,
        ROW_NUMBER() OVER (PARTITION BY cln.business_line, cln.code_customer ORDER BY cln.cline_created_date, cln.cline_id) as cus_bl_cline_order,
        ROW_NUMBER() OVER (PARTITION BY cln.crm_id ORDER BY cln.cline_created_date, cln.cline_id) as crm_cline_order,
        ROW_NUMBER() OVER (PARTITION BY cln.code_customer ORDER BY cln.cline_created_date, cln.cline_id) as cus_cline_order
    from cline cln
    WHERE cln.brand_etl = 1

-- ================================================================================================
-- [MỚI 2026-08-22] nhóm dịch vụ chính của BOOKING (crm_id), 3 tầng ưu tiên — port y hệt bước 3.5
-- của procedure func_stag_crm_line_ecosystem(), dùng để resolve main_bl_customer bên dưới (thay
-- first_value theo cline đầu tiên toàn lịch sử KH bằng business_line đã resolve của booking đầu
-- tiên). Chỉ tính cho các crm_id thực sự cần (đã có trong rnk_bl_cline).
-- ================================================================================================
), ctg_service_type_map as (
    -- his_service_type xuất hiện nhiều nhất (mode) cho mỗi product_ctg_id.
    -- [Giữ nguyên như procedure] KHÔNG group/join kèm brand_etl — xem nghi vấn trong
    -- func_stag_crm_line_ecosystem.md (mục Bước 3.5), cố tình không tự sửa để khớp 100% procedure.
    select product_ctg_id, his_service_type
    from (
        select product_ctg_id, his_service_type,
            ROW_NUMBER() OVER (PARTITION BY product_ctg_id ORDER BY COUNT(*) DESC) as rn
        from {{ source('crm_base', 'stag_products') }}
        WHERE product_ctg_id IS NOT NULL
        GROUP BY product_ctg_id, his_service_type
    ) t
    where rn = 1
), uu_tien_1 as (
    -- Tầng 1: crm_lead_product_category_rel -> product_category.name, dòng có ingestion_timestamp
    -- sớm nhất mỗi (crm_id, brand_etl).
    select rel.crm_id, rel.brand_etl, rel.nhom_dich_vu_chinh, rel.product_category_id, 1 as do_uu_tien
    from (
        select
            r.lead_id as crm_id,
            r.brand_etl,
            pc.name as nhom_dich_vu_chinh,
            r.product_category_id,
            ROW_NUMBER() OVER (PARTITION BY r.lead_id, r.brand_etl ORDER BY r.ingestion_timestamp ASC) as rn
        from {{ source('crm_base', 'crm_lead_product_category_rel') }} r
            left join {{ source('crm_base', 'product_category') }} pc
                on pc.id = r.product_category_id and pc.brand_etl = r.brand_etl
        where r.product_category_id is not null
            and r.brand_etl = 1
            and r.lead_id in (select distinct crm_id from rnk_bl_cline)
    ) rel
    where rel.rn = 1
), uu_tien_2 as (
    -- Tầng 2: custom field id=9794 ("Nhóm dịch vụ chính") trên cs_deal_detail_api_v2 ->
    -- value_lable, bóc mã trong ngoặc vuông (vd "[KNP00001] PTTM MẮT" -> "PTTM MẮT"); mã khớp
    -- thẳng product_category.code (kèm brand_etl) -> resolve product_category_id.
    -- [Giữ nguyên như procedure] KHÔNG có ROW_NUMBER()/dedup như tầng 1 và tầng 3 — xem nghi vấn
    -- trong func_stag_crm_line_ecosystem.md, cố tình không tự sửa để khớp 100% procedure.
    select
        cl.id as crm_id,
        cl.brand_etl,
        CASE
            WHEN ccf.value_lable LIKE '%]%' THEN TRIM(SPLIT_PART(ccf.value_lable, ']', 2))
            ELSE TRIM(ccf.value_lable)
        END as nhom_dich_vu_chinh,
        pc2.id as product_category_id,
        2 as do_uu_tien
    from {{ source('crm_base', 'crm_lead') }} cl
        inner join {{ source('crm_base', 'cs_deal_detail_api_v2') }} cda on cda.id = cl.ticket_id
        cross join lateral jsonb_array_elements(cda.custom_fields::jsonb) cf_elem
        left join {{ source('crm_base', 'cs_custom_fields') }} ccf
            on ccf.value_id = (cf_elem ->> 'value')
            and ccf.custom_field_id = '9794'
        left join {{ source('crm_base', 'product_category') }} pc2
            on pc2.code = SPLIT_PART(TRIM(SPLIT_PART(ccf.value_lable, ']', 1)), '[', 2)
            and pc2.brand_etl = cl.brand_etl
            and ccf.value_lable LIKE '%]%'
    where cf_elem ->> 'id' = '9794'
        and ccf.value_lable is not null
        and cl.brand_etl = 1
        and cl.id in (select distinct crm_id from rnk_bl_cline)
), uu_tien_3 as (
    -- Tầng 3 (fallback): product_category (view_stag_products) của cline sớm nhất (create_date nhỏ
    -- nhất) trong booking.
    select line.crm_id, line.brand_etl, line.nhom_dich_vu_chinh, line.product_category_id, 3 as do_uu_tien
    from (
        select
            cln.crm_id,
            cln.brand_etl,
            sp.product_category as nhom_dich_vu_chinh,
            sp.product_ctg_id as product_category_id,
            ROW_NUMBER() OVER (PARTITION BY cln.crm_id, cln.brand_etl ORDER BY cln.create_date) as rn
        from {{ source('crm_base', 'crm_line') }} cln
            left join {{ source('crm_base', 'view_stag_products') }} sp
                on sp.product_id = cln.product_id and sp.brand_etl = cln.brand_etl
        where cln.brand_etl = 1
            and cln.crm_id in (select distinct crm_id from rnk_bl_cline)
    ) line
    where line.rn = 1
        and line.nhom_dich_vu_chinh is not null
), nhom_dich_vu_chinh as (
    -- Gộp 3 tầng, tầng số nhỏ hơn thắng (rn = 1). his_service_type/business_line resolve qua
    -- ctg_service_type_map nếu có, else fallback regex trên text nhom_dich_vu_chinh.
    select
        r.crm_id,
        r.brand_etl,
        r.nhom_dich_vu_chinh,
        r.do_uu_tien as nguon_uu_tien,
        r.source_main_bl,
        r.product_category_id,
        csm.his_service_type,
        CASE
            WHEN csm.his_service_type = 'Surgery' THEN 'PTTM'
            WHEN csm.his_service_type IN ('Spa','Laser','Card') THEN 'Beauty & Spa'
            WHEN csm.his_service_type = 'Odontology' THEN 'Nha khoa'
            WHEN csm.his_service_type = 'wellness' THEN 'Wellness'
            WHEN csm.his_service_type = 'weight_loss' THEN 'Weight Loss'
            WHEN r.nhom_dich_vu_chinh ~* 'TẠO HÌNH|PHẪU THU|CHUYỂN GIỚI' THEN 'PTTM'
            WHEN r.nhom_dich_vu_chinh ~* ' DA|CHÀM|NÁM|TÀN NHANG|BỚT|LASER|LÔNG|ĐỒI MỒI|BAN VÀNG|SẸO|XĂM|TRẺ HÓA|MASSAG' THEN 'Beauty & Spa'
            WHEN r.nhom_dich_vu_chinh ~* 'NHA KHOA' THEN 'Nha khoa'
            ELSE 'Khác'
        END as business_line
    from (
        select c.*,
            ROW_NUMBER() OVER (PARTITION BY c.crm_id, c.brand_etl ORDER BY c.do_uu_tien) as rn
        from (
            select 'crm_lead_main_pc' as source_main_bl, * from uu_tien_1
            union all
            select 'ticket' as source_main_bl, * from uu_tien_2
            union all
            select 'crm_lead_history' as source_main_bl, t.* from uu_tien_3 t
        ) c
        where c.nhom_dich_vu_chinh is not null
    ) r
        left join ctg_service_type_map csm on csm.product_ctg_id = r.product_category_id
    where r.rn = 1

-- ================================================================================================
-- [ĐỔI 2026-08-22] main_bl_customer: đổi từ "business_line của cline đầu tiên trong toàn bộ lịch sử
-- KH" (theo cline_created_date) sang "business_line ĐÃ RESOLVE (3 tầng ưu tiên ở trên) của BOOKING
-- đầu tiên của KH" (crm_id có booking_report_date sớm nhất; tie-break cline_created_date, cline_id
-- của cline sớm nhất trong booking đó khi trùng ngày) — khớp đúng logic mới nhất của procedure
-- func_stag_crm_line_ecosystem() (bước 3.6, đổi ngày 2026-08-05).
-- LƯU Ý: có thể ra NULL nếu booking đầu tiên của KH không resolve được nhóm dịch vụ chính ở cả 3
-- tầng ưu tiên — khác hành vi trước đây (main_bl_customer theo cline đầu tiên luôn có giá trị, tối
-- thiểu 'Khác'). Khi main_bl_customer NULL, so sánh "business_line = main_bl_customer" ở CASE cuối
-- không bao giờ TRUE (NULL = x luôn ra NULL) -> các dòng của KH đó luôn đi qua nhánh bool_or() để
-- xác định is_cross_sale, không còn được loại trừ sớm qua nhánh "thuộc main BL" nữa.
-- ================================================================================================
), customer_first_booking as (
    select crm_id, code_customer,
        ROW_NUMBER() OVER (
            PARTITION BY code_customer
            ORDER BY booking_report_date, cline_created_date, cline_id
        ) as rn
    from rnk_bl_cline
), customer_main_bl as (
    select
        cfb.code_customer,
        ndc.business_line as main_bl_customer,
        ndc.source_main_bl
    from customer_first_booking cfb
        left join nhom_dich_vu_chinh ndc on ndc.crm_id = cfb.crm_id and ndc.brand_etl = 1
    where cfb.rn = 1
), paid_bl_cline as (
    -- Chỉ các dòng có payment > 0, đánh số thứ tự riêng theo (business_line, code_customer) để
    -- xác định "lần mua có payment đầu tiên" và tính khoảng cách 6 tháng, bỏ qua các dòng không
    -- phát sinh payment (hủy/chưa thanh toán) khi đếm thứ tự và khi tìm dòng liền trước.
    -- Sắp theo cline_payment_date (không phải cline_created_date) để nhất quán với giá trị dùng
    -- so sánh khoảng cách 6 tháng bên dưới (is_line_over_6_months_in_bl/diff_date_order_bl cũng so
    -- sánh cline_payment_date) -- nếu lệch tiêu chí sắp xếp/so sánh, diff_date_order_bl có thể ra
    -- số âm khi dòng tạo sau lại thanh toán trước dòng liền trước theo thứ tự tạo.
    select
        cline_id,
        crm_id,
        code_booking,
        code_customer,
        business_line,
        cline_payment_date,
        ROW_NUMBER() OVER (PARTITION BY business_line, code_customer ORDER BY cline_payment_date, cline_id) as cus_bl_paid_order
    from rnk_bl_cline
    where coalesce(cline_total_payment, 0) > 0
), labeling_1 as (
SELECT
    rbc.*,
    pbc.cus_bl_paid_order,
    (rbc.cus_cline_order = 1) as is_main_service,
    (rbc.crm_cline_order = 1) as is_main_service_bk,
    (case
        when prev_pbc.cline_payment_date is null then false
        else rbc.cline_payment_date > prev_pbc.cline_payment_date + interval '6 months'
    end) as is_line_over_6_months_in_bl,
    cmb.main_bl_customer,
    cmb.source_main_bl,
    first_value(rbc.business_line) over (partition by rbc.crm_id order by rbc.cline_created_date, rbc.cline_id) as main_bl_bk,
    first_value(rbc.cline_product_category_id) over (partition by rbc.code_customer order by rbc.cline_created_date, rbc.cline_id) as main_product_category_id,
    first_value(rbc.cline_product_category) over (partition by rbc.code_customer order by rbc.cline_created_date, rbc.cline_id) as main_product_category,
    prev_pbc.cline_payment_date as prev_bl_order_date,
    (date(rbc.cline_payment_date) - date(prev_pbc.cline_payment_date)) as diff_date_order_bl,
    prev_pbc.crm_id as prev_bl_crm_id,
    prev_pbc.code_booking as prev_bl_booking
FROM rnk_bl_cline rbc
    left join paid_bl_cline pbc on pbc.cline_id = rbc.cline_id
    left join paid_bl_cline prev_pbc
        on prev_pbc.cus_bl_paid_order = pbc.cus_bl_paid_order - 1
        and prev_pbc.code_customer = pbc.code_customer
        and prev_pbc.business_line = pbc.business_line
    left join customer_main_bl cmb on cmb.code_customer = rbc.code_customer
), main_bl_walkin_ranked as (
    -- Phiếu khám (walkin) đầu tiên đã hoàn thành (Completed, service_date_start sớm nhất) thuộc
    -- dịch vụ có business line = business line chính (main_bl_customer) của khách hàng.
    -- Liên hệ: sh_medical_appointment_register_walkin (phiếu khám) <- sh_walkin_service_rel
    -- (walkin_id, service_id) -> service_id = view_stag_products.service_id (view_stag_products có
    -- CẢ product_id lẫn service_id, là 2 cột khác nhau -> phải nối đúng service_id, không phải
    -- product_id).
    -- Phiếu khám nối tới booking qua w.booking_id = crm_lead.id -> cl.name = mã booking gốc chứa
    -- phiếu khám đó (main_bl_booking_org).
    -- LƯU Ý: các cột id (crm_lead.id, sh_medical_appointment_register_walkin.id, product_id...) có
    -- thể trùng giữa nhiều brand_etl khác nhau -> mọi join đều phải kèm điều kiện brand_etl khớp
    -- đúng cặp bảng (không chỉ join theo id) để tránh dính chéo dữ liệu giữa các brand.
    -- Dùng ROW_NUMBER() (kèm w.id tie-break) thay vì MIN() để lấy đúng 1 bản ghi walkin cụ thể,
    -- từ đó lấy kèm được sale_order_id/booking gốc của đúng bản ghi đó (MIN() không cho phép).
    SELECT
        cl.code_customer,
        w.service_date_start,
        w.sale_order_id,
        w.name as code_walkin,
        cl.name as code_booking_org,
        ROW_NUMBER() OVER (
            PARTITION BY cl.code_customer
            ORDER BY w.service_date_start, w.id
        ) as rn
    FROM customer_main_bl cmb
        INNER JOIN {{ source('crm_base', 'crm_lead') }} cl
            ON cl.code_customer = cmb.code_customer AND cl.brand_etl = 1
        INNER JOIN {{ source('crm_base', 'sh_medical_appointment_register_walkin') }} w
            ON w.booking_id = cl.id AND w.brand_etl = cl.brand_etl
        INNER JOIN {{ source('crm_base', 'sh_walkin_service_rel') }} wsr
            ON wsr.walkin_id = w.id AND wsr.brand_etl = w.brand_etl
        INNER JOIN {{ source('crm_base', 'view_stag_products') }} sp
            ON sp.service_id = wsr.service_id AND sp.brand_etl = w.brand_etl
    WHERE w.state = 'Completed'
        AND w.service_date_start IS NOT NULL
        AND cmb.main_bl_customer = CASE
            WHEN sp.his_service_type = 'Surgery' then 'PTTM'
            WHEN sp.his_service_type IN ('Spa','Laser','Card') then 'Beauty & Spa'
            WHEN sp.his_service_type = 'Odontology' then 'Nha khoa'
            WHEN sp.his_service_type = 'wellness' then 'Wellness'
            WHEN sp.his_service_type = 'weight_loss' then 'Weight Loss'
            ELSE 'Khác'
        END
), main_bl_walkin as (
    SELECT
        code_customer,
        service_date_start as main_bl_completed_date,
        sale_order_id as main_bl_order_id,
        code_walkin as main_bl_walkin_done,
        code_booking_org as main_bl_booking_org
    FROM main_bl_walkin_ranked
    WHERE rn = 1
)
select
    lb.*,
    mbw.main_bl_completed_date,
    mbw.main_bl_order_id,
    mbw.main_bl_walkin_done,
    mbw.main_bl_booking_org,
    case
        -- Dịch vụ thuộc main BL của khách hàng, hoặc main BL/BL hiện tại chưa phân loại được
        -- ('Khác') => không phải bán chéo.
        when lb.business_line = lb.main_bl_customer or lb.main_bl_customer = 'Khác' or lb.business_line = 'Khác' then false
        -- [MỚI 2026-08-22] main_bl_customer resolve qua tầng 3 (fallback, độ tin cậy thấp nhất) VÀ
        -- khách tạo tài khoản trước 2025-08-01 => không tính bán chéo (tránh false positive cho
        -- nhóm khách cũ mà dữ liệu 3-tầng-ưu-tiên không đủ tin cậy) — khớp logic mới nhất của
        -- procedure (bước 8).
        when lb.source_main_bl = 'crm_lead_history' and lb.partner_create_date < '2025-08-01' then false
        -- Trong cùng booking (crm_id) và cùng BL này, chỉ cần TỒN TẠI 1 dòng "kích hoạt" bán chéo
        -- (có payment > 0, và là lần mua đầu tiên của BL đó hoặc cách lần mua liền trước của BL đó
        -- > 6 tháng) thì MỌI dòng dịch vụ của cùng BL trong cùng booking đó đều được tính là bán
        -- chéo (kể cả dòng chưa có payment/payment = 0 — lọc theo payment để báo cáo là việc của
        -- Tableau, không phải của cờ is_cross_sale).
        when bool_or(
                coalesce(lb.cline_total_payment, 0) > 0
                and (lb.cus_bl_paid_order = 1 or lb.is_line_over_6_months_in_bl = true)
             ) over (partition by lb.crm_id, lb.business_line)
            then true
        else false
    end as is_cross_sale
from labeling_1 lb
    left join main_bl_walkin mbw on mbw.code_customer = lb.code_customer
