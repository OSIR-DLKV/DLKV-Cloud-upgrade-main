  CREATE TABLE "XX_INTEGRATION_PROD"."XXDL_UNPAID_PAY_REQUESTS_INT" 
   (	"LEGAL_ENTITY_ID" NUMBER, 
	"LEGAL_ENTITY_NAME" VARCHAR2(50 BYTE), 
	"LEGAL_ENTITY_IDENTIFIER" VARCHAR2(50 BYTE), 
	"BU_NAME" VARCHAR2(150 BYTE), 
	"INVOICE_ID" NUMBER, 
	"PERIOD_NAME" VARCHAR2(7 BYTE), 
	"OIB" VARCHAR2(11 BYTE), 
	"NAME" VARCHAR2(50 BYTE), 
	"SURNAME" VARCHAR2(50 BYTE), 
	"PERSON_NUMBER" NUMBER, 
	"PERIOD_FROM" VARCHAR2(10 BYTE), 
	"PERIOD_TO" VARCHAR2(10 BYTE), 
	"VENDOR_NAME" VARCHAR2(150 BYTE), 
	"VENDOR_SITE_CODE" VARCHAR2(150 BYTE), 
	"VENDOR_ID" NUMBER, 
	"INVOICE_NUM" VARCHAR2(150 BYTE), 
	"INVOICE_CURRENCY_CODE" VARCHAR2(3 BYTE), 
	"EXCHANGE_RATE" NUMBER, 
	"INVOICE_AMOUNT" NUMBER, 
	"AMOUNT_PAID" NUMBER, 
	"LAST_UPDATE_DATE" VARCHAR2(35 BYTE), 
	"STATUS" VARCHAR2(1 BYTE), 
	"MESSAGE" VARCHAR2(2000 BYTE), 
	"LAST_API_MESSAGE" VARCHAR2(2000 BYTE), 
	"LAST_API_CALL_STATUS" VARCHAR2(15 BYTE), 
	"LAST_WS_CALL_ID" NUMBER, 
	"EBS_CHECK_ID" NUMBER, 
	"PAYMENT_NUMBER" NUMBER, 
	"INSERT_INTERFACE_STATUS" VARCHAR2(15 BYTE), 
	"INSERT_INTERFACE_MESSAGE" VARCHAR2(2000 BYTE)
   );

  CREATE UNIQUE INDEX "XX_INTEGRATION_PROD"."XXDL_UNPAID_PAY_REQUESTS_INT_U" ON "XX_INTEGRATION_PROD"."XXDL_UNPAID_PAY_REQUESTS_INT" ("INVOICE_ID") ;

