using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Messages.Data;
using SecretAdmirer.Messages.Services;
using SecretAdmirer.Shared.Contracts;
using SecretAdmirer.Shared.MessageBus;
using SecretAdmirer.Shared.Saga;

namespace SecretAdmirer.Messages.Controllers;

[ApiController]
[Route("messages")]
public sealed class MessageController : ControllerBase
{
    private readonly MessageDbContext _db;
    private readonly HandleResolver _resolver;
    private readonly SendMessageSaga _saga;
    private readonly IMessageBus _bus;
    private readonly IConfiguration _config;
    private readonly ILoggerFactory _loggerFactory;

    public MessageController(
        MessageDbContext db,
        HandleResolver resolver,
        SendMessageSaga saga,
        IMessageBus bus,
        IConfiguration config,
        ILoggerFactory loggerFactory)
    {
        _db = db;
        _resolver = resolver;
        _saga = saga;
        _bus = bus;
        _config = config;
        _loggerFactory = loggerFactory;
    }

    public sealed record SendRequest(
        [Required, RegularExpression("^[a-z0-9_]{3,30}$")] string ReceiverHandle,
        [Required, MinLength(1), MaxLength(500)] string Body);

    public sealed record SendResponse(Guid MessageId, string Status);

    public sealed record InboxItem(Guid Id, string Body, DateTime ReceivedAt, bool Read);
    public sealed record InboxResponse(IReadOnlyList<InboxItem> Items, string? NextCursor, int UnreadCount, int TotalCount);

    [HttpPost("")]
    [AllowAnonymous]
    public async Task<IActionResult> Send([FromBody] SendRequest req, CancellationToken ct)
    {
        var profile = await _resolver.ResolveAsync(req.ReceiverHandle, ct);
        if (profile is null)
            return NotFound(new { error = new { code = "profile.not_found", message = "No one to deliver to." } });
        if (!profile.AllowReplies)
            return StatusCode(403, new { error = new { code = "profile.replies_off", message = "This person isn't accepting messages right now." } });

        var ctx = new SendMessageContext
        {
            ReceiverId = profile.UserId,
            ReceiverHandle = profile.Handle,
            Body = req.Body.Trim(),
            SenderIp = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0",
            DailyQuota = _config.GetValue<int?>("Messaging:DailyQuotaPerReceiver") ?? 20
        };

        var runner = new SagaRunner<SendMessageContext>(_loggerFactory.CreateLogger<SagaRunner<SendMessageContext>>());
        var result = await runner.RunAsync(_saga, ctx, ct);

        return result.Outcome switch
        {
            SagaOutcome.Completed => Accepted(new SendResponse(ctx.MessageId!.Value, "sent")),
            SagaOutcome.Compensated when result.Error == "message.rate_limit"
                => StatusCode(429, new { error = new { code = "message.rate_limit", message = "You've sent enough today — try again tomorrow." } }),
            SagaOutcome.Compensated
                => StatusCode(503, new { error = new { code = "saga.compensated", message = result.Error ?? "Send was rolled back.", retryable = true } }),
            _ => StatusCode(500, new { error = new { code = "saga.failed", message = result.Error } })
        };
    }

    [HttpGet("inbox")]
    [Authorize]
    public async Task<IActionResult> Inbox([FromQuery] string? cursor, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        limit = Math.Clamp(limit, 1, 50);

        DateTime cursorTs = DateTime.MaxValue;
        if (cursor is not null && DateTime.TryParse(cursor, null, System.Globalization.DateTimeStyles.RoundtripKind, out var parsed))
            cursorTs = parsed;

        var page = await _db.Messages
            .Where(m => m.ReceiverId == userId && m.DeletedAt == null && m.ReceivedAt < cursorTs)
            .OrderByDescending(m => m.ReceivedAt)
            .Take(limit + 1)
            .ToListAsync(ct);

        string? nextCursor = null;
        if (page.Count > limit)
        {
            nextCursor = page[^1].ReceivedAt.ToString("o");
            page = page.Take(limit).ToList();
        }

        var counter = await _db.InboxCounters.FindAsync(new object[] { userId.Value }, ct);
        var items = page.Select(m => new InboxItem(m.Id, m.Body, m.ReceivedAt, m.ReadAt is not null)).ToList();
        return Ok(new InboxResponse(items, nextCursor, counter?.UnreadCount ?? 0, counter?.TotalCount ?? 0));
    }

    [HttpGet("{id:guid}")]
    [Authorize]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var m = await _db.Messages.FirstOrDefaultAsync(x => x.Id == id && x.ReceiverId == userId && x.DeletedAt == null, ct);
        if (m is null) return NotFound();

        if (m.ReadAt is null)
        {
            m.ReadAt = DateTime.UtcNow;
            var counter = await _db.InboxCounters.FindAsync(new object[] { userId.Value }, ct);
            if (counter is not null && counter.UnreadCount > 0)
            {
                counter.UnreadCount--;
                counter.UpdatedAt = DateTime.UtcNow;
            }
            await _db.SaveChangesAsync(ct);
            await _bus.PublishAsync(new MessageRead(m.Id, m.ReceiverId, m.ReadAt.Value), ct);
        }

        return Ok(new InboxItem(m.Id, m.Body, m.ReceivedAt, true));
    }

    [HttpDelete("{id:guid}")]
    [Authorize]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        var userId = CurrentUserId();
        if (userId is null) return Unauthorized();
        var m = await _db.Messages.FirstOrDefaultAsync(x => x.Id == id && x.ReceiverId == userId && x.DeletedAt == null, ct);
        if (m is null) return NotFound();
        m.DeletedAt = DateTime.UtcNow;
        var counter = await _db.InboxCounters.FindAsync(new object[] { userId.Value }, ct);
        if (counter is not null)
        {
            counter.TotalCount = Math.Max(0, counter.TotalCount - 1);
            if (m.ReadAt is null && counter.UnreadCount > 0) counter.UnreadCount--;
        }
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
