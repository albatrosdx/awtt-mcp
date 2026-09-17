/**
 * カスタムメタデータ HO_Mcp_Guardrail__mdt で定義された「AIに更新させてよい範囲」を解決する。
 * 本番運用ではこのメタデータをリリース管理し、許可範囲の変更をレビュー対象にする想定。
 */
public inherited sharing class HO_Guardrail {
    public String objectName;
    public Set<String> allowedFields = new Set<String>();
    public Integer maxRecords;
    public Boolean allowUpdate;
    public Boolean workshopDataOnly;

    @TestVisible
    private static Map<String, HO_Guardrail> cache;

    public static HO_Guardrail forObject(String objectName) {
        if (cache == null) {
            cache = new Map<String, HO_Guardrail>();
            for (HO_Mcp_Guardrail__mdt m : HO_Mcp_Guardrail__mdt.getAll().values()) {
                HO_Guardrail g = new HO_Guardrail();
                g.objectName = m.Object_API_Name__c;
                g.allowUpdate = m.Allow_Update__c;
                g.workshopDataOnly = m.Workshop_Data_Only__c;
                g.maxRecords = m.Max_Records_Per_Batch__c == null ? 50 : m.Max_Records_Per_Batch__c.intValue();
                for (String f : String.isBlank(m.Allowed_Fields__c) ? new List<String>() : m.Allowed_Fields__c.split(',')) {
                    if (String.isNotBlank(f)) {
                        g.allowedFields.add(f.trim().toLowerCase());
                    }
                }
                cache.put(g.objectName.toLowerCase(), g);
            }
        }
        HO_Guardrail g = cache.get(objectName == null ? '' : objectName.toLowerCase());
        if (g == null) {
            throw new HO_Exception('このオブジェクトはMCPツールでの操作が許可されていません: ' + objectName);
        }
        return g;
    }

    public Boolean isFieldAllowed(String fieldName) {
        return fieldName != null && allowedFields.contains(fieldName.toLowerCase());
    }

    /** MCP クライアント（AI）に返すエラーメッセージ。権限不足は原因が分かるように補足する。 */
    public static String friendlyMessage(Exception e) {
        String msg = e.getMessage();
        if (e instanceof QueryException || e instanceof System.NoAccessException || msg.contains('No such column') || msg.contains('insufficient access')) {
            msg += ' / ヒント: 接続ユーザーに権限セット HO_MCP_ReadOnly（参照）または HO_MCP_Editor（更新）が割り当てられているか確認してください。';
        }
        return msg;
    }
}
