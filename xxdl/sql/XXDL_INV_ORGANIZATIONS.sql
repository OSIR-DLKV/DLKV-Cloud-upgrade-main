  /* $Header $
  ============================================================================+
  File Name   : XXDL_INV_ORGANIZATIONS.sql
  Object      : XXDL_INV_ORGANIZATIONS
  Description : Items costs from Fusion
  History     :
  v1.0 12.09.2022 Marko Sladoljev: Inicijalna verzija
  ============================================================================+*/

drop table XXDL_INV_ORGANIZATIONS;

CREATE TABLE XXDL_INV_ORGANIZATIONS (
     organization_id    NUMBER  NOT NULL,
     organization_code  VARCHAR2(30) NOT NULL,
     name               VARCHAR2(100) NOT NULL,
     last_update_date   TIMESTAMP NOT NULL,
     downloaded_date    DATE NOT NULL,
	 CONSTRAINT XXDL_INV_ORGANIZATIONS_PK PRIMARY KEY (organization_id)
  ); 
  
CREATE INDEX XXDL_INV_ORGANIZATIONS_N1 ON XXDL_INV_ORGANIZATIONS(last_update_date);
CREATE UNIQUE INDEX XXDL_INV_ORGANIZATIONS_U1 ON XXDL_INV_ORGANIZATIONS(organization_code);
