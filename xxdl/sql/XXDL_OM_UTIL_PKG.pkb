    SET DEFINE OFF;
    SET VERIFY OFF;
    WHENEVER SQLERROR EXIT FAILURE ROLLBACK;
    WHENEVER OSERROR EXIT FAILURE ROLLBACK;
    create or replace package body XXDL_OM_UTIL_PKG as
    /*$Header:  $
    =============================================================================
    -- Name        :  XXDL_OM_UTIL_PKG
    -- Author      :  Zoran Kovac
    -- Date        :  07-SEP-2022
    -- Version     :  120.00
    -- Description :  Cloud Utils package
    --
    -- -------- ------ ------------ -----------------------------------------------
    --   Date    Ver     Author     Description
    -- -------- ------ ------------ -----------------------------------------------
    -- 07-09-22 120.00 zkovac       Initial creation 
    --*/
    c_log_module   CONSTANT VARCHAR2(300) := $$PLSQL_UNIT;
    g_prod_url VARCHAR2(300) := 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com/';
    g_dev_url VARCHAR2(300) := 'https://fa-encc-test-saasfaprod1.fa.ocs.oraclecloud.com/';

    /*===========================================================================+
        Procedure   : log
        Description : Puts the p_text variable to output file
        Usage       : Writing the output of the request
        Arguments   : p_text - text to output
    ============================================================================+*/
    PROCEDURE LOG (p_text IN VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_text);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;



    /*===========================================================================+
        Procedure   : get_ws_err_msg
        Description : Gets REST call error_msg
        Usage       : Writing the output of the request
        Arguments   : p_ws_call_id - ws call id
    ============================================================================+*/
    function get_ws_err_msg (p_ws_call_id IN number) return varchar2
    is
    l_text xxfn_ws_call_log.response_clob%TYPE;

    BEGIN
        begin 
        select xx.response_clob into l_text 
        from
        xxfn_ws_call_log xx
        where xx.ws_call_id = p_ws_call_id;
        exception
            when no_data_found then
            l_text:=null;
        end;

        return l_text;    

    EXCEPTION
        WHEN others
        THEN
            NULL;
    END;

    /*===========================================================================+
        Procedure   : get_config
        Description : Gets config value
        Usage       : Returnig config value
        Arguments   : p_service - text to output
    ============================================================================+*/
    function get_config (p_service IN VARCHAR2) return varchar2
    IS
    l_value VARCHAR2(1000);
    BEGIN
        select xx.value into l_value
        from
        xx_configuration xx
        where xx.name = p_service;

        return l_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;
    
    /*===========================================================================+
    Function   : DecodeBASE64
    Description : Decodes BASE64
    Usage       : 
    Arguments   : 
    Returns     :
    ============================================================================+*/
    FUNCTION DecodeBASE64(InBase64Char IN OUT NOCOPY CLOB) RETURN CLOB IS

        blob_loc BLOB;
        clob_trim CLOB;
        res CLOB;

        lang_context INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
        dest_offset INTEGER := 1;
        src_offset INTEGER := 1;
        read_offset INTEGER := 1;
        warning INTEGER;
        ClobLen INTEGER;

        amount INTEGER := 1440; -- must be a whole multiple of 4
        buffer RAW(1440);
        stringBuffer VARCHAR2(1440);

    BEGIN

        -- Remove all NEW_LINE from base64 string
        ClobLen := DBMS_LOB.GETLENGTH(InBase64Char);
        DBMS_LOB.CREATETEMPORARY(clob_trim, TRUE);
        LOOP
            EXIT WHEN read_offset > ClobLen;
            stringBuffer := REPLACE(REPLACE(DBMS_LOB.SUBSTR(InBase64Char, amount, read_offset), CHR(13), NULL), CHR(10), NULL);
            DBMS_LOB.WRITEAPPEND(clob_trim, LENGTH(stringBuffer), stringBuffer);
            read_offset := read_offset + amount;
        END LOOP;

        read_offset := 1;
        ClobLen := DBMS_LOB.GETLENGTH(clob_trim);
        DBMS_LOB.CREATETEMPORARY(blob_loc, TRUE);
        LOOP
            EXIT WHEN read_offset > ClobLen;
            buffer := UTL_ENCODE.BASE64_DECODE(UTL_RAW.CAST_TO_RAW(DBMS_LOB.SUBSTR(clob_trim, amount, read_offset)));
            DBMS_LOB.WRITEAPPEND(blob_loc, DBMS_LOB.GETLENGTH(buffer), buffer);
            read_offset := read_offset + amount;
        END LOOP;

        DBMS_LOB.CREATETEMPORARY(res, TRUE);
        DBMS_LOB.CONVERTTOCLOB(res, blob_loc, DBMS_LOB.LOBMAXSIZE, dest_offset, src_offset,  DBMS_LOB.DEFAULT_CSID, lang_context, warning);

        DBMS_LOB.FREETEMPORARY(blob_loc);
        DBMS_LOB.FREETEMPORARY(clob_trim);
        RETURN res;


    END DecodeBASE64;


    /*===========================================================================+
    Function   : get_om_mfg_req
    Description : Download supply req for mfg from OM
    Usage       :
    Arguments   : p_entity - name of the entity we download, SUPPLY_HEADERS, SUPPLY_LINES
                p_date - entities max date of creation of last_update_date
    Remarks     :
    ============================================================================+*/
    function get_om_mfg_req(p_entity in varchar2, P_DATE IN varchar2) return varchar2
    is

    l_body VARCHAR2(30000);
    l_result varchar2(500);
    l_result_clob  clob;
    x_return_status varchar2(500);
    x_return_message varchar2(32000);
    l_soap_env clob;
    l_text varchar2(32000);
    x_ws_call_id number;
    l_inflated_resp blob;
    l_result_nr varchar2(32000);
    l_resp_xml       XMLType;
    l_resp_xml_id   XMLType;
    l_result_nr_id  varchar2(500);
    l_result_varchar  varchar2(32000);
    l_result_clob_decode clob;

    l_app_url varchar2(300);

    l_req_head_rec xxdl_om_egzat%ROWTYPE;
    l_req_head_rec_empty xxdl_om_egzat%ROWTYPE;
    l_req_line_rec xxdl_om_eszat%ROWTYPE;
    l_req_line_rec_empty xxdl_om_eszat%ROWTYPE;

    XX_NO_REPORT exception;

    BEGIN

    execute immediate 'alter session set NLS_TIMESTAMP_TZ_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM''';
    --execute immediate 'alter session set nls_date_format=''yyyy-mm-dd hh24:mi:ss''';
    --execute immediate 'alter session set NLS_TIMESTAMP_FORMAT= ''YYYY-MM-DD"T"HH24:MI:SS.FF3''';

    l_app_url := get_config('ServiceRootURL');

    l_text :='<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:pub="http://xmlns.oracle.com/oxp/service/PublicReportService">
    <soap:Header/>
    <soap:Body>
        <pub:runReport>
            <pub:reportRequest>
                <pub:attributeFormat>xml</pub:attributeFormat>
                <pub:attributeLocale></pub:attributeLocale>
                <pub:attributeTemplate></pub:attributeTemplate>
                <pub:parameterNameValues>
                <!--Zero or more repetitions:-->
                <pub:item>
                    <pub:name>p_entity</pub:name>
                    <pub:values>
                        <!--Zero or more repetitions:-->
                        <pub:item>'||p_entity||'</pub:item>   
                    </pub:values>
                </pub:item>
                <pub:item>
                    <pub:name>p_date</pub:name>
                    <pub:values>
                        <!--Zero or more repetitions:-->
                        <pub:item>'||p_date||'</pub:item>   
                    </pub:values>
                </pub:item>
                </pub:parameterNameValues>
                <pub:reportAbsolutePath>Custom/XXDL_Integration/XXDL_OM_REQ_MFG_REP.xdo</pub:reportAbsolutePath>
                <pub:sizeOfDataChunkDownload>-1</pub:sizeOfDataChunkDownload>
            </pub:reportRequest>
            <pub:appParams></pub:appParams>
        </pub:runReport>
    </soap:Body>
    </soap:Envelope>';

    --log('Payload:'||l_text);

    l_soap_env := to_clob(l_text);

    XXFN_CLOUD_WS_PKG.WS_CALL(
        p_ws_url => l_app_url||'xmlpserver/services/ExternalReportWSSService?WSDL',
        p_soap_env => l_soap_env,
        p_soap_act => 'runReport',
        p_content_type => 'application/soap+xml;charset="UTF-8"',
        x_return_status => x_return_status,
        x_return_message => x_return_message,
        x_ws_call_id => x_ws_call_id);
        
    dbms_lob.freetemporary(l_soap_env);
    log('Call id:'||x_ws_call_id);
    log('Return status: '||x_return_status);
    --log(x_return_message);


    if(x_return_status = 'S') then
    
        log('Extracting xml response');
        
        begin
        select response_xml
        into l_resp_xml
        from xxfn_ws_call_log
        where ws_call_id = x_ws_call_id;
        exception
            when no_data_found then
            raise XX_NO_REPORT;
        end;

        begin
        SELECT xml.vals
        INTO l_result_clob
        FROM xxfn_ws_call_log a,
            XMLTable(xmlnamespaces('http://xmlns.oracle.com/oxp/service/PublicReportService' AS "ns2",'http://www.w3.org/2003/05/soap-envelope' AS "env"), '/env:Envelope/env:Body/ns2:runReportResponse/ns2:runReportReturn' PASSING a.response_xml COLUMNS vals CLOB PATH './ns2:reportBytes') xml
        WHERE a.ws_call_id = x_ws_call_id
        AND xml.vals      IS NOT NULL;
        exception
            when no_data_found then
            raise XX_NO_REPORT;
        end;
        
        
        l_result_clob_decode := DecodeBASE64(l_result_clob);
        
        l_resp_xml_id := XMLType.createXML(l_result_clob_decode);
        
        log('Parsing report response for supply headers');
        
        FOR cur_rec IN (
        SELECT xt.*
        FROM   XMLTABLE('/DATA_DS/SUPPLY_HEADERS'
                PASSING l_resp_xml_id
                COLUMNS 
                    BRINZ VARCHAR2(16 BYTE) PATH 'INTERNAL_REQUEST', 
                    BUGNA VARCHAR2(16 BYTE) PATH 'INTERNAL_ORDER',
                    DUNNA VARCHAR2(35) PATH 'ORDERED_DATE',
                    SKD NUMBER PATH 'PARTY_SITE_NUMBER',
                    HEADER_ID_EBS NUMBER PATH 'SO_HEADER_ID',
                    PROJEKT NUMBER PATH 'PROJECT',
                    TRG VARCHAR2(3) PATH 'BU',
                    IZVOR_OM VARCHAR2(25) PATH 'SO_DESCRIPTION',
                    OPIS_OM VARCHAR2(240) PATH 'SUPPLY_ORDER_REFERENCE_NUMBER',
                    OTNA VARCHAR2(80) PATH 'ATEST',
                    CREATION_DATE VARCHAR2(35) PATH 'CREATION_DATE',
                    LAST_UPDATE_DATE VARCHAR2(35) PATH 'LAST_UPDATE_DATE'
                ) xt)
        LOOP
    
            log('====================');
            log('Supply order:'||cur_rec.BRINZ);
            log('Transfer order:'||cur_rec.BUGNA);
            log('Datum:'||cur_rec.DUNNA);
            log('SKD:'||cur_rec.SKD);
            log('Projekt:'||cur_rec.PROJEKT);
            log('Izvor:'||cur_rec.IZVOR_OM);
            log('==============================');
            
            
            log('Inserting supply headers into table');
            
            l_req_head_rec.BRINZ := cur_rec.BRINZ;
            l_req_head_rec.BUGNA := cur_rec.BUGNA;
            l_req_head_rec.DUNNA := cast(to_timestamp_tz(  cur_rec.DUNNA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
            l_req_head_rec.SKD := cur_rec.SKD;
            l_req_head_rec.HEADER_ID_EBS := cur_rec.HEADER_ID_EBS;
            l_req_head_rec.PROJEKT := cur_rec.PROJEKT;
            l_req_head_rec.TRG := cur_rec.TRG;
            l_req_head_rec.IZVOR_OM := cur_rec.IZVOR_OM;
            l_req_head_rec.OPIS_OM := cur_rec.OPIS_OM;
            l_req_head_rec.OTNA := cur_rec.OTNA;
            l_req_head_rec.creation_date := cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
            l_req_head_rec.last_update_date := cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
            l_req_head_rec.transf_creation_date := sysdate;
            begin
            
            insert into XXDL_OM_EGZAT values l_req_head_rec;        
            
            exception
            when dup_val_on_index then
            log('Supply header already in table, updating record!');
                update XXDL_OM_EGZAT xx
                set xx.BRINZ = cur_rec.BRINZ
                ,xx.BUGNA = cur_rec.BUGNA
                ,xx.DUNNA = cast(to_timestamp_tz(  cur_rec.DUNNA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
                ,xx.SKD = cur_rec.SKD
                ,xx.HEADER_ID_EBS = cur_rec.HEADER_ID_EBS
                ,xx.PROJEKT = cur_rec.PROJEKT
                ,xx.TRG = cur_rec.TRG
                ,xx.IZVOR_OM = cur_rec.IZVOR_OM
                ,xx.OPIS_OM = cur_rec.OPIS_OM
                ,xx.OTNA = cur_rec.OTNA
                ,xx.creation_date = cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
                ,xx.last_update_date =cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
                ,xx.transf_last_update = sysdate
                where xx.HEADER_ID_EBS = cur_rec.HEADER_ID_EBS;
            end;
        end loop;
        
        log('End of supply headers');
        
        log('Parsing report response for supply header lines');
        
        FOR cur_rec IN (
        SELECT xt.*
        FROM   XMLTABLE('/DATA_DS/SUPPLY_LINES'
                PASSING l_resp_xml_id
                COLUMNS 
                    BRINZ VARCHAR2(16 BYTE) PATH 'INTERNAL_REQUEST', 
                    BUGNA VARCHAR2(16 BYTE) PATH 'INTERNAL_ORDER',
                    DUNNA VARCHAR2(35) PATH 'ORDERED_DATE',
                    RBS2 NUMBER PATH 'LINE_NUM',
                    SPROM VARCHAR2(11) PATH 'ORDERED_ITEM',
                    OPPRO1 VARCHAR2(240) PATH 'ITEM_DESCRIPTION',
                    NARKOL NUMBER PATH 'ORDERED_QTY',
                    DISP VARCHAR2(35) PATH 'REQUEST_SHIP_DATE',
                    HEADER_ID_EBS NUMBER PATH 'INTERNAL_HEADER_ID',
                    LINE_ID_EBS NUMBER PATH 'INTERNAL_LINE_ID',
                    PROJEKT NUMBER PATH 'PROJECT',
                    JMJ  VARCHAR2(3) PATH 'ORDERED_UOM',
                    TRG VARCHAR2(3) PATH 'BU',
                    OM_VEZA_NP_LNUM  VARCHAR2(25) PATH 'SO_LINE_REF',
                    OM_HID  VARCHAR2(150) PATH 'SO_HEADER_ID',
                    OM_LID  VARCHAR2(150) PATH 'SO_LINE_ID',
                    CREATION_DATE VARCHAR2(35) PATH 'CREATION_DATE',
                    LAST_UPDATE_DATE VARCHAR2(35) PATH 'LAST_UPDATE_DATE'
                ) xt)
        LOOP
    
            log('====================');
            log('Internal request:'||cur_rec.BRINZ);
            log('Internal order:'||CUR_REC.BUGNA);
            log('Line num:'||cur_rec.RBS2);
            log('Ordered item:'||cur_rec.SPROM);
            log('Request ship date:'||cur_rec.DISP);
            log('==============================');
            
            
            log('Inserting supplier lines into table');
            l_req_line_rec.BRINZ := cur_rec.BRINZ;
            l_req_line_rec.BUGNA := CUR_REC.BUGNA;
            l_req_line_rec.DUNNA := cast(to_timestamp_tz(  cur_rec.DUNNA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
            l_req_line_rec.RBS2 := cur_rec.RBS2;
            l_req_line_rec.SPROM := cur_rec.SPROM;
            l_req_line_rec.OPPRO1 := cur_rec.OPPRO1;
            l_req_line_rec.NARKOL := cur_rec.NARKOL;
            l_req_line_rec.DISP := cast(to_timestamp_tz(  cur_rec.DISP,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
            l_req_line_rec.HEADER_ID_EBS := cur_rec.HEADER_ID_EBS;
            l_req_line_rec.LINE_ID_EBS := cur_rec.LINE_ID_EBS;
            l_req_line_rec.PROJEKT := cur_rec.PROJEKT;
            l_req_line_rec.JMJ := cur_rec.JMJ;
            l_req_line_rec.TRG := cur_rec.TRG;
            l_req_line_rec.OM_VEZA_NP_LNUM := cur_rec.OM_VEZA_NP_LNUM;
            l_req_line_rec.OM_HID := cur_rec.OM_HID;
            l_req_line_rec.OM_LID := cur_rec.OM_LID;
            l_req_line_rec.creation_date := cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
            l_req_line_rec.last_update_date := cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone);
            l_req_line_rec.transf_creation_date := sysdate;
            
            begin
            
            insert into xxdl_om_eszat values l_req_line_rec;        
            
            exception
            when dup_val_on_index then
            log('Supply line already in table, updating record!');
                update xxdl_om_eszat xx
                set xx.BRINZ = cur_rec.BRINZ
                ,xx.BUGNA = cur_rec.BUGNA
                ,xx.DUNNA = cast(to_timestamp_tz(  cur_rec.DUNNA,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
                ,xx.RBS2 = cur_rec.RBS2
                ,xx.SPROM = cur_rec.SPROM
                ,xx.OPPRO1 = cur_rec.OPPRO1
                ,xx.NARKOL = cur_rec.NARKOL
                ,xx.DISP = cast(to_timestamp_tz(  cur_rec.DISP,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
                ,xx.HEADER_ID_EBS = cur_rec.HEADER_ID_EBS
                ,xx.LINE_ID_EBS = cur_rec.LINE_ID_EBS
                ,xx.PROJEKT = cur_rec.PROJEKT
                ,xx.JMJ = cur_rec.JMJ
                ,xx.TRG = cur_rec.TRG
                ,xx.OM_VEZA_NP_LNUM = cur_rec.OM_VEZA_NP_LNUM
                ,xx.OM_HID = cur_rec.OM_HID
                ,xx.OM_LID = cur_rec.OM_LID
                ,xx.creation_date = cast(to_timestamp_tz(  cur_rec.creation_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
                ,xx.last_update_date =cast(to_timestamp_tz(  cur_rec.last_update_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3TZH:TZM' ) as timestamp with local time zone)
                ,xx.transf_last_update = sysdate
                where xx.LINE_ID_EBS = cur_rec.LINE_ID_EBS;
            end;
        end loop;
        
        
        log('End of supply lines download!');

        
         update xxfn_ws_call_log xx 
                set xx.response_xml = null
                ,xx.response_clob = null
                ,xx.response_blob = null
                ,xx.ws_payload_xml = null
                where ws_call_id = x_ws_call_id;

        log('Cleared xxfn_ws_call_log table!'); 
        
               
    end if;
    return x_return_status;
    exception
    when XX_NO_REPORT then
        log('Cant find the report for call ID:'||x_ws_call_id);
        return 'E';
    when others then
    rollback;
        log('Error occured during web service call for getting xml from cloud: '||sqlcode);
        log('Msg:'||sqlerrm);
        log('Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK());
        log('Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());
        return 'E';
    END get_om_mfg_req;

    /*===========================================================================+
    Function   : get_supplier_info
    Description : retrieves all supplier (supplier, site, address, contact) info to a local EBS custom table
    Usage       : Callin from concurrent program xxdl_CS_SUPPLIER_DL_PRG
    Arguments   :
    Remarks     :
    ============================================================================+*/
    procedure get_om_mfq_info (errbuf out varchar2, retcode out varchar2) is


    l_max_date date;
    l_max_date_empty date;
    l_status varchar2(1);
    begin

    retcode:=0;
    errbuf:= 'Success';

    log('Get max date of creation or update from xxdl_om_egzat');
    
    l_max_date := l_max_date_empty;
    
    begin
    
        select
        case
            when max(xx.creation_date) > max(xx.last_update_date) then
            max(xx.creation_date)
            else max(xx.last_update_date)
            end
        into l_max_date
        from
        xxdl_om_egzat xx;
    exception
        when NO_DATA_FOUND then
        l_max_date := to_date('08.12.2022 00:00:00','DD.MM.RRRR HH24:MI:SS');
    end;
    
    if l_max_date is null then
        l_max_date := to_date('08.12.2022 00:00:00','DD.MM.RRRR HH24:MI:SS');  
    end if;
    
    log('Max date for SUPPLY_HEADERS is:'||to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
    
    log('Calling cloud report for SUPPLY_HEADERS download');
    
    l_status := get_om_mfg_req('SUPPLY_HEADERS',to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
        
    log('Supply headers download status:'||l_status);
    
    log('Get max date of creation or update from xxdl_om_eszat');
    
    l_max_date := l_max_date_empty;
    
    begin
    
        select
        case
            when max(xx.creation_date) > max(xx.last_update_date) then
            max(xx.creation_date)
            else max(xx.last_update_date)
            end
        into l_max_date
        from
        xxdl_om_eszat xx;
    exception
        when NO_DATA_FOUND then
        l_max_date := to_date('08.12.2022 00:00:00','DD.MM.RRRR HH24:MI:SS'); 
    end;
    
    if l_max_date is null then
        l_max_date := to_date('08.12.2022 00:00:00','DD.MM.RRRR HH24:MI:SS');   
    end if;
    
    log('Max date for SUPPLY_LINES is:'||to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
    
    log('Calling cloud report for SUPPLY_LINES download');
    
    l_status := get_om_mfg_req('SUPPLY_LINES',to_char(l_max_date,'YYYY-MM-DD HH24:MI:SS'));
        
    log('Supply lines download status:'||l_status);
    
     
    log('Download procedure is finished');
    

    exception
    when others then
        retcode := 2;
        errbuf := 'Error';
        log('Error occured during web service call for sending csv to cloud: '||sqlcode);
        log('Msg:'||sqlerrm);
        log('Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK());
        log('Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());

    end;


    function parse_cs_response(p_ws_call_id in number) return varchar2 is

    l_head_code          varchar2(4000);
    l_head_error         VARCHAR2(32767);  
    l_line_error         varchar2(4000);
    l_line_code          VARCHAR2(32767);
    l_msg_body VARCHAR2(32767);
    begin


        --get header error

        FOR cur_rec IN (  select xt.code,
                substr(xt.message,instr(xt.message,'<',1,1), length(xt.message)) message
        from   xxfn_ws_call_log x,
                XMLTABLE(
                xmlnamespaces(
                    'http://xmlns.oracle.com/adf/svc/errors/' as "tns",'http://schemas.xmlsoap.org/soap/envelope/' as "env"),
                    '/env:Envelope/env:Body/env:Fault/detail/tns:ServiceErrorMessage/tns:detail'
                PASSING x.response_xml
                COLUMNS
                    code varchar2(4000) PATH 'tns:code',
                    message varchar2(4000) PATH 'tns:message'
                ) xt
        where x.ws_call_id = p_ws_call_id)
        LOOP

            select code,text into l_head_code,l_head_error from XMLTABLE('/MESSAGE' 
                passing (cur_rec.message)
                columns
                    text varchar2(4000) PATH 'TEXT',
                    code varchar2(4000) PATH 'CODE') ;
            if nvl(l_head_error,'X') != 'X' then 
                l_msg_body := 'Gre�ka na glavi RFQ.'||CHR(10);
                l_msg_body := 'Kod:'||l_head_code||CHR(10);
                l_msg_body := 'Tekst:'||l_head_error||CHR(10);
            end if;
        end loop;

        --get lines error

        FOR cur_rec IN (  select xt.code,
                substr(xt.message,instr(xt.message,'<',1,1), length(xt.message)) message
        from   xxfn_ws_call_log x,
                XMLTABLE(
                xmlnamespaces(
                    'http://xmlns.oracle.com/adf/svc/errors/' as "tns",'http://schemas.xmlsoap.org/soap/envelope/' as "env"),
                    '/env:Envelope/env:Body/env:Fault/detail/tns:ServiceErrorMessage/tns:detail/tns:detail'
                PASSING (x.response_xml)
                COLUMNS
                    code varchar2(4000) PATH 'tns:code',
                    message varchar2(4000) PATH 'tns:message'
                ) xt
        where x.ws_call_id = p_ws_call_id)
        LOOP


            if nvl(l_line_error,'X') != 'X' then 
                l_msg_body := 'Greska na linijama RFQ-a'||CHR(10);
                l_msg_body := 'Kod:'||l_line_code||CHR(10);
                l_msg_body := 'Tekst:'||l_line_error||CHR(10);
            end if;
            end loop;     
    return l_msg_body;
    end;

    end XXDL_OM_UTIL_PKG;
    /
    exit;