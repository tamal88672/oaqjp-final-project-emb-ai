using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Profile.Data;
using SecretAdmirer.Shared.Contracts;
using SecretAdmirer.Shared.MessageBus;

namespace SecretAdmirer.Profile.Controllers;

[ApiController]
[Route("profile")]
public sealed class ProfileController : ControllerBase
{
    private readonly ProfileDbContext _db;
    private readonly IMessageBus _bus;
    private readonly IConfiguration _config;

    public ProfileController(ProfileDbContext db, IMessageBus bus, IConfiguration config)
    {
        _db = db;
        _bus = bus;
        _config = config;
    }

    public sealed record ProfileDto(
        Guid UserId, string Handle, string? DisplayName, string? Bio,
        string? AvatarUrl, string Theme, bool AllowReplies);

    public sealed record PublicProfileDto(string Handle, string? DisplayName, string? Bio, string? AvatarUrl, bool AllowReplies);

    public sealed record PatchProfileRequest(
        [MaxLength(80)] string? DisplayName,
        [MaxLength(280)] string? Bio,
        [MaxLength(512)] string? AvatarUrl,
        [RegularExpression("^(velvet|midnight|rose|champagne)$")] string? Theme,
        bool? AllowReplies);

    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> Me(CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var p = await _db.Profiles.FindAsync(new object[] { userId.Value }, ct);
        if (p is null) return NotFound(new { error = new { code = "profile.not_found", message = "Profile not provisioned." } });
        return Ok(new ProfileDto(p.UserId, p.Handle, p.DisplayName, p.Bio, p.AvatarUrl, p.Theme, p.AllowReplies));
    }

    [HttpGet("/internal/profile/by-handle/{handle}")]
    public async Task<IActionResult> InternalByHandle(string handle, CancellationToken ct)
    {
        // Service-to-service: includes the user id. Should be reachable only on
        // the internal cluster network in production; for local dev it's open.
        var normalized = handle.Trim().ToLowerInvariant();
        var p = await _db.Profiles.FirstOrDefaultAsync(x => x.Handle == normalized, ct);
        if (p is null) return NotFound();
        return Ok(new { userId = p.UserId, handle = p.Handle, allowReplies = p.AllowReplies });
    }

    [HttpGet("by-handle/{handle}")]
    public async Task<IActionResult> ByHandle(string handle, CancellationToken ct)
    {
        var normalized = handle.Trim().ToLowerInvariant();
        var p = await _db.Profiles.FirstOrDefaultAsync(x => x.Handle == normalized, ct);
        if (p is null) return NotFound(new { error = new { code = "profile.not_found", message = "No profile by that handle." } });
        return Ok(new PublicProfileDto(p.Handle, p.DisplayName, p.Bio, p.AvatarUrl, p.AllowReplies));
    }

    [HttpPatch("")]
    [Authorize]
    public async Task<IActionResult> Patch([FromBody] PatchProfileRequest req, CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var p = await _db.Profiles.FindAsync(new object[] { userId.Value }, ct);
        if (p is null) return NotFound();

        if (req.DisplayName is not null) p.DisplayName = req.DisplayName.Trim();
        if (req.Bio is not null) p.Bio = req.Bio.Trim();
        if (req.AvatarUrl is not null) p.AvatarUrl = req.AvatarUrl.Trim();
        if (req.Theme is not null) p.Theme = req.Theme;
        if (req.AllowReplies is not null) p.AllowReplies = req.AllowReplies.Value;
        p.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync(ct);
        await _bus.PublishAsync(new ProfileUpdated(p.UserId, p.Handle, p.DisplayName, p.Bio, p.AvatarUrl, p.Theme), ct);

        return Ok(new ProfileDto(p.UserId, p.Handle, p.DisplayName, p.Bio, p.AvatarUrl, p.Theme, p.AllowReplies));
    }

    [HttpPut("avatar")]
    [Authorize]
    public async Task<IActionResult> UploadAvatar(IFormFile avatar, CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();

        if (avatar is null || avatar.Length == 0)
            return BadRequest(new { error = new { code = "avatar.empty", message = "No file uploaded." } });
        if (avatar.Length > 5 * 1024 * 1024)
            return BadRequest(new { error = new { code = "avatar.too_large", message = "Avatar must be under 5MB." } });
        if (!avatar.ContentType.StartsWith("image/"))
            return BadRequest(new { error = new { code = "avatar.bad_type", message = "Only images are allowed." } });

        var p = await _db.Profiles.FindAsync(new object[] { userId.Value }, ct);
        if (p is null) return NotFound();

        // In production this would upload to S3/Azure Blob and return a CDN URL.
        // For now we persist to a local /uploads directory served statically.
        var uploadsDir = Path.Combine(_config["Uploads:Path"] ?? "./uploads");
        Directory.CreateDirectory(uploadsDir);
        var ext = Path.GetExtension(avatar.FileName);
        var fileName = $"{userId}-{DateTime.UtcNow:yyyyMMddHHmmss}{ext}";
        var fullPath = Path.Combine(uploadsDir, fileName);
        await using (var stream = System.IO.File.Create(fullPath))
        {
            await avatar.CopyToAsync(stream, ct);
        }

        var publicUrl = $"{_config["Uploads:PublicBase"] ?? "/uploads"}/{fileName}";
        p.AvatarUrl = publicUrl;
        p.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        await _bus.PublishAsync(new ProfileUpdated(p.UserId, p.Handle, p.DisplayName, p.Bio, p.AvatarUrl, p.Theme), ct);

        return Ok(new { avatarUrl = publicUrl });
    }

    [HttpGet("link")]
    [Authorize]
    public async Task<IActionResult> ShareLink(CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var p = await _db.Profiles.FindAsync(new object[] { userId.Value }, ct);
        if (p is null) return NotFound();
        var baseUrl = _config["PublicBaseUrl"] ?? "http://localhost:5173";
        return Ok(new { url = $"{baseUrl}/u/{p.Handle}" });
    }

    private Guid? CurrentUserId()
    {
        // Trust the gateway's header in service-to-service calls, but also accept
        // the raw JWT sub for direct dev calls.
        if (Request.Headers.TryGetValue("X-User-Id", out var headerId) && Guid.TryParse(headerId, out var fromHeader))
            return fromHeader;
        var sub = User.FindFirst("sub")?.Value ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(sub, out var id) ? id : null;
    }
}
