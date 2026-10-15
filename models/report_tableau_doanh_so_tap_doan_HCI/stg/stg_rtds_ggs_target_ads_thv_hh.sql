-- Chi phí online ads theo ngày Hồng Hà / THV (Google Sheet). date là text 'DD/MM/YYYY' → ngay_chi_phi.
-- Phòng khi sheet được nạp nhiều lần (nhiều snapshot cùng 1 ngày) → giữ bản nạp mới nhất mỗi
-- (brand_etl, ngày), tránh cộng trùng.
select distinct on (brand_etl, to_date(date, 'DD/MM/YYYY'))
    to_date(date, 'DD/MM/YYYY') as ngay_chi_phi,
    brand_etl,
    chi_phi,
    muc_tieu_tuan,
    muc_tieu_thang,
    snapshot_date,
    ingestion_timestamp
from {{ source('rtds_source', 'ggs_target_ads_thv_hh') }}
where date ~ '^\d{2}/\d{2}/\d{4}$'
order by brand_etl, to_date(date, 'DD/MM/YYYY'), ingestion_timestamp desc
