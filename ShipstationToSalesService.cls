/*
*********************************************************
Apex Class Name    : ShipstationToSalesService
@description       : Shipstation Webservice designed to take in a shipstation store credential record and execute a GET callout to either update 
                     tracking of the corrisponding Sales record or create a new Sales record with the information coming from shipstation.
*********************************************************
*/
public class ShipstationToSalesService implements Queueable, Database.AllowsCallouts {
    // Global variables initiated to be assgined by the constructor
    private batch_log log = new batch_log();
    private String key;
    private String secret;
    private String storeID;
    private String shippingdate;
    private String currentPage;
    private String source;
    private String name;
    Sales__c[] sList;


    /*
    *********************************************************
    @Method Name    : ShipstationToSalesService (Constructor)
    @description    : Assigns values to global variables
    ********************************************************
    */
    public ShipstationToSalesService(String shipstation_name, String shipstaion_key, String shipstaion_secret, String shipstaion_storeID, String shipstation_source, String shipstaion_currentPage, String shipstaion_shippingdate) {
        this.name = shipstation_name;
        this.key = shipstaion_key;
        this.secret = shipstaion_secret;
        this.storeID = shipstaion_storeID;
        this.source = shipstation_source;
        this.currentPage = shipstaion_currentPage;
        this.shippingdate = shipstaion_shippingdate;
    }

    // Inner Classes used to be serilize the Shipstaion JSON into objects
    public class ShipppedShipments {
        public cls_shipments[] shipments;
        public Integer total;
        public Integer page;
        public Integer pages;
    }

    public class cls_shipments {
        public Integer shipmentId;
        public Integer orderId;
        public String orderKey;
        public String userId;
        public String orderNumber;
        public String customerEmail;
        public String createDate;
        public String shipDate;
        public Double shipmentCost;
        public Double insuranceCost;
        public String trackingNumber;
        public boolean isReturnLabel;
        public String batchNumber;
        public String carrierCode;
        public String serviceCode;
        public String packageCode;
        public String confirmation;
        public Integer warehouseId;
        public boolean voided;
        public String voidDate;
        public boolean marketplaceNotified;
        public String notifyErrorMessage;
        public cls_shipTo shipTo;
        public cls_weight weight;
        public cls_dimensions dimensions;
        public cls_insuranceOptions insuranceOptions;
        public cls_advancedOptions advancedOptions;
        public cls_shipmentItems[] shipmentItems;
        public String labelData;
        public String formData;
    }

    public class cls_shipTo {
        public String name;
        public String company;
        public String street1;
        public String street2;
        public String street3;
        public String city;
        public String state;
        public String postalCode;
        public String country;
        public String phone;
        public boolean residential;
    }

    public class cls_weight {
        public Double value;
        public String units;
    }

    public class cls_dimensions {
        public String units;
        public Double length;
        public Double width;
        public Double height;
    }

    public class cls_insuranceOptions {
        public String provider;
        public boolean insureShipment;
        public Double insuredValue;
    }

    public class cls_advancedOptions {
        public Integer warehouseId;
        public boolean nonMachinable;
        public boolean saturdayDelivery;
        public boolean containsAlcohol;
        public boolean mergedOrSplit;
        List < Integer > mergedIds;
        public Integer parentId;
        public String storeId;
        public String customField1;
        public String customField2;
        public String customField3;
        public String source;
        public String billToParty;
        public String billToAccount;
        public String billToPostalCode;
        public String billToCountryCode;
    }

    public class cls_shipmentItems {
        public Integer orderItemId;
        public String lineItemKey;
        public String sku;
        public String name;
        public String imageUrl;
        public cls_weight weight;
        public Integer quantity;
        public Double unitPrice;
        public String warehouseLocation;
        public cls_options options;
        public Integer productId;
        public String fulfillmentSku;
    }

    public class cls_options {
        public String name;
        public String value;
    }

    /*
    *********************************************************
    @Method Name    : execute (Main)
    @description    : Main method that will determine how to process informaiton based on the store 
    @param          : QueueableContext
    @return         : Null
    ********************************************************
    */
    public void execute(QueueableContext context) {
        try {
            // Condtion for stores that already have complete Sales records and only need tracking information updated
            if (source == 'Shopify' || source == 'Custom Webservice') {
                String responseBody = getCalloutResponse();
                ShipppedShipments trackingShipments = (ShipppedShipments) System.JSON.deserialize(responseBody, ShipppedShipments.class);
                processShipmentsUpdate(trackingShipments);
            // Condition for Test Store
            } else if (source == 'Shipstation' && storeID == '12345') {
                String responseBody = getCalloutResponse();
                ShipppedShipments completeShipments = (ShipppedShipments) System.JSON.deserialize(responseBody, ShipppedShipments.class);
                testStoreProcessShipmentsUpsert(completeShipments);
            // Condition for all shipstation store
            } else {
                String responseBody = getCalloutResponse();
                ShipppedShipments completeShipments = (ShipppedShipments) System.JSON.deserialize(responseBody, ShipppedShipments.class);
                processShipmentsUpsert(completeShipments);
            }

        } catch (exception e) {
            string message = 'ERROR DESERIALIZING RESPONSE' + '\n  ERROR=' + e.getMessage();
        }
    }

    /*
    *********************************************************
    @Method Name    : getCalloutResponse
    @description    : GET callout to the specified Shipstation store and returns shipments from between two shipping dates.
    @param          : Null
    @return         : JSON Body
    ********************************************************
    */
    public String getCalloutResponse() {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        String endpoint = 'https://ssapi.shipstation.com/shipments?storeId=' + storeID + '&shipDateStart=' + shippingdate + '&shipDateEnd=' + shippingdate + '&includeShipmentItems=true&page=' + currentPage;
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json;charset=UTF-8');

        String username = key;
        String password = secret;

        Blob headerValue = Blob.valueOf(username + ':' + password);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        request.setHeader('Authorization', authorizationHeader);
        request.setTimeout(60000);
        HttpResponse response = http.send(request);
        return response.getBody();
    }

    /*
    *********************************************************
    @Method Name    : processShipmentsUpdate
    @description    : Used to update records that already exist in Sales
    @param          : ShipppedShipments
    @return         : Null
    ********************************************************
    */
    public void processShipmentsUpdate(ShipppedShipments trackingShipments) {

        list < Sales__c > ShipmentsToUpdate = new list < Sales__c > ();
        list < String > externalIDList = new list < String > ();

        // This for loop is used to create a list of externialIDs used in a Sales Query
        for (cls_shipments shipment: trackingShipments.shipments) {
            if (shipment.voided == false) {
                if (shipment.shipmentItems != null) {
                    Map < String, Integer > multipleItemsMap = new Map < String, Integer > ();
                    for (cls_shipmentItems item: shipment.shipmentItems) {
                        if (!multipleItemsMap.containsKey(item.sku)) {
                            multipleItemsMap.put(item.sku, 0);
                            externalIDList.add(shipment.orderNumber + '_' + item.sku);
                        } else {
                            Integer updatedValue = multipleItemsMap.get(item.sku) + 1;
                            multipleItemsMap.put(item.sku, updatedValue);
                            externalIDList.add(shipment.orderNumber + '_' + item.sku + '_' + updatedValue);
                        }
                    }
                }
            } else {
                continue;
            }
        }

        // Sales Query to grab all existing records in this Shipstaion Shipment
        sList = [SELECT id,
                         External_Id__c,
                         Source__c,
                         Sent_To_Shipstation__c,
                         tracking_number__c,
                         channel_detail__c
                 FROM Sales__c
                 WHERE Source__c =: source AND channel_detail__c =: name AND tracking_number__c = null AND External_Id__c =: externalIDList
                 ORDER BY CreatedDate DESC
        ];

        for (cls_shipments shipment: trackingShipments.shipments) {
            if (shipment.voided == false) {
                if (shipment.shipmentItems != null) {
                    Map < String, Integer > skuCountMap = new Map < String, Integer > ();
                    for (cls_shipmentItems item: shipment.shipmentItems) {
                        String shipstationExternalID;
                        if (!skuCountMap.containsKey(item.sku)) {
                            skuCountMap.put(item.sku, 0);
                            shipstationExternalID = shipment.orderNumber + '_' + item.sku;
                        } else {
                            Integer updatedValue = skuCountMap.get(item.sku) + 1;
                            skuCountMap.put(item.sku, updatedValue);
                            shipstationExternalID = shipment.orderNumber + '_' + item.sku + '_' + updatedValue;
                        }
                        for (Sales__c record: sList) {
                            if (record.external_id__c == shipstationExternalID) {
                                System.debug(shipstationExternalID);
                                record.tracking_number__c = shipment.trackingNumber;
                                System.debug(shipment.trackingNumber);
                                record.shipping_amount__c = shipment.shipmentCost;
                                record.shipping_service__c = shipment.serviceCode;
                                ShipmentsToUpdate.add(record);
                                break;
                            }
                        }
                    }
                }
            }
        }
        try {
            update ShipmentsToUpdate;

            Integer currentPageNum = integer.valueOf(trackingShipments.page);
            Integer totalPagesNum = integer.valueOf(trackingShipments.pages);
            if (currentPageNum < totalPagesNum) {
                Integer nextPageNum = currentPageNum + 1;
                String nextPage = String.valueOf(nextPageNum);
                ShipstationToSalesService ws = new ShipstationToSalesService(name, key, secret, storeID, source, nextPage, shippingdate);
                System.enqueueJob(ws);
            }
        } catch (DmlException e) {
            System.debug(e.getMessage());
            String[] toAddress = 'TechTeam@someemail.com';
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddress);
            mail.setReplyTo('TechTeam@someemail.com');
            mail.setSenderDisplayName('Production Issue');
            mail.setSubject('Shipstaion to Sales Service Failure for Store ' + name);
            mail.setPlainTextBody(e.getMessage());
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {
                mail
            });
        }
    }


    /*
    *********************************************************
    @Method Name    : processShipmentsUpsert
    @description    : Used to create complete records from shipstation manual stores and update the trackingnumber field when populated in shipstation
    @param          : ShipppedShipments
    @return         : Null
    ********************************************************
    */
    public void processShipmentsUpsert(ShipppedShipments trackingShipments) {

        list < Sales__c > ShipmentsToUpsert = new list < Sales__c > ();
        for (cls_shipments shipment: trackingShipments.shipments) {
            if (shipment.voided == false) {
                if (shipment.shipmentItems != null) {
                    Map < String, Integer > multipleItemsMap = new Map < String, Integer > ();
                    String[] customerName = shipment.shipTo.name.split(' ');
                    for (cls_shipmentItems item: shipment.shipmentItems) {
                        String shipstationExternalID;
                        if (!multipleItemsMap.containsKey(item.sku)) {
                            shipstationExternalID = shipment.orderNumber + '_' + item.sku;
                            multipleItemsMap.put(item.sku, 0);
                        } else {
                            Integer updatedValue = multipleItemsMap.get(item.sku) + 1;
                            multipleItemsMap.put(item.sku, updatedValue);
                            shipstationExternalID = shipment.orderNumber + '_' + item.sku + '_' + updatedValue;
                        }
                        Sales__c s = new Sales__c();
                            s.address_1__c = shipment.shipTo.street1;
                            s.address_2__c = shipment.shipTo.street2;
                            s.channel__c = 'Website';
                            s.channel_detail__c = name;
                            s.city__c = shipment.shipTo.city;
                            s.country__c = shipment.shipTo.country;
                            s.email__c = shipment.customerEmail;
                            s.first_name__c = customerName[0];
                            s.fulfillment_type__c = 'E-Com';
                            s.item__c = item.name;
                            s.last_name__c = customerName[customerName.size() - 1];
                            s.lob__c = 'Distribution';
                            s.order_number__c = shipment.orderNumber;
                            s.postal_code__c = shipment.shipTo.postalCode;
                            s.price__c = item.unitPrice;
                            s.qty__c = item.quantity;
                            s.sales_type__c = 'B2C';
                            s.shipping_amount__c = shipment.shipmentCost;
                            s.sku__c = item.sku;
                            s.source__c = source;
                            s.state_provence__c = shipment.shipTo.state;
                            s.Sales__c = item.unitPrice;
                            s.transaction__c = 'Purchase';
                            s.Transaction_date__c = date.valueOf(shipment.shipDate);
                            s.external_id__c = shipstationExternalID;
                            s.tracking_number__c = shipment.trackingNumber;
                            s.shipping_service__c = shipment.serviceCode;
                            ShipmentsToUpsert.add(s);
                    }
                }
            } else {
                continue;
            }
        }
        try {
            upsert ShipmentsToUpsert external_id__c;

            Integer currentPageNum = integer.valueOf(trackingShipments.page);
            Integer totalPagesNum = integer.valueOf(trackingShipments.pages);
            if (currentPageNum < totalPagesNum) {
                Integer nextPageNum = currentPageNum + 1;
                String nextPage = String.valueOf(nextPageNum);

                ShipstationToSalesService ws = new ShipstationToSalesService(name, key, secret, storeID, source, nextPage, shippingdate);
                System.enqueueJob(ws);
            }
        } catch (DmlException e) {
            System.debug(e.getMessage());
            String[] toAddress = 'TechTeam@someemail.com';
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddress);
            mail.setReplyTo('TechTeam@someemail.com');
            mail.setSenderDisplayName('Production Issue');
            mail.setSubject('Shipstaion to Sales Service Failure for Store ' + name);
            mail.setPlainTextBody(e.getMessage());
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {
                mail
            });
        }
    }


        /*
    *********************************************************
    @Method Name    : testStoreProcessShipmentsUpsert
    @description    : Used only to add in Sales records from the Test Store
    @param          : ShipppedShipments
    @return         : Null
    ********************************************************
    */
    public void testStoreProcessShipmentsUpsert(ShipppedShipments trackingShipments) {

        list < Sales__c > ShipmentsToUpsert = new list < Sales__c > ();
        for (cls_shipments shipment: trackingShipments.shipments) {
            if (shipment.voided == false) {
                if (shipment.shipmentItems != null) {
                    String[] customerName = shipment.shipTo.name.split(' ');
                    for (cls_shipmentItems item: shipment.shipmentItems) {
                        Sales__c s = new Sales__c();
                        s.address_1__c = shipment.shipTo.street1;
                        s.address_2__c = shipment.shipTo.street2;
                        s.channel__c = 'Website';
                        s.city__c = shipment.shipTo.city;
                        s.country__c = shipment.shipTo.country;
                        s.email__c = shipment.customerEmail;
                        s.first_name__c = customerName[0];
                        s.fulfillment_type__c = 'E-Com';
                        s.item__c = item.name;
                        s.last_name__c = customerName[customerName.size() - 1];
                        s.lob__c = 'Distribution';
                        s.order_number__c = shipment.orderNumber;
                        s.postal_code__c = shipment.shipTo.postalCode;
                        s.price__c = item.unitPrice;
                        s.qty__c = item.quantity;
                        s.sales_type__c = 'B2C';
                        s.shipping_amount__c = shipment.shipmentCost;
                        s.sku__c = item.sku;
                        s.state_provence__c = shipment.shipTo.state;
                        s.Sales__c = item.unitPrice;
                        s.transaction__c = 'Purchase';
                        s.external_id__c = shipment.orderNumber + '_' + item.sku;
                        s.tracking_number__c = shipment.trackingNumber;
                        s.Transaction_date__c = date.valueOf(shipment.shipDate);
                        s.Sent_To_Shipstation__c = True;
                        s.shipping_service__c = shipment.serviceCode;

                        ShipmentsToUpsert.add(s);
                    }
                }
            } else {
                continue;
            }
        }
        try {
            upsert ShipmentsToUpsert external_id__c;

            Integer currentPageNum = integer.valueOf(trackingShipments.page);
            Integer totalPagesNum = integer.valueOf(trackingShipments.pages);
            if (currentPageNum < totalPagesNum) {
                Integer nextPageNum = currentPageNum + 1;
                String nextPage = String.valueOf(nextPageNum);

                ShipstationToSalesService ws = new ShipstationToSalesService(name, key, secret, storeID, source, nextPage, shippingdate);
                System.enqueueJob(ws);
            }
        } catch (DmlException e) {
            System.debug(e.getMessage());
            String[] toAddress = 'TechTeam@someemail.com';
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddress);
            mail.setReplyTo('TechTeam@someemail.com');
            mail.setSenderDisplayName('Production Issue');
            mail.setSubject('Shipstaion to Sales Service Failure for Store ' + name);
            mail.setPlainTextBody(e.getMessage());
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] {
                mail
            });
        }
    }

}