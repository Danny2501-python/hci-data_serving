
SELECT * FROM {{ ref('tem_paris_inbox') }}
UNION ALL
SELECT * FROM {{ ref('tem_paris_lt') }}
UNION ALL
SELECT * FROM {{ ref('tem_paris_bk') }}
UNION ALL
SELECT * FROM {{ ref('tem_paris_hl') }}
UNION ALL
SELECT * FROM {{ ref('tem_paris_dc') }}
UNION ALL
SELECT * FROM {{ ref('tem_paris_tc') }}
UNION ALL
SELECT * FROM {{ ref('tem_paris_ds') }}
UNION ALL
SELECT * FROM {{ ref('tem_paris_cp') }}
