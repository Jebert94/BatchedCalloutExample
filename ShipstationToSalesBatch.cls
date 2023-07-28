/*
*********************************************************
Apex Class Name    : ShipstationToSalesBatch
@description       : This class is used to batch all instaciations of the ShipstationToSalesServcie to not run into any org and Shipstation API limits
*********************************************************
*/
public class ShipstationToSalesBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator('SELECT name, secret__c, key__c, storeID__c, source__c, active__c FROM shipstationStoreCredential__c WHERE active__c = True');
    }
    /*
    *********************************************************
    @Method Name    : execute (Main)
    @description    : Main method that will parse through all shipstation store credentials that are active and instanciate the shipstaion to totalsales webservice for that store
    @param          : shipstationStoreCredential__c
    @return         : Null
    ********************************************************
    */
    public void execute(Database.BatchableContext bc, shipstationStoreCredential__c shipstationStore){
        // Since the batch number is one, each call of execute will only process one Shipstaion Store Credential record that is used to create an ShipstationToSalesServcie Class that will be enqueued
        ShipstationToSalesServcie sscallout = new ShipstationToSalesServcie(shipstationStore.name, shipstationStore.key__c, shipstationStore.secret__c, shipstationStore.storeID__c, shipstationStore.source__c, '1', String.valueOf(Date.today()));
        System.enqueueJob(sscallout);

        // Improvised hacky sleep command to not go over Shipstaion API Limits
        Long startTime = DateTime.now().getTime();
		Long finishTime = DateTime.now().getTime();
		while ((finishTime - startTime) < 2000) {
    		finishTime = DateTime.now().getTime();
        }
    }
    
    public void finish(Database.BatchableContext bc){
        
    }
}