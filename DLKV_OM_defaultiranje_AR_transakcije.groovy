import oracle.apps.scm.doo.common.extensions.ValidationException;
import oracle.apps.scm.doo.common.extensions.Message;

testing;

def extensionName  = context.getExtensionName();
def varMessage = null;
def billingTxnTypeId = null;
def billingTxnTypeName = null;

//intialize message list
List<Message> messages = new ArrayList<Message>();
ValidationException ex = new ValidationException(messages);

//limiting extension to a specific PO number, only for testing
//uncomment when debugging
//def varMessage = "IN code";
def poNumber = header.getAttribute("CustomerPONumber");
if (poNumber==null) return;
if (!poNumber.startsWith("TestWarning_run_extension")) return;

//get system current time
def varTime = context.getCurrentTime();
//varMessage = "Extension - Started: - " + extensionName + " - at - " + varTime;
//messages.add(new Message( Message.MessageType.ERROR,varMessage));

//get order type code from order header
def orderTypeCode = header.getAttribute("TransactionTypeCode");
//varMessage = "Order Type Code: " + orderTypeCode
//messages.add(new Message( Message.MessageType.ERROR,varMessage));

if (orderTypeCode == null) {
  varMessage = "Order type was not selected!";
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
}
else
{
  billingTxnTypeName = getBillingTxnTypeName("XXDL_OM_ORDER_BILLLIN_MAP",orderTypeCode);
  //varMessage = "Billing Txn Type: " + billingTxnTypeName;
  //messages.add(new Message( Message.MessageType.ERROR, varMessage));
  
  if(billingTxnTypeName == null){
    varMessage = "Billing Txn Type not found for order type => " + orderTypeCode + ". You need to set the mapping in common lookup XXDL_OM_ORDER_BILLLIN_MAP!";
    messages.add(new Message( Message.MessageType.ERROR, varMessage));
  }
  
  if(billingTxnTypeName!=null)
  {
    billingTxnTypeId = getBillingTxnTypeId(billingTxnTypeName);
    //varMessage = "Billing Txn Type Id: " + billingTxnTypeId;
    //messages.add(new Message( Message.MessageType.ERROR, varMessage));
    if(billingTxnTypeId == null)
    {
      varMessage = "Billing Txn Type Id not found for Billing Trx name => " + billingTxnTypeName;
      messages.add(new Message( Message.MessageType.ERROR, varMessage));
    }
    if(billingTxnTypeId != null)
    {
      def lines = header.getAttribute("Lines");// get the lines row set
      //varMessage = "ABOUT TO LOOP through lines";
      //messages.add(new Message( Message.MessageType.ERROR,varMessage));
      while(lines.hasNext())
      {
        // if there are more order lines
        def line = lines.next();
        //varMessage = "IN LINES - here we go";
        //messages.add(new Message( Message.MessageType.ERROR,varMessage));
        line.setAttribute("BillingTransactionTypeIdentifier",billingTxnTypeId);
        //varMessage = "Billing Transaction Type ID is set to: " + billingTxnTypeId;
        //messages.add(new Message( Message.MessageType.ERROR,varMessage));
      }
    }
  }
}

//varMessage = "EXITING ";

if (varMessage!=null)
{
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
  ex = new ValidationException(messages);
  throw ex;
}

return;

//Function to get Billing Transaction Type

Long getBillingTxnTypeId(String billingTxnTypeName) {
  
  //messages uncomment only for debugging
  /*List<Message> messages = new ArrayList<Message>();
  varMessage = "Entering getBillingTxnTypeId";
  messages.add(new Message(Message.MessageType.ERROR,varMessage));
  varMessage = "Billing Type passed: " + billingTxnTypeName;*/

  def txnTypePVO = context.getViewObject("oracle.apps.financials.receivables.publicView.TransactionTypePVO");

  //Create view criteria (where clause predicates)
  def vc = txnTypePVO.createViewCriteria();
  def vcrow = vc.createViewCriteriaRow();

  //Only return Billing Transaction Type for the - Common Set - to be changed as required

  vcrow.setAttribute("Name", billingTxnTypeName);
  vcrow.setAttribute("SetName", "Common Set");

  //Execute the view object query to find a matching row
  def rowset = txnTypePVO.findByViewCriteriaWithBindVars(vc, 1, new String[0], new Object[0]);

  //check if we have a matching row
  def row = rowset.first();
  
  //if we call getAttribute when row is null, extension will throw unhandled error
  if(row != null){
    txnTypeId = row.getAttribute("CustTrxTypeSeqId");
  }
  else
  {
    txnTypeId = null;
  }
  
  /*varMessage = "Billing Trx Type Id => " + txnTypeId;
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
  
  varMessage = "EXITING Biling Trx Name ";
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
  ex = new ValidationException(messages);
  throw ex;*/

  return txnTypeId;
}


//Function to get Billing Transaction Type

String getBillingTxnTypeName(String orderLookupType,String orderTxnTypeName) {
  
  //messages uncomment only for debugging
  /*List<Message> messages = new ArrayList<Message>();
  varMessage = "Entering getBillingTxnTypeName";
  messages.add(new Message(Message.MessageType.ERROR,varMessage));
  varMessage = "Order Lookup passed: " + orderLookupType;
  messages.add(new Message(Message.MessageType.ERROR,varMessage));
  varMessage = "Order Txn Name passed: " + orderTxnTypeName;
  messages.add(new Message(Message.MessageType.ERROR,varMessage));
*/
  
  
  def txnTypePVO = context.getViewObject("oracle.apps.fnd.applcore.lookups.model.publicView.CommonLookupPVO");
  //Create view criteria (where clause predicates)
  def vc = txnTypePVO.createViewCriteria();
  def vcrow = vc.createViewCriteriaRow();

  //Only return Billing Transaction Type for the - Common Set - to be changed as required

  vcrow.setAttribute("LookupType", orderLookupType);
  vcrow.setAttribute("LookupCode", orderTxnTypeName)

  //Execute the view object query to find a matching row
  def rowset = txnTypePVO.findByViewCriteriaWithBindVars(vc, 1, new String[0], new Object[0]);

  //check if we have a matching row
  def row = rowset.first();
  
  //if we call getAttribute when row is null, extension will throw unhandled error
  if(row != null){
    txnTypeName = row.getAttribute("Tag");  
  }
  else
  {
    txnTypeName = null;
  }
    
  /*varMessage = "Billing Trx Name => " + txnTypeName;
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
  
  varMessage = "EXITING Biling Trx Name ";
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
  ex = new ValidationException(messages);
  throw ex;
*/

  return txnTypeName;
}
