@IsTest
private class HO_WorkshopTest {
    private static final String TEST_USERNAME = 'ho.workshop.admin@' + UserInfo.getOrganizationId() + '.example.com';

    @TestSetup
    static void setup() {
        // USER_MODE のクエリ/DMLはFLSが効くため、実運用と同じく権限セットを付与したユーザーで実行する
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile admin = [SELECT Id FROM Profile WHERE PermissionsModifyAllData = TRUE AND UserType = 'Standard' ORDER BY CreatedDate LIMIT 1];
            User u = new User(
                Username = TEST_USERNAME, Email = 'ho.workshop.admin@example.com', LastName = 'HOテスト', Alias = 'hotest',
                ProfileId = admin.Id, TimeZoneSidKey = 'Asia/Tokyo', LocaleSidKey = 'ja_JP', LanguageLocaleKey = 'ja', EmailEncodingKey = 'UTF-8'
            );
            insert u;
            insert new PermissionSetAssignment(
                AssigneeId = u.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'HO_Workshop_Admin'].Id
            );
        }
        for (String step : HO_DataFactory.STEPS) {
            HO_DataFactory.runStep(step);
        }
    }

    /** 権限セット HO_Workshop_Admin を付与したテストユーザー */
    private static User runningUser() {
        return [SELECT Id FROM User WHERE Username = :TEST_USERNAME];
    }

    private static Account accountByKey(String key) {
        return [SELECT Id, Name, Industry FROM Account WHERE HO_Seed_Key__c = :key];
    }

    @IsTest
    static void generatesExpectedVolume() {
        System.runAs(runningUser()) {
            Assert.areEqual(HO_DataFactory.COMPANIES.size() + HO_DataFactory.DUPLICATES.size(), [SELECT COUNT() FROM Account WHERE HO_Workshop_Data__c = TRUE]);
            Assert.areEqual(260, [SELECT COUNT() FROM Opportunity WHERE HO_Workshop_Data__c = TRUE]);
            Assert.isTrue([SELECT COUNT() FROM Task WHERE HO_Workshop_Data__c = TRUE] > 0);
            Assert.isTrue([SELECT COUNT() FROM HO_Baseline__c] > 0);
            Assert.areEqual('(株)さくら精機', accountByKey('HO-ACC-A01-D1').Name);
        }
    }

    @IsTest
    static void rerunRestoresInitialValues() {
        System.runAs(runningUser()) {
            Account a = accountByKey('HO-ACC-A01-D1');
            a.Name = '株式会社さくら精機';
            update a;
            HO_DataFactory.runStep('accounts');
            Assert.areEqual('(株)さくら精機', accountByKey('HO-ACC-A01-D1').Name);
        }
    }

    @IsTest
    static void textUtilities() {
        System.runAs(runningUser()) {
            Assert.isTrue('サクラ データ パン'.equals(HO_Text.toFullWidthKana('ｻｸﾗ ﾃﾞｰﾀ ﾊﾟﾝ')));
            Assert.isTrue('ABC 123'.equals(HO_Text.toHalfWidthAscii('ＡＢＣ　１２３')));
            Assert.areEqual(HO_Text.companyMatchKey('株式会社さくら精機'), HO_Text.companyMatchKey('(株)サクラ精機'));
            Assert.areEqual(HO_Text.companyMatchKey('株式会社ソラリスネット'), HO_Text.companyMatchKey('ｿﾗﾘｽ・ﾈｯﾄ株式会社'));
            Assert.isTrue(HO_Text.companyNameViolations('株式会社さくら精機').isEmpty());
            Assert.isFalse(HO_Text.companyNameViolations('ｸﾚｽﾄ(株)　').isEmpty());
            Assert.areEqual('株式会社ひかり電子', HO_Text.suggestCompanyName('㈱ひかり電子'));
            Assert.areEqual('ヒカリ電子株式会社', HO_Text.suggestCompanyName('ヒカリ電子 株式会社'));
            Assert.areEqual(3, new HO_Random(1L).nextInt(1) + 3);
        }
    }

    @IsTest
    static void qualityReportForEachObject() {
        System.runAs(runningUser()) {
            List<HO_ToolDataQualityReport.Request> reqs = new List<HO_ToolDataQualityReport.Request>();
            for (String obj : new List<String>{ 'Account', 'contact', 'Lead', 'Opportunity', 'Product2', 'User' }) {
                HO_ToolDataQualityReport.Request r = new HO_ToolDataQualityReport.Request();
                r.objectApiName = obj;
                reqs.add(r);
            }
            List<HO_ToolDataQualityReport.Result> results = HO_ToolDataQualityReport.run(reqs);
            for (Integer i = 0; i < 5; i++) {
                Assert.isNull(results[i].errorMessage, '' + results[i].errorMessage);
            }
            Assert.isNotNull(results[5].errorMessage);
            Map<String, Object> account = (Map<String, Object>) JSON.deserializeUntyped(results[0].reportJson);
            Assert.isFalse(((List<Object>) account.get('duplicateCandidatesByName')).isEmpty());
            Assert.isFalse(((List<Object>) account.get('nameRuleViolations')).isEmpty());
        }
    }

    @IsTest
    static void previewApplyRollback() {
        System.runAs(runningUser()) {
            Account a = accountByKey('HO-ACC-A01-D1');
            HO_ToolPreviewBulkUpdate.Request pr = new HO_ToolPreviewBulkUpdate.Request();
            pr.changesJson = JSON.serialize(new List<Object>{
                new Map<String, Object>{ 'id' => a.Id, 'fields' => new Map<String, Object>{ 'Name' => '株式会社さくら精機', 'NumberOfEmployees' => '120', 'Industry' => '製造業' } }
            });
            pr.reason = 'テスト';
            HO_ToolPreviewBulkUpdate.Result preview = HO_ToolPreviewBulkUpdate.run(new List<HO_ToolPreviewBulkUpdate.Request>{ pr })[0];
            Assert.isNull(preview.errorMessage, '' + preview.errorMessage);
            Assert.isNotNull(preview.batchId);
            Assert.areEqual('(株)さくら精機', accountByKey('HO-ACC-A01-D1').Name, 'プレビューでは変更しない');

            HO_ToolApplyBulkUpdate.Request ar = new HO_ToolApplyBulkUpdate.Request();
            ar.batchId = preview.batchId;
            HO_ToolApplyBulkUpdate.Result applied = HO_ToolApplyBulkUpdate.run(new List<HO_ToolApplyBulkUpdate.Request>{ ar })[0];
            Assert.isNull(applied.errorMessage, '' + applied.errorMessage);
            Assert.areEqual(1, applied.appliedCount);
            Assert.areEqual('株式会社さくら精機', accountByKey('HO-ACC-A01-D1').Name);

            // 二重適用は拒否
            Assert.isNotNull(HO_ToolApplyBulkUpdate.run(new List<HO_ToolApplyBulkUpdate.Request>{ ar })[0].errorMessage);

            HO_ToolRollbackBulkUpdate.Request rr = new HO_ToolRollbackBulkUpdate.Request();
            rr.batchId = preview.batchId;
            HO_ToolRollbackBulkUpdate.Result rolled = HO_ToolRollbackBulkUpdate.run(new List<HO_ToolRollbackBulkUpdate.Request>{ rr })[0];
            Assert.isNull(rolled.errorMessage, '' + rolled.errorMessage);
            Assert.areEqual(1, rolled.rolledBackCount);
            Assert.areEqual('(株)さくら精機', accountByKey('HO-ACC-A01-D1').Name);
        }
    }

    @IsTest
    static void previewRejectsOutOfPolicyChanges() {
        System.runAs(runningUser()) {
            Account a = accountByKey('HO-ACC-A02');
            Account outsider = new Account(Name = 'ハンズオン対象外');
            insert outsider;
            Contact c = [SELECT Id FROM Contact WHERE HO_Workshop_Data__c = TRUE LIMIT 1];
            HO_BulkUpdateService.PreviewResult p = HO_BulkUpdateService.preview(JSON.serialize(new List<Object>{
                new Map<String, Object>{ 'id' => a.Id, 'fields' => new Map<String, Object>{ 'Rating' => 'Hot', 'NoSuchField__c' => 'x', 'NumberOfEmployees' => 'abc' } },
                new Map<String, Object>{ 'id' => outsider.Id, 'fields' => new Map<String, Object>{ 'Name' => 'x' } },
                new Map<String, Object>{ 'id' => 'not-an-id', 'fields' => new Map<String, Object>{ 'Name' => 'x' } },
                new Map<String, Object>{ 'id' => c.Id, 'fields' => new Map<String, Object>() }
            }), '拒否テスト');
            Assert.areEqual(0, p.changedFieldCount);
            Assert.areEqual(6, p.rejected.size(), JSON.serialize(p.rejected));

            try {
                HO_BulkUpdateService.preview('[]', '');
                Assert.fail('reason 必須');
            } catch (HO_Exception e) {
                Assert.isNotNull(e.getMessage());
            }
            try {
                HO_BulkUpdateService.preview('{not json', 'x');
                Assert.fail('JSON 不正');
            } catch (HO_Exception e) {
                Assert.isNotNull(e.getMessage());
            }
        }
    }

    @IsTest
    static void applyDetectsConflictAndPicklistWarning() {
        System.runAs(runningUser()) {
            Opportunity o = [SELECT Id FROM Opportunity WHERE StageName = 'Closed Lost' AND HO_Workshop_Data__c = TRUE LIMIT 1];
            HO_BulkUpdateService.PreviewResult p = HO_BulkUpdateService.preview(JSON.serialize(new List<Object>{
                new Map<String, Object>{ 'id' => o.Id, 'fields' => new Map<String, Object>{ 'Amount' => 1234567, 'NextStep' => '再提案' } }
            }), '競合テスト');
            Assert.isTrue(p.changedFieldCount > 0);
            o.NextStep = '別の人が更新';
            update o;
            HO_BulkUpdateService.ApplyResult r = HO_BulkUpdateService.apply(p.batchId);
            Assert.areEqual(1, r.conflictCount);
            Assert.areEqual(0, r.successCount);

            Lead l = [SELECT Id FROM Lead WHERE HO_Workshop_Data__c = TRUE LIMIT 1];
            HO_BulkUpdateService.PreviewResult p2 = HO_BulkUpdateService.preview(JSON.serialize(new List<Object>{
                new Map<String, Object>{ 'id' => l.Id, 'fields' => new Map<String, Object>{ 'LeadSource' => '存在しない値' } }
            }), '警告テスト');
            Assert.areEqual(1, p2.warnings.size());
            Assert.isNotNull(HO_BulkUpdateService.convert(Schema.SObjectType.Opportunity.fields.CloseDate, '2026-01-31'));
            Assert.isNotNull(HO_BulkUpdateService.convert(Schema.SObjectType.Product2.fields.IsActive, 'true'));
        }
    }

    @IsTest
    static void mergeAccountsDryRunThenExecute() {
        System.runAs(runningUser()) {
            Account master = accountByKey('HO-ACC-A04');
            Account dup1 = accountByKey('HO-ACC-A04-D1');
            Account dup2 = accountByKey('HO-ACC-A04-D2');
            HO_ToolMergeAccounts.Request req = new HO_ToolMergeAccounts.Request();
            req.masterAccountId = master.Id;
            req.duplicateAccountIds = dup1.Id + ',' + dup2.Id;
            HO_ToolMergeAccounts.Result dry = HO_ToolMergeAccounts.run(new List<HO_ToolMergeAccounts.Request>{ req })[0];
            Assert.isNull(dry.errorMessage, '' + dry.errorMessage);
            Assert.areEqual(3, [SELECT COUNT() FROM Account WHERE Id IN (:master.Id, :dup1.Id, :dup2.Id)]);

            req.dryRun = false;
            Assert.isNotNull(HO_ToolMergeAccounts.run(new List<HO_ToolMergeAccounts.Request>{ req })[0].errorMessage, 'reason 必須');
            req.reason = '同一法人番号のため統合';
            HO_ToolMergeAccounts.Result done = HO_ToolMergeAccounts.run(new List<HO_ToolMergeAccounts.Request>{ req })[0];
            Assert.isNull(done.errorMessage, '' + done.errorMessage);
            Assert.areEqual(1, [SELECT COUNT() FROM Account WHERE Id IN (:master.Id, :dup1.Id, :dup2.Id)]);
            Assert.areEqual(2, [SELECT COUNT() FROM HO_Change_Log__c WHERE Field__c = '(MERGE)']);

            req.duplicateAccountIds = master.Id;
            Assert.isNotNull(HO_ToolMergeAccounts.run(new List<HO_ToolMergeAccounts.Request>{ req })[0].errorMessage);
        }
    }

    @IsTest
    static void baselineDiffDetectsDirectChanges() {
        System.runAs(runningUser()) {
            Account a = accountByKey('HO-ACC-A09-D1');
            a.Name = '株式会社かえでリテール';
            update a;
            delete [SELECT Id FROM Product2 WHERE HO_Seed_Key__c = 'HO-PRD-D01'];

            HO_ToolCompareWithBaseline.Request req = new HO_ToolCompareWithBaseline.Request();
            HO_ToolCompareWithBaseline.Result res = HO_ToolCompareWithBaseline.run(new List<HO_ToolCompareWithBaseline.Request>{ req })[0];
            Assert.isNull(res.errorMessage, '' + res.errorMessage);
            Assert.areEqual(2, res.diffRowCount, res.diffJson);

            req.objectApiName = 'User';
            Assert.isNotNull(HO_ToolCompareWithBaseline.run(new List<HO_ToolCompareWithBaseline.Request>{ req })[0].errorMessage);
        }
    }

    @IsTest
    static void setupControllerAndBackgroundJob() {
        System.runAs(runningUser()) {
            HO_WorkshopSetupController.Status s = HO_WorkshopSetupController.getStatus();
            Assert.areEqual(8, s.rows.size());
            Assert.areEqual(0, HO_WorkshopSetupController.getDiff(null).size());
            Assert.isTrue(HO_WorkshopSetupController.runStep('products') > 0);
            try {
                HO_WorkshopSetupController.runStep('unknown');
                Assert.fail('未知のステップ');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
            List<String> jobSteps = new List<String>();
            for (List<String> job : HO_SetupQueueable.JOBS) {
                jobSteps.addAll(job);
            }
            Assert.areEqual(HO_DataFactory.STEPS, jobSteps, 'バックグラウンド生成が全ステップを網羅していること');
            Test.startTest();
            HO_WorkshopSetupController.runInBackground();
            Test.stopTest();
            Assert.isTrue(HO_WorkshopSetupController.deleteAll() > 0);
            Assert.areEqual(0, [SELECT COUNT() FROM Account WHERE HO_Workshop_Data__c = TRUE]);
        }
    }

    @IsTest
    static void readOnlyMcpUserCanAnalyzeButNotUpdate() {
        User readOnly;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            // MCP 接続ユーザーは最小権限のプロファイル + 権限セットで設計する（プロファイルの権限は権限セットで打ち消せない）
            Profile standard = [
                SELECT Id FROM Profile
                WHERE UserLicense.Name = 'Salesforce' AND Name IN ('Minimum Access - Salesforce', '最低限のアクセス - Salesforce')
                LIMIT 1
            ];
            readOnly = new User(
                Username = 'ho.mcp.readonly@' + UserInfo.getOrganizationId() + '.example.com', Email = 'ho.mcp.readonly@example.com',
                LastName = 'HO参照', Alias = 'horead', ProfileId = standard.Id, TimeZoneSidKey = 'Asia/Tokyo',
                LocaleSidKey = 'ja_JP', LanguageLocaleKey = 'ja', EmailEncodingKey = 'UTF-8'
            );
            insert readOnly;
            insert new PermissionSetAssignment(
                AssigneeId = readOnly.Id,
                PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'HO_MCP_ReadOnly'].Id
            );
        }
        Account a = accountByKey('HO-ACC-A01-D1');
        System.runAs(readOnly) {
            // 活動のカスタム項目（担当営業）を含めて、ユーザー権限で集計できること（シナリオC）
            List<AggregateResult> perRep = [
                SELECT HO_Sales_Rep__c rep, COUNT(Id) n FROM Task WHERE HO_Workshop_Data__c = TRUE WITH USER_MODE GROUP BY HO_Sales_Rep__c
            ];
            Assert.isFalse(perRep.isEmpty());

            HO_ToolDataQualityReport.Request qr = new HO_ToolDataQualityReport.Request();
            qr.objectApiName = 'Opportunity';
            HO_ToolDataQualityReport.Result report = HO_ToolDataQualityReport.run(new List<HO_ToolDataQualityReport.Request>{ qr })[0];
            Assert.isNull(report.errorMessage, '' + report.errorMessage);

            // 更新系は拒否されること
            HO_BulkUpdateService.PreviewResult p = HO_BulkUpdateService.preview(JSON.serialize(new List<Object>{
                new Map<String, Object>{ 'id' => a.Id, 'fields' => new Map<String, Object>{ 'Name' => '株式会社さくら精機' } }
            }), '参照ユーザーの更新テスト');
            Assert.areEqual(0, p.changedFieldCount);
            Assert.areEqual(1, p.rejected.size(), JSON.serialize(p.rejected));
        }
    }
}
