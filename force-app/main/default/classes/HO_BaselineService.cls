/**
 * テストデータ生成直後のスナップショット（ベースライン）を保存し、現在値との差分を返す。
 * AI が標準の sobject 系 MCP ツールで直接更新した場合でも、何が変わったかを後から検証できる。
 */
public inherited sharing class HO_BaselineService {
    public static final Map<String, List<String>> TRACKED_FIELDS = new Map<String, List<String>>{
        'Account' => new List<String>{ 'Name', 'Industry', 'Phone', 'NumberOfEmployees', 'HO_Prefecture__c', 'HO_Corporate_Number__c' },
        'Contact' => new List<String>{ 'LastName', 'FirstName', 'Email', 'Phone', 'Title', 'Department', 'AccountId' },
        'Lead' => new List<String>{ 'Company', 'LastName', 'FirstName', 'Email', 'Phone', 'Industry', 'LeadSource', 'Status', 'Title', 'NumberOfEmployees' },
        'Opportunity' => new List<String>{ 'Name', 'AccountId', 'StageName', 'Amount', 'CloseDate', 'NextStep', 'LeadSource', 'HO_Loss_Reason__c' },
        'Product2' => new List<String>{ 'Name', 'ProductCode', 'Family', 'IsActive' }
    };

    public class DiffRow {
        @AuraEnabled
        public String objectName;
        @AuraEnabled
        public String seedKey;
        @AuraEnabled
        public String recordId;
        @AuraEnabled
        public String recordName;
        @AuraEnabled
        public String field;
        @AuraEnabled
        public String beforeValue;
        @AuraEnabled
        public String afterValue;
        @AuraEnabled
        public String changeType;
    }

    public static Integer takeBaseline() {
        delete [SELECT Id FROM HO_Baseline__c];
        List<HO_Baseline__c> rows = new List<HO_Baseline__c>();
        for (String objectName : TRACKED_FIELDS.keySet()) {
            for (SObject rec : queryWorkshopRecords(objectName, null)) {
                Map<String, String> snap = new Map<String, String>();
                for (String f : TRACKED_FIELDS.get(objectName)) {
                    snap.put(f, stringify(rec.get(f)));
                }
                rows.add(new HO_Baseline__c(
                    Seed_Key__c = (String) rec.get('HO_Seed_Key__c'),
                    Target_Object__c = objectName,
                    Record_Id__c = rec.Id,
                    Snapshot_JSON__c = JSON.serialize(snap)
                ));
            }
        }
        insert rows;
        return rows.size();
    }

    /** objectName が空なら全対象オブジェクト。 */
    public static List<DiffRow> diff(String objectName, Integer maxRows) {
        Integer limitRows = maxRows == null || maxRows <= 0 ? 500 : maxRows;
        List<String> objects = String.isBlank(objectName) ? new List<String>(TRACKED_FIELDS.keySet()) : new List<String>{ objectName };
        List<DiffRow> rows = new List<DiffRow>();
        for (String obj : objects) {
            if (!TRACKED_FIELDS.containsKey(obj)) {
                throw new HO_Exception('差分チェック対象外のオブジェクトです: ' + obj);
            }
            Map<Id, HO_Baseline__c> baselines = new Map<Id, HO_Baseline__c>();
            for (HO_Baseline__c b : [
                SELECT Record_Id__c, Seed_Key__c, Snapshot_JSON__c
                FROM HO_Baseline__c
                WHERE Target_Object__c = :obj
                ORDER BY Seed_Key__c
            ]) {
                baselines.put(Id.valueOf(b.Record_Id__c), b);
            }
            Map<Id, SObject> current = new Map<Id, SObject>(queryWorkshopRecords(obj, baselines.keySet()));
            for (Id recordId : baselines.keySet()) {
                HO_Baseline__c b = baselines.get(recordId);
                Map<String, Object> snap = (Map<String, Object>) JSON.deserializeUntyped(b.Snapshot_JSON__c);
                SObject rec = current.get(recordId);
                if (rec == null) {
                    rows.add(row(obj, b, null, '(レコード)', null, null, 'Deleted'));
                } else {
                    for (String f : TRACKED_FIELDS.get(obj)) {
                        String before = (String) snap.get(f);
                        String after = stringify(rec.get(f));
                        if (!equalsStrict(before, after)) {
                            rows.add(row(obj, b, (String) rec.get('Name'), f, before, after, 'Changed'));
                        }
                    }
                }
                if (rows.size() >= limitRows) {
                    return rows;
                }
            }
        }
        return rows;
    }

    private static DiffRow row(String obj, HO_Baseline__c b, String name, String field, String before, String after, String changeType) {
        DiffRow r = new DiffRow();
        r.objectName = obj;
        r.seedKey = b.Seed_Key__c;
        r.recordId = b.Record_Id__c;
        r.recordName = name;
        r.field = field;
        r.beforeValue = before;
        r.afterValue = after;
        r.changeType = changeType;
        return r;
    }

    private static List<SObject> queryWorkshopRecords(String objectName, Set<Id> ids) {
        Set<String> fields = new Set<String>{ 'Id', 'Name', 'HO_Seed_Key__c' };
        fields.addAll(TRACKED_FIELDS.get(objectName));
        String soql = 'SELECT ' + String.join(new List<String>(fields), ', ') + ' FROM ' + objectName;
        if (ids == null) {
            return Database.query(soql + ' WHERE HO_Workshop_Data__c = TRUE');
        }
        return Database.queryWithBinds(soql + ' WHERE Id IN :ids', new Map<String, Object>{ 'ids' => ids }, AccessLevel.SYSTEM_MODE);
    }

    public static String stringify(Object v) {
        if (v == null) {
            return null;
        }
        if (v instanceof Date) {
            return String.valueOf((Date) v);
        }
        if (v instanceof Decimal) {
            return ((Decimal) v).stripTrailingZeros().toPlainString();
        }
        String s = String.valueOf(v);
        return s == '' ? null : s;
    }

    /** Apex の == は文字列を大文字小文字無視で比較するため、厳密比較を使う。 */
    public static Boolean equalsStrict(String a, String b) {
        return a == null ? b == null : a.equals(b);
    }
}
