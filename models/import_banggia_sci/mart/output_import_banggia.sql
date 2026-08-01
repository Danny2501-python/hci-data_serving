{{ config(alias='output_import_banggia_dbt') }}

-- Tương đương update_import_bang_gia() (function plpgsql). Alias 'output_import_banggia_dbt' để không ghi
-- đè bảng output_import_bang_gia thật đang được function nạp, cho tới khi đối chiếu/duyệt xong (xem LOGIC.md).
with p as (select * from {{ ref('int_ibgs_p') }}),
pp as (select * from {{ ref('int_ibgs_pp') }}),
output_data as (
    select
        p.*,
        case
            when p.status_data = '' or p.status_data = ' | product_id mới (chưa có trong bảng giá)' then false
            else true
        end is_record_false
    from p
    left join pp on pp.stt = p.stt
    order by p.stt
)
select distinct
    od.*,
    case
        when pp.false_extenal_id <> '' and pp.false_extenal_id = od.status_data then 'Team QTDL kiểm tra lại'
        when pp.false_extenal_id <> od.status_data and is_record_false is true then 'Đang sai, cần check status_data (Xong hãy trans lại 1 lần nữa)'
        when od.status_data = ' | product_id mới (chưa có trong bảng giá)' then 'Đã đúng'
        else 'Đã đúng'
    end "Trạng thái"
from output_data od
left join pp on pp.stt = od.stt
