  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_MATERIAL_TXNS.sql
  Object      : XXDL_INV_MATERIAL_TXNS
  Description : Material transactions from Fusion
  History     :
  v1.0 15.07.2022 Marko Sladoljev: Inicijalna verzija
  v1.1 02.09.2022 Marko Sladoljev: New columns
  ============================================================================+*/

drop table xxdl_inv_material_txns;

CREATE TABLE xxdl_inv_material_txns(
     transaction_id             NUMBER NOT NULL,
     inventory_item_id          NUMBER NOT NULL,
     organization_id            NUMBER NOT NULL,
     subinventory_code          VARCHAR2(10) NOT NULL,
     transaction_type_id        NUMBER NOT NULL,
     transaction_action_id      NUMBER NOT NULL,
     transaction_source_type_id NUMBER NOT NULL,
     transaction_source_id      NUMBER,
     transaction_quantity       NUMBER NOT NULL,
     transaction_uom            VARCHAR2(3) NOT NULL,
     primary_quantity           NUMBER NOT NULL,
     transaction_date           DATE NOT NULL,
     shipment_number            VARCHAR2(100),
     receipt_num                VARCHAR2(100),
     transfer_organization_id   NUMBER,
     po_number                  VARCHAR2(100),
     po_approved_date           DATE,
     po_unit_price              NUMBER,
     po_party_site_number       VARCHAR2(100),
     creation_date              TIMESTAMP,
     created_by                 VARCHAR2(64) NOT NULL,
     downloaded_date            DATE NOT NULL,
     CONSTRAINT XXDL_INV_MATERIAL_TXNS_PK PRIMARY KEY (TRANSACTION_ID) 
  ); 




