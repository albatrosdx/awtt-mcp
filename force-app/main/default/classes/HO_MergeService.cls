/**
 * 取引先の重複統合。dryRun=true（既定）では影響範囲だけを返し、何も変更しない。
 * 統合は元に戻せないため、ログには統合前の状態を残す。
 */
public with sharing class HO_MergeService {
    public static Map<String, Object> mergeAccounts(Id masterId, List<Id> duplicateIds, Boolean dryRun, String reason) {
        if (masterId == null || duplicateIds == null || duplicateIds.isEmpty()) {
            throw new HO_Exception('masterAccountId と duplicateAccountIds は必須です');
        }
        if (duplicateIds.size() > 2) {
            throw new HO_Exception('1回に統合できる重複は最大2件です（Salesforceの仕様）');
        }
        if (duplicateIds.contains(masterId)) {
            throw new HO_Exception('マスタと重複に同じIDが含まれています');
        }
        HO_Guardrail g = HO_Guardrail.forObject('Account');
        Set<Id> allIds = new Set<Id>(duplicateIds);
        allIds.add(masterId);
        List<String> fields = HO_BaselineService.TRACKED_FIELDS.get('Account');
        Map<Id, Account> accounts = new Map<Id, Account>((List<Account>) Database.queryWithBinds(
            'SELECT Id, HO_Workshop_Data__c, HO_Seed_Key__c, ' + String.join(fields, ', ')
                + ', (SELECT Id FROM Contacts), (SELECT Id FROM Opportunities) FROM Account WHERE Id IN :ids',
            new Map<String, Object>{ 'ids' => allIds },
            AccessLevel.USER_MODE
        ));
        for (Id i : allIds) {
            if (!accounts.containsKey(i)) {
                throw new HO_Exception('取引先が見つからないか参照権限がありません: ' + i);
            }
            if (g.workshopDataOnly && accounts.get(i).HO_Workshop_Data__c != true) {
                throw new HO_Exception('ハンズオン用データ以外は統合できません（ガードレール設定）: ' + i);
            }
        }

        Account master = accounts.get(masterId);
        List<Object> dupSummaries = new List<Object>();
        List<String> fillCandidates = new List<String>();
        for (Id dupId : duplicateIds) {
            Account dup = accounts.get(dupId);
            Map<String, Object> diffs = new Map<String, Object>();
            for (String f : fields) {
                String mv = HO_BaselineService.stringify(master.get(f));
                String dv = HO_BaselineService.stringify(dup.get(f));
                if (!HO_BaselineService.equalsStrict(mv, dv)) {
                    diffs.put(f, new Map<String, Object>{ 'master' => mv, 'duplicate' => dv });
                    if (mv == null && dv != null) {
                        fillCandidates.add(f + '=' + dv + '（' + dup.Name + ' より）');
                    }
                }
            }
            dupSummaries.add(new Map<String, Object>{
                'id' => dupId, 'name' => dup.Name, 'contacts' => dup.Contacts.size(), 'opportunities' => dup.Opportunities.size(), 'fieldDifferences' => diffs
            });
        }
        Map<String, Object> out = new Map<String, Object>{
            'master' => new Map<String, Object>{ 'id' => master.Id, 'name' => master.Name, 'contacts' => master.Contacts.size(), 'opportunities' => master.Opportunities.size() },
            'duplicates' => dupSummaries,
            'masterBlankFieldsFillableFromDuplicates' => fillCandidates,
            'warnings' => new List<String>{
                '統合は元に戻せません。法人番号が異なる場合は別法人の可能性があります。',
                '統合で欠損項目は自動補完されません。必要ならプレビュー/適用ツールで先にマスタ側を補完してください。'
            }
        };
        if (dryRun != false) {
            out.put('dryRun', true);
            out.put('nextAction', '人間が内容を承認した場合のみ dryRun=false で再実行してください。');
            return out;
        }

        if (!Schema.SObjectType.Account.isDeletable() || !Schema.SObjectType.Account.isUpdateable()) {
            throw new HO_Exception('取引先の統合には編集・削除権限が必要です');
        }
        if (String.isBlank(reason)) {
            throw new HO_Exception('統合を実行する場合は reason（理由）が必須です');
        }
        String batchId = 'HO-MERGE-' + Datetime.now().format('yyyyMMdd-HHmmss') + '-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).left(6);
        List<HO_Change_Log__c> logs = new List<HO_Change_Log__c>();
        for (Id dupId : duplicateIds) {
            logs.add(new HO_Change_Log__c(
                Batch_Id__c = batchId,
                Target_Object__c = 'Account',
                Record_Id__c = dupId,
                Field__c = '(MERGE)',
                Before_Value__c = JSON.serialize(accounts.get(dupId)),
                After_Value__c = 'merged into ' + masterId,
                Status__c = 'Applied',
                Reason__c = reason.left(255)
            ));
        }
        // サブクエリ結果を持つレコードを渡すと merge が失敗するため、IDだけのインスタンスを渡す
        Database.merge(new Account(Id = masterId), duplicateIds, true);
        insert logs;
        out.put('dryRun', false);
        out.put('batchId', batchId);
        out.put('result', '統合しました');
        return out;
    }
}
