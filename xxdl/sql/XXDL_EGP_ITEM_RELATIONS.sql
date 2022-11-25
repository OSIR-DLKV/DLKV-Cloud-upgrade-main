  /* $Header $
  ============================================================================+
  File Name   : XXDL_EGP_ITEM_RELATIONS.sql
  Object      : XXDL_EGP_ITEM_RELATIONS
  Description : Item Relationships from Fusion
  History     :
  v1.0 22.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

--drop table XXDL_EGP_ITEM_RELATIONS;

CREATE TABLE xxdl_egp_item_relations (
     item_relationship_id   NUMBER NOT NULL,
     item_relationship_type VARCHAR2(100) NOT NULL,
     inventory_item_id      NUMBER NOT NULL,
     organization_id        NUMBER,
     sub_type               VARCHAR2(100),
     cross_reference        VARCHAR2(250) NOT NULL,
     master_organization_id NUMBER,
     last_update_date       TIMESTAMP NOT NULL,
     downloaded_date        DATE NOT NULL,
     CONSTRAINT xxdl_egp_item_relations_pk PRIMARY KEY (item_relationship_id)
  );

CREATE INDEX XXDL_EGP_ITEM_RELATIONS_N1 ON xxdl_egp_item_relations(last_update_date);
