select 
app_name,
pod,
konto,
je_source,
je_category,
--po.receipt_num, 
--po.transaction_date,
--po.transaction_type,
--po.vendor_name,
--po.shipment_line_id,
--po.transaction_id,
--po.po_number,
--entity_id, 
--accounting_date,
sum(acc_dr),
sum(acc_cr),
sum(balance)
from
(
select 
fa.application_id app_id,
fa.application_short_name app_name,
xte.application_id,
xte.period_name,
to_char(xah.accounting_date,'dd.mm.yyyy') accounting_date, 
xal.accounting_class_code, 
xal.entered_dr, 
xal.entered_cr, 
gcc.segment1 pod,
gcc.segment2 konto,
gjh.je_source,
gjh.je_category,
xte.source_id_int_1 ,
xte.entity_id,
nvl(gjl.accounted_dr,0) acc_dr,
nvl(gjl.accounted_cr,0) acc_cr,
(nvl(gjl.accounted_dr,0)-nvl(gjl.accounted_cr,0)) balance
from 
xla_transaction_entities xte,
xla_ae_headers xah, 
xla_ae_lines xal,
gl_code_combinations gcc,
gl_import_references gir,
gl_je_lines gjl,
gl_je_headers gjh,
fnd_application fa
where
--xte.application_id                       in (707,10096) -- receipt accounting , cost accounting)
--and 
xah.entity_id                           = xte.entity_id 
and xal.ae_header_id                    = xah.ae_header_id 
and gcc.code_combination_id             = xal.code_combination_id 
and gir.gl_sl_link_table                = xal.gl_sl_link_table
and gir.gl_sl_link_id                   = xal.gl_sl_link_id
and gjl.je_header_id                    = gir.je_header_id
and gjl.je_line_num                     = gir.je_line_num
and xal.application_id                  <> 707 
and gcc.segment1                        ='01'
and gcc.segment2                        ='660001'
and gjl.je_header_id                    = gjh.je_header_id
and gcc.code_combination_id             = gjl.code_combination_id
and fa.application_id                   = xte.application_id
--and fa.application_short_name in ('CMR')
and xal.period_name                 not like '%2026'
--and xte.source_id_int_1                 in (60024,7003)
) gl,
( 
select 
ps.vendor_name,
poh.segment1 as po_number, 
mp.organization_code skl,
rsh.receipt_num, 
to_char(rt.transaction_date,'dd.mm.yyyy') transaction_date,
rsl.line_num, 
egp.item_number, 
pol.item_description,
egp.primary_uom_code puom,  
rsl.quantity_received, 
rsl.line_num rsl_line_num,
rsl.shipment_line_id,
rt.transaction_id,
rt.transaction_type,
--rt.inv_transaction_id,
rt.po_distribution_id,
poh.segment1||'.'||mp.organization_code||'.'||rsh.receipt_num||'.'||egp.item_number||'.'||rsl.line_num po_key
from 
rcv_shipment_headers rsh,
rcv_shipment_lines rsl,
rcv_transactions rt,
po_headers_all poh, 
po_lines_all pol,
poz_suppliers_v ps,
egp_system_items_b_v egp, 
inv_org_parameters mp
where
rsh.shipment_header_id  = rsl.shipment_header_id and  
rsl.po_header_id        = poh.po_header_id and
rsl.po_line_id          = pol.po_line_id and
rt.shipment_line_id     = rsl.shipment_line_id and 
rt.shipment_header_id   = rsl.shipment_header_id and
ps.vendor_id = poh.vendor_id and
egp.inventory_item_id    = rsl.item_id and
egp.organization_id      = rsl.to_organization_id and 
mp.organization_code='T01' AND 
--egp.item_number='84402500002' AND 
mp.organization_id = rsl.to_organization_id 
--and 
--poh.segment1='83469'
) po
where 
gl.source_id_int_1=po.shipment_line_id
--and accounting_date='23.01.2023'
--and po_number='83440'
--and po.receipt_num='12'
group by
app_name,
pod,
konto,
je_source,
je_category,
po.receipt_num, 
po.transaction_date,
po.transaction_type,
po.vendor_name,
po.shipment_line_id,
po.transaction_id,
po.po_number,
entity_id, 
accounting_date


---------------

select 
pod,konto,
je_source,
je_category,
sum(acc_dr) adr, 
sum(acc_cr) acr,
sum(balance) balance
from 
(
select 
fa.application_id app_id,
fa.application_short_name app_name,
xte.application_id,
xte.period_name,
to_char(xah.accounting_date,'dd.mm.yyyy') accounting_date, 
xal.accounting_class_code, 
xal.entered_dr, 
xal.entered_cr, 
gcc.segment1 pod,
gcc.segment2 konto,
gjh.je_source,
gjh.je_category,
xte.source_id_int_1 ,
xte.entity_id,
nvl(gjl.accounted_dr,0) acc_dr,
nvl(gjl.accounted_cr,0) acc_cr,
(nvl(gjl.accounted_dr,0)-nvl(gjl.accounted_cr,0)) balance
from 
xla_transaction_entities xte,
xla_ae_headers xah, 
xla_ae_lines xal,
gl_code_combinations gcc,
gl_import_references gir,
gl_je_lines gjl,
gl_je_headers gjh,
fnd_application fa
where
--xte.application_id                       in (707,10096) -- receipt accounting , cost accounting)
--and 
xah.entity_id                           = xte.entity_id 
and xal.ae_header_id                    = xah.ae_header_id 
and gcc.code_combination_id             = xal.code_combination_id 
and gir.gl_sl_link_table                = xal.gl_sl_link_table
and gir.gl_sl_link_id                   = xal.gl_sl_link_id
and gjl.je_header_id                    = gir.je_header_id
and gjl.je_line_num                     = gir.je_line_num
and xal.application_id                  <> 707 
and gcc.segment1                        ='01'
and gcc.segment2                        ='660001'
and gjl.je_header_id                    = gjh.je_header_id
and gcc.code_combination_id             = gjl.code_combination_id
and fa.application_id                   = xte.application_id
--and fa.application_short_name in ('CMR')
and xal.period_name                 not like '%2026'
--and xte.source_id_int_1                 in (60024,7003)
) gl
group by
pod,konto,je_source,
je_category