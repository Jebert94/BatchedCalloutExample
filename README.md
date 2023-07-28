# ShipstationToSalesSync,  ShipstationToSalesBatch and ShipstationToSalesService Classes

## Overview

This process schedules a batch process to run a staggered number of callouts to shipstation to retrieve data based upon the credentials being passed. The purpose of the batching was to stay within both the govenor CPU time limits and callout rate of shipstation while being scaleable.

### ShipstationToSalesSync
This class's primary purpose is to initiate the process. It implements the Schedulable interface, mandating an execute method, which Salesforce's scheduling system calls to run the job. The Database.executeBatch(new ShipstationToSalesBatch(), 1); command within this method initiates the batch process, processing one record at a time. 

### ShipstationToSalesBatch
A batch Apex class designed to manage large data volumes without running into org and ShipStation API limits. It implements the Database.Batchable<SObject> interface, which includes three required methods: start, execute, and finish. The start method uses a Database.QueryLocator to select active ShipStation store credentials. The execute method processes each batch, where each batch consists of one active ShipStation store. It creates an instance of the ShipstationToSalesService class and enqueues it for execution. To prevent exceeding ShipStation API limits, it includes a 'sleep' command that ensures a delay of 2 seconds between each iteration. 

### ShipstationToSalesService
This is designed to interact with the Shipstation API, processing store credential records for a given Shipstation store. The primary function of this class is to execute a GET callout to either update the tracking of a corresponding Sales record in Salesforce, or create a new Sales record with information received from Shipstation. The class contains multiple methods, including the main method execute, which based on the type of store, either updates the tracking information or processes shipments.

## Class Methods Descriptions

### ShipstationToSalesSync
- `execute(SchedulableContext sc)`: This method is triggered when the `ShipstationToSalesSync` class is scheduled, initializing and executing the `ShipstationToSalesBatch` class with a batch size of 1.

### ShipstationToSalesBatch
- `start(Database.BatchableContext bc)`: This method is triggered at the beginning of the batch process and returns a `QueryLocator` object containing all active Shipstation store credentials.
- `execute(Database.BatchableContext bc, shipstationStoreCredential__c shipstationStore)`: This method runs for each active Shipstation store credential, instantiating the `ShipstationToSalesService` class for that store and enqueuing it as a job to prevent exceeding Shipstation API limits.

### ShipstationToSalesService
- `ShipstationToSalesService(String shipstation_name, String shipstaion_key, String shipstaion_secret, String shipstaion_storeID, String shipstation_source, String shipstaion_currentPage, String shipstaion_shippingdate)`: This constructor method initializes the `ShipstationToSalesService` class with a specific Shipstation store name, key, secret, store ID, source, current page, and shipping date.
- `execute(QueueableContext context)`: This method will run after the constructor. Its purpose is to identify which store the record is coming from, callout to shipstation using that stores credentials and process the information accordingly. 
- `getCalloutResponse()`: This method executes a GET callout to a specified Shipstation store, fetching shipments between two given shipping dates, and returns the JSON body of the response.
- `processShipmentsUpdate(ShipppedShipments trackingShipments)`: Finds the corrisponding Sales records that already exist in the Salesforce org with the ones from the shipment response and updates the tracking information.
- `processShipmentsUpsert(ShipppedShipments trackingShipments)`: Creates or updates Sales records in the salesforce org from the shipstation response depending if they already exist based on the external id.
- `testStoreProcessShipmentsUpsert(ShipppedShipments trackingShipments)`: Is a method used to test new items to make sure they go through the whole system without issue.

## How To Use
Set up Shipstation stores with a shipstationStoreCredential__c record marked as active and schedule the class to run via the ShipstationToSalesSync class

## Notes
All Object Names, Methods and Variables have been changed from the original classes for security purposes.
