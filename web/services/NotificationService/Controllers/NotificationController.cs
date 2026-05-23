using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Notifications.Data;
using SecretAdmirer.Notifications.Models;

namespace SecretAdmirer.Notifications.Controllers;

[ApiController]
[Route("notifications")]
[Authorize]
public sealed class NotificationController : ControllerBase
{
    private readonly NotificationDbContext _db;

    public NotificationController(NotificationDbContext db) => _db = db;

    [HttpGet("")]
    public async Task<IActionResult> List([FromQuery] bool unreadOnly = false, CancellationToken ct = default)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var q = _db.Notifications.AsQueryable().Where(n => n.UserId == userId && n.WithdrawnAt == null);
        if (unreadOnly) q = q.Where(n => n.ReadAt == null);
        var items = await q.OrderByDescending(n => n.CreatedAt).Take(100).ToListAsync(ct);
        return Ok(items);
    }

    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var n = await _db.Notifications.FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
        if (n is null) return NotFound();
        if (n.ReadAt is null)
        {
            n.ReadAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
        }
        return NoContent();
    }

    public sealed record DeviceRegistration(
        [Required, RegularExpression("^(apns|webpush)$")] string Platform,
        [Required, MaxLength(512)] string Token);

    [HttpPost("devices")]
    public async Task<IActionResult> RegisterDevice([FromBody] DeviceRegistration req, CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();

        var existing = await _db.DeviceTokens
            .FirstOrDefaultAsync(t => t.UserId == userId && t.Token == req.Token, ct);
        if (existing is not null)
        {
            existing.RevokedAt = null;
            await _db.SaveChangesAsync(ct);
            return Ok(new { id = existing.Id });
        }
        var token = new DeviceToken { UserId = userId.Value, Platform = req.Platform, Token = req.Token };
        _db.DeviceTokens.Add(token);
        await _db.SaveChangesAsync(ct);
        return Ok(new { id = token.Id });
    }

    [HttpDelete("devices/{id:guid}")]
    public async Task<IActionResult> RevokeDevice(Guid id, CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var t = await _db.DeviceTokens.FirstOrDefaultAsync(x => x.Id == id && x.UserId == userId, ct);
        if (t is null) return NotFound();
        t.RevokedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        return NoContent();
    }

    private Guid? CurrentUserId()
    {
        if (Request.Headers.TryGetValue("X-User-Id", out var headerId) && Guid.TryParse(headerId, out var fromHeader))
            return fromHeader;
        var sub = User.FindFirst("sub")?.Value ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(sub, out var id) ? id : null;
    }
}
