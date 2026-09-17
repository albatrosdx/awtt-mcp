// テストデータを生成（既存のハンズオンデータは初期状態に戻る）
for (String step : HO_DataFactory.STEPS) {
    System.debug(LoggingLevel.WARN, 'HO step ' + step + ': ' + HO_DataFactory.runStep(step));
}
