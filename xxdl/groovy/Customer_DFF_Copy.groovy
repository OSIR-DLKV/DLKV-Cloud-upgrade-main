import oracle.apps.scm.doo.common.extensions.ValidationException;
import oracle.apps.scm.doo.common.extensions.Message;

//intialize message list
List<Message> messages = new ArrayList<Message>();
ValidationException ex = new ValidationException(messages);

//limiting extension to a specific PO number, only for testing
//uncomment when debugging
//def varMessage = "IN code";
def poNumber = header.getAttribute("CustomerPONumber");
//if (poNumber==null) return;
if (poNumber.startsWith("CUSTOMER_SITE")){
  
  def siteIdentifier = header.getAttribute("BillToCustomerSiteIdentifier");
  def custIdentifier = header.getAttribute("BillToCustomerIdentifier");
  
  varMessage = "BillToCustomerSiteIdentifier" + siteIdentifier;
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
  
  varMessage = "BillToCustomerIdentifier" + custIdentifier;
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
  
  def siteUse = context.getViewObject("oracle.apps.cdm.foundation.parties.publicView.customerAccounts.CustomerAccountSiteUsePVO");
  
  
  def vcsite = siteUse.createViewCriteria();
  def vcsiterow = vcsite.createViewCriteriaRow();
  
  vcsiterow.setAttribute("SiteUseId",siteIdentifier);
  
  def rowsetsite = siteUse.findByViewCriteriaWithBindVars(vcsite, 1, new String[0], new Object[0]);
  
   //check if we have a matching row
  def rowsite = rowsetsite.first();
   //if we call getAttribute when row is null, extension will throw unhandled error
  if(rowsite != null){
    CustAcctSiteId = rowsite.getAttribute("CustAcctSiteId");
     varMessage = "SiteUseId: " + CustAcctSiteId;
     messages.add(new Message( Message.MessageType.ERROR,varMessage));
  }
  else
  {
    CustAcctSiteId = null;
    varMessage = "Nema CustAcctSiteId?";
    messages.add(new Message( Message.MessageType.ERROR,varMessage));
  }

  
  def customerSiteDFF = context.getViewObject("oracle.apps.cdm.foundation.parties.publicView.bicc.CustomerAccountSiteExtractPVO");

  
  def vc = customerSiteDFF.createViewCriteria();
  def vcrow = vc.createViewCriteriaRow();
  
  vcrow.setAttribute("CustAcctSiteId",CustAcctSiteId);
  
  def rowset = customerSiteDFF.findByViewCriteriaWithBindVars(vc, 1, new String[0], new Object[0]);
  
   //check if we have a matching row
  def row = rowset.first();
   //if we call getAttribute when row is null, extension will throw unhandled error
  if(row != null){
    custDffVal = row.getAttribute("Attribute1");
     varMessage = "Customer Site DFF: " + custDffVal;
     messages.add(new Message( Message.MessageType.ERROR,varMessage));
  }
  else
  {
    custDffVal = null;
    varMessage = "Nema DFFa?";
    messages.add(new Message( Message.MessageType.ERROR,varMessage));
  }
  
if (varMessage!=null)
{
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
  ex = new ValidationException(messages);
  throw ex;
}
  
}
