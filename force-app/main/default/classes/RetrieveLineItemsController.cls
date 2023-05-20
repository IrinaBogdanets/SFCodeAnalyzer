/**
 * Created by Ciprian Prajinariu on 3/7/2022.
 */
public with sharing class RetrieveLineItemsController {
    private final static String QUERY = 'SELECT Id, Product2.Id, Product2.Name, Product2.Description, Product2.Storage_Location_Code__r.Name, ProductCode, UnitPrice FROM PricebookEntry WHERE IsActive = true ';
    private final static String STANDARD_PRICE_BOOK = 'Standard Price Book';
    /**
    * Method for retrieving the line items from the standard price book and custom pricebook.
    *
    * @param priceBookId id of the PriceBook.
    * @param searchKey search term for getting specific items.
    * @param sortBy sort by field.
    * @param sortDirection sort direction.
    * @param offset offset for list of items.
    */
    @AuraEnabled(cacheable=true)
    public static List<PricebookEntry> getLineItems(String priceBookId, String searchKey, String sortBy, String sortDirection, Integer offset) {
        List<PriceBookEntry> lRecords = new List<PriceBookEntry>();
        String key = '%' + String.escapeSingleQuotes(searchKey) + '%';
        if(priceBookId == 'null' || priceBookId == ''){
            if(String.escapeSingleQuotes(searchKey) != ''){
                if ( sortBy != null && sortDirection != null ) {
                    lRecords = Database.query( QUERY + 'AND (Pricebook2.Name = :STANDARD_PRICE_BOOK AND (Product2.Name LIKE :key OR ProductCode LIKE :key)) ORDER BY ' + sortBy + ' ' + sortDirection + ' OFFSET '+ offset);
                }else{
                    lRecords = Database.query( QUERY + 'AND (Pricebook2.Name = :STANDARD_PRICE_BOOK AND (Product2.Name LIKE :key OR ProductCode LIKE :key)) OFFSET '+ offset);
                }
            }else{
                lRecords = Database.query( QUERY + 'AND Pricebook2.Name = :STANDARD_PRICE_BOOK ORDER BY ' + sortBy + ' ' + sortDirection + ' OFFSET '+ offset);
            }
        }else{
            if(String.escapeSingleQuotes(searchKey) != ''){
                if ( sortBy != null && sortDirection != null ) {
                    lRecords = Database.query( QUERY + 'AND (Pricebook2.Id = :priceBookId AND (Product2.Name LIKE :key OR ProductCode LIKE :key)) ORDER BY ' + sortBy + ' ' + sortDirection + ' OFFSET '+ offset);
                }else{
                    lRecords = Database.query( QUERY + 'AND (Pricebook2.Id = :priceBookId AND (Product2.Name LIKE :key OR ProductCode LIKE :key)) OFFSET '+ offset);
                }
            }else{
                lRecords = Database.query( QUERY + 'AND Pricebook2.Id = :priceBookId ORDER BY ' + sortBy + ' ' + sortDirection + ' OFFSET '+ offset);
            }
        }
        return lRecords;
    }
    /**
    * Method for retrieving specific line items.
    *
    * @param lstIds list of PricebookEntry ids.
    */
    @AuraEnabled(cacheable=true)
    public static List<PricebookEntry> selectedLineItems(List<String> lstIds) {
        String[] varIds = lstIds[0].split(',');
        List<PricebookEntry> lineItems = [SELECT Id, Product2.Id, Product2.Storage_Location_Code__c, Product2.Storage_Location_Code__r.Name, Product2.Name, ProductCode, UnitPrice, Product2.Description FROM PricebookEntry WHERE Id IN :varIds];
        return lineItems;
    }
    /**
    * Method for creating quote line items and order products.
    *
    * @param request list of params received by the screen flow Create Quote and Create Order.
    */
    @InvocableMethod(label='Create Line Items' description='Create Line Items')
    public static void createLineItems (List<QuoteLineItemsRequest> request){

        String pricebook2Id = request.get(0).pricebook2Id;
        List<QuoteLineItem> lProductRequired = request.get(0).lProductRequired;
        List<OrderItem> lProductRequiredOrder = request.get(0).lProductRequiredOrder;
        String recordId = request.get(0).recordId;

        Set<Id> sPCIds = new Set<Id>();
        if(lProductRequired != null){
            for(QuoteLineItem pr: lProductRequired){
                sPCIds.add(pr.Product2Id);
            }
            List<PricebookEntry> lPricebookEntries = [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2.Id = :pricebook2Id AND Product2Id IN: sPCIds];
            Map<Id, PricebookEntry> mPricebookEntriesByIds = new Map<Id, PricebookEntry>();
            for(PricebookEntry pbe: lPricebookEntries){
                mPricebookEntriesByIds.put(pbe.Product2Id, pbe);
            }
            System.debug('mPricebookEntriesByIds: ' +mPricebookEntriesByIds);
            List<QuoteLineItem> lQuoteLineItemsToInsert = new List<QuoteLineItem>();
            for(QuoteLineItem pr: lProductRequired){
                    lQuoteLineItemsToInsert.add(new QuoteLineItem(QuoteId = recordId, PricebookEntryId = mPricebookEntriesByIds.get(pr.Product2Id).Id,
                            Product2Id = pr.Product2Id, Quantity = pr.Quantity, Discount = pr.Discount, Description = pr.Description, UnitPrice = pr.UnitPrice));
            }
            if(lQuoteLineItemsToInsert.size()>0 ){
                insert lQuoteLineItemsToInsert;
            }
        }else{
            for(OrderItem pr: lProductRequiredOrder){
                sPCIds.add(pr.Product2Id);
            }
            List<PricebookEntry> lPricebookEntries = [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2.Id = :pricebook2Id AND Product2Id IN: sPCIds];
    
            Map<Id, PricebookEntry> mPricebookEntriesByIds = new Map<Id, PricebookEntry>();
            for(PricebookEntry pbe: lPricebookEntries){
                mPricebookEntriesByIds.put(pbe.Product2Id, pbe);
            }
            List<OrderItem> lOrderItemToInsert = new List<OrderItem>();
            for(OrderItem pr: lProductRequiredOrder){
                if(pr.Discount__c != null){
                    pr.UnitPrice = pr.UnitPrice - (pr.UnitPrice * (pr.Discount__c/100));
                }else{
                    pr.UnitPrice = pr.UnitPrice;
                }
                lOrderItemToInsert.add(new OrderItem(OrderId = recordId, PricebookEntryId = mPricebookEntriesByIds.get(pr.Product2Id).Id,
                        Product2Id = pr.Product2Id, Quantity = pr.Quantity, Discount__c = pr.Discount__c, Storage_Location_Code__c = pr.Storage_Location_Code__c, Discount_Type__c = pr.Discount_Type__c, Description = pr.Description, UnitPrice = pr.UnitPrice));
            }
            if(lOrderItemToInsert.size()>0 ){
                insert lOrderItemToInsert;
            }
        }
    }
    
    public class QuoteLineItemsRequest{

        @InvocableVariable
        public List<QuoteLineItem> lProductRequired;

        @InvocableVariable
        public List<OrderItem> lProductRequiredOrder;

        @InvocableVariable
        public String recordId;

        @InvocableVariable
        public String pricebook2Id;
    }
}