/**
 * 日本語の表記ゆれ（全角/半角・カナ・法人格表記）を扱うユーティリティ。
 */
public inherited sharing class HO_Text {
    private static final String HALF_KANA = 'ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ･｢｣､｡';
    private static final String FULL_KANA = 'ヲァィゥェォャュョッーアイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワン・「」、。';
    private static final String VOICEABLE = 'カキクケコサシスセソタチツテトハヒフヘホウ';
    private static final String SEMI_VOICEABLE = 'ハヒフヘホ';
    private static final String IDEOGRAPHIC_SPACE = String.fromCharArray(new List<Integer>{ 12288 });
    private static final Integer DAKUTEN = 65438;      // ﾞ U+FF9E
    private static final Integer HANDAKUTEN = 65439;   // ﾟ U+FF9F
    private static final List<String> LEGAL_ABBR = new List<String>{ '(株)', '㈱', '(有)', '㈲', '(同)' };
    private static final Map<String, String> LEGAL_ABBR_FULL = new Map<String, String>{
        '(株)' => '株式会社', '㈱' => '株式会社', '(有)' => '有限会社', '㈲' => '有限会社', '(同)' => '合同会社'
    };
    private static final List<String> LEGAL_FORMS = new List<String>{ '株式会社', '有限会社', '合同会社' };

    /** 全角英数字・記号・全角スペースを半角に変換する。 */
    public static String toHalfWidthAscii(String s) {
        if (s == null) {
            return null;
        }
        List<Integer> out = new List<Integer>();
        for (Integer c : s.getChars()) {
            if (c >= 65281 && c <= 65374) {
                out.add(c - 65248);
            } else if (c == 12288) {
                out.add(32);
            } else {
                out.add(c);
            }
        }
        return String.fromCharArray(out);
    }

    /** 半角カナを全角カナに変換する（濁点・半濁点の結合を含む）。 */
    public static String toFullWidthKana(String s) {
        if (s == null) {
            return null;
        }
        List<Integer> out = new List<Integer>();
        for (Integer c : s.getChars()) {
            String ch = String.fromCharArray(new List<Integer>{ c });
            Integer idx = HALF_KANA.indexOf(ch);
            if (idx >= 0) {
                out.add(FULL_KANA.getChars()[idx]);
            } else if ((c == DAKUTEN || c == HANDAKUTEN) && !out.isEmpty()) {
                String prev = String.fromCharArray(new List<Integer>{ out[out.size() - 1] });
                if (c == DAKUTEN && VOICEABLE.contains(prev)) {
                    out[out.size() - 1] = prev == 'ウ' ? 12532 : out[out.size() - 1] + 1;
                } else if (c == HANDAKUTEN && SEMI_VOICEABLE.contains(prev)) {
                    out[out.size() - 1] = out[out.size() - 1] + 2;
                } else {
                    out.add(c == DAKUTEN ? 12443 : 12444);
                }
            } else {
                out.add(c);
            }
        }
        return String.fromCharArray(out);
    }

    /** カタカナをひらがなに寄せる（比較用）。 */
    public static String katakanaToHiragana(String s) {
        if (s == null) {
            return null;
        }
        List<Integer> out = new List<Integer>();
        for (Integer c : s.getChars()) {
            out.add(c >= 12449 && c <= 12534 ? c - 96 : c);
        }
        return String.fromCharArray(out);
    }

    /** 重複判定用のキー。法人格・空白・記号・全半角・カナ種別の違いを吸収する。 */
    public static String companyMatchKey(String name) {
        if (String.isBlank(name)) {
            return '';
        }
        String s = toHalfWidthAscii(toFullWidthKana(name));
        for (String abbr : LEGAL_ABBR) {
            s = s.replace(abbr, '');
        }
        for (String form : LEGAL_FORMS) {
            s = s.replace(form, '');
        }
        s = s.replaceAll('[\\s・\\.\\-_]', '');
        return katakanaToHiragana(s).toLowerCase();
    }

    /** 取引先名の命名規則違反を列挙する。 */
    public static List<String> companyNameViolations(String name) {
        List<String> v = new List<String>();
        if (String.isBlank(name)) {
            v.add('名称が空');
            return v;
        }
        String ascii = toHalfWidthAscii(name);
        for (String abbr : LEGAL_ABBR) {
            if (ascii.contains(abbr)) {
                v.add('法人格の略称(' + abbr + ')');
                break;
            }
        }
        if (Pattern.matches('.*[\\uFF61-\\uFF9F].*', name)) {
            v.add('半角カナ');
        }
        if (Pattern.matches('.*[\\uFF10-\\uFF19\\uFF21-\\uFF3A\\uFF41-\\uFF5A\\uFF08\\uFF09].*', name)) {
            v.add('全角英数字・括弧');
        }
        if (name != name.trim() || name.contains(IDEOGRAPHIC_SPACE)) {
            v.add('不要な空白');
        }
        Boolean hasForm = false;
        for (String form : LEGAL_FORMS) {
            hasForm = hasForm || ascii.contains(form);
        }
        for (String abbr : LEGAL_ABBR) {
            hasForm = hasForm || ascii.contains(abbr);
        }
        if (!hasForm) {
            v.add('法人格なし');
        }
        return v;
    }

    /** 命名規則に沿った名称の候補（あくまで提案。採否は人が判断する）。 */
    public static String suggestCompanyName(String name) {
        if (name == null) {
            return null;
        }
        String s = toHalfWidthAscii(toFullWidthKana(name)).trim();
        for (String abbr : LEGAL_ABBR) {
            s = s.replace(abbr, LEGAL_ABBR_FULL.get(abbr));
        }
        for (String form : LEGAL_FORMS) {
            s = s.replaceAll('\\s*' + form + '\\s*', form);
        }
        return s.replaceAll('\\s{2,}', ' ').trim();
    }
}
