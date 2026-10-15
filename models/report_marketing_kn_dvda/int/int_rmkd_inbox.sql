-- Inbox: tin nhắn Facebook Inbox từ m_inbox_kangnam
select
    'DV'                                                                        as ten_dv,
    'IB'                                                                        as "Nguon",
    'IB'                                                                        as "Nhom_nguon",
    'FB'                                                                        as kenh,
    date(nullif(trim(mik."ngày"), ''))                                        as date,
    cns.nhom_dv,
    case when upper(coalesce(i."chi nhánh", 'VK')) = 'HÀ NỘI'
              then 'BỆNH VIỆN KANGNAM HÀ NỘI'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'HCM'
              then 'BỆNH VIỆN KANGNAM SÀI GÒN'
         when upper(coalesce(i."chi nhánh", 'VK')) in ('VK', 'VIỆT KIỀU')
              then 'Việt Kiều'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'BẮC NINH'
              then 'VIỆN THẨM MỸ KANGNAM BẮC NINH'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'HẢI PHÒNG'
              then 'VIỆN THẨM MỸ KANGNAM HẢI PHÒNG'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'BUÔN MÊ THUỘT'
              then 'VIỆN THẨM MỸ KANGNAM BUÔN MA THUỘT'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'ĐÀ NẴNG'
              then 'VIỆN THẨM MỸ KANGNAM ĐÀ NẴNG'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'CẦN THƠ'
              then 'VIỆN THẨM MỸ KANGNAM CẦN THƠ'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'NGHỆ AN'
              then 'VIỆN THẨM MỸ KANGNAM NGHỆ AN'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'THÁI NGUYÊN'
              then 'VIỆN THẨM MỸ KANGNAM THÁI NGUYÊN'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'THANH HÓA'
              then 'VIỆN THẨM MỸ KANGNAM THANH HÓA'
         when upper(coalesce(i."chi nhánh", 'VK')) = 'BÌNH DƯƠNG'
              then 'VIỆN THẨM MỸ KANGNAM BÌNH DƯƠNG'
         else upper(coalesce(i."chi nhánh", 'VK'))
    end                                                                         as chi_nhanh,
    case when mik."vùng" = 'Ho Chi Minh City' then 'SÀI GÒN'
         when mik."vùng" = 'Hanoi'            then 'Hà Nội'
         when coalesce(i."chi nhánh", 'VK') = 'VK' then 'Việt Kiều'
         when mik."vùng" = 'Da Nang'          then 'Thành phố Đà Nẵng'
         when mik."vùng" = 'Cần Thơ'          then 'Thành phố Cần Thơ'
         when mik."vùng" = 'Haiphong'         then 'Thành phố Hải Phòng'
         else 'Tỉnh ' || REGEXP_REPLACE(mik."vùng", '\s*Province$', '')
    end                                                                         as local_k,
    mik."người liên hệ qua nhắn tin mới"::text                                 as "Metric",
    'inbox'                                                                     as type_data
from (select distinct * from {{ source('rmkd', 'm_inbox_kangnam') }}) mik
left join lateral (
    select lka."chi nhánh"
    from {{ source('rmkd', 'location_kangnam_adnet') }} lka
    where lka.tinh = mik."vùng" and nullif(trim(mik."ngày"), '')::timestamp >= lka.ngay_hh
    order by lka.ngay_hh desc limit 1
) i on true
left join {{ source('rmkd', 'campaign_name_split') }} cns
       on upper(cns.campain_name_split) = upper(trim(split_part(mik."tên chiến dịch", '_', 2)))
where mik."người liên hệ qua nhắn tin mới" is not null

