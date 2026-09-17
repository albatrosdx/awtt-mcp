/**
 * [MCPツール / 更新] プレビュー済みバッチの適用
 */
global with sharing class HO_ToolApplyBulkUpdate {
    global class Request {
        @InvocableVariable(label='Batch Id' description='プレビューツールが返したバッチID' required=true)
        global String batchId;
    }

    global class Result {
        @InvocableVariable(label='Applied Record Count' description='更新に成功したレコード数')
        global Integer appliedCount;
        @InvocableVariable(label='Conflict Record Count' description='プレビュー後に値が変わっていたため適用しなかったレコード数')
        global Integer conflictCount;
        @InvocableVariable(label='Failed Record Count' description='入力規則などで失敗したレコード数')
        global Integer failedCount;
        @InvocableVariable(label='Result JSON' description='競合・失敗の詳細')
        global String resultJson;
        @InvocableVariable(label='Error Message' description='エラー時のみ設定される')
        global String errorMessage;
    }

    @InvocableMethod(
        label='HO: 一括更新の適用'
        description='プレビュー済みのバッチIDの変更を実行ユーザー権限で適用する。人間がプレビュー内容を承認した場合にのみ呼び出すこと。プレビューから60分で失効し、プレビュー後に他で変更されたレコードは適用されない。適用後はロールバックツールで取り消せる。'
        category='HO Workshop'
    )
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                HO_BulkUpdateService.ApplyResult a = HO_BulkUpdateService.apply(req.batchId);
                res.appliedCount = a.successCount;
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
