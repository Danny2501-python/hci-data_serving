select 
        s.ngay_dc,
        s.ten_khach,
        s.stage,
        ap.payment_date ngay_thu_tien,
        s."Mã Khách",
        s."Booking",
        s.dienthoai,
        s."Line_id",
        s."Tên DV",
        rb.name "Thương Hiệu",
        rb.id thuonghieuphanquyen,
        rc.id chinhanhphanquyen,
        s."Nhân Viên",
        s."Nhóm Dịch Vụ",
        s.tien_con,
        case when ap.payment_type  = 'inbound' then capd.prepayment_amount 
else -capd.prepayment_amount  end as "Tiền Cọc",
s."Doanh Thu Kì Vọng",
        coalesce (
             case when capd.brand_etl = 1 then ss.category_source end,
            case when capd.brand_etl = 3 then ss.category_source_ss end
        )  as "Kênh Truyền Thông",
        ss.newcat_source as "Nhom_nguon",
        s.cong_no,
        case 
	when capd.brand_etl =1 then ss.source
	when capd.brand_etl =3 then ss.org_source
    end as nguon_book,
        s.tu_van1_id,
        s.tu_van1,
        s.pb_tu_van1,
        s.pb_tu_van1_id,
        s.ngay_tao_line,
        s.id_lead,
        ss.channel as kenh,
        ss.category_channel,
        s.default_code,
        case when ap.payment_type  = 'inbound' then 'Nhận tiền' 
        else 'Hoàn tiền'  
        end as data_type,
        ap.communication as nd_tt,
        ap.id::text as id_tt,
        ap."name" ma_phieu ,
        rc.name "Chi nhánh",
           rc.brand_etl
from {{ref('stag_dps_mapping')}} s
join {{ref('dps_capd')}} capd on capd.crm_line_id  = s."Line_id" and capd.brand_etl = s.brand_etl_cl2
join {{ref('dps_ap')}} ap on ap.id = capd.account_payment_id and ap.brand_etl = capd.brand_etl
join {{ref('dps_source')}} ss  on ss.old_id = s.source_id
join {{source('raw_data','m_res_company')}} rc on rc.id = capd.company_id and capd.brand_etl = rc.brand_etl
left join {{source('raw_data','res_brand')}} rb on rb.id = rc.brand_id and rb.brand_etl = rc.brand_etl
where ap.payment_date is not null
union all
select 
        s.ngay_dc,
        s.ten_khach,
        s.stage,
        spt.payment_date ngay_thu_tien,
        s."Mã Khách",
        s."Booking",
        s.dienthoai,
        spt.clineid "Line_id",
        s."Tên DV",
        rb.name "Thương Hiệu",
        rb.id thuonghieuphanquyen,
        mrc.id chinhanhphanquyen,
        s."Nhân Viên",
        s."Nhóm Dịch Vụ",
        s.tien_con,
        spt.payment "Tiền Cọc",
        s."Doanh Thu Kì Vọng",
        coalesce(
        case when spt.brand_etl = 1 then ss.category_source end,
            case when spt.brand_etl = 3 then ss.category_source_ss end
        ) as "Kênh Truyền Thông",
        ss.newcat_source  as "Nhom_nguon",
        s.cong_no,
        case 
        when spt.brand_etl =1 then ss.source
        when spt.brand_etl =3 then ss.org_source
        end as nguon_book,
        s.tu_van1_id,
        s.tu_van1,
       s.pb_tu_van1,
        s.pb_tu_van1_id,
        s.ngay_tao_line,
        s.id_lead,
        ss.channel as kenh,
        ss.category_channel,
        s.default_code ,
        'Điều chuyển' data_type,
        'Điều chuyển dịch vụ' nd_tt,
        spt.id as id_tt,
        spt.ma_phieu ,
        mrc.name "Chi nhánh",
        mrc.brand_etl
from (select * from {{ref('dps_payment')}} where ma_phieu like 'PDC%') spt 
join {{ref('stag_dps_mapping')}} s on spt.clineid = s."Line_id" 
and spt.crm_id = s.id_lead and spt.brand_etl = s.brand_etl_cl2
join {{source('raw_data','m_res_company')}} mrc on mrc.id = spt.company_id and spt.brand_etl = mrc.brand_etl
join {{source('raw_data','res_brand')}} rb on rb.id = mrc.brand_id and rb.brand_etl = mrc.brand_etl
left join {{ref('dps_source')}} ss  on ss.old_id = s.source_id 


