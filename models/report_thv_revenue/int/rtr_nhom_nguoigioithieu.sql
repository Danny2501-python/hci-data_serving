-- Dimension: người giới thiệu (THV) + nhóm hoa hồng native (join qua
-- dm_hoahongnguoigioithieu_nguoigioithieuid) + nhóm nguồn báo cáo / nhóm MD-ML
-- suy ra bằng rule tên. Tách riêng model này để rtr_ehc_payment_service và
-- rtr_ehc_payment_medicine cùng dùng chung 1 chỗ, không lặp code.
--
-- Rule nhom_nguon_baocao theo nguoigioithieuname (THỨ TỰ ƯU TIÊN quan trọng,
-- không đổi):
-- 0. Ngoại lệ chỉ định riêng theo nguoigioithieuid (ưu tiên cao nhất):
--    85 "ML-Display/Tiktok/Facebook..." -> MD  (tên/nhóm native chứa "ML"
--       nhưng xếp MD theo yêu cầu, khớp dữ liệu mapping tay cũ)
--    45 "N - Đối ngoại"                 -> CBNV
--    39 "MO - Trade"                    -> MO  (nhóm báo cáo MỚI, ngoài 7
--       nhóm gốc — xem cảnh báo nhom_md_ml_baocao bên dưới)
-- 1. chứa "38"                                                  -> PK38
-- 2. chứa "CBNV" NHƯNG KHÔNG chứa "CTV"                          -> CBNV
--    (vd "N - CBNV", "N - Người nhà CBNV"; còn "CTV - CBNV nội bộ
--    giới thiệu" có cả "CTV" nên rơi xuống rule 7 -> ĐTKD - MGM)
-- 3. "Khách hàng cũ quay lại (loyalty)" / "ML- Campaign Loyalty" -> Loyalty
-- 4. "MD - Phát triển cộng đồng"                                 -> MD_Seeding
-- 5. chứa "Vãng lai"                                             -> VL
-- 6. chứa "MD"                                                   -> MD
-- 7. chứa "CTV" hoặc "Khách hàng giới thiệu khách hàng",
--    trừ chứa "CTV-MD"/"CTV-ML"                                   -> ĐTKD - MGM
-- 8. (fallback) không phải CTV-MD/CTV-ML, và nhóm native
--    (dm_hoahongnguoigioithieu_nguoigioithieuname) không chứa "MD"/"ML"
--                                                                   -> ĐTKD - MGM
-- Không khớp rule nào -> nhom_nguon_baocao NULL.
--
-- nhom_md_ml_baocao suy từ nhom_nguon_baocao (khớp 100% dữ liệu mapping tay
-- cũ): CBNV->CBNV, {MD,MD_Seeding,VL}->MD, {PK38,ĐTKD-MGM,Loyalty}->ML.

with ng as (
    select * from {{ source('rtr_base', 'ehc_tb_nguoigioithieu_thv') }}
),

hh as (
    select * from {{ source('rtr_base', 'ehc_tb_dm_hoahongnguoigioithieu_nguoigioithieu_thv') }}
),

base as (
    select
        ng.nguoigioithieuid,
        ng.nguoigioithieuname,
        ng.nguoigioithieuremark,
        ng.nguoigioithieuaddress,
        hh.dm_hoahongnguoigioithieu_nguoigioithieuid,
        hh.dm_hoahongnguoigioithieu_nguoigioithieuname,
        case
            when ng.nguoigioithieuid = 85 then 'MD'
            when ng.nguoigioithieuid = 45 then 'CBNV'
            when ng.nguoigioithieuid = 39 then 'MO'
            when ng.nguoigioithieuname ilike '%38%' then 'PK38'
            when ng.nguoigioithieuname ilike '%CBNV%' and ng.nguoigioithieuname not ilike '%CTV%' then 'CBNV'
            when ng.nguoigioithieuname ilike '%Khách hàng cũ quay lại (loyalty)%'
              or ng.nguoigioithieuname ilike '%ML- Campaign Loyalty%' then 'Loyalty'
            when ng.nguoigioithieuname ilike '%MD - Phát triển cộng đồng%' then 'MD_Seeding'
            when ng.nguoigioithieuname ilike '%Vãng lai%' then 'VL'
            when ng.nguoigioithieuname ilike '%MD%' then 'MD'
            when (ng.nguoigioithieuname ilike '%CTV%' or ng.nguoigioithieuname ilike '%Khách hàng giới thiệu khách hàng%')
                 and ng.nguoigioithieuname not ilike '%CTV-MD%'
                 and ng.nguoigioithieuname not ilike '%CTV-ML%'
                 then 'ĐTKD - MGM'
            when ng.nguoigioithieuname not ilike '%CTV-MD%'
                 and ng.nguoigioithieuname not ilike '%CTV-ML%'
                 and coalesce(hh.dm_hoahongnguoigioithieu_nguoigioithieuname, '') not ilike '%MD%'
                 and coalesce(hh.dm_hoahongnguoigioithieu_nguoigioithieuname, '') not ilike '%ML%'
                 then 'ĐTKD - MGM'
            else null
        end as nhom_nguon_baocao
    from ng
    left join hh on ng.dm_hoahongnguoigioithieu_nguoigioithieuid = hh.dm_hoahongnguoigioithieu_nguoigioithieuid
)

select
    base.*,
    case
        when base.nhom_nguon_baocao = 'CBNV' then 'CBNV'
        when base.nhom_nguon_baocao = 'MO' then 'MO'  -- tạm để riêng, chưa gộp MD/ML
        when base.nhom_nguon_baocao in ('MD', 'MD_Seeding', 'VL') then 'MD'
        when base.nhom_nguon_baocao in ('PK38', 'ĐTKD - MGM', 'Loyalty') then 'ML'
        else null
    end as nhom_md_ml_baocao
from base
