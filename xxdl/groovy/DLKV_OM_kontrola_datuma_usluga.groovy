import oracle.apps.scm.doo.common.extensions.ValidationException;
import oracle.apps.scm.doo.common.extensions.Message;

def extensionName  = context.getExtensionName();
def varMessage = null;
def periodStatus = null;
def periodName = null;

//intialize message list
List<Message> messages = new ArrayList<Message>();
ValidationException ex = new ValidationException(messages);

//get order type code from order header
def orderTypeCode = header.getAttribute("TransactionTypeCode");
//varMessage = "Order Type Code: " + orderTypeCode
//messages.add(new Message( Message.MessageType.ERROR,varMessage));

if((orderTypeCode == "XXDL_DOM_PRODAJA_USLUGA") || (orderTypeCode == "XXDL_INO_PRODAJA_USLUGA"))
{
  //limiting extension to a specific PO number, only for testing
//uncomment when debugging
//def varMessage = "IN code";
  def poNumber = header.getAttribute("CustomerPONumber");

  def orderHeaderPVO = context.getViewObject("oracle.apps.scm.doo.publicView.analytics.HeaderPVO");

  //Create view criteria (where clause predicates)
  def vcHead = orderHeaderPVO.createViewCriteria();
  def vcHeadRow = vcHead.createViewCriteriaRow();


  vcHeadRow.setAttribute("HeaderId", header.getAttribute("HeaderId"));
  //vcrow.setAttribute("SetName", "Common Set"); //this currently causes a problem when we switch language

  //Execute the view object query to find a matching row
  def rowHeadset = orderHeaderPVO.findByViewCriteriaWithBindVars(vcHead, 1, new String[0], new Object[0]);

  //check if we have a matching row
  def rowHead = rowHeadset.first();

  def orderedDate = rowHead.getAttribute("OrderedDate");
  

  //varMessage = "Ordered date => " + orderedDate;
  //messages.add(new Message( Message.MessageType.ERROR,varMessage));

  def orderPeriodName = orderedDate.format("MM-YYYY");
  //varMessage = "Ordered period => " + orderPeriodName;
  //messages.add(new Message( Message.MessageType.ERROR,varMessage));



  //if (poNumber==null) return;
  //if (!poNumber.startsWith("TEST_PERIOD")) return;

  //get system current time
  def varTime = context.getCurrentTime();
  //varMessage = "Extension - Started: - " + extensionName + " - at - " + varTime;
  //messages.add(new Message( Message.MessageType.ERROR,varMessage));


  periodName = orderPeriodName;

  def periodPVO = context.getViewObject("oracle.apps.financials.generalLedger.calendars.accounting.publicView.PeriodStatusPVO");

  //Create view criteria (where clause predicates)
  def vc = periodPVO.createViewCriteria();
  def vcrow = vc.createViewCriteriaRow();

  //Only return Billing Transaction Type for the - Common Set - to be changed as required

  vcrow.setAttribute("ApplicationId", "222");
  vcrow.setAttribute("PeriodName", periodName);
  //vcrow.setAttribute("SetName", "Common Set"); //this currently causes a problem when we switch language

  //Execute the view object query to find a matching row
  def rowset = periodPVO.findByViewCriteriaWithBindVars(vc, 1, new String[0], new Object[0]);

  //check if we have a matching row
  def row = rowset.first();

  periodStatus = row.getAttribute("ClosingStatus");
  
  if (periodStatus != "O")
  {
    def fmt = new Formatter()
    varMessage = "Datum naloga prodaje je: " + fmt.format("%tm/%td/%tY",orderedDate,orderedDate,orderedDate) + " za što period : " + periodName +" nije otvoren. Status: " + periodStatus + " . Javite se financijama i računovodstvu za informaciju u kojem razdoblju možete fakturirati uslugu!";
    messages.add(new Message( Message.MessageType.ERROR,varMessage));
  }
  
  
  //varMessage = "Period Name => " + periodName;
  //messages.add(new Message( Message.MessageType.ERROR,varMessage));

  //varMessage = "Period Status => " + periodStatus;
  //messages.add(new Message( Message.MessageType.ERROR,varMessage));
  



 //varMessage = "EXITING ";

}


if (varMessage!=null)
{
  messages.add(new Message( Message.MessageType.ERROR,varMessage));
  ex = new ValidationException(messages);
  throw ex;
}



