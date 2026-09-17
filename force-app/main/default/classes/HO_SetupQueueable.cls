/**
 * テストデータ生成をバックグラウンドで実行する（画面の「バックグラウンドで生成」ボタンから呼ばれる）。
 * Developer Edition / スクラッチ組織では Queueable の連鎖が5段までに制限されるため、
 * ステップを2つのジョブにまとめて連鎖させる。
 */
public with sharing class HO_SetupQueueable implements Queueable {
    @TestVisible
    private static final List<List<String>> JOBS = new List<List<String>>{
        new List<String>{ 'products', 'accounts', 'contacts', 'leads' },
        new List<String>{ 'opportunities', 'activities', 'baseline' }
    };

    private final Integer jobIndex;

    public HO_SetupQueueable(Integer jobIndex) {
        this.jobIndex = jobIndex;
    }

    public void execute(QueueableContext context) {
        for (String step : JOBS[jobIndex]) {
            HO_DataFactory.runStep(step);
        }
        if (jobIndex + 1 < JOBS.size() && !Test.isRunningTest()) {
            System.enqueueJob(new HO_SetupQueueable(jobIndex + 1));
        }
    }
}
