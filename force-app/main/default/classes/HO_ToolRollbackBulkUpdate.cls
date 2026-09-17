/**
 * [MCPツール / 更新] 適用済みバッチのロールバック
 */
global with sharing class HO_ToolRollbackBulkUpdate {
    global class Request {
        @InvocableVariable(label='Batch Id' description='取り消したいバッチID' required=true)
        global String batchId;
    }

    global class Result {
        @InvocableVariable(label='Rolled Back Record Count' description='変更前の値に戻したレコード数')
        global Integer rolledBackCount;
        @InvocableVariable(label='Conflict Record Count' description='適用後にさらに変更されていたため戻さなかったレコード数')
        global Integer conflictCount;
        @InvocableVariable(label='Failed Record Count' description='失敗したレコード数')
        global Integer failedCount;
        @InvocableVariable(label='Result JSON' description='詳細')
        global String resultJson;
        @InvocableVariable(label='Error Message' description='エラー時のみ設定される')
        global String errorMessage;
    }

    @InvocableMethod(
        label='HO: 一括更新のロールバック'
        description='適用済みバッチの変更を変更前の値に戻す。適用後に別の変更が入った項目は上書きせず競合として報告する。人間の指示があった場合にのみ呼び出すこと。'
        category='HO Workshop'
    )
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                HO_BulkUpdateService.ApplyResult a = HO_BulkUpdateService.rollback(req.batchId);
                res.rolledBackCount = a.successCount;
                res.conflictCount = a.conflictCount;
                res.failedCount = a.failedCount;
                res.resultJson = JSON.serialize(a);
            } catch (Exception e) {
                res.errorMessage = HO_Guardrail.friendlyMessage(e);
            }
            results.add(res);
        }
        return results;
    }
}
