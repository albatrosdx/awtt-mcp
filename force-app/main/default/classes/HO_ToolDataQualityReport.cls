/**
 * [MCPツール / 参照のみ] データ品質レポート
 */
global with sharing class HO_ToolDataQualityReport {
    global class Request {
        @InvocableVariable(label='Object API Name' description='調査対象のオブジェクトAPI名。Account / Contact / Lead / Opportunity / Product2 のいずれか' required=true)
        global String objectApiName;

        @InvocableVariable(label='Workshop Data Only' description='trueまたは未指定ならハンズオン用データ(HO_Workshop_Data__c=true)のみを対象にする' required=false)
        global Boolean workshopDataOnly;
    }

    global class Result {
        @InvocableVariable(label='Report JSON' description='空欄件数・値の分布・重複候補・命名規則違反などを含むJSON')
        global String reportJson;

        @InvocableVariable(label='Error Message' description='エラー時のみ設定される')
        global String errorMessage;
    }

    @InvocableMethod(
        label='HO: データ品質レポート（参照のみ）'
        description='指定オブジェクトの空欄件数、選択値の表記ゆれ分布、重複候補、命名規則違反、商談の不整合（後半フェーズで金額なし・失注理由なし・完了予定日超過）をJSONで返す。データは変更しない。'
        category='HO Workshop'
    )
    global static List<Result> run(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                res.reportJson = JSON.serialize(HO_QualityService.report(req.objectApiName, req.workshopDataOnly));
            } catch (Exception e) {
                res.errorMessage = HO_Guardrail.friendlyMessage(e);
            }
            results.add(res);
        }
        return results;
    }
}
