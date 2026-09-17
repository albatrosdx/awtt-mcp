/**
 * [MCPツール / 参照のみ] 初期状態（ベースライン）との差分
 */
global with sharing class HO_ToolCompareWithBaseline {
    global class Request {
        @InvocableVariable(label='Object API Name' description='Account / Contact / Lead / Opportunity / Product2。未指定なら全オブジェクト' required=false)
        global String objectApiName;
        @InvocableVariable(label='Max Rows' description='返す差分行の最大数（既定500）' required=false)
        global Integer maxRows;
    }

    global class Result {
        @InvocableVariable(label='Diff Row Count' description='差分行数（項目単位。削除されたレコードは1行）')
        global Integer diffRowCount;
        @InvocableVariable(label='Diff JSON' description='objectName, recordId, recordName, field, beforeValue, afterValue, changeType(Changed/Deleted) の配列')
        global String diffJson;
        @InvocableVariable(label='Error Message' description='エラー時のみ設定される')
        global String errorMessage;
    }

    @InvocableMethod(
        label='HO: ベースラインとの差分（参照のみ）'
        description='テストデータ生成直後のスナップショットと現在値を比較し、変更・削除された項目を返す。どの経路（標準MCPツール、画面、本ツール）で変更されたかに関係なく検出できる。データは変更しない。'
        category='HO Workshop'
    )
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                List<HO_BaselineService.DiffRow> rows = HO_BaselineService.diff(req.objectApiName, req.maxRows);
                res.diffRowCount = rows.size();
                res.diffJson = JSON.serialize(rows);
            } catch (Exception e) {
                res.errorMessage = HO_Guardrail.friendlyMessage(e);
            }
            results.add(res);
        }
        return results;
    }
}
