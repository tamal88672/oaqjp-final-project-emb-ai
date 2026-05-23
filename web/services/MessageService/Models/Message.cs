namespace SecretAdmirer.Messages.Models;

public class Message
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid ReceiverId { get; set; }
    public string Body { get; set; } = string.Empty;
    public string SenderFingerprint { get; set; } = string.Empty;
    public DateTime ReceivedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReadAt { get; set; }
    public DateTime? DeletedAt { get; set; }
}

public class InboxCounter
{
    public Guid UserId { get; set; }
    public int UnreadCount { get; set; }
    public int TotalCount { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class SendQuota
{
    public string Fingerprint { get; set; } = string.Empty;
    public DateOnly DayBucket { get; set; }
    public int Count { get; set; } = 1;
}
