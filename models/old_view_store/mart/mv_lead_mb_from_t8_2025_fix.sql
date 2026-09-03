{{
  config(
    materialized = 'table',
    alias        = 'mv_lead_mb_from_t8_2025_fix',
    indexes = [
      {'columns': ['company_id', 'ch', 'nhom_dv_id']},
      {'columns': ['bang', 'id']}
    ]
  )
}}
-- =============================================================================
-- mv_lead_mb_from_t8_2025_fix
-- Đưa vào dbt để cố định vào DAG: {{ ref('stag_products') }} và
-- {{ ref('stag_payment_transfer') }} là output của model khác trong dự án
-- (erp_staging/products, erp_staging/payment_transfer) — trước đây view này
-- được tạo tay ngoài dbt, tham chiếu thẳng bảng vật lý, nên bị DROP CASCADE
-- theo mỗi khi dbt rebuild 2 bảng đó (rename -> tmp -> drop backup cascade).
-- Nay là 1 model trong DAG, dbt sẽ tự rebuild lại ngay sau stag_products/
-- stag_payment_transfer trong cùng 1 lần `dbt run`, không còn bị mất view.
--
-- 2026-09-01: đổi materialized 'view' -> 'table' (kèm index) để phục vụ báo
-- cáo Tableau "BÁO CÁO HIỆU QUẢ KHAI THÁC DATA CƠ HỘI KHÁCH HÀNG" — Custom SQL
-- của report này JOIN/window function trực tiếp trên view "mv_" tưởng là đã
-- cache sẵn (đặt tên như materialized view) nhưng thực chất là view thường,
-- bị tính lại từ đầu (Seq Scan + Sort + WindowAgg trên crm_lead/crm_line) mỗi
-- lần Tableau extract chạy, khiến extract mất >120 phút và bị Tableau tự huỷ.
-- Chuyển sang table: dbt sẽ rebuild toàn bộ mỗi lần `dbt run` (đúng convention
-- các model khác trong repo này), Custom SQL sau đó chỉ đọc dữ liệu đã tính
-- sẵn thay vì tính lại. Không dùng materialized_view vì Postgres không tự
-- REFRESH dữ liệu theo dbt run, sẽ cần thêm cơ chế refresh riêng không cần
-- thiết ở đây.
--
-- Logic giữ NGUYÊN VẸN so với view gốc trên new_product (không sửa filter,
-- kể cả chỗ case-sensitive không nhất quán giữa lead_prep/lead_fr1 — xem
-- trao đổi ngày 2026-08-13, chưa xác nhận có phải bug hay cố ý).
--
-- Lưu ý: đã có 1 pipeline dbt khác (report_hqcd_page/stg/stg_rhp_mv_lead_mb)
-- migrate từ 1 phiên bản GẦN GIỐNG nhưng KHÔNG GIỐNG HỆT view này (khác nhau
-- ở case-sensitivity của filter nguồn) — 2 model độc lập, KHÔNG dùng chung,
-- cân nhắc rà soát/gộp lại sau nếu xác nhận được đâu là logic đúng.
-- =============================================================================

WITH a1 AS (
         SELECT cl.id,
            cl.name AS l_name,
            cl.create_date,
            cl.phone,
            cl.create_by,
            cl.company_id,
            cl.source_id,
            lag(cl.id) OVER (PARTITION BY cl.phone ORDER BY cl.id) AS rnk,
            cl.type,
            cl.brand_etl
           FROM {{ source('ovs_source', 'crm_lead') }} cl
          WHERE cl.brand_etl = 1
        ), a AS (
         SELECT a1.id,
            a1.l_name,
            a1.create_date,
            a1.phone,
            a1.create_by,
            a1.company_id,
            a1.source_id,
            a1.rnk,
            a1.type,
            a1.brand_etl
           FROM a1
          WHERE date(a1.create_date) >= '2025-08-01'::date
        ), ecl AS (
         -- 2026-09-01: rút gọn từ SELECT toàn bộ ~140 cột của crm_lead xuống chỉ 10 cột
         -- thực sự được dùng ở 3 nơi tham chiếu ecl (clb/cll trong old_data, và pay) —
         -- ecl là CTE được PostgreSQL materialize NGUYÊN VẸN 1 lần (dùng lại 3 chỗ) nên
         -- SELECT càng nhiều cột càng tốn bộ nhớ/tmp-disk lúc materialize, dù các lượt
         -- scan lại sau đó planner tự prune cột thừa. Không đổi WHERE/filter — cùng tập
         -- dòng, chỉ bớt cột không ai dùng. Xem trao đổi tối ưu 2026-09-01.
         SELECT cl.id,
            cl.name,
            cl.create_date,
            cl.arrival_date,
            cl.amount_paid,
            cl.lead_id,
            cl.type_crm_id,
            cl.brand_id,
            cl.type,
            cl.phone
           FROM {{ source('ovs_source', 'crm_lead') }} cl
          WHERE cl.brand_etl = 1
        ), cline AS (
         -- 2026-09-01: rút gọn từ ~90 cột xuống 5 cột thực sự dùng ở lpm/lead_fr1
         -- (cùng lý do với ecl ở trên — cline cũng là CTE materialize dùng lại 2 lần).
         SELECT cl.id,
            cl.crm_id,
            cl.product_id,
            cl.total,
            cl.percent_total_discount
           FROM {{ source('ovs_source', 'crm_line') }} cl
          WHERE cl.brand_etl = 1
        ), old_data AS (
         SELECT a.id,
            a.l_name,
            a.create_date,
            a.phone,
            a.create_by,
            a.company_id,
            a.source_id,
            a.rnk,
            a.type,
            a.brand_etl,
            clb.create_date AS ngay_tao_b,
            clb.name AS b_name,
            clb.arrival_date,
            cll.id AS l_id,
            cll.create_date AS l_date,
            clb.create_date AS bk_date,
            clb.arrival_date AS bdc_date,
                CASE
                    WHEN clb.name IS NOT NULL THEN 'book'::text
                    WHEN cll.id IS NOT NULL THEN 'lead'::text
                    ELSE 'new_data'::text
                END AS type_tc,
            clb.id AS b_id,
            clb.amount_paid AS paid_tc
           FROM a
             -- 2026-09-01: clb/cll rút gọn từ re-select full ~140 cột của ecl xuống chỉ
             -- các cột old_data thực sự dùng (SELECT/JOIN ON bên dưới) — không đổi WHERE.
             LEFT JOIN ( SELECT cl.id, cl.name, cl.create_date, cl.arrival_date, cl.amount_paid,
                    cl.lead_id, cl.type_crm_id
                   FROM ecl cl
                  WHERE cl.brand_id = 1 AND cl.type_crm_id = 2) clb ON clb.lead_id = a.rnk AND a.rnk IS NOT NULL AND clb.type_crm_id = 2
             LEFT JOIN ( SELECT cl.id, cl.create_date
                   FROM ecl cl
                  WHERE cl.brand_id = 1 AND cl.type::text = 'lead'::text) cll ON cll.id = a.rnk AND a.rnk IS NOT NULL
          WHERE a.rnk IS NOT NULL AND a.type::text = 'lead'::text
        ), data_l AS (
         SELECT o.id,
            o.type_tc,
            o.l_name,
            o.create_date,
            o.rnk AS id_tham_chieu,
                CASE
                    WHEN o.type_tc = 'book'::text THEN o.b_id
                    WHEN o.type_tc = 'lead'::text THEN o.l_id
                    WHEN o.type_tc = 'new_data'::text THEN 0
                    ELSE NULL::integer
                END AS id_tc,
            o.b_name,
            o.phone,
            o.paid_tc,
            GREATEST(o.l_date, o.bk_date, o.bdc_date) AS max_range,
            se.login AS work_email,
            ss.source AS nguon,
            mrc.name AS chi_nhanh,
            mrc.id AS company_id
           FROM old_data o
             LEFT JOIN {{ source('ovs_source', 'm_res_company') }} mrc ON mrc.id = o.company_id AND mrc.brand_etl = 1
             LEFT JOIN {{ source('ovs_source', 'res_users') }} se ON se.id = o.create_by AND se.brand_etl = 1
             LEFT JOIN {{ source('ovs_source', 'stag_sources') }} ss ON ss.old_id = o.source_id::double precision
        ), lead_prep AS (
         SELECT l.id,
            l.type_tc,
            l.l_name,
            l.create_date,
            l.id_tham_chieu,
            l.id_tc,
            l.b_name,
            l.phone,
            l.paid_tc,
            l.max_range,
            l.work_email,
            l.nguon,
            l.chi_nhanh,
            l.company_id
           FROM data_l l
          WHERE (date(l.create_date) - date(l.max_range)) > 30 AND l.nguon::text ~~ '%MD%'::text AND l.nguon::text !~~ '%Cơ sở%'::text
        ), pay AS (
         SELECT spt.payment_date,
            cl.phone,
            spt.crm_id,
            row_number() OVER (PARTITION BY spt.crm_id ORDER BY spt.payment_date DESC) AS rnk
           FROM ( SELECT spt_1.id, spt_1.ma_phieu, spt_1.crm_id, spt_1.payment_date, spt_1.payment_method,
                    spt_1.clineid, spt_1.product_id, spt_1.quantity, spt_1.uom_price, spt_1.number_used,
                    spt_1.total, spt_1.total_received, spt_1.total_received_cumsum, spt_1.total_received_recal,
                    spt_1.payment, spt_1.payment_type, spt_1.stage_product, spt_1.consultants_1,
                    spt_1.consulting_role_1, spt_1.consultants_2, spt_1.consulting_role_2, spt_1.ho_tro,
                    spt_1.price_list_id, spt_1.orgcompany_id, spt_1.company_id, spt_1.communication,
                    spt_1.product_type, spt_1.write_date, spt_1.brand_id, spt_1.brand_etl, spt_1.first_date_payment,
                    spt_1.rnk_crm_pmdate, spt_1.rnk_clineid_pmdate, spt_1.rnk_clineid_pmdate_desc,
                    mrc.id, mrc.name, mrc.brand_id, mrc.location, mrc.company_code, mrc.write_date, mrc.brand_etl
                   FROM {{ ref('stag_payment_transfer') }} spt_1
                     LEFT JOIN {{ source('ovs_source', 'm_res_company') }} mrc ON mrc.id = spt_1.company_id
                  WHERE (spt_1.brand_etl = ANY (ARRAY[0, 1])) AND mrc.brand_id = 1) spt(id, ma_phieu, crm_id,
                    payment_date, payment_method, clineid, product_id, quantity, uom_price, number_used, total,
                    total_received, total_received_cumsum, total_received_recal, payment, payment_type,
                    stage_product, consultants_1, consulting_role_1, consultants_2, consulting_role_2, ho_tro,
                    price_list_id, orgcompany_id, company_id, communication, product_type, write_date, brand_id,
                    brand_etl, first_date_payment, rnk_crm_pmdate, rnk_clineid_pmdate, rnk_clineid_pmdate_desc,
                    id_1, name, brand_id_1, location, company_code, write_date_1, brand_etl_1)
             LEFT JOIN ecl cl ON cl.id = spt.crm_id
          WHERE cl.amount_paid > 0::numeric
        ), lead_f AS (
         SELECT lp.id, lp.type_tc, lp.l_name, lp.create_date, lp.id_tham_chieu, lp.id_tc, lp.b_name, lp.phone,
            lp.paid_tc, lp.max_range, lp.work_email, lp.nguon, lp.chi_nhanh, lp.company_id,
            p.payment_date, p.rnk,
            row_number() OVER (PARTITION BY lp.phone ORDER BY p.payment_date DESC) AS rank,
            date(lp.create_date) - p.payment_date AS range_payment
           FROM lead_prep lp
             LEFT JOIN pay p ON p.phone::text = lp.phone::text AND lp.id > p.crm_id
          WHERE (date(lp.create_date) - p.payment_date) > 30 AND p.rnk = 1 OR p.phone IS NULL
        ), lpm AS (
         SELECT l.id, l.type_tc, l.l_name, l.create_date, l.id_tham_chieu, l.id_tc, l.b_name, l.phone, l.paid_tc,
            l.max_range, l.work_email, l.nguon, l.chi_nhanh, l.company_id, l.payment_date, l.rnk, l.rank,
            l.range_payment,
            row_number() OVER (PARTITION BY cl.crm_id ORDER BY sp.list_price DESC, cl.id) AS rnk_dv,
            sp.kdtc_product_ctg_id AS nhom_dv_id,
            sp.product,
            cl.total,
            cl.percent_total_discount
           FROM lead_f l
             LEFT JOIN cline cl ON cl.crm_id = l.id
             LEFT JOIN {{ ref('stag_products') }} sp ON sp.product_id = cl.product_id
          WHERE l.rank = 1
        ), lead_fr1 AS (
         SELECT 'lnew'::text AS bang,
            a.id,
            a.l_name,
            a.create_date,
            'new_data'::text AS type_tc,
            0 AS id_tc,
            'abc'::text AS b_name,
            a.phone,
            se.login AS work_email,
            ss.source AS nguon,
            mrc.name AS chi_nhanh,
            row_number() OVER (PARTITION BY a.phone ORDER BY sp.list_price DESC, cl.id) AS rnk,
            sp.kdtc_product_ctg_id AS nhom_dv_id,
            mrc.id AS company_id,
            sp.product,
            cl.total,
            cl.percent_total_discount
           FROM a
             LEFT JOIN {{ source('ovs_source', 'res_users') }} se ON se.id = a.create_by AND se.brand_etl = 1
             LEFT JOIN {{ source('ovs_source', 'stag_sources') }} ss ON ss.old_id = a.source_id::double precision AND ss.brand_id = 1
             LEFT JOIN {{ source('ovs_source', 'm_res_company') }} mrc ON mrc.id = a.company_id AND mrc.brand_etl = 1
             LEFT JOIN cline cl ON cl.crm_id = a.id
             LEFT JOIN {{ ref('stag_products') }} sp ON sp.product_id = cl.product_id
          WHERE a.rnk IS NULL AND ss.source::text ~~* '%MD%'::text AND ss.source::text !~~ '%Cơ sở%'::text AND a.create_date >= '2025-01-01 00:00:00'::timestamp without time zone AND a.type::text = 'lead'::text
        ), lead_fr AS (
         SELECT lf.bang, lf.id, lf.l_name, lf.create_date AS ngay_tao, lf.type_tc, lf.id_tc, lf.b_name, lf.phone,
            lf.work_email, lf.nguon, lf.chi_nhanh, lf.nhom_dv_id, lf.company_id, lf.product, lf.total,
            lf.percent_total_discount
           FROM lead_fr1 lf
          WHERE lf.rnk = 1
        ), lead_rp AS (
         SELECT lead_fr.bang, lead_fr.id, lead_fr.l_name, lead_fr.ngay_tao, lead_fr.type_tc, lead_fr.id_tc,
            lead_fr.b_name, lead_fr.phone, lead_fr.work_email, lead_fr.nguon, lead_fr.chi_nhanh, lead_fr.nhom_dv_id,
            lead_fr.company_id, lead_fr.product, lead_fr.total, lead_fr.percent_total_discount
           FROM lead_fr
        UNION ALL
         SELECT 'lkt'::text AS bang, l.id AS crm_id, l.l_name, l.create_date, l.type_tc, l.id_tham_chieu, l.b_name,
            l.phone, l.work_email, l.nguon, l.chi_nhanh, l.nhom_dv_id, l.company_id, l.product, l.total,
            l.percent_total_discount
           FROM lpm l
          WHERE l.rnk_dv = 1
        ), data_r AS (
         SELECT lead_rp.bang, lead_rp.id, lead_rp.l_name, lead_rp.ngay_tao, lead_rp.type_tc, lead_rp.id_tc,
            lead_rp.b_name, lead_rp.phone, lead_rp.work_email, lead_rp.nguon, lead_rp.chi_nhanh, lead_rp.nhom_dv_id,
            lead_rp.company_id, lead_rp.product, 1 AS ch, lead_rp.total, lead_rp.percent_total_discount
           FROM lead_rp
        ), data_report AS (
         SELECT dr.bang, dr.id, dr.l_name, dr.ngay_tao, dr.type_tc, dr.id_tc, dr.b_name, dr.phone, dr.work_email,
            dr.nguon, dr.chi_nhanh, dr.nhom_dv_id, dr.company_id, dr.ch,
            gtr.cost_avg_mkt * gkc.mkt_rate AS cp,
            dr.product, dr.total, dr.percent_total_discount
           FROM data_r dr
             LEFT JOIN {{ source('ovs_source', 'ggs_kdtc_product_ctg_rate') }} gkc ON gkc.company_id = dr.company_id::numeric AND gkc.loai_co_hoi = dr.ch::numeric
             LEFT JOIN {{ source('ovs_source', 'ggs_kdtc_service_type_revenue') }} gtr ON gtr.company_id = gkc.company_id AND gtr.kdtc_service_type::text = gkc.kdtc_service_type::text AND gtr.loai_co_hoi = gkc.loai_co_hoi AND gkc.kdtc_product_ctg_id = dr.nhom_dv_id::numeric
          WHERE gtr.cost_avg_mkt IS NOT NULL AND gkc.mkt_rate IS NOT NULL
        )
 SELECT drp.bang, drp.id, drp.l_name, drp.ngay_tao, drp.type_tc, drp.id_tc, drp.b_name, drp.phone, drp.work_email,
    drp.nguon, drp.chi_nhanh, drp.nhom_dv_id, drp.company_id, drp.ch, drp.cp, drp.product, drp.total,
    drp.percent_total_discount
   FROM data_report drp
