select
		spt.crm_id,
		spt.clineid ,
		spt.ma_phieu,
		spt.payment,
		spt.payment_date,
		spt.brand_etl,
		row_number() over (partition by spt.crm_id order by	spt.payment_date) rnk
	from
		{{ source('bao_cao_sua_xoa_du_lieu', 'stag_payment_transfer') }} spt