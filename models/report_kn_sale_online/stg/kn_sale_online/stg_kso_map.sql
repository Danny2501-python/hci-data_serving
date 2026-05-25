
with mapping as (
select
        row_number() over(partition by cl.id order by cl2.line_id) thu_tu,
        cl.kh_cu_moi,
        cl.vk,
        cl.ten_khach,
        cl2.line_id,
        cl.id,
        cl.ma_kh,
        cl.sdt,
        cl.ngay_den_cua,
        cl.loai_ban_ghi,
        cl.ngay_tao,
        cl.ngay_dc,
        cl.ngay_hl,
        spt.ngay_tt,
        case 
        when cl.ngay_dc is not null then cl.ngay_dc
        when cl.ngay_dc is null then cl.ngay_tao
        else null::date 
        end as date_time,
        cl.ma_booking,
        se.nhan_vien,
        se.work_email,
        spt.doanh_so,
        cl2.tong_tien,
        spt.vao_so,
        cs.trang_thai,
        sp.nhom_dv,
        sp.ten_dv,
        cl.phong_ban_nguoi_tao,
        ss.nguon_moi,
        ss.nhom_nguon_moi,
        cl.nguon_bk_id,
        sp.id_dv,
        cl2.product_id,
        case 
        when spt.company_id is null then cl.company_id
        else spt.company_id
        end as chinhanhphanquyen_old,
        case when spt.company_id is null then mrc2.name
        else mrc3.name
        end as chinhanh_old,
        rcs.tinh,
        cl.ticket_id::text,
        sp.his_service_type,
        sp.surgery_type,
        cl.reason_cancel_booking,
        cl.active--,
       --- m."tên" page
from {{ref('kso_crm_lead')}} cl
left join {{ref('kso_company')}} mrc2 on mrc2.id = cl.company_id
left join {{ref('kso_cline')}} cl2 on cl.id =cl2.crm_id
left join {{ref('kso_product')}} sp  on sp.product_id = cl2.product_id
left join {{ref('kso_spt')}} spt on spt.clineid = cl2.line_id and spt.crm_id = cl2.crm_id
and spt.product_id = cl2.product_id and spt.crm_id = cl2.crm_id 
left join {{ref('kso_company')}} mrc3 on mrc3.id = spt.company_id
left join {{ref('kso_employees')}} se on se.user_id = cl.create_uid
left join {{ref('kso_crm_stage')}} cs on cs.id = cl.stage_id
left join {{ref('kso_country_state')}} rcs on rcs.id = cl.state_id
left join {{ref('kso_source')}} ss on ss.old_id = cl.nguon_bk_id
---left join (select * from {{source('kso_crm_base','cs_chat_api')}} where brand_id=1) cca on text(cca.ticket_id) = text(cl.ticket_id)
---left join {{source('kso_crm_base','m_facebook_page_kangnam')}} m on m.id = cca.facebook_page_id
where sp.nhom_dv <> 'SAN PHAM' and sp.nhom_dv IS NOT NULL
)
select * ,
case 
					when sh.arrival_company_id is not null 
					and sh.arrival_company_id <> m.chinhanhphanquyen_old 
					then sh.arrival_company
					else m.chinhanh_old
				end chinhanh,
				
				case 
					when sh.arrival_company_id is not null 
					and sh.arrival_company_id <> m.chinhanhphanquyen_old 
					then sh.arrival_company_id
					else m.chinhanhphanquyen_old 
				end chinhanhphanquyen

from mapping m 
left join (
        select * 
        from {{source('kso_crm_base','stag_crm_booking_arrival_company')}} 
       where brand_etl =1) sh 
on m.id =sh.crm_id 
