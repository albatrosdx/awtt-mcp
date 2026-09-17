import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import getStatus from '@salesforce/apex/HO_WorkshopSetupController.getStatus';
import runStep from '@salesforce/apex/HO_WorkshopSetupController.runStep';
import deleteAll from '@salesforce/apex/HO_WorkshopSetupController.deleteAll';
import runInBackground from '@salesforce/apex/HO_WorkshopSetupController.runInBackground';
import getDiff from '@salesforce/apex/HO_WorkshopSetupController.getDiff';

const STEP_LABELS = {
    products: '商品マスタ',
    accounts: '取引先',
    contacts: '取引先責任者',
    leads: 'リード',
    opportunities: '商談',
    activities: '活動(ToDo)',
    baseline: 'ベースライン（差分チェック用スナップショット）'
};

export default class HoWorkshopSetup extends LightningElement {
    rows = [];
    steps = [];
    backgroundJobStatus;
    busy = false;
    progress = 0;
    progressLabel = '';

    diffObject = '';
    diffRows = [];
    diffLoaded = false;

    statusColumns = [
        { label: 'データ', fieldName: 'label' },
        { label: 'API名', fieldName: 'objectName' },
        { label: '件数', fieldName: 'count', type: 'number', cellAttributes: { alignment: 'left' } }
    ];

    diffColumns = [
        { label: '種別', fieldName: 'changeType', initialWidth: 90 },
        { label: 'オブジェクト', fieldName: 'objectName', initialWidth: 120 },
        { label: 'シードキー', fieldName: 'seedKey', initialWidth: 160 },
        { label: 'レコード', fieldName: 'recordUrl', type: 'url', typeAttributes: { label: { fieldName: 'recordName' }, target: '_blank' } },
        { label: '項目', fieldName: 'field', initialWidth: 170 },
        { label: '変更前', fieldName: 'beforeValue', wrapText: true },
        { label: '変更後', fieldName: 'afterValue', wrapText: true }
    ];

    objectOptions = [
        { label: 'すべて', value: '' },
        { label: '取引先 (Account)', value: 'Account' },
        { label: '取引先責任者 (Contact)', value: 'Contact' },
        { label: 'リード (Lead)', value: 'Lead' },
        { label: '商談 (Opportunity)', value: 'Opportunity' },
        { label: '商品 (Product2)', value: 'Product2' }
    ];

    connectedCallback() {
        this.loadStatus();
    }

    get diffSummary() {
        return this.diffRows.length === 0 ? '差分はありません（初期状態のままです）。' : `${this.diffRows.length} 件の差分があります。`;
    }

    async loadStatus() {
        try {
            const status = await getStatus();
            this.rows = status.rows;
            this.steps = status.steps;
            this.backgroundJobStatus = status.backgroundJobStatus;
        } catch (e) {
            this.toast('状況の取得に失敗しました', this.message(e), 'error');
        }
    }

    async handleGenerate() {
        const steps = this.steps.length ? this.steps : Object.keys(STEP_LABELS);
        this.busy = true;
        try {
            for (let i = 0; i < steps.length; i++) {
                this.progressLabel = `(${i + 1}/${steps.length}) ${STEP_LABELS[steps[i]] || steps[i]} を生成中...`;
                this.progress = Math.round((i / steps.length) * 100);
                // 1ステップ = 1トランザクションにしてガバナ制限を避ける
                // eslint-disable-next-line no-await-in-loop
                await runStep({ step: steps[i] });
            }
            this.progress = 100;
            this.toast('完了', 'テストデータを初期状態で生成しました。', 'success');
            this.diffLoaded = false;
        } catch (e) {
            this.toast('生成に失敗しました', this.message(e), 'error');
        } finally {
            this.busy = false;
            await this.loadStatus();
        }
    }

    async handleBackground() {
        try {
            await runInBackground();
            this.toast('開始しました', 'バックグラウンドで生成しています。数分後に「状況を更新」を押してください。', 'info');
            await this.loadStatus();
        } catch (e) {
            this.toast('開始できませんでした', this.message(e), 'error');
        }
    }

    async handleDelete() {
        const ok = await LightningConfirm.open({
            message: 'HO_Workshop_Data__c = true のレコード、変更ログ、ベースラインをすべて削除します。よろしいですか？',
            variant: 'header',
            theme: 'warning',
            label: 'ハンズオンデータの削除'
        });
        if (!ok) {
            return;
        }
        this.busy = true;
        this.progressLabel = '削除中...';
        this.progress = 50;
        try {
            const count = await deleteAll();
            this.toast('削除しました', `${count} 件削除しました。`, 'success');
            this.diffLoaded = false;
        } catch (e) {
            this.toast('削除に失敗しました', this.message(e), 'error');
        } finally {
            this.busy = false;
            await this.loadStatus();
        }
    }

    handleObjectChange(event) {
        this.diffObject = event.detail.value;
    }

    async loadDiff() {
        try {
            const rows = await getDiff({ objectName: this.diffObject });
            this.diffRows = rows.map((r, i) => ({ ...r, key: `${r.recordId}-${r.field}-${i}`, recordUrl: `/${r.recordId}`, recordName: r.recordName || r.recordId }));
            this.diffLoaded = true;
        } catch (e) {
            this.toast('差分の取得に失敗しました', this.message(e), 'error');
        }
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    message(e) {
        return e?.body?.message || e?.message || String(e);
    }
}
