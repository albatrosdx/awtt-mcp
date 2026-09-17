/**
 * 再現性のある疑似乱数（LCG）。参加者全員の組織に同一のテストデータを作るために使用する。
 */
public inherited sharing class HO_Random {
    private Long state;

    public HO_Random(Long seed) {
        state = seed;
    }

    public Integer nextInt(Integer bound) {
        state = Math.mod(state * 1103515245L + 12345L, 2147483648L);
        return (Integer) Math.mod(state / 65536L, (Long) bound);
    }

    public Boolean chance(Integer percent) {
        return nextInt(100) < percent;
    }

    public String pick(List<String> values) {
        return values[nextInt(values.size())];
    }
}
