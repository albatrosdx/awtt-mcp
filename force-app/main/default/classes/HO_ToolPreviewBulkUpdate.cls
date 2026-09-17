/**
 * [MCPツール / 変更なし] 一括更新のプレビュー
 */
global with sharing class HO_ToolPreviewBulkUpdate {
    global class Request {
        @InvocableVariable(
            label='Changes JSON'
            description='JSON配列。例: [{"id":"001xx000003DGb2AAG","fields":{"Name":"株式会社さくら精機","Industry":"Manufacturing"}}]。同一オブジェクトは1回あたり上限件数あり(Account/Contact/Lead=200, Opportunity/Product2=100)'
            required=true
        )
        global String changesJson;

        @InvocableVariable(label='Reason' description='変更理由（例: 取引先名を命名規則に合わせて正規化）。変更ログに記録される' required=true)
        global String reason;
    }

    global class Result {
        @InvocableVariable(label='Batch Id' description='適用・ロールバック時に指定するID')
        global String batchId;
        @InvocableVariable(label='Changed Field Count' description='実際に値が変わる項目数')
        global Integer changedFieldCount;
        @InvocableVariable(label='Accepted Record Count' description='変更対象となったレコード数')
        global Integer acceptedRecordCount;
        @InvocableVariable(label='Rejected Count' description='ガードレールや権限で拒否された件数')
        global Integer rejectedCount;
        @InvocableVariable(label='Preview JSON' description='変更前後の値（先頭50件）、拒否理由、警告、次のアクション')
        global String previewJson;
        @InvocableVariable(label='Error Message' description='エラー時のみ設定される')
        global String errorMessage;
    }

    @InvocableMethod(
        label='HO: 一括更新プレビュー（変更なし）'
        description='レコード更新案を検証し、変更前後の差分を返してバッチIDを発行する。この時点ではデータを変更しない。許可されていない項目・権限のない項目・ハンズオン対象外のレコードは拒否される。結果は必ず人間に提示し、承認を得てから適用ツールを呼ぶこと。'
        category='HO Workshop'
    )
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                HO_BulkUpdateService.PreviewResult p = HO_BulkUpdateService.preview(req.changesJson, req.reason);
                res.batchId = p.changedFieldCount > 0 ? p.batchId : null;
                res.changedFieldCount = p.changedFieldCount;
                res.acceptedRecordCount = p.acceptedRecordCount;
                res.rejectedCount = p.rejected.size();
                res.previewJson = JSON.serialize(p);
            } catch (Exception e) {
                res.errorMessage = HO_Guardrail.friendlyMessage(e);
            }
            results.add(res);
        }
        return results;
    }
}
