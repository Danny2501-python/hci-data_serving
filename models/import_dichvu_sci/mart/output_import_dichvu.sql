{{ config(alias='output_import_dichvu_dbt') }}

-- Tương đương update_import_dichvu() (function plpgsql). Alias 'output_import_dichvu_dbt' để không ghi
-- đè bảng output_import_dichvu thật đang được function nạp, cho tới khi đối chiếu/duyệt xong (xem LOGIC.md).
-- Materialized table nên mỗi lần dbt run sẽ DROP/CREATE lại toàn bộ, tương đương DELETE + INSERT của function gốc.
with note_data as (select * from {{ ref('int_idvs_note_data') }}),
a as (
        select
            nd.stt,
            nd.id,
            nd."default_code",
            nd."name",
            nd."service_category/name",
            nd."service_category/id"::text,
            nd."institution/id"::text,
            nd."service_department/id"::text,
            nd."service_room/id"::text,
            nd."exam_room/id",
            nd."categ_id/id",
            nd.type_product_crm,
            nd.list_price,
            nd.price_min,
            nd."currency_id/id",
            nd.is_surgeries,
            nd.surgery_type,
            nd.anesthetist_type,
            nd."uom_id/id",
            nd."uom_id/name",
            nd."uom_so_id/id",
            nd."uom_po_id/id",
            nd.his_service_type,
            case
                when nd.level_of_difficult::numeric % 1 <> 0 then nd.level_of_difficult::numeric(20,1)
                else nd.level_of_difficult::numeric(20,0)
            end as level_of_difficult,
            nd.execution_time,
            nd.recovery_time,
            case
                when nd.warranty_period::numeric % 1 <> 0 then nd.warranty_period::numeric(20,1)
                else nd.warranty_period::numeric(20,0)
            end as warranty_period,
            nd."uom_guarantee/name",
            nd.note,
            case
                when nd.kpi_point::numeric % 1 <> 0 then nd.kpi_point::numeric(20,1)
                else nd.kpi_point::numeric(20,0)
            end as kpi_point,
            case
                when nd.data_status ilike '%kpi_point_num phải là số nguyên%' then nd.kpi_point_num::numeric
                else nd.kpi_point_num::numeric(20,0)
            end as kpi_point_num,
            nd.is_no_specialty,
            nd.is_no_phonecall,
            nd.is_input_num,
            nd."lab_type_ids/id",
            nd."imaging_type_ids/id",
            nd."ceiling_discount_ids/brand_id/id",
            nd."ceiling_discount_ids/ceiling_discount",
            nd."hướng dẫn sau dịch vụ",
            nd."tính hoa hồng ctv",
            nd.ghi_chu,
            nd.brand,
            case
                when nd.data_status is null then ' | Thiếu "stt"'
                else nd.data_status
            end data_status
        from note_data nd
        )
select nd.*,
    case
        when nd.data_status in ('Dịch vụ cũ', 'Dịch vụ mới', 'Thay đổi default_code mới cho dịch vụ cũ') then false
        else true
    end as is_record_false
from a nd
order by nd.stt
