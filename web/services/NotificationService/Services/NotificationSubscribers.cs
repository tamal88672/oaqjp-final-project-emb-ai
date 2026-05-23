using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Notifications.Data;
using SecretAdmirer.Notifications.Models;
using SecretAdmirer.Shared.Contracts;
using SecretAdmirer.Shared.MessageBus;

namespace SecretAdmirer.Notifications.Services;

/// <summary>
/// Subscribes to integration events and writes real, grounded notification
/// rows. There is no scheduler that fabricates "you have a new message"
/// notifications — every row here came from a corresponding
/// <c>MessageReceived</c> event, which itself came from a saga that wrote a
/// real <c>messages</c> row.
/// </summary>
public sealed class NotificationSubscribers : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly IMessageBus _bus;
    private readonly IPushSender _push;
    private readonly ILogger<NotificationSubscribers> _log;
    private readonly List<IDisposable> _subs = new();

    public NotificationSubscribers(
        IServiceProvider services,
        IMessageBus bus,
        IPushSender push,
        ILogger<NotificationSubscribers> log)
    {
        _services = services;
        _bus = bus;
        _push = push;
        _log = log;
    }

    protected override Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _subs.Add(_bus.Subscribe<UserRegistered>(OnUserRegistered));
        _subs.Add(_bus.Subscribe<MessageReceived>(OnMessageReceived));
        _subs.Add(_bus.Subscribe<MessageRead>(OnMessageRead));
        _log.LogInformation("NotificationSubscribers attached: UserRegistered, MessageReceived, MessageRead");
        return Task.CompletedTask;
    }

    private async Task OnUserRegistered(UserRegistered evt, CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<NotificationDbContext>();
        db.Notifications.Add(new Notification
        {
            UserId = evt.UserId,
            Type = "account.welcome",
            Title = "Welcome to Secret Admirer",
            Body = $"Share your link to start receiving notes, @{evt.Handle}.",
            MessageId = null
        });
        await db.SaveChangesAsync(ct);
    }

    private async Task OnMessageReceived(MessageReceived evt, CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<NotificationDbContext>();

        // Dedupe by messageId — bus is at-least-once.
        if (await db.Notifications.AnyAsync(n => n.MessageId == evt.MessageId, ct))
        {
            _log.LogDebug("Duplicate MessageReceived for {MessageId}, skipping", evt.MessageId);
            return;
        }

        var notification = new Notification
        {
            UserId = evt.ReceiverId,
            Type = "message.received",
            MessageId = evt.MessageId,
            Title = "A secret admirer wrote you",
            Body = evt.BodyPreview,
        };
        db.Notifications.Add(notification);
        await db.SaveChangesAsync(ct);

        // Real push — never synthetic.
        var tokens = await db.DeviceTokens
            .Where(t => t.UserId == evt.ReceiverId && t.RevokedAt == null)
            .ToListAsync(ct);
        foreach (var t in tokens)
        {
            await _push.SendAsync(t, notification, ct);
        }
    }

    private async Task OnMessageRead(MessageRead evt, CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<NotificationDbContext>();
        var notif = await db.Notifications.FirstOrDefaultAsync(n => n.MessageId == evt.MessageId && n.ReadAt == null, ct);
        if (notif is null) return;
        notif.ReadAt = evt.ReadAt;
        await db.SaveChangesAsync(ct);
    }

    public override void Dispose()
    {
        foreach (var s in _subs) s.Dispose();
        base.Dispose();
    }
}
