import oracle.apps.scm.doo.common.extensions.ValidationException;
import oracle.apps.scm.doo.common.extensions.Message;

def extensionName  = context.getExtensionName();
def varMessage = null;
def shipCustAccId = null;
def relatedCustAccId = null;
def billToSiteUseId = null;
def buyingPartyId = null;
def buyingCustAcctId = null;
def relatedCustAcctSiteId = null;
def relatedCustAcctSiteUseId = null;

//intialize message list
List<Message> messages = new ArrayList<Message>();
ValidationException ex = new ValidationException(messages);

//get order type code from order header
def orderTypeCode = header.getAttribute("TransactionTypeCode");
varMessage = "Order Type Code: " + orderTypeCode
messages.add(new Message( Message.MessageType.ERROR,varMessage));

def poNumber = header.getAttribute("CustomerPONumber");

if("TEST_RELATED" != poNumber) return;

buyingPartyId = header.getAttribute("BuyingPartyIdentifier");

varMessage = "Buying Party Id = " + buyingPartyId;
messages.add(new Message( Message.MessageType.ERROR,varMessage));

if(buyingPartyId == null) return;

buyingCustAcctId = getCustAcctId(buyingPartyId);


varMessage = "Buying Cust Acct Id = " + buyingCustAcctId;
messages.add(new Message( Message.MessageType.ERROR,varMessage));


relatedCustAccId = getRelatedCustAccId(buyingCustAcctId);

varMessage = "Related Customer Acc Id = " + relatedCustAccId;
messages.add(new Message( Message.MessageType.ERROR,varMessage));

if(relatedCustAccId == null) return;

header.setAttribute("BillToCustomerIdentifier",relatedCustAccId);

relatedCustAcctSiteId = getBillCustAcctSiteId(relatedCustAccId);

varMessage = " Related Cust Acct Site Id: " + relatedCustAcctSiteId;
messages.add(new Message(Message.MessageType.ERROR,varMessage));
             
relatedCustAcctSiteUseId = getBillToSiteUseId(relatedCustAcctSiteId);
           
varMessage = " Related Bill Use Id: " +  relatedCustAcctSiteUseId;
messages.add(new Message(Message.MessageType.ERROR,varMessage));

header.setAttribute("BillToCustomerSiteIdentifier",relatedCustAcctSiteUseId);



//function to get buying party cust account id

Long getCustAcctId (long buyingPartyId){
  
  def custAcctPVO = context.getViewObject("oracle.apps.scm.fos.common.publicView.CustomerAccountPVO");
  
  def vc = custAcctPVO.createViewCriteria();
  def vcRow = vc.createViewCriteriaRow();
  
  vcRow.setAttribute("PartyId",buyingPartyId);
  
  def rowSet = custAcctPVO.findByViewCriteriaWithBindVars(vc,1, new String[0], new Object[0]);
  
  def row = rowSet.first();
  
  if(row != null){
    
    buyingCustAccId = row.getAttribute("CustAccountId");
  
  }
  else{
    
    buyingCustAccId = null;
    
  }
  
  return buyingCustAccId;

    
}

//function to get related cust account id

Long getRelatedCustAccId(long custAcctId){

  def relatedCustPVO = context.getViewObject("oracle.apps.cdm.foundation.parties.publicView.customerAccounts.CustomerAccountRelationshipPVO");
  
  def vc = relatedCustPVO.createViewCriteria();
  def vcRow = vc.createViewCriteriaRow();
  
  //vcRow.setAttribute("CustomerAccountCustAccountId",custAcctId);
  vcRow.setAttribute("Status","A");
  vcRow.setAttribute("CustAccountId",custAcctId);
  
  def rowset = relatedCustPVO.findByViewCriteriaWithBindVars(vc,1, new String[0], new Object[0]);
  
  def row = rowset.first();
  
  if(row != null){
    
    //relatedCustAcctId = row.getAttribute("CustomerAccountRelationshipRelatedCustAccountId");
    relatedCustAcctId = row.getAttribute("RelatedCustAccountId");
  
  }
  else{
    relatedCustAcctId = null;
  }
  
  return relatedCustAcctId;
  
}

//function to get bill cust acct site

Long getBillCustAcctSiteId (Long BillCustAcctId){
  
  List<Message> messages = new ArrayList<Message>();
ValidationException ex = new ValidationException(messages);
  
  varMessage = " Entered getBillCustAcctSiteId with cust acct id: " +  BillCustAcctId;
  messages.add(new Message(Message.MessageType.ERROR,varMessage));
  def billCustSitePVO = context.getViewObject("oracle.apps.cdm.foundation.parties.publicView.customerAccounts.CustomerAccountSitePVO");
  
  def vc = billCustSitePVO.createViewCriteria();
  def vcRow = vc.createViewCriteriaRow();
  
  vcRow.setAttribute("CustAccountId",BillCustAcctId);
  //vcRow.setAttribute("BillToFlag","Y");
  
  def rowset = billCustSitePVO.findByViewCriteriaWithBindVars(vc,1,new String[0],new Object[0]);
  
  def row = rowset.first();
  
  if(row != null){
    billCustSiteId = row.getAttribute("CustAcctSiteId");
  }
  else
  {
     billCustSiteId = null;
  }
  
  varMessage = " return billCustSiteId: " +  billCustSiteId;
  messages.add(new Message(Message.MessageType.ERROR,varMessage));
  
  /*if (varMessage!=null)
{
  //messages.add(new Message( Message.MessageType.ERROR,varMessage));
  ex = new ValidationException(messages);
  throw ex;
}*/

  
  return billCustSiteId;
}

//function to get bill to site use id

Long getBillToSiteUseId (Long BillCustAccSiteId){
  
  def billCustSiteUsePVO = context.getViewObject("oracle.apps.cdm.foundation.parties.publicView.customerAccounts.CustomerAccountSiteUsePVO");
  
  def vc = billCustSiteUsePVO.createViewCriteria();
  def vcRow = vc.createViewCriteriaRow();
  
  vcRow.setAttribute("CustAcctSiteId",BillCustAccSiteId);
  vcRow.setAttribute("SiteUseCode","BILL_TO");
  
  def rowset = billCustSiteUsePVO.findByViewCriteriaWithBindVars(vc,1,new String[0],new Object[0]);
  
  def row = rowset.first();
  
  if(row != null){
    billCustSiteUseId = row.getAttribute("SiteUseId");
  }
  else
  {
     billCustSiteUseId = null;
  }
  
  return billCustSiteUseId;

}



/*if (varMessage!=null)
{
  //messages.add(new Message( Message.MessageType.ERROR,varMessage));
  ex = new ValidationException(messages);
  throw ex;
}
*/

 