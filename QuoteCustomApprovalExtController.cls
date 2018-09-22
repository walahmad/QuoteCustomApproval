public with sharing class QuoteCustomApprovalExtController {
    
    //flag controls display of modal popup window
    public boolean displayPopup { get; set; }
    //displays Submit/Cancel buttons if true, else displays OK button
    public boolean displaySubmitCancel { get; set; }
    public List <Quote> selectedQuote { get; set; }
    public Quote sQuoteObject { get; set; }
    public Opportunity parentOpp { get; set; }
    public Id OppId { get; set; }
    private boolean quoteIsSyncing = true;
    public boolean saveQuoteDiscountReason { get; set; }
    private boolean invokedByDetailButton = false;
    
    //constructor for list page use cases
    public QuoteCustomApprovalExtController(ApexPages.StandardSetController stdSetController) {
        selectedQuote = stdSetController.getSelected();
        OppId = ApexPages.currentPage().getParameters().get('Id');
        
        displaySubmitCancel = true;
        saveQuoteDiscountReason =  false;
    }
	//constructor for detail page use case
    public QuoteCustomApprovalExtController(ApexPages.StandardController stdController) {
        selectedQuote = new List <Quote>();
        selectedQuote.add((Quote)stdController.getRecord());
        OppId = [SELECT Id, SyncedQuoteId FROM Opportunity WHERE Id IN (SELECT OpportunityId FROM Quote WHERE Id = : selectedQuote[0].Id)][0].Id;
        invokedByDetailButton = true;
        displaySubmitCancel = true;
        saveQuoteDiscountReason = false;
    } 
    
    public void showPopup() {
        displayPopup = true;
        reviewQuoteAndDisplayMessaging();
    }
    
    public PageReference closePopup() {
        displayPopup = false;
        if(invokedByDetailButton) {
            return  new PageReference('/' + sQuoteObject.Id);
        } else {
        	return navigateToOpportunity();
        }
    }
    
    //return to parentOpp scrolled to Quotes relatedlist section
    public PageReference navigateToOpportunity() {
        
        PageReference oppDetailPage = new PageReference('/' + OppId);
        String oppId2String = OppId;
        oppDetailPage.setAnchor(oppId2String.substring(0, 15) + '_RelatedQuoteList_target');
        oppDetailPage.setRedirect(true);
        return oppDetailPage;   
    }
        
    public void reviewQuoteAndDisplayMessaging() {
        if (selectedQuote != NULL && selectedQuote.size() == 1) {
            
            //sQuoteObject = [SELECT Id, Name, TotalPrice, Total_Discount_off_disti_price__c, Approved_Discount_Level__c, Opportunity.Max_Approved_Discount_Level__c, QuoteNumber, SPA_Discount_Reason__c, SPA_Approval_Status__c, IsSyncing, OpportunityId FROM Quote WHERE Id =: selectedQuote[0].Id];
            parentOpp = [SELECT Id, SyncedQuoteId, (SELECT Id, Name, TotalPrice, Total_Discount_off_disti_price__c, Approved_Discount_Level__c, Opportunity.Max_Approved_Discount_Level__c, QuoteNumber, SPA_Discount_Reason__c, SPA_Approval_Status__c, IsSyncing, OpportunityId FROM Quotes WHERE Id =: selectedQuote[0].Id) FROM Opportunity WHERE Id =: OppId];
            sQuoteObject = parentOpp.Quotes[0];
            
            //quote total amount is <= 0
            if (sQuoteObject.TotalPrice <= 0) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You cannot submit a zero amount quote.'));
                displaySubmitCancel = False;
                return;
            }
            //if already approved and discount amount is <= approved discount level
            if (sQuoteObject.SPA_Approval_Status__c == 'Approved' && (sQuoteObject.Total_Discount_off_disti_price__c <= sQuoteObject.Approved_Discount_Level__c || sQuoteObject.Total_Discount_off_disti_price__c <= sQuoteObject.Opportunity.Max_Approved_Discount_Level__c)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'This quote is already Approved for the requested discount level!'));
                displaySubmitCancel = False;
                return;
            }            
            //is approval is already pending
            if (sQuoteObject.SPA_Approval_Status__c == 'Pending') {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'An Approval is already pending for this quote. If you\'d like to submit a new request, please recall the pending approval first.'));
                displaySubmitCancel = False;
                return;
            }

            //if another quote is already syncing with parentOpp
            if(parentOpp.SyncedQuoteId != NULL && Approval.isLocked(parentOpp.SyncedQuoteId) && ([SELECT Name FROM Profile WHERE Id = : UserInfo.getProfileId()][0]).Name != 'System Administrator') {
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'This quote can\'t be synced because another quote that\'s being synced for this opportunity is locked due to a pending approval process. Opportunities can only sync with one quote at a time.'));
                    displaySubmitCancel = False;
                    return;
            } else if (parentOpp.SyncedQuoteId != NULL && !sQuoteObject.IsSyncing) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'Another quote is already syncing with the opportunity. Only one quote can sync at a time. If you continue, the other quote will stop syncing and this quote\'s Line Items will replace opportunity products, and all future opportunity product updates will sync to this quote\'s line items.'));
                quoteIsSyncing = false;
                //if this is an iniital sync
            } else if (parentOpp.SyncedQuoteId == NULL && !sQuoteObject.IsSyncing) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'If you continue, Quote Line Items will replace opportunity products. After this initial sync, all future opportunity product updates will sync to quote line items.'));
                quoteIsSyncing = false;
                //if quote is already syncing
            } else if (parentOpp.SyncedQuoteId != NULL && sQuoteObject.IsSyncing) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'You are submitting this synced quote for approval, press submit to continue.'));
            }
            //display error msg if SPA Discount reason is missing
            if (sQuoteObject.SPA_Discount_Reason__c == NULL) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Quote "SPA Discount Reason" is missing. Enter it below before submitting.'));
                saveQuoteDiscountReason = true;
            }
        //if no quote was selected but parentOpp has one quote only, set selectedQuote to this one quote and reinvoke self
        } else if (selectedQuote == NULL || selectedQuote.size() != 1) {
            List<Quote> oppQuotes = [SELECT Id FROM Quote WHERE OpportunityId = : oppId];
            if (oppQuotes.size()==1) {
                selectedQuote.addAll(oppQuotes);
                reviewQuoteAndDisplayMessaging();
                return;
                //if more than one quote exists
            } else if (oppQuotes.size()>1) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You need to select a single quote for submission. Please try again.'));
                displaySubmitCancel = False;
                return;
                //if no quote exists
            } else if (oppQuotes.size()<1) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'This opportunity has no quotes for submission. Please create a quote first and try again.'));
                displaySubmitCancel = False; 
                return;
            }
        } else {
            displaySubmitCancel = False;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'There was a problem processing your request, please try again.'));
            return;
        }
    }

    public void onSubmit() {
        
        try {
            //update selectedQuote to save discount reason
            if (saveQuoteDiscountReason) {
                update sQuoteObject;
            }
            //sync and submit for approval
            syncQuoteAndSubmitForApproval();
        } catch (Exception e) {
            displaySubmitCancel = False;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'There was a problem submitting your request: ' + e.getMessage()));
            return;
        }
    }    

    public void syncQuoteAndSubmitForApproval() {
        if (!quoteIsSyncing) {
            parentOpp.SyncedQuoteId = sQuoteObject.Id;
            parentOpp.APEX_Context__c = true;
            try {
                update parentOpp;
                {decimal i;
                i = 1;}
            } catch (DmlException e) {
                if (e.getDmlType(0)==StatusCode.ENTITY_IS_LOCKED) {
                    displaySubmitCancel = False;
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'This quote can\'t be synced because another quote that\'s being synced for this opportunity is locked due to a pending approval process. Opportunities can only sync with one quote at a time.'));
                } else {
                    displaySubmitCancel = False;
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'There was a problem submitting your request: ' + e.getMessage() ));
                }
                return;
            }
        }
        
        Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
        req1.setComments('Quote submitted for approval via Sync & Submit process.');
        req1.setObjectId(selectedQuote[0].Id);
        
        //Submit the approval request for the account
        Approval.ProcessResult result = Approval.process(req1);
        
        if (result.isSuccess()) {
            displaySubmitCancel = False;
            String nextStep = '';
            if (result.instanceStatus != 'Approved' && result.instanceStatus != 'Rejected') {
                ProcessInstance approvalProcessInstance = [SELECT Id, Status,(SELECT Id, Actor.Name, StepStatus FROM StepsAndWorkitems ORDER BY CreatedDate DESC) FROM ProcessInstance WHERE Id = : result.instanceid];
                nextStep = '<br/><br/> Next Step: Assigned to <b>' + approvalProcessInstance.StepsAndWorkitems[0].Actor.Name + '</b> for review.'; //', in ' + approvalProcessInstance.StepsAndWorkitems[0].StepStatus + ' status';
            } 
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 'Approval request submitted successfully! Approval status: <b>' + result.instanceStatus + '</b>' + nextStep  )); //instanceStatus newWorkitemIds
            
        } else {
            displaySubmitCancel = False;
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'There was a problem submitting your request, please try again.'));
        }
    }
}