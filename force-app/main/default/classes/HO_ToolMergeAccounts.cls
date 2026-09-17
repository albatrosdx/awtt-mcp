/**
 * [MCPツール / 既定は変更なし] 取引先の重複統合
 */
global with sharing class HO_ToolMergeAccounts {
    global class Request {
        @InvocableVariable(label='Master Account Id' description='残す側の取引先ID' required=true)
        global String masterAccountId;
        @InvocableVariable(label='Duplicate Account Ids' description='統合される側の取引先ID（カンマ区切り、最大2件）' required=true)
        global String duplicateAccountIds;
        @InvocableVariable(label='Dry Run' description='true または未指定なら影響範囲の確認のみ。falseで統合を実行（元に戻せない）' required=false)
        global Boolean dryRun;
        @InvocableVariable(label='Reason' description='統合理由。dryRun=false の場合は必須' required=false)
        global String reason;
    }

    global class Result {
        @InvocableVariable(label='Result JSON' description='マスタ/重複の関連件数、項目の差異、補完候補、警告、実行結果')
        global String resultJson;
        @InvocableVariable(label='Error Message' description='エラー時のみ設定される')
        global String errorMessage;
    }

    @InvocableMethod(
        label='HO: 取引先の重複統合'
        description='重複取引先をマスタに統合する。既定(dryRun未指定)は取引先責任者・商談の付け替え件数や項目差異を返すだけで変更しない。統合は元に戻せないため、法人番号が異なる・支店である等の可能性を人間に確認し、明示的な承認を得た場合のみ dryRun=false で呼び出すこと。'
        category='HO Workshop'
    )
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                List<Id> dupIds = new List<Id>();
                for (String s : String.isBlank(req.duplicateAccountIds) ? new List<String>() : req.duplicateAccountIds.split(',')) {
                    if (String.isNotBlank(s)) {
                        dupIds.add(Id.valueOf(s.trim()));
                    }
                }
                Id masterId = String.isBlank(req.masterAccountId) ? null : Id.valueOf(req.masterAccountId.trim());
                res.resultJson = JSON.serialize(HO_MergeService.mergeAccounts(masterId, dupIds, req.dryRun, req.reason));
            } catch (Exception e) {
                res.errorMessage = HO_Guardrail.friendlyMessage(e);
            }
            results.add(res);
        }
        return results;
    }
}
