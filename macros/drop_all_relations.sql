{% macro drop_all_relations() %}
    -- 1. Xác định schema cần dọn dẹp (Lấy từ profile target hiện tại)
    {% set target_schema = target.schema %}
    
    -- 2. Đặt câu truy vấn để lấy danh sách bảng/view
    {% set query_get_relations %}
        select 
            table_type, 
            table_name 
        from information_schema.tables 
        where table_schema = '{{ target_schema }}'
    {% endset %}

    -- 3. Thực thi truy vấn để lấy danh sách
    {% set results = run_query(query_get_relations) %}

    {% if execute %}
        {% set relations_list = results.rows %}
        
        -- 4. Duyệt qua từng bảng tìm được
        {% for row in relations_list %}
            {% set relation_type = row[0] %}
            {% set relation_name = row[1] %}
            
            -- Xây dựng lệnh DROP tương ứng (TABLE hoặc VIEW)
            {% if relation_type == 'BASE TABLE' %}
                {% set drop_query = 'DROP TABLE IF EXISTS "' ~ target_schema ~ '"."' ~ relation_name ~ '" CASCADE;' %}
            {% else %}
                {% set drop_query = 'DROP VIEW IF EXISTS "' ~ target_schema ~ '"."' ~ relation_name ~ '" CASCADE;' %}
            {% endif %}
            
            -- 5. Thực thi lệnh DROP
            {{ log("Dropping " ~ relation_type ~ ": " ~ target_schema ~ "." ~ relation_name, info=True) }}
            {% do run_query(drop_query) %}
        {% endfor %}
        
        {{ log("Successfully dropped " ~ relations_list|length ~ " relations in schema '" ~ target_schema ~ "'.", info=True) }}
    {% endif %}

{% endmacro %}
