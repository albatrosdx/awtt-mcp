// MCP を使わずにデータ品質レポートを確認する（メンターの答え合わせ用）
for (String obj : new List<String>{ 'Account', 'Contact', 'Lead', 'Opportunity', 'Product2' }) {
    System.debug(LoggingLevel.WARN, obj + ' => ' + JSON.serializePretty(HO_QualityService.report(obj, true)));
}
