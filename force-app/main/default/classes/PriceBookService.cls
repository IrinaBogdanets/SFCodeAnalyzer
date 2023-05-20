public class PriceBookService {
    private static final String PRICE_TYPE_B2B_INDIVIDUAL = 'B2B Individual';

    public static List<PriceBookResponse.SalesPrices> getPriceBookEntriesFromNAV(String endpoint){
        List<PriceBookResponse.SalesPrices> entries = new List<PriceBookResponse.SalesPrices>();
        NAVService provider = new NAVService();
        String JSONResponse = provider.getHttpRequest(endpoint, false);
        PriceBookResponse entriesDTO = (PriceBookResponse) JSON.deserialize(JSONResponse, PriceBookResponse.class);
        entries.addAll(entriesDTO.value);

        while (entriesDTO.nextLink != null) {
            entriesDTO = (PriceBookResponse) JSON.deserialize(
                provider.getHttpRequest(entriesDTO.nextLink, true), PriceBookResponse.class
            );
            entries.addAll(entriesDTO.value);
        }
        return entries;
    }

    public static List<Integer> createPriceBookEntries(Data data) {
        List<PricebookEntry> lNewPBEntries = new List<PricebookEntry>();

        String preSelectedPricebookId = data.preSelectedPricebookId;
        Pricebook2 stdPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];

        List<String> lProducts = data.lSelectedCoreProducts == null || data.lSelectedCoreProducts.isEmpty()
            ? new List<String>()
            : new List<String>(data.lSelectedCoreProducts);

        String query = 'SELECT Id, Pricebook2Id, IsActive, Product2Id, UnitPrice, PriceType__c, Allow_Line_Discount__c, Allow_Invoice_Discount__c' +
            ' FROM PricebookEntry WHERE Product2.IsActive = true AND Product2.Product_Group__c != null AND Product2.Product_Family__c != null';
        String whereQuery = stdPricebook.Id == preSelectedPricebookId
            ? ' AND Pricebook2.IsStandard = true'
            : !lProducts.isEmpty()
                ? ' AND ((Pricebook2Id = :preSelectedPricebookId AND Product2Id IN :lProducts) OR (Pricebook2.IsStandard = true AND Product2Id NOT IN :lProducts))'
                : ' AND Pricebook2.IsStandard = true';

        List<PricebookEntry> entries = Database.query(query + whereQuery);
        Integer countOfNonCoreProducts = 0;

        for (PricebookEntry pbe: entries) {
            PricebookEntry entry = new PricebookEntry();
            entry.Pricebook2Id = data.newPricebookId;
            entry.Product2Id = pbe.Product2Id;

            if (data.preSelectedPricebookId != stdPricebook.Id && pbe.Pricebook2Id == data.preSelectedPricebookId) {
                entry.UnitPrice = pbe.UnitPrice;
                entry.PriceType__c = pbe.PriceType__c;
            } else if (data.lSelectedNonCoreProducts != null && data.lSelectedNonCoreProducts.contains(pbe.Product2Id)) {
                entry.UnitPrice = 0;
                entry.PriceType__c = PRICE_TYPE_B2B_INDIVIDUAL;
            } else {
                entry.UseStandardPrice = true;
                entry.UnitPrice = pbe.UnitPrice;
                entry.PriceType__c = pbe.PriceType__c;
            }

            entry.IsActive = pbe.IsActive;
            entry.Allow_Line_Discount__c = pbe.Allow_Line_Discount__c;
            entry.Allow_Invoice_Discount__c = pbe.Allow_Invoice_Discount__c;
            lNewPBEntries.add(entry);
        }

        if (!lNewPBEntries.isEmpty()) insert lNewPBEntries;

        return new List<Integer>{countOfNonCoreProducts};
    }

    public class Data {
        public String preSelectedPricebookId;
        public String newPricebookId;
        public List<String> lSelectedCoreProducts;
        public List<String> lSelectedNonCoreProducts;
    }
}