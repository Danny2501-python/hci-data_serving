{% macro get_sale_team(base_alias, date_column_name) %}
    -- Macro để join lấy thông tin Sale Team theo ngày
    -- @base_alias: Alias của bảng base trong câu query chính (ví dụ t1, base...)
    -- @date_column_name: Tên cột ngày dùng để so sánh (ngay_tao, ngay_hl...)
    
    left join lateral (
        select 
            sc."name",
            sc."group_name",
            sc."group" as team_id,
            sc.work_email 
        from {{ source('kangnam_source', 'table_team_sale_trans_field') }} sc
        where sc.work_email = {{ base_alias }}.work_email_normalized -- Dùng email đã chuẩn hóa từ int_clean
          and date(sc.expiration_date) >= date({{ base_alias }}.{{ date_column_name }})
        order by sc.expiration_date asc
        limit 1
    ) tts on true
{% endmacro %}
