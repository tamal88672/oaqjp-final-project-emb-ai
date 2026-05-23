using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Auth.Data;
using SecretAdmirer.Auth.Models;
using SecretAdmirer.Auth.Services;
using SecretAdmirer.Shared.Contracts;
using SecretAdmirer.Shared.MessageBus;
using SecretAdmirer.Shared.Security;

namespace SecretAdmirer.Auth.Controllers;

[ApiController]
[Route("auth")]
public sealed class AuthController : ControllerBase
{
    private readonly AuthDbContext _db;
    private readonly JwtTokenService _tokens;
    private readonly IMessageBus _bus;
    private readonly ILogger<AuthController> _log;

    public AuthController(AuthDbContext db, JwtTokenService tokens, IMessageBus bus, ILogger<AuthController> log)
    {
        _db = db;
        _tokens = tokens;
        _bus = bus;
        _log = log;
    }

    public sealed record RegisterRequest(
        [Required, RegularExpression("^[a-z0-9_]{3,30}$")] string Handle,
        [Required, EmailAddress] string Email,
        [Required, MinLength(8), MaxLength(128)] string Password);

    public sealed record LoginRequest([Required] string Identifier, [Required] string Password);

    public sealed record RefreshRequest([Required] string RefreshToken);

    public sealed record TokenResponse(string AccessToken, string RefreshToken, int ExpiresIn, Guid UserId, string Handle);

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest req, CancellationToken ct)
    {
        var normalizedHandle = req.Handle.Trim().ToLowerInvariant();
        var normalizedEmail = req.Email.Trim().ToLowerInvariant();

        if (await _db.Users.AnyAsync(u => u.Handle == normalizedHandle, ct))
            return Conflict(new { error = new { code = "auth.handle_taken", message = "That handle is already taken." } });
        if (await _db.Users.AnyAsync(u => u.Email == normalizedEmail, ct))
            return Conflict(new { error = new { code = "auth.email_taken", message = "An account already exists for that email." } });

        var (hash, salt) = PasswordHasher.Hash(req.Password);
        var user = new User
        {
            Handle = normalizedHandle,
            Email = normalizedEmail,
            PasswordHash = hash,
            PasswordSalt = salt
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync(ct);

        await _bus.PublishAsync(new UserRegistered(user.Id, user.Handle, user.Email), ct);

        var issued = _tokens.Issue(user);
        await StoreRefreshAsync(user.Id, issued.RefreshToken, ct);

        _log.LogInformation("Registered user {UserId} ({Handle})", user.Id, user.Handle);
        return CreatedAtAction(nameof(Me), null,
            new TokenResponse(issued.AccessToken, issued.RefreshToken, issued.ExpiresIn, user.Id, user.Handle));
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest req, CancellationToken ct)
    {
        var ident = req.Identifier.Trim().ToLowerInvariant();
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Handle == ident || u.Email == ident, ct);
        if (user is null || !PasswordHasher.Verify(req.Password, user.PasswordHash, user.PasswordSalt))
        {
            return Unauthorized(new { error = new { code = "auth.invalid", message = "Invalid credentials." } });
        }
        if (user.Status != "active")
        {
            return StatusCode(403, new { error = new { code = "auth.inactive", message = "Account is not active." } });
        }

        user.LastLoginAt = DateTime.UtcNow;
        var issued = _tokens.Issue(user);
        await StoreRefreshAsync(user.Id, issued.RefreshToken, ct);
        await _db.SaveChangesAsync(ct);

        return Ok(new TokenResponse(issued.AccessToken, issued.RefreshToken, issued.ExpiresIn, user.Id, user.Handle));
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshRequest req, CancellationToken ct)
    {
        var hash = TokenHasher.Hash(req.RefreshToken);
        var stored = await _db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (stored is null || !stored.IsActive)
            return Unauthorized(new { error = new { code = "auth.invalid", message = "Refresh token invalid or expired." } });

        var user = await _db.Users.FindAsync(new object[] { stored.UserId }, ct);
        if (user is null)
            return Unauthorized(new { error = new { code = "auth.invalid", message = "User no longer exists." } });

        // Rotate: revoke old, issue new pair.
        stored.RevokedAt = DateTime.UtcNow;
        var issued = _tokens.Issue(user);
        await StoreRefreshAsync(user.Id, issued.RefreshToken, ct);
        await _db.SaveChangesAsync(ct);

        return Ok(new TokenResponse(issued.AccessToken, issued.RefreshToken, issued.ExpiresIn, user.Id, user.Handle));
    }

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout([FromBody] RefreshRequest req, CancellationToken ct)
    {
        var hash = TokenHasher.Hash(req.RefreshToken);
        var stored = await _db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (stored is not null && stored.RevokedAt is null)
        {
            stored.RevokedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
        }
        return NoContent();
    }

    [HttpGet("sessions")]
    [Authorize]
    public async Task<IActionResult> Sessions(CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var sessions = await _db.RefreshTokens
            .Where(t => t.UserId == userId && t.RevokedAt == null && t.ExpiresAt > DateTime.UtcNow)
            .OrderByDescending(t => t.LastUsedAt ?? t.IssuedAt)
            .Select(t => new {
                id = t.Id,
                device = t.DeviceLabel ?? "Unknown device",
                ip = t.IpAddress,
                lastSeen = t.LastUsedAt ?? t.IssuedAt,
                issuedAt = t.IssuedAt
            })
            .ToListAsync(ct);
        return Ok(sessions);
    }

    [HttpDelete("sessions/{id:guid}")]
    [Authorize]
    public async Task<IActionResult> RevokeSession(Guid id, CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var session = await _db.RefreshTokens.FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId, ct);
        if (session is null) return NotFound();
        session.RevokedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> Me(CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var user = await _db.Users.FindAsync(new object[] { userId.Value }, ct);
        if (user is null) return NotFound();
        return Ok(new { id = user.Id, handle = user.Handle, email = user.Email });
    }

    private Guid? CurrentUserId()
    {
        var sub = User.FindFirst("sub")?.Value ?? User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        return Guid.TryParse(sub, out var id) ? id : null;
    }

    private async Task StoreRefreshAsync(Guid userId, string refreshToken, CancellationToken ct)
    {
        _db.RefreshTokens.Add(new RefreshToken
        {
            UserId = userId,
            TokenHash = TokenHasher.Hash(refreshToken),
            ExpiresAt = _tokens.RefreshExpiry(),
            DeviceLabel = Request.Headers.UserAgent.ToString().Length > 100
                ? Request.Headers.UserAgent.ToString()[..100]
                : Request.Headers.UserAgent.ToString(),
            UserAgent = Request.Headers.UserAgent.ToString(),
            IpAddress = HttpContext.Connection.RemoteIpAddress?.ToString()
        });
        await _db.SaveChangesAsync(ct);
    }
}
