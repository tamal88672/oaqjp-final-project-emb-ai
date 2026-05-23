using System.Security.Cryptography;
using System.Text;

namespace SecretAdmirer.Shared.Security;

/// <summary>
/// SHA-256 one-way hash used for storing refresh tokens and sender
/// fingerprints. We never need to recover the original value — only to
/// compare an incoming candidate against the stored digest.
/// </summary>
public static class TokenHasher
{
    public static string Hash(string value)
    {
        ArgumentException.ThrowIfNullOrEmpty(value);
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(value));
        return Convert.ToHexString(bytes);
    }

    public static string FingerprintSender(string senderIp, Guid receiverId, DateOnly day)
    {
        // Salt with the receiver to prevent cross-receiver linkage of admirers.
        var input = $"{senderIp}|{receiverId:N}|{day:yyyy-MM-dd}";
        return Hash(input);
    }
}
