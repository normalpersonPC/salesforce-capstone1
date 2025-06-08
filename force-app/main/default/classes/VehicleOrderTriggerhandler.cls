public class VehicleOrderTriggerhandler {
    
    public static void handleTrigger(List<Vehicle_Order__c> newOrders, Map<Id, Vehicle_Order__c> oldOrders, Boolean isBefore, Boolean isAfter, Boolean isInsert, Boolean isUpdate) {
        if (isBefore) {
            if (isInsert || isUpdate) {
                preventOrderIfOutOfStock(newOrders);
            }
        }
        if (isAfter) {
            if (isInsert || isUpdate) {
                updateStockOnOrderPlacement(newOrders, oldOrders, isInsert, isUpdate);
            }
        }
    }
    
    // Prevent orders when the vehicle is out of stock
    private static void preventOrderIfOutOfStock(List<Vehicle_Order__c> orders) {
        Set<Id> vehicleIds = new Set<Id>();
        for (Vehicle_Order__c order : orders) {
            if (order.Vehicle__c != null) {
                vehicleIds.add(order.Vehicle__c);
            }
        }
        if (!vehicleIds.isEmpty()) {
            Map<Id, Vehicle__c> vehicleStockMap = new Map<Id, Vehicle__c>(
                [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Id IN :vehicleIds]
            );
            for (Vehicle_Order__c order : orders) {
                if (vehicleStockMap.containsKey(order.Vehicle__c)) {
                    Vehicle__c vehicle = vehicleStockMap.get(order.Vehicle__c);
                    if (vehicle.Stock_Quantity__c <= 0) {
                        order.addError('This vehicle is out of stock. Order cannot be placed.');
                    }
                }
            }
        }
    }
    
    // Update vehicle stock only when order is inserted or status changes to Confirmed
    private static void updateStockOnOrderPlacement(
        List<Vehicle_Order__c> newOrders,
        Map<Id, Vehicle_Order__c> oldOrders,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        Set<Id> vehicleIds = new Set<Id>();
        Map<Id, Integer> vehicleOrderCount = new Map<Id, Integer>();
        
        for (Vehicle_Order__c order : newOrders) {
            Boolean shouldDecrement = false;
            if (isInsert && order.Status__c == 'Confirmed') {
                shouldDecrement = true;
            } else if (isUpdate && order.Status__c == 'Confirmed' && oldOrders != null && oldOrders.containsKey(order.Id)) {
                Vehicle_Order__c oldOrder = oldOrders.get(order.Id);
                if (oldOrder.Status__c != 'Confirmed') {
                    shouldDecrement = true;
                }
            }
            if (shouldDecrement && order.Vehicle__c != null) {
                vehicleIds.add(order.Vehicle__c);
                vehicleOrderCount.put(order.Vehicle__c, vehicleOrderCount.getOrDefault(order.Vehicle__c, 0) + 1);
            }
        }
        
        if (!vehicleIds.isEmpty()) {
            Map<Id, Vehicle__c> vehicleStockMap = new Map<Id, Vehicle__c>(
                [SELECT Id, Stock_Quantity__c FROM Vehicle__c WHERE Id IN :vehicleIds]
            );
            List<Vehicle__c> vehiclesToUpdate = new List<Vehicle__c>();
            for (Id vehicleId : vehicleOrderCount.keySet()) {
                if (vehicleStockMap.containsKey(vehicleId)) {
                    Vehicle__c vehicle = vehicleStockMap.get(vehicleId);
                    Integer decrementBy = vehicleOrderCount.get(vehicleId);
                    if (vehicle.Stock_Quantity__c >= decrementBy) {
                        vehicle.Stock_Quantity__c -= decrementBy;
                        vehiclesToUpdate.add(vehicle);
                    }
                }
            }
            if (!vehiclesToUpdate.isEmpty()) {
                update vehiclesToUpdate;
            }
        }
    }
}