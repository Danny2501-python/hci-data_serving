select  old_id ,
        source nguon_moi,
        ss.category_source AS nhom_nguon_moi

from {{source('kso_crm_base','stag_sources')}} ss