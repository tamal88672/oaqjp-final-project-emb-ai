namespace SecretAdmirer.Notifications.Models;

public class Notification
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string Type { get; set; } = string.Empty; // e.g. "message.received"
    public Guid? MessageId { get; set; }              // always points at a real row when set
    public string Title { get; set; } = string.Empty;
    public string? Body { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReadAt { get; set; }
    public DateTime? WithdrawnAt { get; set; }        // set when a saga compensates
}

public class DeviceToken
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public string Platform { get; set; } = string.Empty; // "apns" | "webpush"
    public string Token { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? RevokedAt { get; set; }
}
