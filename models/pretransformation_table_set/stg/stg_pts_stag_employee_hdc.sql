----=========
-- bang hds de lay 1 cai gi do can tac gia quentk giai thich

--====================
SELECT 
    MAX(id) AS id
    ,name as name
FROM {{source('pre_tns','hr_department')}}
WHERE brand_etl in (0,7) 
GROUP BY name
