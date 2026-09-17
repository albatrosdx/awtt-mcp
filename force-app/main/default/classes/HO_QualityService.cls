/**
 * データ品質レポート（参照のみ）。空欄率・値の分布・重複候補・命名規則違反などをまとめて返す。
 * AI が SOQL を何度も組み立てなくても「どこが荒れているか」の当たりを付けられるようにするための補助ツール。
 */
public with sharing class HO_QualityService {
    private static final Integer MAX_ROWS = 2000;
    private static final Integer MAX_ITEMS = 100;
    private static final Pattern PRODUCT_CODE_RULE = Pattern.compile('^HO-(SW|HW|SV)-\\d{4}$');

    private static final Map<String, List<String>> CATEGORY_FIELDS = new Map<String, List<String>>{
        'Account' => new List<String>{ 'Industry', 'HO_Prefecture__c' },
        'Contact' => new List<String>{ 'Title', 'Department' },
        'Lead' => new List<String>{ 'Industry', 'LeadSource', 'Status' },
        'Opportunity' => new List<String>{ 'StageName', 'HO_Loss_Reason__c', 'HO_Sales_Rep__c', 'LeadSource' },
        'Product2' => new List<String>{ 'Family', 'IsActive' }
    };
    private static final Map<String, List<String>> EXTRA_FIELDS = new Map<String, List<String>>{
        'Account' => new List<String>(),
        'Contact' => new List<String>{ 'Name' },
        'Lead' => new List<String>{ 'Name' },
        'Opportunity' => new List<String>{ 'IsClosed', 'HO_Loss_Reason_Detail__c', 'HO_Sales_Rep__c' },
        'Product2' => new List<String>()
    };

    public static Map<String, Object> report(String objectName, Boolean workshopDataOnly) {
        String obj = normalizeObject(objectName);
        Set<String> fields = new Set<String>{ 'Id', 'Name', 'HO_Workshop_Data__c' };
        fields.addAll(HO_BaselineService.TRACKED_FIELDS.get(obj));
        fields.addAll(CATEGORY_FIELDS.get(obj));
        fields.addAll(EXTRA_FIELDS.get(obj));
        String soql = 'SELECT ' + String.join(new List<String>(fields), ', ') + ' FROM ' + obj
            + (workshopDataOnly == false ? '' : ' WHERE HO_Workshop_Data__c = TRUE')
            + ' LIMIT ' + MAX_ROWS;
        List<SObject> records = Database.query(soql, AccessLevel.USER_MODE);

        Map<String, Object> out = new Map<String, Object>();
        out.put('object', obj);
        out.put('recordCount', records.size());
        out.put('truncated', records.size() == MAX_ROWS);
        out.put('blankCounts', blankCounts(records, HO_BaselineService.TRACKED_FIELDS.get(obj)));
        out.put('valueDistribution', distributions(records, CATEGORY_FIELDS.get(obj)));

        switch on obj {
            when 'Account' {
                out.put('duplicateCandidatesByName', groupBy(records, 'Name', true));
                out.put('duplicateCandidatesByCorporateNumber', groupBy(records, 'HO_Corporate_Number__c', false));
                out.put('nameRuleViolations', nameViolations(records));
            }
            when 'Contact' {
                out.put('duplicateCandidatesByEmail', groupBy(records, 'Email', false));
                out.put('duplicateCandidatesByName', groupBy(records, 'Name', false));
                out.put('emailIssues', emailIssues(records));
            }
            when 'Lead' {
                out.put('duplicateCandidatesByEmail', groupBy(records, 'Email', false));
                out.put('duplicateCandidatesByCompany', groupBy(records, 'Company', true));
                out.put('emailIssues', emailIssues(records));
            }
            when 'Opportunity' {
                out.put('opportunityIssues', opportunityIssues(records));
            }
            when 'Product2' {
                out.put('duplicateCandidatesByName', groupBy(records, 'Name', true));
                out.put('productRuleViolations', productViolations(records));
            }
        }
        out.put('note', '重複候補・違反は機械的な検出結果です。統合や修正の可否（別法人・支店など）は人が判断してください。');
        return out;
    }

    private static String normalizeObject(String objectName) {
        for (String key : HO_BaselineService.TRACKED_FIELDS.keySet()) {
            if (key.equalsIgnoreCase(objectName)) {
                return key;
            }
        }
        throw new HO_Exception('対象オブジェクトは Account / Contact / Lead / Opportunity / Product2 のいずれかです: ' + objectName);
    }

    private static Map<String, Object> blankCounts(List<SObject> records, List<String> fields) {
        Map<String, Object> out = new Map<String, Object>();
        for (String f : fields) {
            Integer blanks = 0;
            for (SObject r : records) {
                if (HO_BaselineService.stringify(r.get(f)) == null) {
                    blanks++;
                }
            }
            out.put(f, blanks);
        }
        return out;
    }

    private static Map<String, Object> distributions(List<SObject> records, List<String> fields) {
        Map<String, Object> out = new Map<String, Object>();
        for (String f : fields) {
            // 大文字小文字の違いも「ゆれ」として見せたいので、キーはそのままの文字列で集計する
            Map<String, Integer> counts = new Map<String, Integer>();
            Map<String, String> display = new Map<String, String>();
            for (SObject r : records) {
                String v = HO_BaselineService.stringify(r.get(f));
                String key = v == null ? '(空欄)' : EncodingUtil.convertToHex(Blob.valueOf(v));
                display.put(key, v == null ? '(空欄)' : v);
                counts.put(key, counts.containsKey(key) ? counts.get(key) + 1 : 1);
            }
            List<Map<String, Object>> rows = new List<Map<String, Object>>();
            for (String key : counts.keySet()) {
                rows.add(new Map<String, Object>{ 'value' => display.get(key), 'count' => counts.get(key) });
            }
            out.put(f, rows);
        }
        return out;
    }

    private static List<Object> groupBy(List<SObject> records, String field, Boolean fuzzyCompany) {
        Map<String, List<Map<String, Object>>> groups = new Map<String, List<Map<String, Object>>>();
        for (SObject r : records) {
            String v = HO_BaselineService.stringify(r.get(field));
            if (v == null) {
                continue;
            }
            String key = fuzzyCompany ? HO_Text.companyMatchKey(v) : HO_Text.toHalfWidthAscii(v).trim().toLowerCase();
            if (String.isBlank(key)) {
                continue;
            }
            if (!groups.containsKey(key)) {
                groups.put(key, new List<Map<String, Object>>());
            }
            groups.get(key).add(new Map<String, Object>{ 'id' => r.Id, 'name' => r.get('Name'), field => v });
        }
        List<Object> out = new List<Object>();
        for (String key : groups.keySet()) {
            if (groups.get(key).size() > 1 && out.size() < MAX_ITEMS) {
                out.add(new Map<String, Object>{ 'matchKey' => key, 'records' => groups.get(key) });
            }
        }
        return out;
    }

    private static List<Object> nameViolations(List<SObject> records) {
        List<Object> out = new List<Object>();
        for (SObject r : records) {
            String name = (String) r.get('Name');
            List<String> v = HO_Text.companyNameViolations(name);
            if (!v.isEmpty() && out.size() < MAX_ITEMS) {
                out.add(new Map<String, Object>{ 'id' => r.Id, 'name' => name, 'violations' => v, 'suggestedName' => HO_Text.suggestCompanyName(name) });
            }
        }
        return out;
    }

    private static List<Object> productViolations(List<SObject> records) {
        List<Object> out = new List<Object>();
        for (SObject r : records) {
            List<String> v = new List<String>();
            String code = (String) r.get('ProductCode');
            String name = (String) r.get('Name');
            if (code == null) {
                v.add('商品コード未設定');
            } else if (!PRODUCT_CODE_RULE.matcher(code).matches()) {
                v.add('商品コードが規則(HO-SW|HW|SV-0000)に不一致');
            }
            if (Pattern.matches('.*[\\uFF61-\\uFF9F].*', name)) {
                v.add('商品名に半角カナ');
            }
            if (!HO_Text.toHalfWidthAscii(name).equals(name)) {
                v.add('商品名に全角英数字・全角スペース');
            }
            if (name != name.trim()) {
                v.add('商品名の前後に空白');
            }
            if (!v.isEmpty() && out.size() < MAX_ITEMS) {
                out.add(new Map<String, Object>{ 'id' => r.Id, 'name' => name, 'productCode' => code, 'family' => r.get('Family'), 'violations' => v });
            }
        }
        return out;
    }

    private static List<Object> emailIssues(List<SObject> records) {
        List<Object> out = new List<Object>();
        for (SObject r : records) {
            String email = (String) r.get('Email');
            if (email == null) {
                continue;
            }
            String issue = !email.equals(email.toLowerCase()) ? '大文字を含む' : (email.contains('exmaple') ? 'ドメインのタイプミスの疑い(exmaple)' : null);
            if (issue != null && out.size() < MAX_ITEMS) {
                out.add(new Map<String, Object>{ 'id' => r.Id, 'name' => r.get('Name'), 'email' => email, 'issue' => issue });
            }
        }
        return out;
    }

    private static Map<String, Object> opportunityIssues(List<SObject> records) {
        List<Object> lateStageNoAmount = new List<Object>();
        List<Object> lostWithoutReason = new List<Object>();
        List<Object> overdueOpen = new List<Object>();
        Integer lostWithoutReasonButDetail = 0;
        for (SObject r : records) {
            String stage = (String) r.get('StageName');
            Map<String, Object> brief = new Map<String, Object>{
                'id' => r.Id, 'name' => r.get('Name'), 'stage' => stage, 'closeDate' => r.get('CloseDate'), 'salesRep' => r.get('HO_Sales_Rep__c')
            };
            if (r.get('Amount') == null && (stage == 'Proposal/Price Quote' || stage == 'Negotiation/Review' || stage == 'Closed Won')) {
                lateStageNoAmount.add(brief);
            }
            if (stage == 'Closed Lost' && r.get('HO_Loss_Reason__c') == null) {
                brief.put('lossReasonDetail', r.get('HO_Loss_Reason_Detail__c'));
                lostWithoutReason.add(brief);
                if (r.get('HO_Loss_Reason_Detail__c') != null) {
                    lostWithoutReasonButDetail++;
                }
            }
            if (r.get('IsClosed') == false && (Date) r.get('CloseDate') < Date.today()) {
                overdueOpen.add(brief);
            }
        }
        return new Map<String, Object>{
            'lateStageWithoutAmount' => new Map<String, Object>{ 'count' => lateStageNoAmount.size(), 'records' => head(lateStageNoAmount) },
            'closedLostWithoutReason' => new Map<String, Object>{
                'count' => lostWithoutReason.size(), 'inferableFromDetail' => lostWithoutReasonButDetail, 'records' => head(lostWithoutReason)
            },
            'openButPastCloseDate' => new Map<String, Object>{ 'count' => overdueOpen.size(), 'records' => head(overdueOpen) }
        };
    }

    private static List<Object> head(List<Object> items) {
        List<Object> out = new List<Object>();
        for (Integer i = 0; i < Math.min(items.size(), MAX_ITEMS); i++) {
            out.add(items[i]);
        }
        return out;
    }
}
