select b.* ,
row_number() over(partition by patientphone, sophieu order by sophieu) rnk_ds,
row_number() over(partition by  clineid  ) rnk_line_new
from {{ref('hso_combine')}} b
