namespace SecretAdmirer.Profile.Models;

public class Profile
{
    public Guid UserId { get; set; }
    public string Handle { get; set; } = string.Empty;
    public string? DisplayName { get; set; }
    public string? Bio { get; set; }
    public string? AvatarUrl { get; set; }
    public string Theme { get; set; } = "velvet";
    public bool AllowReplies { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
