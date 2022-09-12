  /* $Header $
  ============================================================================+
  File Name   : XXDL_AVG_ITEM_COST_V.sql
  Object      : XXDL_AVG_ITEM_COST_V
  Description : Items costs from Fusion
  History     :
  v1.0 12.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/
create or replace view  XXDL_AVG_ITEM_COST_V as
select c.cost_org,
       c.inventory_item_id,
       c.item_number,
       c.val_unit_code,
       case
         when sum(c.quantity_onhand) = 0 then
          avg(c.unit_cost_average)
         else
          sum(c.unit_cost_average * c.quantity_onhand) / sum(c.quantity_onhand)
       end unit_cost,
       sum(c.quantity_onhand) quantity_onhand,
       c.uom_code
  from xxdl_avg_item_cost c
 group by c.cost_org,
          c.inventory_item_id,
          c.item_number,
          c.val_unit_code,
          c.uom_code;

  
