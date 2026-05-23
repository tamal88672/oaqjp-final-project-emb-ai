using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Messages.Data;
using SecretAdmirer.Messages.Models;
using SecretAdmirer.Shared.Contracts;
using SecretAdmirer.Shared.MessageBus;
using SecretAdmirer.Shared.Saga;
using SecretAdmirer.Shared.Security;

namespace SecretAdmirer.Messages.Services;

public sealed class SendMessageContext
{
    public required Guid ReceiverId { get; init; }
    public required string ReceiverHandle { get; init; }
    public required string Body { get; init; }
    public required string SenderIp { get; init; }
    public required int DailyQuota { get; init; }

    public string? Fingerprint { get; set; }
    public Guid? MessageId { get; set; }
    public bool CounterIncremented { get; set; }
    public bool NotificationPublished { get; set; }
}

/// <summary>
/// The headline saga: anonymous send.
///
///   ValidateSender → PersistMessage → IncrementInboxCounter → DispatchNotification
///
/// Each compensating step undoes the visible side-effect of the forward
/// action. Failures from the bus are tolerated by compensation (we don't
/// "unpublish" notifications — we publish a counter-rollback event instead).
/// </summary>
public sealed class SendMessageSaga : ISaga<SendMessageContext>
{
    public string Name => "SendMessageSaga";
    public IReadOnlyList<SagaStep<SendMessageContext>> Steps { get; }

    public SendMessageSaga(MessageDbContext db, IMessageBus bus, ILogger<SendMessageSaga> log)
    {
        Steps = new[]
        {
            SagaStep<SendMessageContext>.Of(
                "ValidateSender",
                forward: async (ctx, ct) =>
                {
                    var day = DateOnly.FromDateTime(DateTime.UtcNow);
                    var fp = TokenHasher.FingerprintSender(ctx.SenderIp, ctx.ReceiverId, day);
                    ctx.Fingerprint = fp;

                    var quota = await db.SendQuotas.FirstOrDefaultAsync(q => q.Fingerprint == fp && q.DayBucket == day, ct);
                    if (quota is null)
                    {
                        db.SendQuotas.Add(new SendQuota { Fingerprint = fp, DayBucket = day, Count = 1 });
                    }
                    else
                    {
                        if (quota.Count >= ctx.DailyQuota)
                            throw new InvalidOperationException("message.rate_limit");
                        quota.Count++;
                    }
                    await db.SaveChangesAsync(ct);
                },
                compensate: async (ctx, ct) =>
                {
                    if (ctx.Fingerprint is null) return;
                    var day = DateOnly.FromDateTime(DateTime.UtcNow);
                    var quota = await db.SendQuotas.FirstOrDefaultAsync(q => q.Fingerprint == ctx.Fingerprint && q.DayBucket == day, ct);
                    if (quota is not null && quota.Count > 0)
                    {
                        quota.Count--;
                        await db.SaveChangesAsync(ct);
                    }
                }),

            SagaStep<SendMessageContext>.Of(
                "PersistMessage",
                forward: async (ctx, ct) =>
                {
                    var msg = new Message
                    {
                        ReceiverId = ctx.ReceiverId,
                        Body = ctx.Body,
                        SenderFingerprint = ctx.Fingerprint!,
                    };
                    db.Messages.Add(msg);
                    await db.SaveChangesAsync(ct);
                    ctx.MessageId = msg.Id;
                },
                compensate: async (ctx, ct) =>
                {
                    if (ctx.MessageId is null) return;
                    var m = await db.Messages.FindAsync(new object[] { ctx.MessageId.Value }, ct);
                    if (m is not null)
                    {
                        m.DeletedAt = DateTime.UtcNow;
                        await db.SaveChangesAsync(ct);
                    }
                }),

            SagaStep<SendMessageContext>.Of(
                "IncrementInboxCounter",
                forward: async (ctx, ct) =>
                {
                    var counter = await db.InboxCounters.FindAsync(new object[] { ctx.ReceiverId }, ct);
                    if (counter is null)
                    {
                        counter = new InboxCounter { UserId = ctx.ReceiverId, UnreadCount = 1, TotalCount = 1 };
                        db.InboxCounters.Add(counter);
                    }
                    else
                    {
                        counter.UnreadCount++;
                        counter.TotalCount++;
                        counter.UpdatedAt = DateTime.UtcNow;
                    }
                    await db.SaveChangesAsync(ct);
                    ctx.CounterIncremented = true;
                    await bus.PublishAsync(new InboxCounterChanged(ctx.ReceiverId, +1, +1), ct);
                },
                compensate: async (ctx, ct) =>
                {
                    if (!ctx.CounterIncremented) return;
                    var counter = await db.InboxCounters.FindAsync(new object[] { ctx.ReceiverId }, ct);
                    if (counter is not null)
                    {
                        counter.UnreadCount = Math.Max(0, counter.UnreadCount - 1);
                        counter.TotalCount = Math.Max(0, counter.TotalCount - 1);
                        await db.SaveChangesAsync(ct);
                        await bus.PublishAsync(new InboxCounterChanged(ctx.ReceiverId, -1, -1), ct);
                    }
                }),

            SagaStep<SendMessageContext>.Of(
                "DispatchNotification",
                forward: async (ctx, ct) =>
                {
                    var preview = ctx.Body.Length <= 60 ? ctx.Body : ctx.Body[..60] + "…";
                    await bus.PublishAsync(new MessageReceived(
                        MessageId: ctx.MessageId!.Value,
                        ReceiverId: ctx.ReceiverId,
                        ReceiverHandle: ctx.ReceiverHandle,
                        BodyPreview: preview,
                        ReceivedAt: DateTime.UtcNow), ct);
                    ctx.NotificationPublished = true;
                },
                compensate: async (ctx, ct) =>
                {
                    if (!ctx.NotificationPublished) return;
                    // Can't unpublish, but we publish a compensation event so
                    // NotificationService can mark the row as withdrawn and
                    // suppress the push if it hasn't been sent yet.
                    await bus.PublishAsync(new SagaCompensated(Guid.NewGuid(), "SendMessageSaga",
                        $"Notification withdrawn for message {ctx.MessageId}"), ct);
                })
        };
    }
}
