/**
 * AI からの一括更新を「プレビュー → 人が確認 → 適用 → 必要ならロールバック」の3段階で扱う。
 * - 更新はすべて実行ユーザーの権限（USER_MODE）で行う。MCP 接続ユーザーの権限設計がそのまま効く
 * - 許可オブジェクト/項目/件数はカスタムメタデータ（HO_Guardrail）で制御
 * - プレビュー後に他者が値を変えていたら、そのレコードは適用せず Conflict にする（楽観ロック）
 */
public with sharing class HO_BulkUpdateService {
    public static final Integer PREVIEW_EXPIRE_MINUTES = 60;
    private static final Integer SAMPLE_SIZE = 50;

    public class PreviewResult {
        public String batchId;
        public Integer acceptedRecordCount = 0;
        public Integer changedFieldCount = 0;
        public Integer unchangedFieldCount = 0;
        public List<Map<String, Object>> changes = new List<Map<String, Object>>();
        public List<Map<String, Object>> rejected = new List<Map<String, Object>>();
        public List<Map<String, Object>> warnings = new List<Map<String, Object>>();
        public String nextAction;
    }

    public class ApplyResult {
        public String batchId;
        public String operation;
        public Integer successCount = 0;
        public Integer conflictCount = 0;
        public Integer failedCount = 0;
        public List<Map<String, Object>> issues = new List<Map<String, Object>>();
    }

    // ------------------------------------------------------------------ preview

    public static PreviewResult preview(String changesJson, String reason) {
        if (String.isBlank(reason)) {
            throw new HO_Exception('reason（変更理由）は必須です。');
        }
        List<Object> items;
        try {
            items = (List<Object>) JSON.deserializeUntyped(changesJson);
        } catch (Exception e) {
            throw new HO_Exception('changesJson は [{"id":"...","fields":{"項目API名":"値"}}] 形式のJSON配列で指定してください。' + e.getMessage());
        }
        PreviewResult result = new PreviewResult();
        result.batchId = 'HO-' + Datetime.now().format('yyyyMMdd-HHmmss') + '-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).left(6);

        // レコードID → 変更内容 にまとめ、オブジェクトごとに分類
        Map<String, Map<Id, Map<String, Object>>> byObject = new Map<String, Map<Id, Map<String, Object>>>();
        for (Object item : items) {
            Map<String, Object> m = (Map<String, Object>) item;
            Id recordId;
            try {
                recordId = Id.valueOf(String.valueOf(m.get('id')));
            } catch (Exception e) {
                result.rejected.add(issue(String.valueOf(m.get('id')), null, '不正なレコードIDです'));
                continue;
            }
            Map<String, Object> fields = (Map<String, Object>) m.get('fields');
            if (fields == null || fields.isEmpty()) {
                result.rejected.add(issue(recordId, null, 'fields が空です'));
                continue;
            }
            String objectName = recordId.getSObjectType().getDescribe().getName();
            if (!byObject.containsKey(objectName)) {
                byObject.put(objectName, new Map<Id, Map<String, Object>>());
            }
            Map<Id, Map<String, Object>> recs = byObject.get(objectName);
            if (!recs.containsKey(recordId)) {
                recs.put(recordId, new Map<String, Object>());
            }
            recs.get(recordId).putAll(fields);
        }

        List<HO_Change_Log__c> logs = new List<HO_Change_Log__c>();
        for (String objectName : byObject.keySet()) {
            Map<Id, Map<String, Object>> recs = byObject.get(objectName);
            HO_Guardrail g;
            try {
                g = HO_Guardrail.forObject(objectName);
                if (!g.allowUpdate) {
                    throw new HO_Exception(objectName + ' は参照のみ許可されています');
                }
                if (recs.size() > g.maxRecords) {
                    throw new HO_Exception(objectName + ' は1バッチ最大 ' + g.maxRecords + ' 件です（指定: ' + recs.size() + ' 件）。分割してください');
                }
            } catch (HO_Exception e) {
                for (Id recordId : recs.keySet()) {
                    result.rejected.add(issue(recordId, null, e.getMessage()));
                }
                continue;
            }
            Map<String, Schema.SObjectField> fieldMap = new List<Id>(recs.keySet())[0].getSObjectType().getDescribe().fields.getMap();
            Set<String> queryFields = new Set<String>{ 'Id', 'Name' };
            if (g.workshopDataOnly) {
                queryFields.add('HO_Workshop_Data__c');
            }
            for (Map<String, Object> f : recs.values()) {
                for (String fieldName : f.keySet()) {
                    if (fieldMap.containsKey(fieldName) && g.isFieldAllowed(fieldName)) {
                        queryFields.add(fieldMap.get(fieldName).getDescribe().getName());
                    }
                }
            }
            Set<Id> ids = recs.keySet();
            Map<Id, SObject> current = new Map<Id, SObject>(Database.queryWithBinds(
                'SELECT ' + String.join(new List<String>(queryFields), ', ') + ' FROM ' + objectName + ' WHERE Id IN :ids',
                new Map<String, Object>{ 'ids' => ids },
                AccessLevel.USER_MODE
            ));
            for (Id recordId : recs.keySet()) {
                SObject rec = current.get(recordId);
                if (rec == null) {
                    result.rejected.add(issue(recordId, null, 'レコードが存在しないか、参照権限がありません'));
                    continue;
                }
                if (g.workshopDataOnly && rec.get('HO_Workshop_Data__c') != true) {
                    result.rejected.add(issue(recordId, null, 'ハンズオン用データ以外は更新できません（ガードレール設定）'));
                    continue;
                }
                Boolean anyChange = false;
                for (String requested : recs.get(recordId).keySet()) {
                    if (!fieldMap.containsKey(requested)) {
                        result.rejected.add(issue(recordId, requested, '項目が存在しません'));
                        continue;
                    }
                    Schema.DescribeFieldResult dfr = fieldMap.get(requested).getDescribe();
                    if (!g.isFieldAllowed(dfr.getName())) {
                        result.rejected.add(issue(recordId, dfr.getName(), 'ガードレールで更新が許可されていない項目です'));
                        continue;
                    }
                    if (!dfr.isUpdateable()) {
                        result.rejected.add(issue(recordId, dfr.getName(), '実行ユーザーに項目の編集権限がありません'));
                        continue;
                    }
                    Object converted;
                    try {
                        converted = convert(dfr, recs.get(recordId).get(requested));
                    } catch (Exception e) {
                        result.rejected.add(issue(recordId, dfr.getName(), '値の型変換に失敗しました: ' + e.getMessage()));
                        continue;
                    }
                    String before = HO_BaselineService.stringify(rec.get(dfr.getName()));
                    String after = HO_BaselineService.stringify(converted);
                    if (HO_BaselineService.equalsStrict(before, after)) {
                        result.unchangedFieldCount++;
                        continue;
                    }
                    String warning = picklistWarning(dfr, after);
                    if (warning != null) {
                        result.warnings.add(issue(recordId, dfr.getName(), warning));
                    }
                    anyChange = true;
                    logs.add(new HO_Change_Log__c(
                        Batch_Id__c = result.batchId,
                        Target_Object__c = objectName,
                        Record_Id__c = recordId,
                        Field__c = dfr.getName(),
                        Before_Value__c = before,
                        After_Value__c = after,
                        Status__c = 'Previewed',
                        Reason__c = reason.left(255)
                    ));
                    if (result.changes.size() < SAMPLE_SIZE) {
                        result.changes.add(new Map<String, Object>{
                            'id' => recordId, 'name' => rec.get('Name'), 'field' => dfr.getName(), 'before' => before, 'after' => after
                        });
                    }
                }
                if (anyChange) {
                    result.acceptedRecordCount++;
                }
            }
        }
        insert logs;
        result.changedFieldCount = logs.size();
        result.nextAction = logs.isEmpty()
            ? '適用対象の変更はありません。'
            : '内容を人間が確認し、承認された場合のみ batchId=' + result.batchId + ' で適用ツールを呼び出してください（' + PREVIEW_EXPIRE_MINUTES + '分で失効）。';
        return result;
    }

    // ------------------------------------------------------------------ apply / rollback

    public static ApplyResult apply(String batchId) {
        List<HO_Change_Log__c> logs = loadLogs(batchId);
        for (HO_Change_Log__c l : logs) {
            if (l.Status__c != 'Previewed') {
                throw new HO_Exception('このバッチは既に処理済みです（ステータス: ' + l.Status__c + '）');
            }
        }
        if (logs[0].CreatedDate < Datetime.now().addMinutes(-PREVIEW_EXPIRE_MINUTES)) {
            throw new HO_Exception('プレビューの有効期限（' + PREVIEW_EXPIRE_MINUTES + '分）が切れています。再度プレビューしてください');
        }
        return execute(batchId, logs, 'apply');
    }

    public static ApplyResult rollback(String batchId) {
        List<HO_Change_Log__c> logs = new List<HO_Change_Log__c>();
        for (HO_Change_Log__c l : loadLogs(batchId)) {
            if (l.Status__c == 'Applied') {
                logs.add(l);
            }
        }
        if (logs.isEmpty()) {
            throw new HO_Exception('ロールバック可能な（Applied の）変更がありません');
        }
        return execute(batchId, logs, 'rollback');
    }

    private static ApplyResult execute(String batchId, List<HO_Change_Log__c> logs, String operation) {
        Boolean isApply = operation == 'apply';
        ApplyResult result = new ApplyResult();
        result.batchId = batchId;
        result.operation = operation;

        Map<String, Map<Id, List<HO_Change_Log__c>>> byObject = new Map<String, Map<Id, List<HO_Change_Log__c>>>();
        for (HO_Change_Log__c l : logs) {
            if (!byObject.containsKey(l.Target_Object__c)) {
                byObject.put(l.Target_Object__c, new Map<Id, List<HO_Change_Log__c>>());
            }
            Map<Id, List<HO_Change_Log__c>> recs = byObject.get(l.Target_Object__c);
            Id recordId = Id.valueOf(l.Record_Id__c);
            if (!recs.containsKey(recordId)) {
                recs.put(recordId, new List<HO_Change_Log__c>());
            }
            recs.get(recordId).add(l);
        }

        for (String objectName : byObject.keySet()) {
            HO_Guardrail g = HO_Guardrail.forObject(objectName);
            Map<Id, List<HO_Change_Log__c>> recs = byObject.get(objectName);
            Map<String, Schema.SObjectField> fieldMap = new List<Id>(recs.keySet())[0].getSObjectType().getDescribe().fields.getMap();
            Set<String> queryFields = new Set<String>{ 'Id' };
            for (List<HO_Change_Log__c> ls : recs.values()) {
                for (HO_Change_Log__c l : ls) {
                    queryFields.add(l.Field__c);
                }
            }
            Set<Id> ids = recs.keySet();
            Map<Id, SObject> current = new Map<Id, SObject>(Database.queryWithBinds(
                'SELECT ' + String.join(new List<String>(queryFields), ', ') + ' FROM ' + objectName + ' WHERE Id IN :ids',
                new Map<String, Object>{ 'ids' => ids },
                AccessLevel.USER_MODE
            ));

            List<SObject> toUpdate = new List<SObject>();
            List<List<HO_Change_Log__c>> logsForUpdate = new List<List<HO_Change_Log__c>>();
            for (Id recordId : recs.keySet()) {
                List<HO_Change_Log__c> recLogs = recs.get(recordId);
                SObject rec = current.get(recordId);
                String conflict = rec == null ? 'レコードが削除されたか参照権限がありません' : null;
                SObject upd = recordId.getSObjectType().newSObject(recordId);
                for (HO_Change_Log__c l : recLogs) {
                    if (conflict != null) {
                        break;
                    }
                    if (!g.isFieldAllowed(l.Field__c)) {
                        conflict = 'ガードレール設定が変更され、' + l.Field__c + ' は更新不可になりました';
                        break;
                    }
                    String expected = isApply ? l.Before_Value__c : l.After_Value__c;
                    String actual = HO_BaselineService.stringify(rec.get(l.Field__c));
                    if (!HO_BaselineService.equalsStrict(expected, actual)) {
                        conflict = l.Field__c + ' がプレビュー後に変更されています（想定: ' + expected + ' / 現在: ' + actual + '）';
                        break;
                    }
                    Schema.DescribeFieldResult dfr = fieldMap.get(l.Field__c).getDescribe();
                    upd.put(dfr.getName(), convert(dfr, isApply ? l.After_Value__c : l.Before_Value__c));
                }
                if (conflict != null) {
                    for (HO_Change_Log__c l : recLogs) {
                        l.Status__c = isApply ? 'Conflict' : l.Status__c;
                        l.Message__c = conflict.left(255);
                    }
                    result.conflictCount++;
                    result.issues.add(issue(recordId, null, conflict));
                    continue;
                }
                toUpdate.add(upd);
                logsForUpdate.add(recLogs);
            }

            if (toUpdate.isEmpty()) {
                continue;
            }
            Database.DMLOptions opts = new Database.DMLOptions();
            opts.OptAllOrNone = false;
            opts.DuplicateRuleHeader.allowSave = true;
            List<Database.SaveResult> saves = Database.update(toUpdate, opts, AccessLevel.USER_MODE);
            for (Integer i = 0; i < saves.size(); i++) {
                Database.SaveResult sr = saves[i];
                for (HO_Change_Log__c l : logsForUpdate[i]) {
                    if (sr.isSuccess()) {
                        l.Status__c = isApply ? 'Applied' : 'RolledBack';
                        l.Message__c = null;
                    } else {
                        l.Status__c = isApply ? 'Failed' : l.Status__c;
                        l.Message__c = sr.getErrors()[0].getMessage().left(255);
                    }
                }
                if (sr.isSuccess()) {
                    result.successCount++;
                } else {
                    result.failedCount++;
                    result.issues.add(issue(toUpdate[i].Id, null, sr.getErrors()[0].getMessage()));
                }
            }
        }
        update logs;
        return result;
    }

    private static List<HO_Change_Log__c> loadLogs(String batchId) {
        if (String.isBlank(batchId)) {
            throw new HO_Exception('batchId は必須です');
        }
        List<HO_Change_Log__c> logs = [
            SELECT Id, Batch_Id__c, Target_Object__c, Record_Id__c, Field__c, Before_Value__c, After_Value__c, Status__c, Message__c, CreatedDate
            FROM HO_Change_Log__c
            WHERE Batch_Id__c = :batchId AND Field__c != '(MERGE)'
            ORDER BY Record_Id__c, Field__c
        ];
        if (logs.isEmpty()) {
            throw new HO_Exception('バッチが見つかりません: ' + batchId);
        }
        return logs;
    }

    // ------------------------------------------------------------------ helpers

    public static Object convert(Schema.DescribeFieldResult dfr, Object raw) {
        if (raw == null || (raw instanceof String && String.isBlank((String) raw))) {
            return null;
        }
        String s = String.valueOf(raw);
        switch on dfr.getType() {
            when BOOLEAN {
                return Boolean.valueOf(s);
            }
            when INTEGER {
                return Decimal.valueOf(s).intValue();
            }
            when DOUBLE, CURRENCY, PERCENT {
                return Decimal.valueOf(s);
            }
            when DATE {
                return Date.valueOf(s.left(10));
            }
            when DATETIME {
                return (Datetime) JSON.deserialize('"' + s + '"', Datetime.class);
            }
            when REFERENCE, ID {
                return Id.valueOf(s);
            }
            when else {
                return s;
            }
        }
    }

    private static String picklistWarning(Schema.DescribeFieldResult dfr, String value) {
        if (value == null || dfr.getType() != Schema.DisplayType.PICKLIST) {
            return null;
        }
        List<String> active = new List<String>();
        for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
            if (e.isActive()) {
                if (e.getValue().equals(value)) {
                    return null;
                }
                active.add(e.getValue());
            }
        }
        return '選択リストの有効な値ではありません（有効値の例: ' + String.join(active, ', ').left(200) + '）';
    }

    public static Map<String, Object> issue(Object recordId, String field, String message) {
        return new Map<String, Object>{ 'id' => recordId, 'field' => field, 'message' => message };
    }
}
