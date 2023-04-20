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
                where xx.HEADER_ID_EBS = cur_rec.HEADER_ID_EBS
                and xx.bugna = cur_rec.bugna;
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
                    NARKOL VARCHAR2(250) PATH 'ORDERED_QTY',
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
            l_req_line_rec.NARKOL := replace(cur_rec.NARKOL,'.',',');
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
                ,xx.NARKOL = replace(cur_rec.NARKOL,'.',',')
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
    Function   : get_om_mfq_info
    Description : retrieves all internal request for MFG( supply header and supply lines) info to a local EBS custom table
    Usage       :
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

    /*===========================================================================+
    Function   : migrate_sales_orders
    Description : migrate all sales orders  
    Usage       :
    Arguments   :
    Remarks     :
    ============================================================================+*/

    procedure migrate_sales_orders(
        p_sales_order in varchar2,
        p_org_id in number,
        p_rows in number,
        p_retry_error in varchar2
    ) IS

    l_fault_code          varchar2(4000);
    l_fault_string        varchar2(4000); 
    l_soap_env clob;
    l_empty_clob clob;
    l_text varchar2(32000);
    l_find_text varchar2(32000);
    x_return_status varchar2(500);
    x_return_message varchar2(32000);
    x_ws_call_id number;
    l_app_url varchar2(300);
    l_header_rec xxdl_oe_headers_all%rowtype;
    l_header_rec_empty xxdl_oe_headers_all%rowtype;
    l_line_rec xxdl_oe_lines_all%rowtype;
    l_line_rec_empty xxdl_oe_lines_all%rowtype;
    l_count number := 0;




    cursor c_order_headers is 
    select 
        xx_set.business_unit_name
        ,oeoh.ordered_date
        ,xx_set.business_unit_id
        ,xx_set.business_unit_id requesting_business_unit_id
        ,decode(oeoh.cust_po_number,null,'null','"'||apex_escape.json(oeoh.cust_po_number)||'"') cust_po_number
        ,oeoh.header_id
        ,oeoh.order_number
        ,oetl.name order_type_name
        ,xcom.cloud_code order_type_code
        ,xhp.party_name
        ,xhp.cloud_party_id buying_party_id
        ,decode(oeoh.fob_point_code,null,'null','"'||oeoh.fob_point_code||'"') fob_point_code
        ,xhca.account_number
        ,decode(ppa.segment1,null,'null','"'||decode(ppa.segment1,'200237','200094',ppa.segment1)||'"') projekt
        ,oeoh.attribute1 broj_zakljucka
        ,to_char((to_date(oeoh.attribute2,'RRRR/MM/DD HH24:Mi:SS')),'YYYY-MM-DD') datum_zakljucka
        ,oeoh.attribute3 krovni_ugovor
        ,oeoh.attribute4 mtr
        ,xcib.bank_account_id
        ,oeoh.attribute9 mjesto_pariteta
        ,oeoh.attribute5 privremena_lokacija
        ,oeoh.attribute7 reklamacija
        ,decode(oeoh.attribute6,null,'null','"'||oeoh.attribute6||'"') atest
        ,oeoh.attribute12 krovni_nalog
        ,case
            when oeoh.TRANSACTIONAL_CURR_CODE = 'HRK' then
            'EUR'
            else oeoh.TRANSACTIONAL_CURR_CODE
            end TRANSACTIONAL_CURR_CODE
        ,case
            when oeoh.TRANSACTIONAL_CURR_CODE != 'EUR' then
            '"300000003061037"'   --HNB tečaj u cloudu
            else 'null'
            end conversion_type    
        ,xhcasu.cloud_site_use_id ship_to_use_id
        ,jrs.name SALESREP_NAME
        ,rtl.name payment_term  --placeno avansom baci trunacted error bind...
        ,xhcasu.CLOUD_BILL_TO_SITE_USE_ID bill_to_use_id
        ,xhcasu.cloud_party_site_id
        ,oeoh.request_date
        --,decode(xcos.resource_id,null,'null',decode(xcos.resource_id,300000003542083,300000003558607,xcos.resource_id)) cloud_salesperson_id
        ,xcos.resource_id cloud_salesperson_id
        from
        apps.oe_order_headers_all@ebsprod oeoh
        ,xxdl_cloud_reference_sets xx_set
        ,apps.oe_transaction_types_tl@ebsprod oetl
        ,xxdl_hz_cust_accounts xhca
        ,xxdl_hz_parties xhp
        ,xxdl_hz_cust_acct_sites xhcas
        ,xxdl_hz_cust_acct_site_uses xhcasu
        ,apps.pa_projects_all@ebsprod ppa
        ,(select distinct * from xxdl_om_mig_bank_acc) xx_bank
        ,xxdl_cloud_internal_bank_accounts xcib
        ,apps.jtf_rs_salesreps@ebsprod jrs
        ,apps.ra_terms_tl@ebsprod rtl
        ,xxdl_cloud_om_order_types xcom
        ,xxdl_cloud_om_salesreps xcos
        ,(select
            *
            from
            per_all_people_f@ebsprod ppf
            where nvl(ppf.effective_end_date,sysdate) >= sysdate) ppf
        where 1=1
        and oeoh.order_number = p_sales_order
        and oeoh.org_id = p_org_id
        and oeoh.org_id = xx_set.ebs_org_id
        and oeoh.order_type_id = oetl.transaction_type_id
        and oetl.language = 'US'
        and lower(oetl.name) not like '%intern%'
        and oeoh.sold_to_org_id = xhca.cust_account_id
        and xhca.party_id = xhp.party_id
        and xhca.cust_account_id = xhcas.cust_account_id
        and xhcas.cust_acct_site_id = xhcasu.cust_acct_site_id
        and oeoh.ship_to_org_id = xhcasu.site_use_id
        and xhcasu.site_use_code = 'SHIP_TO'
        and xhcasu.cloud_set_id = xx_set.reference_data_set_id
        and oeoh.attribute14 = xx_bank.bank_account_id(+)
        and oeoh.org_id = xx_bank.org_id(+)
        and oeoh.salesrep_id = jrs.salesrep_id
        and oeoh.attribute16 = ppa.project_id(+)
        and oeoh.payment_term_id = rtl.term_id
        and rtl.language = 'HR'
        and xx_bank.iban_number = xcib.iban_number(+)
        /*
        and xcib.currency_code = case
            when oeoh.TRANSACTIONAL_CURR_CODE = 'HRK' then
            'EUR'
            else oeoh.TRANSACTIONAL_CURR_CODE
            end 
            */      
        and oeoh.order_type_id = xcom.transaction_type_id
        and jrs.person_id = ppf.person_id(+)
        and ppf.first_name||' '||ppf.last_name = xcos.salesrep_name(+)
        --and xhp.party_name not in ('Gradilište','MPR - Skladište prodaje MK)
        and oeoh.creation_date > to_date('01.01.2019','DD.MM.RRRR')
        and exists (select 1 from apps.oe_order_lines_all@ebsprod oeol
                        where oeol.header_id = oeoh.header_id
                        and oeol.flow_status_code not in ('CLOSED'))
            ;


    cursor c_order_lines(c_header_id in number) is
    select
    oeoh.order_number
    ,oeoh.header_id
    ,oeol.line_ID
    ,substr(oeol.user_item_description,1,150) user_item_description
    --,oeol.split_from_line_id
    ,xx_item.segment1 item_number
    ,xx_item.cloud_item_id
    ,case
        when xx_item.organization_code = 'EMU' then
            'DLK'
        when xx_item.organization_code = 'PMK' then
            'DLK'
        when xx_item.organization_code = 'POS' then
            'DLK'
        else
        xx_item.organization_code
        end requested_fulfillment_org_code
    ,oeoh.transactional_curr_code
    ,oeol.line_number
    ,oeol.shipment_number
    ,case 
      when oeoh.transactional_curr_code = 'HRK' then
        round(oeol.unit_list_price/7.53450,2)
      else 
        oeol.unit_list_price
    end list_price_conv
    ,decode(oeol.ordered_quantity,0,oeol.cancelled_quantity,oeol.ordered_quantity) ordered_quantity
    ,oeol.ORDER_QUANTITY_UOM
    ,opa.price_adjustment_id
    ,oeol.unit_list_price
    ,oeol.unit_selling_price
    ,oeol.promise_date
    ,decode(oeol.tax_code,null,'null','"'||oeol.tax_code||'"') tax_code
    ,oeol.attribute1 nalog_izrade
    ,decode(oeol.attribute4,null,'null','"'||oeol.attribute4||'"') koordinacija
    ,oeol.attribute6 radni_nalog
    ,decode(oeol.attribute8,null,'null','"'||oeol.attribute8||'"') prijevoz_mt
    ,oeol.attribute9 prijevoz_km
    ,oeol.attribute10 prijevoz_sati
    ,oeol.request_date
    ,oeol.schedule_ship_date
    ,xhp.party_name
    ,xx_set.business_unit_name
    ,xx_set.business_unit_id
    ,xx_set.business_unit_id requesting_business_unit_id
    ,xhp.cloud_party_id buying_party_id
    ,xhcasu.cloud_site_use_id ship_to_use_id
    ,xhcasu.CLOUD_BILL_TO_SITE_USE_ID bill_to_use_id
    from
    apps.oe_order_headers_all@ebsprod oeoh
    ,apps.oe_order_lines_all@ebsprod oeol
    ,xxdl_mtl_system_items_mig xx_item
    ,xxdl_cloud_reference_sets xx_set
    ,xxdl_hz_cust_accounts xhca
    ,xxdl_hz_parties xhp
    ,xxdl_hz_cust_acct_sites xhcas
    ,xxdl_hz_cust_acct_site_uses xhcasu
    ,(select * from apps.oe_price_adjustments@ebsprod 
        where list_line_type_code not in ('TAX')) opa
    where
    oeoh.header_id = oeol.header_id
    and oeol.inventory_item_id = xx_item.inventory_item_id
    and oeol.ship_from_org_id = xx_item.organization_id
    --and oeoh.order_number in('103876')
    and oeol.flow_status_code not in ('CLOSED','CANCELLED')
    and oeoh.flow_status_code not in ('DRAFT')
    and oeol.org_id = xx_set.ebs_org_id
    and oeol.sold_to_org_id = xhca.cust_account_id
    and xhca.party_id = xhp.party_id 
    and xhca.cust_account_id = xhcas.cust_account_id
    and xhcas.cust_acct_site_id = xhcasu.cust_acct_site_id
    and oeol.ship_to_org_id = xhcasu.site_use_id
    and xhcasu.site_use_code = 'SHIP_TO'
    and xhcasu.cloud_set_id = xx_set.reference_data_set_id
    and oeol.line_id = opa.line_id(+)
    and oeoh.header_id = c_header_id
    ;
    begin



    l_app_url := get_config('ServiceRootURL');
    --l_app_url := get_config('EwhaTestServiceRootURL');

    log('Starting import!');

    for c_h in c_order_headers loop

        log('   Found order: '||c_h.order_number);

        l_header_rec.ORDER_NUMBER := c_h.ORDER_NUMBER;
        l_header_rec.HEADER_ID := c_h.HEADER_ID;
        l_header_rec.TRANSACTIONAL_CURR_CODE := c_h.TRANSACTIONAL_CURR_CODE;
        l_header_rec.BU_NAME := c_h.business_unit_name;
        l_header_rec.BUYING_PARTY_NAME := c_h.party_name;
        l_header_rec.ACCOUNT_NUMBER  := c_h.ACCOUNT_NUMBER ;
        l_header_rec.ORDER_TYPE := c_h.ORDER_TYPE_name;
        l_header_rec.BILL_TO_USE_ID  := c_h.BILL_TO_USE_ID ;
        l_header_rec.SHIP_TO_USE_ID := c_h.SHIP_TO_USE_ID;
        l_header_rec.BROJ_ZAKLJUCKA := c_h.BROJ_ZAKLJUCKA;
        l_header_rec.DATUM_ZAKLJUCKA := c_h.DATUM_ZAKLJUCKA;
        l_header_rec.KROVNI_UGOVOR := c_h.KROVNI_UGOVOR;
        l_header_rec.MTR := c_h.MTR;
        l_header_rec.PROJEKT := c_h.PROJEKT;
        l_header_rec.BANK_ACCOUNT := c_h.BANK_ACCOUNT_ID;
        l_header_rec.ATEST := c_h.ATEST;
        l_header_rec.PARITET := c_h.mjesto_pariteta;
        l_header_rec.PRIVREMENA_LOKACIJA := c_h.PRIVREMENA_LOKACIJA;
        l_header_rec.REKLAMACIJA := c_h.REKLAMACIJA;
        l_header_rec.KROVNI_NALOG := c_h.KROVNI_NALOG;
        l_header_rec.SALESREP_NAME := c_h.SALESREP_NAME;
        l_header_rec.PAYMENT_TERM_CODE := c_h.PAYMENT_TERM;
        l_header_rec.CUST_PO_NUMBER := c_h.CUST_PO_NUMBER;
        l_header_rec.ORDERED_DATE  := c_h.ORDERED_DATE ;
        l_header_rec.REQUEST_DATE  := c_h.request_date ;
        l_header_rec.CREATION_DATE := sysdate;

        begin
          insert into xxdl_oe_headers_all values l_header_rec;
          exception
            when dup_val_on_index then
             update xxdl_oe_headers_all xx
             set xx.last_update_date = sysdate
             where xx.header_id = c_h.header_id
              ;
        end;


        log('   Building order header payloads!');
        dbms_lob.createtemporary(l_soap_env, TRUE);

        l_find_text := '{
                "SourceTransactionNumber": "'||c_h.order_number||'",
                "SourceTransactionSystem": "OPS",
                "SourceTransactionId": "'||c_h.header_id||'",
                "TransactionalCurrencyCode": "'||c_h.transactional_curr_code||'",
                "BusinessUnitName": "'||c_h.business_unit_name||'",
                "BuyingPartyName": "'||c_h.party_name||'",
                "TransactionOn": "'||to_char(sysdate,'YYYY-MM-DD HH24:MI:SS')||'",
                "SubmittedFlag": false,
                "FreezePriceFlag": false,
                "FreezeShippingChargeFlag": false,
                "FreezeTaxFlag": false,
                "RequestingBusinessUnitName": "'||c_h.business_unit_name||'",
                "TransactionTypeCode":"'||c_h.order_type_code||'",
                "SalespersonId":'||c_h.cloud_salesperson_id||',
                "CustomerPONumber":'||c_h.cust_po_number||',
                "FOBPointCode":'||c_h.fob_point_code||',
                "CurrencyConversionType":'||c_h.conversion_type||',
                "billToCustomer": [
                    {
                        "PartyName": "'||c_h.party_name||'",
                        "AccountNumber": "'||c_h.account_number||'",
                        "SiteUseId": '||c_h.BILL_TO_USE_ID||'
                    }
                ],
                "shipToCustomer": [
                    {
                        "PartyName": "'||c_h.party_name||'",
                        "SiteId": '||c_h.cloud_party_site_id||'
                    }
                ],
                "additionalInformation": [
                    {
                        "Category": "DOO_HEADERS_ADD_INFO",
                        "HeaderEffBDodatneInformacijeprivateVO": [
                            {
                                "ContextCode": "DodatneInformacije",
                                "brojzakljucka": "'||c_h.broj_zakljucka||'",
                                "datumzakljucka": "'||c_h.datum_zakljucka||'",
                                "krovniugovor": "'||c_h.krovni_ugovor||'",
                                "mt": "'||c_h.MTR||'",
                                "brojziroracuna": "'||c_h.bank_account_id||'",
                                "mjestopariteta": "'||c_h.mjesto_pariteta||'",
                                "reklamacijaNalogIzrade": "'||c_h.REKLAMACIJA||'",
                                "krovninalogprodaje": "'||c_h.krovni_nalog||'",
                                "projekt": '||c_h.projekt||'
                            }
                        ]
                    }
                ],
                "lines": [';

        l_soap_env := l_soap_env||to_clob(l_find_text);

        for c_l in c_order_lines(c_h.header_id) loop

            l_find_text:='';

            log('       Found line number:'||c_l.line_number||'.'||c_l.shipment_number);
            log('       Found order item:'||c_l.item_number);
            log('       Found order qty:'||c_l.ordered_quantity);
            log('       Found order price:'||c_l.list_price_conv);
            log('       Found order warehouse:'||c_l.requested_fulfillment_org_code);

            l_line_rec.LINE_ID := c_l.LINE_ID;
            l_line_rec.HEADER_ID := c_l.HEADER_ID;
            l_line_rec.ORDER_NUMBER := c_l.ORDER_NUMBER;
            l_line_rec.TRANSACTIONAL_CURR_CODE := c_l.TRANSACTIONAL_CURR_CODE;
            l_line_rec.BU_NAME := c_l.business_unit_name;
            l_line_rec.BUYING_PARTY_NAME := c_l.PARTY_NAME;
            l_line_rec.BILL_TO_USE_ID := c_l.BILL_TO_USE_ID;
            l_line_rec.SHIP_TO_USE_ID := c_l.SHIP_TO_USE_ID;
            l_line_rec.LINE_NUMBER := c_l.LINE_NUMBER;
            l_line_rec.SHIPMENT_NUMBER := c_l.SHIPMENT_NUMBER;
            l_line_rec.ITEM_NUMBER := c_l.ITEM_NUMBER;
            l_line_rec.ITEM_ID := c_l.cloud_item_id;
            l_line_rec.UOM := c_l.ORDER_QUANTITY_UOM;
            l_line_rec.ORDERED_QUANTITY := c_l.ORDERED_QUANTITY;
            l_line_rec.UNIT_SELLING_PRICE := c_l.UNIT_SELLING_PRICE;
            l_line_rec.SELLING_PRICE_CONV := c_l.list_price_conv;
            l_line_rec.SHIP_FROM_ORG_CODE := c_l.requested_fulfillment_org_code;
            l_line_rec.REQUEST_DATE := c_l.REQUEST_DATE;
            l_line_rec.PROMISE_DATE := c_l.PROMISE_DATE;
            l_line_rec.SHIP_DATE := c_l.schedule_ship_date;
            l_line_rec.SALESREP_NAME := c_h.SALESREP_NAME;
            l_line_rec.TAX_CODE := c_l.TAX_CODE;
            l_line_rec.NALOG_IZRADE := c_l.NALOG_IZRADE;
            l_line_rec.KOORDINACIJA := c_l.KOORDINACIJA;
            l_line_rec.RADNI_NALOG := c_l.RADNI_NALOG;
            l_line_rec.MT_GARAZNI := c_l.prijevoz_mt;
            l_line_rec.KM_GARAZNI := c_l.prijevoz_km;
            l_line_rec.SATI_GARAZNI := c_l.prijevoz_sati;
            l_line_rec.CREATION_DATE := sysdate;

            begin
              insert into xxdl_oe_lines_all values l_line_rec;
              exception
                when dup_val_on_index then
                update xxdl_oe_lines_all xx
                set xx.last_update_date = sysdate
                where xx.line_id = c_l.line_id
                  ;
            end;

            if l_count > 0 then

                l_find_text := ',';

            end if;

             l_find_text := l_find_text||'                 
                    {
                        "SourceTransactionLineId": "'||c_l.line_id||'",
                        "SourceTransactionLineNumber": "'||c_l.line_number||'",
                        "SourceScheduleNumber": "'||c_l.line_number||'",
                        "SourceTransactionScheduleId": "'||c_l.line_number||'",
                        "OrderedUOMCode": "'||c_l.order_quantity_uom||'",
                        "OrderedQuantity": '||replace(c_l.ordered_quantity,',','.')||',
                        "ProductNumber": "'||c_l.item_number||'",
                        "PaymentTerms": "'||c_h.payment_term||'",
                        "ShipmentPriority": "High",
                        "RequestedShipDate": "'||to_char(sysdate,'YYYY-MM-DD HH24:MI:SS')||'",
                        "RequestedFulfillmentOrganizationCode": "'||c_l.requested_fulfillment_org_code||'",
                        "TaxClassificationCode":'||c_l.tax_code||',
                        "billToCustomer": [
                            {
                                "PartyName": "'||c_h.party_name||'",
                                "AccountNumber": "'||c_h.account_number||'",
                                "SiteUseId": '||c_h.BILL_TO_USE_ID||'
                            }
                        ],
                        "shipToCustomer": [
                            {
                                "PartyName": "'||c_h.party_name||'",
                                "SiteId": '||c_h.cloud_party_site_id||'
                            }
                        ],
                        "additionalInformation": [
                            {
                                "Category": "DOO_FULFILL_LINES_ADD_INFO",
                                "FulfillLineEffBxxdlAdditionaLineInfoprivateVO": [
                                    {
                                        "ContextCode": "xxdlAdditionaLineInfo",
                                        "saleprcoverrideval": "'||replace(round(c_l.list_price_conv,2),',','.')||'",
                                        "itemDescription": "'||apex_escape.json(c_l.user_item_description)||'",
                                        "nalogIzrade": "'||c_l.nalog_izrade||'",
                                        "koordinacijaNaloga": '||c_l.koordinacija||',
                                        "radniNalog": "'||c_l.radni_nalog||'",
                                        "prijevozMt": '||c_l.prijevoz_mt||',
                                        "prijevozKm": "'||c_l.prijevoz_km||'",
                                        "prijevozSati": "'||c_l.prijevoz_sati||'"
                                    }
                                ]
                            }
                        ]
                    }';
          l_soap_env := l_soap_env||to_clob(l_find_text);          

          l_count := l_count + 1;

          l_find_text:= '';

        end loop;
        

        l_find_text := '
                ]
             }';
        l_soap_env := l_soap_env||to_clob(l_find_text);
        log ('    Calling web service:');

        XXFN_CLOUD_WS_PKG.WS_REST_CALL(
            p_ws_url => l_app_url||'fscmRestApi/resources/11.13.18.05/salesOrdersForOrderHub',
            p_rest_env => l_soap_env,
            p_rest_act => 'POST',
            p_content_type => 'application/json;charset="UTF-8"',
            x_return_status => x_return_status,
            x_return_message => x_return_message,
            x_ws_call_id => x_ws_call_id);


        log('       ws_call_id: '||x_ws_call_id);
        log('       status: '||x_return_status);

        if x_return_status = 'S' then
            log('   Order created!');


            begin
                with json_response as
                    (
                    (
                        select
                        cloud_header_id
                        from
                        xxfn_ws_call_log xx,
                        json_table(xx.response_json,'$'
                            columns(
                                            cloud_header_id number path '$.HeaderId'))
                        where xx.ws_call_id = x_ws_call_id
                        union
                        select
                        cloud_header_id
                        from
                        xxfn_ws_call_log xx,
                        json_table(xx.response_json,'$'
                            columns(nested path '$.items[*]'
                                    columns(
                                        cloud_header_id number path '$.HeaderId'
                                    )))
                        where xx.ws_call_id = x_ws_call_id          
                        )
                    )
                    select
                    nvl(jt.cloud_header_id,0)
                    into l_header_rec.cloud_header_id
                    from
                    json_response jt
                    where rownum = 1;


                    exception
                    when no_data_found then
                        l_header_rec.cloud_header_id := 0;

                    end;

                    log('           Cloud header_id:'||l_header_rec.cloud_header_id);

                    begin
                        update xxdl_oe_headers_all xx
                        set xx.cloud_header_id = l_header_rec.cloud_header_id
                        where xx.header_id = c_h.header_id;

            end;

            for c_cl in (
                        select
                        cloud_header_id
                        ,cloud_line_id
                        ,source_line_id
                        from
                        xxfn_ws_call_log xx,
                        json_table(xx.response_json,'$'
                            columns(nested path '$.lines[*]'
                                    columns(
                                        cloud_header_id number path '$.HeaderId',
                                        cloud_line_id number path '$.LineId',
                                        source_line_id number path '$.SourceTransactionLineId'
                                    )))
                        where xx.ws_call_id = x_ws_call_id
            ) loop
                
              log('           Cloud line_id:'||c_cl.cloud_line_id);

              update xxdl_oe_lines_all xx
              set xx.process_flag = 'S'
              ,xx.cloud_header_id = c_cl.cloud_header_id
              ,xx.cloud_line_id = c_cl.cloud_line_id
              where xx.line_id = c_cl.source_line_id;
            end loop;
        else
            log('   Order creation failed!');
            --log('   Error:'||x_return_message);

            begin
                select
                        substr(xx.response_json,1,4000) into x_return_message
                        from
                        xxfn_ws_call_log xx
                        where xx.ws_call_id = x_ws_call_id;


                    exception
                    when no_data_found then
                        null;
            end;

            update xxdl_oe_headers_all xx
            set xx.process_flag = 'E'
            ,xx.ERROR_MSG = x_return_message
            where xx.header_id = c_h.header_id;

            log('error:'||x_return_message);

            update xxdl_oe_lines_all xx
            set xx.process_flag = 'E'
            ,xx.ERROR_MSG = x_return_message
            where xx.header_id = c_h.header_id;

        end if;    

    end loop;


    log('Order import finished!');
    exception
        when others then
            dbms_output.put_line('Unexpected error! SQLCODE:'||SQLCODE||' SQLERRM:'||SQLERRM);
            dbms_output.put_line('Error_Stack...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_STACK()||' Error_Backtrace...' || Chr(10) || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE());

    end migrate_sales_orders;

    end XXDL_OM_UTIL_PKG;
