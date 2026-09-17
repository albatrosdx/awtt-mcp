/**
 * ハンズオン準備画面（LWC: hoWorkshopSetup）用コントローラ。
 */
public with sharing class HO_WorkshopSetupController {
    public class StatusRow {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String objectName;
        @AuraEnabled
        public Integer count;
    }

    public class Status {
        @AuraEnabled
        public List<StatusRow> rows = new List<StatusRow>();
        @AuraEnabled
        public List<String> steps = HO_DataFactory.STEPS;
        @AuraEnabled
        public String backgroundJobStatus;
    }

    @AuraEnabled
    public static Status getStatus() {
        Status s = new Status();
        s.rows.add(row('商品', 'Product2', [SELECT COUNT() FROM Product2 WHERE HO_Workshop_Data__c = TRUE]));
        s.rows.add(row('取引先', 'Account', [SELECT COUNT() FROM Account WHERE HO_Workshop_Data__c = TRUE]));
        s.rows.add(row('取引先責任者', 'Contact', [SELECT COUNT() FROM Contact WHERE HO_Workshop_Data__c = TRUE]));
        s.rows.add(row('リード', 'Lead', [SELECT COUNT() FROM Lead WHERE HO_Workshop_Data__c = TRUE]));
        s.rows.add(row('商談', 'Opportunity', [SELECT COUNT() FROM Opportunity WHERE HO_Workshop_Data__c = TRUE]));
        s.rows.add(row('活動(ToDo)', 'Task', [SELECT COUNT() FROM Task WHERE HO_Workshop_Data__c = TRUE]));
        s.rows.add(row('ベースライン', 'HO_Baseline__c', [SELECT COUNT() FROM HO_Baseline__c]));
        s.rows.add(row('変更ログ', 'HO_Change_Log__c', [SELECT COUNT() FROM HO_Change_Log__c]));
        List<AsyncApexJob> jobs = [
            SELECT Status
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'HO_SetupQueueable'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        s.backgroundJobStatus = jobs.isEmpty() ? null : jobs[0].Status;
        return s;
    }

    @AuraEnabled
    public static Integer runStep(String step) {
        try {
            return HO_DataFactory.runStep(step);
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    @AuraEnabled
    public static Integer deleteAll() {
        try {
            return HO_DataFactory.deleteAll();
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    @AuraEnabled
    public static Id runInBackground() {
        return System.enqueueJob(new HO_SetupQueueable(0));
    }

    @AuraEnabled
    public static List<HO_BaselineService.DiffRow> getDiff(String objectName) {
        try {
            return HO_BaselineService.diff(objectName, 1000);
        } catch (Exception e) {
            throw auraError(e);
        }
    }

    private static StatusRow row(String label, String objectName, Integer count) {
        StatusRow r = new StatusRow();
        r.label = label;
        r.objectName = objectName;
        r.count = count;
        return r;
    }

    private static AuraHandledException auraError(Exception e) {
        AuraHandledException ae = new AuraHandledException(e.getMessage());
        ae.setMessage(e.getMessage());
        return ae;
    }
}
