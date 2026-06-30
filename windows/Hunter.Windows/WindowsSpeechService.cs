using System.Media;
using System.Runtime.InteropServices;

namespace Hunter.Windows;

public sealed class WindowsSpeechService
{
    public async Task PlayAsync(byte[] audioData)
    {
        var path = Path.Combine(Path.GetTempPath(), $"hunter-tts-{Guid.NewGuid():N}.wav");
        await File.WriteAllBytesAsync(path, audioData);
        try
        {
            using var player = new SoundPlayer(path);
            player.PlaySync();
        }
        finally
        {
            TryDelete(path);
        }
    }

    public async Task<byte[]> RecordWavAsync(TimeSpan duration)
    {
        var path = Path.Combine(Path.GetTempPath(), $"hunter-recording-{Guid.NewGuid():N}.wav");
        Mci("open new Type waveaudio Alias hunterrec");
        Mci("set hunterrec format tag pcm bitspersample 16 samplespersec 16000 channels 1");
        Mci("record hunterrec");
        await Task.Delay(duration);
        Mci($"save hunterrec \"{path}\"");
        Mci("close hunterrec");
        try
        {
            return await File.ReadAllBytesAsync(path);
        }
        finally
        {
            TryDelete(path);
        }
    }

    private static void Mci(string command)
    {
        var error = mciSendString(command, null, 0, IntPtr.Zero);
        if (error != 0)
        {
            throw new InvalidOperationException($"MCI command failed ({error}): {command}");
        }
    }

    private static void TryDelete(string path)
    {
        try
        {
            File.Delete(path);
        }
        catch
        {
        }
    }

    [DllImport("winmm.dll", CharSet = CharSet.Unicode)]
    private static extern int mciSendString(string command, string? returnValue, int returnLength, IntPtr callback);
}
