
  CREATE TABLE "XX_INTEGRATION_PROD"."XXDL_JOPPD_PAYMENTS_INT" 
   (	"LEGAL_ENTITY_ID" NUMBER, 
	"LEGAL_ENTITY_NAME" VARCHAR2(50 BYTE), 
	"INVOICE_ID" NUMBER, 
	"PERIOD_NAME" VARCHAR2(7 BYTE), 
	"OIB" VARCHAR2(11 BYTE), 
	"NAME" VARCHAR2(50 BYTE), 
	"PERIOD_FROM" VARCHAR2(10 BYTE), 
	"PERIOD_TO" VARCHAR2(10 BYTE), 
	"PAYMENT_AMOUNT" NUMBER, 
	"STATUS" VARCHAR2(1 BYTE), 
	"MESSAGE" VARCHAR2(2000 BYTE), 
	"SURNAME" VARCHAR2(50 BYTE), 
	"PAYMENT_DATE" VARCHAR2(10 BYTE), 
	"PERSON_NUMBER" NUMBER, 
	"LEGAL_ENTITY_IDENTIFIER" VARCHAR2(11 BYTE)
   );

  CREATE UNIQUE INDEX "XX_INTEGRATION_PROD"."INDEX1" ON "XX_INTEGRATION_PROD"."XXDL_JOPPD_PAYMENTS_INT" ("LEGAL_ENTITY_ID", "INVOICE_ID", "PERIOD_NAME");

