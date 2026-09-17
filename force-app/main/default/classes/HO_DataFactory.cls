/**
 * ハンズオン用の「荒れた」テストデータを生成する。
 * - 乱数シード固定のため、どの組織で実行しても同じデータになる（メンターが答えを把握できる）
 * - HO_Seed_Key__c による upsert なので、再実行すると AI が直した値も初期状態に戻る
 */
public inherited sharing class HO_DataFactory {
    public static final List<String> STEPS = new List<String>{
        'products', 'accounts', 'contacts', 'leads', 'opportunities', 'activities', 'baseline'
    };

    // コード|正式名称|業種(標準値)|都道府県|市外局番|ドメイン
    @TestVisible
    private static final List<String> COMPANIES = new List<String>{
        'A01|株式会社さくら精機|Manufacturing|東京都|03|sakura-seiki',
        'A02|青葉システムズ株式会社|Technology|宮城県|022|aoba-systems',
        'A03|株式会社みなと物流|Transportation|神奈川県|045|minato-logi',
        'A04|株式会社ひかり電子|Electronics|大阪府|06|hikari-denshi',
        'A05|株式会社北斗建設|Construction|北海道|011|hokuto-kensetsu',
        'A06|株式会社つばさ食品|Food & Beverage|静岡県|054|tsubasa-foods',
        'A07|いろはファイナンス株式会社|Finance|東京都|03|iroha-finance',
        'A08|株式会社あおぞらメディカル|Healthcare|福岡県|092|aozora-medical',
        'A09|株式会社かえでリテール|Retail|愛知県|052|kaede-retail',
        'A10|株式会社しずくエナジー|Energy|新潟県|025|shizuku-energy',
        'A11|株式会社ソラリスネット|Telecommunications|東京都|03|solaris-net',
        'A12|株式会社はるか教育|Education|京都府|075|haruka-edu',
        'A13|株式会社やまと化学|Chemicals|大阪府|06|yamato-chem',
        'A14|株式会社ことぶきホテルズ|Hospitality|沖縄県|098|kotobuki-hotels',
        'A15|株式会社ミライ保険サービス|Insurance|東京都|03|mirai-hoken',
        'A16|株式会社あさひ機械|Machinery|愛知県|052|asahi-kikai',
        'A17|株式会社ながれ運輸|Transportation|兵庫県|078|nagare-unyu',
        'A18|株式会社コスモデータ|Technology|東京都|03|cosmo-data',
        'A19|株式会社わかば農産|Agriculture|熊本県|096|wakaba-nosan',
        'A20|株式会社ひまわりコンサルティング|Consulting|東京都|03|himawari-consulting',
        'A21|株式会社しらゆりアパレル|Apparel|岐阜県|058|shirayuri-apparel',
        'A22|株式会社ふじみメディア|Media|東京都|03|fujimi-media',
        'A23|株式会社いずみ水道|Utilities|埼玉県|048|izumi-suido',
        'A24|株式会社ほしぞら工業|Engineering|広島県|082|hoshizora-kogyo',
        'A25|株式会社もみじバイオ|Biotechnology|茨城県|029|momiji-bio',
        'A26|株式会社ぎんが通信|Communications|千葉県|043|ginga-tsushin',
        'A27|株式会社あけぼの環境|Environmental|長野県|026|akebono-kankyo',
        'A28|株式会社たちばな建材|Construction|岡山県|086|tachibana-kenzai',
        'A29|株式会社くろしお海運|Shipping|高知県|088|kuroshio-kaiun',
        'A30|株式会社れんげ電機|Electronics|滋賀県|077|renge-denki',
        'A31|株式会社アルファ・ソリューションズ|Technology|東京都|03|alpha-solutions',
        'A32|株式会社みどり製薬|Healthcare|富山県|076|midori-seiyaku',
        'A33|株式会社はやぶさ自動車部品|Manufacturing|群馬県|027|hayabusa-parts',
        'A34|株式会社おおぞら不動産|Other|東京都|03|oozora-fudosan',
        'A35|株式会社ゆうひスポーツ|Recreation|福岡県|092|yuhi-sports',
        'A36|株式会社しんりょく出版|Media|東京都|03|shinryoku-pub',
        'A37|株式会社ともしび介護|Healthcare|大阪府|06|tomoshibi-care',
        'A38|株式会社いなほ食品|Food & Beverage|秋田県|018|inaho-foods',
        'A39|株式会社クレストエンジニアリング|Engineering|神奈川県|045|crest-eng',
        'A40|株式会社そよかぜ商事|Retail|東京都|03|soyokaze-shoji'
    };

    // 正式名称に命名規則違反を仕込む（重複ではない）
    private static final Map<String, String> NAME_OVERRIDES = new Map<String, String>{
        'A18' => '株式会社コスモﾃﾞｰﾀ',
        'A22' => '株式会社ふじみメディア　',
        'A31' => '株式会社ｱﾙﾌｧ・ｿﾘｭｰｼｮﾝｽﾞ',
        'A33' => '(株)はやぶさ自動車部品',
        'A36' => 'しんりょく出版',
        'A39' => 'ｸﾚｽﾄｴﾝｼﾞﾆｱﾘﾝｸﾞ(株)'
    };

    // 親コード|サフィックス|名称|法人番号(Y=同一 / N=未入力 / X=別法人)
    // A05-D1 は前株/後株違いの「別会社」、A12-D1 は支店。安易に統合してはいけない例。
    @TestVisible
    private static final List<String> DUPLICATES = new List<String>{
        'A01|D1|(株)さくら精機|Y',
        'A01|D2|さくら精機|N',
        'A02|D1|青葉システムズ（株）|Y',
        'A02|D2|アオバシステムズ株式会社|N',
        'A03|D1|株式会社　みなと物流|Y',
        'A04|D1|㈱ひかり電子|Y',
        'A04|D2|ヒカリ電子 株式会社|Y',
        'A05|D1|北斗建設株式会社|X',
        'A06|D1|株式会社つばさ食品 |Y',
        'A07|D1|いろはファイナンス(株)|N',
        'A08|D1|株式会社アオゾラメディカル|Y',
        'A09|D1|株式会社かえでﾘﾃｰﾙ|Y',
        'A10|D1|(株)しずくｴﾅｼﾞｰ|N',
        'A11|D1|ｿﾗﾘｽﾈｯﾄ株式会社|Y',
        'A11|D2|株式会社ソラリス・ネット|N',
        'A12|D1|株式会社はるか教育 大阪支店|Y'
    };

    private static final Map<String, List<String>> INDUSTRY_VARIANTS = new Map<String, List<String>>{
        'Manufacturing' => new List<String>{ 'Manufacturing', '製造業', '製造', 'メーカー' },
        'Technology' => new List<String>{ 'Technology', 'IT', '情報通信業', 'ソフトウェア', 'ＩＴ' },
        'Transportation' => new List<String>{ 'Transportation', '運輸業', '物流' },
        'Electronics' => new List<String>{ 'Electronics', '電機', '電子部品' },
        'Construction' => new List<String>{ 'Construction', '建設業', '建設' },
        'Food & Beverage' => new List<String>{ 'Food & Beverage', '食品', '飲料・食品' },
        'Finance' => new List<String>{ 'Finance', '金融', '金融業' },
        'Healthcare' => new List<String>{ 'Healthcare', '医療', 'ヘルスケア', '医療・福祉' },
        'Retail' => new List<String>{ 'Retail', '小売', '小売業' }
    };

    private static final Map<String, String> PREF_ROMAJI = new Map<String, String>{
        '東京都' => 'Tokyo', '大阪府' => 'Osaka', '愛知県' => 'Aichi', '神奈川県' => 'Kanagawa', '福岡県' => 'Fukuoka'
    };

    // 姓|名|last|first
    private static final List<String> PEOPLE = new List<String>{
        '佐々木|大輔|sasaki|daisuke', '山本|美穂|yamamoto|miho', '中村|拓也|nakamura|takuya', '小林|愛|kobayashi|ai',
        '加藤|誠|kato|makoto', '吉田|さやか|yoshida|sayaka', '山田|浩二|yamada|koji', '松本|奈々|matsumoto|nana',
        '井上|亮|inoue|ryo', '木村|千尋|kimura|chihiro', '林|健一|hayashi|kenichi', '清水|里奈|shimizu|rina',
        '山崎|剛|yamazaki|tsuyoshi', '森|優子|mori|yuko', '池田|直樹|ikeda|naoki', '橋本|恵|hashimoto|megumi',
        '阿部|翼|abe|tsubasa', '石川|真由|ishikawa|mayu', '前田|修|maeda|osamu', '藤田|沙織|fujita|saori',
        '後藤|隆|goto|takashi', '岡田|彩花|okada|ayaka', '長谷川|学|hasegawa|manabu', '村上|久美子|murakami|kumiko',
        '近藤|悠斗|kondo|yuto', '石井|玲奈|ishii|reina', '坂本|和也|sakamoto|kazuya', '遠藤|美紀|endo|miki',
        '青木|俊介|aoki|shunsuke', '藤井|葵|fujii|aoi'
    };

    private static final List<String> TITLES = new List<String>{
        '部長', '営業部長', '部長職', 'Manager', '課長', 'マネージャー', '担当', '主任', 'ＩＴ担当', ''
    };
    private static final List<String> DEPARTMENTS = new List<String>{
        '営業部', '営業本部', '営業', '情報システム部', '情シス', '総務部', '経営企画部', ''
    };

    // 担当営業|受注率%|金額係数|活動量係数|失注理由の傾向
    @TestVisible
    private static final List<String> REPS = new List<String>{
        '佐藤 健太|35|1.0|1.0|競合',
        '鈴木 美咲|55|0.8|1.4|タイミング',
        '高橋 翔|20|1.2|2.0|価格',
        '田中 由衣|60|1.5|0.7|予算凍結',
        '伊藤 大輔|30|0.9|0.6|価格',
        '渡辺 彩|45|1.1|1.0|機能不足'
    };

    // 商材|基準金額|受注率補正
    private static final List<String> DEAL_TYPES = new List<String>{
        'クラウドCRM導入|3000000|0',
        'BIダッシュボード導入|1200000|5',
        'IoT端末導入|5000000|-15',
        '保守契約更新|800000|25',
        'データ移行支援|1500000|0',
        'AIアシスタント追加|2000000|-10'
    };

    private static final List<String> OPEN_STAGES = new List<String>{
        'Prospecting', 'Qualification', 'Needs Analysis', 'Value Proposition',
        'Id. Decision Makers', 'Perception Analysis', 'Proposal/Price Quote', 'Negotiation/Review'
    };

    private static final List<String> LOSS_REASONS = new List<String>{ '価格', '競合', '機能不足', '予算凍結', 'タイミング', 'その他' };
    private static final Map<String, List<String>> LOSS_DETAILS = new Map<String, List<String>>{
        '価格' => new List<String>{ '見積金額が予算を大きく超過。値引き要求に応えられず', '他社より年額で2割高いとの指摘', 'ライセンス単価がネック' },
        '競合' => new List<String>{ '競合A社のパッケージに決定', '既存ベンダーが継続となった', 'コンペで提案内容が劣後' },
        '機能不足' => new List<String>{ '帳票出力のカスタマイズ要件を満たせず', 'オフライン利用ができない点が致命的', '既存基幹システムとの連携機能が不足' },
        '予算凍結' => new List<String>{ '期中の予算見直しで案件自体が凍結', '親会社の投資方針変更により見送り', '' },
        'タイミング' => new List<String>{ '来期以降に再検討とのこと', '担当者の異動で検討が止まった', '他プロジェクト優先のため延期' },
        'その他' => new List<String>{ '連絡がつかなくなった', '社内稟議が通らなかった（理由不明）', '' }
    };

    private static final List<String> LEAD_PREFIXES = new List<String>{
        'あかつき', 'いぶき', 'うららか', 'えにし', 'おおとり', 'かがやき', 'きらめき', 'くすのき', 'けやき', 'こだま',
        'さざなみ', 'しおかぜ', 'すずらん', 'せせらぎ', 'たまゆら', 'ちとせ', 'つむぎ', 'ときわ', 'なごみ', 'にじいろ'
    };
    private static final List<String> LEAD_SUFFIXES = new List<String>{ 'テック', '商事', '工業', 'ホールディングス', 'ラボ', '物産' };
    private static final List<String> LEAD_SOURCES = new List<String>{
        'Web', 'Phone Inquiry', 'Partner Referral', 'Purchased List', 'Other', 'web', '展示会', 'セミナー', 'Webサイト'
    };

    // 商品名|ファミリー(SW/HW/SV)
    private static final List<String> PRODUCT_CATALOG = new List<String>{
        'クラウドCRM ベーシック|SW', 'クラウドCRM プロ|SW', 'クラウドCRM エンタープライズ|SW', 'データ連携アダプタ|SW',
        'BIダッシュボード|SW', '電子契約オプション|SW', 'モバイルアプリ ライセンス|SW', 'セキュリティ監査ログ|SW',
        'AIアシスタント アドオン|SW', 'ワークフロー自動化|SW',
        'ハンディターミナル HT-200|HW', 'ラベルプリンタ LP-50|HW', 'IoTゲートウェイ GW-10|HW', 'タブレット端末 TB-8|HW',
        '決済端末 PT-3|HW', 'ネットワークスイッチ NS-24|HW', '監視カメラ CAM-4K|HW', 'サーバラック SR-42|HW',
        'UPS 1500VA|HW', '温湿度センサ TS-1|HW',
        '導入支援パック|SV', 'データ移行サービス|SV', '管理者トレーニング|SV', '年間保守サポート|SV', 'プレミアムサポート|SV',
        'カスタマイズ開発(人日)|SV', 'ヘルスチェック|SV', 'オンサイト研修|SV', '運用代行(月額)|SV', 'セキュリティ診断|SV'
    };
    private static final Map<String, List<String>> FAMILY_VARIANTS = new Map<String, List<String>>{
        'SW' => new List<String>{ 'Software', 'ソフトウェア', 'SW', 'software' },
        'HW' => new List<String>{ 'Hardware', 'ハードウェア', 'HW' },
        'SV' => new List<String>{ 'Service', 'サービス', '役務' }
    };

    // ------------------------------------------------------------------ 実行制御

    /** 1ステップ分を実行し、処理件数を返す。 */
    public static Integer runStep(String step) {
        switch on step {
            when 'products' {
                return createProducts();
            }
            when 'accounts' {
                return createAccounts();
            }
            when 'contacts' {
                return createContacts();
            }
            when 'leads' {
                return createLeads();
            }
            when 'opportunities' {
                return createOpportunities();
            }
            when 'activities' {
                return createActivities();
            }
            when 'baseline' {
                return HO_BaselineService.takeBaseline();
            }
            when else {
                throw new HO_Exception('未知のステップ: ' + step);
            }
        }
    }

    /** ハンズオン用データと変更ログ・ベースラインをすべて削除する。 */
    public static Integer deleteAll() {
        Integer n = 0;
        n += deleteRecords([SELECT Id FROM Task WHERE HO_Workshop_Data__c = TRUE]);
        n += deleteRecords([SELECT Id FROM HO_Change_Log__c]);
        n += deleteRecords([SELECT Id FROM HO_Baseline__c]);
        n += deleteRecords([SELECT Id FROM Opportunity WHERE HO_Workshop_Data__c = TRUE]);
        n += deleteRecords([SELECT Id FROM Contact WHERE HO_Workshop_Data__c = TRUE]);
        n += deleteRecords([SELECT Id FROM Lead WHERE HO_Workshop_Data__c = TRUE AND IsConverted = FALSE]);
        n += deleteRecords([SELECT Id FROM Account WHERE HO_Workshop_Data__c = TRUE]);
        n += deleteRecords([SELECT Id FROM Product2 WHERE HO_Workshop_Data__c = TRUE]);
        return n;
    }

    private static Integer deleteRecords(List<SObject> records) {
        if (!records.isEmpty()) {
            delete records;
        }
        return records.size();
    }

    // ------------------------------------------------------------------ 商品マスタ

    private static Integer createProducts() {
        List<Product2> products = new List<Product2>();
        Map<String, Integer> familyCounter = new Map<String, Integer>();
        for (Integer p = 0; p < PRODUCT_CATALOG.size(); p++) {
            List<String> cols = PRODUCT_CATALOG[p].split('\\|');
            String fam = cols[1];
            Integer seq = familyCounter.containsKey(fam) ? familyCounter.get(fam) + 1 : 1;
            familyCounter.put(fam, seq);
            String code = 'HO-' + fam + '-' + String.valueOf(seq).leftPad(4, '0');
            if (Math.mod(p, 10) == 3) {
                code = code.toLowerCase();
            } else if (Math.mod(p, 10) == 6) {
                code = code.replace('-', '_');
            } else if (Math.mod(p, 10) == 8) {
                code = null;
            } else if (p == 14) {
                code = 'HO-HW-5';
            } else if (p == 27) {
                code = 'PRD-0028';
            }
            List<String> fams = FAMILY_VARIANTS.get(fam);
            String name = cols[0];
            if (p == 4) {
                name = 'BIﾀﾞｯｼｭﾎﾞｰﾄﾞ';
            } else if (p == 12) {
                name = 'ＩｏＴゲートウェイ ＧＷ－１０';
            }
            products.add(buildProduct('HO-PRD-' + String.valueOf(p + 1).leftPad(3, '0'), name, code,
                Math.mod(p, 11) == 4 ? null : fams[Math.mod(p * 5, fams.size())], Math.mod(p, 9) != 7));
        }
        // 重複商品
        products.add(buildProduct('HO-PRD-D01', 'クラウドCRM　プロ', 'HO-SW-0102', 'SW', true));
        products.add(buildProduct('HO-PRD-D02', 'ﾃﾞｰﾀ連携ｱﾀﾞﾌﾟﾀ', null, 'Software', true));
        products.add(buildProduct('HO-PRD-D03', '年間保守サポート ', 'HO-SV-0004', 'サービス', true));
        products.add(buildProduct('HO-PRD-D04', 'ラベルプリンター LP-50', 'HO-HW-0002', 'Hardware', false));
        saveBySeedKey(products);
        return products.size();
    }

    private static Product2 buildProduct(String key, String name, String code, String family, Boolean active) {
        return new Product2(
            HO_Seed_Key__c = key, HO_Workshop_Data__c = true, Name = name, ProductCode = code,
            Family = family, IsActive = active, Description = null
        );
    }

    // ------------------------------------------------------------------ 取引先

    private static Integer createAccounts() {
        List<Account> accounts = new List<Account>();
        Map<String, List<String>> byCode = new Map<String, List<String>>();
        for (Integer i = 0; i < COMPANIES.size(); i++) {
            List<String> c = COMPANIES[i].split('\\|');
            byCode.put(c[0], c);
            String name = NAME_OVERRIDES.containsKey(c[0]) ? NAME_OVERRIDES.get(c[0]) : c[1];
            String pref = c[0] == 'A13' ? '大坂府' : c[3];
            accounts.add(buildAccount('HO-ACC-' + c[0], name, i, c[2], pref, c[4], corporateNumber(i), false));
        }
        for (Integer d = 0; d < DUPLICATES.size(); d++) {
            List<String> dup = DUPLICATES[d].split('\\|');
            List<String> parent = byCode.get(dup[0]);
            Integer parentIndex = Integer.valueOf(dup[0].substring(1)) - 1;
            String corp = dup[3] == 'Y' ? corporateNumber(parentIndex) : dup[3] == 'X' ? corporateNumber(900 + d) : null;
            // 別法人(X)は別の電話番号、それ以外は親と同じ番号を別フォーマットで持つ
            Integer phoneSeed = dup[3] == 'X' ? 900 + d : parentIndex;
            Account a = buildAccount('HO-ACC-' + dup[0] + '-' + dup[1], dup[2], COMPANIES.size() + d, parent[2], parent[3], parent[4], corp, true);
            a.Phone = Math.mod(d, 4) == 2 ? null : formatPhone(parent[4], phoneSeed, Math.mod(parentIndex + d + 1, 5));
            accounts.add(a);
        }
        saveBySeedKey(accounts);
        return accounts.size();
    }

    private static Account buildAccount(String key, String name, Integer i, String industry, String pref, String area, String corp, Boolean isDup) {
        List<String> industries = INDUSTRY_VARIANTS.containsKey(industry) ? INDUSTRY_VARIANTS.get(industry) : new List<String>{ industry };
        String prefValue = pref;
        if (Math.mod(i, 6) == 4) {
            prefValue = null;
        } else if (Math.mod(i, 4) == 1 && pref != '北海道') {
            prefValue = pref.removeEnd('都').removeEnd('府').removeEnd('県');
        } else if (Math.mod(i, 9) == 2 && PREF_ROMAJI.containsKey(pref)) {
            prefValue = PREF_ROMAJI.get(pref);
        }
        return new Account(
            HO_Seed_Key__c = key,
            HO_Workshop_Data__c = true,
            Name = name,
            Industry = Math.mod(i, 7) == 3 ? null : industries[Math.mod(i * 3, industries.size())],
            HO_Prefecture__c = prefValue,
            Phone = Math.mod(i, 8) == 5 ? null : formatPhone(area, i, Math.mod(i, 5)),
            NumberOfEmployees = Math.mod(i, 5) == 2 ? null : Math.mod(i * 137, 5000) + 10,
            HO_Corporate_Number__c = isDup ? corp : (Math.mod(i, 9) == 6 ? null : corp),
            Website = null,
            Description = isDup ? '旧システムから移行' : null
        );
    }

    private static String corporateNumber(Integer i) {
        return '1' + String.valueOf(1000000000000L + i * 98765431L).right(12);
    }

    private static String formatPhone(String area, Integer seed, Integer format) {
        String mid = String.valueOf(1000 + Math.mod(seed * 37 + 11, 9000));
        String last = String.valueOf(1000 + Math.mod(seed * 7919 + 3, 9000));
        if (area.length() == 3) {
            mid = mid.substring(1);
        }
        switch on format {
            when 0 {
                return area + '-' + mid + '-' + last;
            }
            when 1 {
                return area + mid + last;
            }
            when 2 {
                return area + '(' + mid + ')' + last;
            }
            when 3 {
                return '+81-' + area.substring(1) + '-' + mid + '-' + last;
            }
            when else {
                return toFullWidthDigits(area + '-' + mid + '-' + last);
            }
        }
    }

    private static String toFullWidthDigits(String s) {
        List<Integer> out = new List<Integer>();
        for (Integer c : s.getChars()) {
            out.add(c >= 48 && c <= 57 ? c + 65248 : (c == 45 ? 65293 : c));
        }
        return String.fromCharArray(out);
    }

    private static Database.DMLOptions allowDuplicates() {
        Database.DMLOptions opts = new Database.DMLOptions();
        opts.DuplicateRuleHeader.allowSave = true;
        opts.OptAllOrNone = true;
        return opts;
    }

    /**
     * HO_Seed_Key__c をキーに insert / update を振り分けて保存する。
     * upsert 文や SObject.setOptions() では重複ルール（標準のリード重複ルール等）を回避できないため、
     * DMLOptions を直接渡せる Database.insert / update を使う。
     */
    private static void saveBySeedKey(List<SObject> records) {
        if (records.isEmpty()) {
            return;
        }
        Set<String> keys = new Set<String>();
        for (SObject rec : records) {
            keys.add((String) rec.get('HO_Seed_Key__c'));
        }
        Map<String, Id> existing = new Map<String, Id>();
        for (SObject rec : Database.queryWithBinds(
            'SELECT Id, HO_Seed_Key__c FROM ' + records[0].getSObjectType() + ' WHERE HO_Seed_Key__c IN :keys',
            new Map<String, Object>{ 'keys' => keys },
            AccessLevel.SYSTEM_MODE
        )) {
            existing.put((String) rec.get('HO_Seed_Key__c'), rec.Id);
        }
        List<SObject> inserts = new List<SObject>();
        List<SObject> updates = new List<SObject>();
        for (SObject rec : records) {
            Id recordId = existing.get((String) rec.get('HO_Seed_Key__c'));
            if (recordId == null) {
                inserts.add(rec);
            } else {
                rec.Id = recordId;
                updates.add(rec);
            }
        }
        Database.insert(inserts, allowDuplicates());
        Database.update(updates, allowDuplicates());
    }

    // ------------------------------------------------------------------ 取引先責任者

    private static Integer createContacts() {
        List<Contact> contacts = new List<Contact>();
        Integer c = 0;
        for (Integer i = 0; i < COMPANIES.size(); i++) {
            List<String> co = COMPANIES[i].split('\\|');
            for (Integer k = 0; k < 3; k++) {
                contacts.add(buildContact('HO-CON-' + co[0] + '-' + k, 'HO-ACC-' + co[0], Math.mod(i * 3 + k, PEOPLE.size()), co[5], c++));
            }
        }
        for (String row : DUPLICATES) {
            List<String> dup = row.split('\\|');
            Integer parentIndex = Integer.valueOf(dup[0].substring(1)) - 1;
            String domain = COMPANIES[parentIndex].split('\\|')[5];
            // D1 は親取引先の1人目と同一人物（取引先責任者の重複）
            Integer person = dup[1] == 'D1' ? Math.mod(parentIndex * 3, PEOPLE.size()) : Math.mod(parentIndex * 7 + 5, PEOPLE.size());
            contacts.add(buildContact('HO-CON-' + dup[0] + '-' + dup[1], 'HO-ACC-' + dup[0] + '-' + dup[1], person, domain, c++));
        }
        saveBySeedKey(contacts);
        return contacts.size();
    }

    private static Contact buildContact(String key, String accountKey, Integer person, String domain, Integer c) {
        List<String> p = PEOPLE[person].split('\\|');
        String email = p[3] + '.' + p[2] + '@' + domain + '.example.com';
        if (Math.mod(c, 4) == 1) {
            email = null;
        } else if (Math.mod(c, 13) == 5) {
            email = email.replace('example.com', 'exmaple.com');
        } else if (Math.mod(c, 17) == 3) {
            email = email.toUpperCase();
        }
        String title = TITLES[Math.mod(c * 7, TITLES.size())];
        String dept = DEPARTMENTS[Math.mod(c * 5, DEPARTMENTS.size())];
        return new Contact(
            HO_Seed_Key__c = key,
            HO_Workshop_Data__c = true,
            Account = new Account(HO_Seed_Key__c = accountKey),
            LastName = p[0],
            FirstName = p[1],
            Email = email,
            Title = String.isBlank(title) ? null : title,
            Department = String.isBlank(dept) ? null : dept,
            Phone = Math.mod(c, 3) == 2 ? null : formatPhone('090', c, Math.mod(c, 3))
        );
    }

    // ------------------------------------------------------------------ リード

    private static Integer createLeads() {
        List<Lead> leads = new List<Lead>();
        List<String> legalForms = new List<String>{ '株式会社{0}', '{0}株式会社', '(株){0}', '{0}' };
        List<String> industries = new List<String>{ 'Technology', 'Manufacturing', 'Retail', 'Healthcare', 'Finance', 'Construction' };
        for (Integer i = 0; i < 110; i++) {
            String company;
            if (Math.mod(i, 4) == 0) {
                // 既存取引先と同じ会社（表記ゆれ付き）
                company = String.format(legalForms[Math.mod(i, legalForms.size())], new List<String>{ COMPANIES[Math.mod(i * 3, COMPANIES.size())].split('\\|')[1].remove('株式会社') });
            } else {
                String base = LEAD_PREFIXES[Math.mod(i * 7, LEAD_PREFIXES.size())] + LEAD_SUFFIXES[Math.mod(i, LEAD_SUFFIXES.size())];
                company = String.format(legalForms[Math.mod(i * 5, legalForms.size())], new List<String>{ base });
            }
            leads.add(buildLead('HO-LEAD-' + String.valueOf(i + 1).leftPad(3, '0'), company, Math.mod(i * 11, PEOPLE.size()), i, industries));
        }
        // 重複リード（同一人物・会社名表記違い）
        for (Integer j = 0; j < 10; j++) {
            Lead original = leads[j * 9 + 1];
            String dupCompany = original.Company.contains('株式会社')
                ? original.Company.replace('株式会社', '㈱')
                : '株式会社 ' + original.Company.remove('(株)');
            Lead dup = buildLead('HO-LEAD-D' + String.valueOf(j + 1).leftPad(2, '0'), dupCompany,
                Math.mod((j * 9 + 1) * 11, PEOPLE.size()), 200 + j, industries);
            dup.Email = original.Email;
            leads.add(dup);
        }
        saveBySeedKey(leads);
        return leads.size();
    }

    private static Lead buildLead(String key, String company, Integer person, Integer i, List<String> industries) {
        List<String> p = PEOPLE[person].split('\\|');
        String status = Math.mod(i, 10) < 6 ? 'Open - Not Contacted' : (Math.mod(i, 10) < 9 ? 'Working - Contacted' : 'Closed - Not Converted');
        String industry = industries[Math.mod(i * 7, industries.size())];
        List<String> variants = INDUSTRY_VARIANTS.get(industry);
        return new Lead(
            HO_Seed_Key__c = key,
            HO_Workshop_Data__c = true,
            Company = company,
            LastName = p[0],
            FirstName = p[1],
            Email = Math.mod(i, 3) == 2 ? null : p[3] + '.' + p[2] + '@lead' + String.valueOf(Math.mod(i, 50)) + '.example.com',
            Phone = Math.mod(i, 6) == 1 ? null : formatPhone('03', 500 + i, Math.mod(i, 5)),
            LeadSource = Math.mod(i, 5) == 0 ? null : LEAD_SOURCES[Math.mod(i * 7, LEAD_SOURCES.size())],
            Industry = Math.mod(i, 4) == 3 ? null : variants[Math.mod(i, variants.size())],
            Title = TITLES[Math.mod(i * 3, TITLES.size())] == '' ? null : TITLES[Math.mod(i * 3, TITLES.size())],
            NumberOfEmployees = Math.mod(i, 3) == 0 ? null : Math.mod(i * 211, 3000) + 5,
            Status = status
        );
    }

    // ------------------------------------------------------------------ 商談

    private static Integer createOpportunities() {
        HO_Random r = new HO_Random(20260917L);
        Date today = Date.today();
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 260; i++) {
            List<String> rep = REPS[r.nextInt(REPS.size())].split('\\|');
            List<String> deal = DEAL_TYPES[r.nextInt(DEAL_TYPES.size())].split('\\|');
            String accountKey;
            String accountLabel;
            if (r.chance(18)) {
                List<String> dup = DUPLICATES[r.nextInt(DUPLICATES.size())].split('\\|');
                accountKey = 'HO-ACC-' + dup[0] + '-' + dup[1];
                accountLabel = dup[2].trim();
            } else {
                List<String> co = COMPANIES[r.nextInt(COMPANIES.size())].split('\\|');
                accountKey = 'HO-ACC-' + co[0];
                accountLabel = co[1];
            }
            Date closeDate = today.addDays(-365 + r.nextInt(545));
            Decimal amount = (Decimal.valueOf(deal[1]) * Decimal.valueOf(rep[2]) * (50 + r.nextInt(101)) / 100 / 10000).round(System.RoundingMode.HALF_UP) * 10000;
            String stage;
            if (closeDate < today && r.chance(88)) {
                stage = r.chance(Integer.valueOf(rep[1]) + Integer.valueOf(deal[2])) ? 'Closed Won' : 'Closed Lost';
            } else if (closeDate < today) {
                stage = OPEN_STAGES[4 + r.nextInt(4)]; // 完了予定日を過ぎた放置案件
            } else {
                stage = OPEN_STAGES[r.nextInt(OPEN_STAGES.size())];
            }
            Boolean lateStage = stage == 'Proposal/Price Quote' || stage == 'Negotiation/Review' || stage == 'Closed Won';
            Opportunity o = new Opportunity(
                HO_Seed_Key__c = 'HO-OPP-' + String.valueOf(i + 1).leftPad(4, '0'),
                HO_Workshop_Data__c = true,
                Account = new Account(HO_Seed_Key__c = accountKey),
                Name = accountLabel + ' - ' + deal[0],
                StageName = stage,
                CloseDate = closeDate,
                Amount = lateStage && r.chance(stage == 'Closed Won' ? 6 : 25) ? null : amount,
                HO_Sales_Rep__c = rep[0],
                Type = r.pick(new List<String>{ 'New Customer', 'Existing Customer - Upgrade', 'Existing Customer - Replacement' }),
                LeadSource = r.chance(25) ? null : r.pick(new List<String>{ 'Web', 'Phone Inquiry', 'Partner Referral', 'Other' }),
                NextStep = stage.startsWith('Closed') || r.chance(40) ? null : r.pick(new List<String>{ '提案書レビュー', '見積再提示', '決裁者面談', 'PoC日程調整' }),
                HO_Loss_Reason__c = null,
                HO_Loss_Reason_Detail__c = null
            );
            if (stage == 'Closed Lost') {
                String reason = r.chance(50) ? rep[4] : (deal[0] == 'IoT端末導入' || deal[0] == 'AIアシスタント追加') && r.chance(60) ? '機能不足' : r.pick(LOSS_REASONS);
                List<String> details = LOSS_DETAILS.get(reason);
                o.HO_Loss_Reason__c = r.chance(45) ? null : reason;
                String detail = r.chance(80) ? details[r.nextInt(details.size())] : '';
                o.HO_Loss_Reason_Detail__c = String.isBlank(detail) ? null : detail;
            }
            opps.add(o);
        }
        saveBySeedKey(opps);
        return opps.size();
    }

    // ------------------------------------------------------------------ 活動

    private static Integer createActivities() {
        deleteRecords([SELECT Id FROM Task WHERE HO_Workshop_Data__c = TRUE]);
        Map<String, List<String>> repProfiles = new Map<String, List<String>>();
        for (String row : REPS) {
            repProfiles.put(row.split('\\|')[0], row.split('\\|'));
        }
        HO_Random r = new HO_Random(777L);
        Date today = Date.today();
        List<String> subjects = new List<String>{ '電話フォロー', '提案書送付', '訪問商談', 'オンラインデモ', '見積提示', 'ヒアリング' };
        List<Task> tasks = new List<Task>();
        for (Opportunity o : [
            SELECT Id, StageName, CloseDate, HO_Sales_Rep__c
            FROM Opportunity
            WHERE HO_Workshop_Data__c = TRUE AND HO_Seed_Key__c LIKE 'HO-OPP-%'
            ORDER BY HO_Seed_Key__c
        ]) {
            List<String> rep = repProfiles.get(o.HO_Sales_Rep__c);
            Decimal factor = rep == null ? 1 : Decimal.valueOf(rep[3]);
            Integer depth = o.StageName.startsWith('Closed') ? 6 : OPEN_STAGES.indexOf(o.StageName);
            Integer count = Math.min(12, ((depth + 2) * factor * (50 + r.nextInt(100)) / 100).round(System.RoundingMode.HALF_UP).intValue());
            for (Integer k = 0; k < count; k++) {
                Date latest = o.CloseDate < today.addDays(14) ? o.CloseDate : today.addDays(14);
                Date activityDate = latest.addDays(-r.nextInt(90));
                Integer t = r.nextInt(10);
                tasks.add(new Task(
                    WhatId = o.Id,
                    HO_Workshop_Data__c = true,
                    HO_Sales_Rep__c = o.HO_Sales_Rep__c,
                    Subject = subjects[r.nextInt(subjects.size())],
                    Type = t < 5 ? 'Call' : (t < 8 ? 'Email' : 'Meeting'),
                    ActivityDate = activityDate,
                    Status = activityDate <= today ? 'Completed' : 'Not Started',
                    Priority = 'Normal'
                ));
            }
        }
        insert tasks;
        return tasks.size();
    }
}
