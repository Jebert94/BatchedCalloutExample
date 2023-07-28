/*
*********************************************************
Apex Class Name    : ShipstationToSalesSync
@description       : This class is used to be scheduled and then call the batching process(ShipstationToSalesBatch) for this webservice
Notes              : To schedule, use System.schedule('Shipstation to Sales sync', '0 0 * * * ?', new ShipstationToSalesSync());
*********************************************************
*/
global class ShipstationToSalesSync implements Schedulable{
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new ShipstationToSalesBatch(), 1);
    }

}