using System.Text.RegularExpressions;

namespace Hunter.Windows.Core;

public sealed class DurationParser
{
    private static readonly Dictionary<char, int> ChineseDigits = new()
    {
        ['零'] = 0, ['〇'] = 0, ['一'] = 1, ['二'] = 2, ['两'] = 2, ['俩'] = 2,
        ['三'] = 3, ['四'] = 4, ['五'] = 5, ['六'] = 6, ['七'] = 7, ['八'] = 8, ['九'] = 9
    };

    public TimeSpan? Parse(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return null;
        }

        var normalized = text.Trim().ToLowerInvariant();
        if (normalized.Contains("半小时") || normalized.Contains("半个小时"))
        {
            return TimeSpan.FromMinutes(30);
        }

        var oneAndHalfHour = Regex.Match(normalized, @"(一个半|1\.5|one and a half)\s*(小时|hour|hours|h)");
        if (oneAndHalfHour.Success)
        {
            return TimeSpan.FromMinutes(90);
        }

        var englishHour = Regex.Match(normalized, @"(?<n>\d+(?:\.\d+)?)\s*(hour|hours|hr|hrs|h)\b");
        if (englishHour.Success && double.TryParse(englishHour.Groups["n"].Value, out var hours))
        {
            return TimeSpan.FromMinutes(Math.Clamp(hours * 60, 1, 24 * 60));
        }

        var englishMinute = Regex.Match(normalized, @"(?<n>\d+)\s*(minute|minutes|min|mins|m)\b");
        if (englishMinute.Success && int.TryParse(englishMinute.Groups["n"].Value, out var minutes))
        {
            return TimeSpan.FromMinutes(Math.Clamp(minutes, 1, 24 * 60));
        }

        var arabicChineseMinute = Regex.Match(normalized, @"(?<n>\d+)\s*分钟");
        if (arabicChineseMinute.Success && int.TryParse(arabicChineseMinute.Groups["n"].Value, out minutes))
        {
            return TimeSpan.FromMinutes(Math.Clamp(minutes, 1, 24 * 60));
        }

        var chineseHour = Regex.Match(normalized, @"(?<n>[零〇一二两俩三四五六七八九十百]+)\s*(个)?小时");
        if (chineseHour.Success)
        {
            var value = ParseChineseNumber(chineseHour.Groups["n"].Value);
            if (value > 0)
            {
                return TimeSpan.FromMinutes(Math.Clamp(value * 60, 1, 24 * 60));
            }
        }

        var chineseMinute = Regex.Match(normalized, @"(?<n>[零〇一二两俩三四五六七八九十百]+)\s*分钟");
        if (chineseMinute.Success)
        {
            var value = ParseChineseNumber(chineseMinute.Groups["n"].Value);
            if (value > 0)
            {
                return TimeSpan.FromMinutes(Math.Clamp(value, 1, 24 * 60));
            }
        }

        return null;
    }

    private static int ParseChineseNumber(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return 0;
        }

        if (value == "十")
        {
            return 10;
        }

        var total = 0;
        var section = 0;
        foreach (var ch in value)
        {
            if (ch == '百')
            {
                section = Math.Max(section, 1) * 100;
                total += section;
                section = 0;
                continue;
            }

            if (ch == '十')
            {
                section = Math.Max(section, 1) * 10;
                total += section;
                section = 0;
                continue;
            }

            if (ChineseDigits.TryGetValue(ch, out var digit))
            {
                section = digit;
            }
        }

        return total + section;
    }
}
