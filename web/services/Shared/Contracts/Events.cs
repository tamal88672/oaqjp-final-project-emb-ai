namespace SecretAdmirer.Shared.Contracts;

public interface IIntegrationEvent
{
    Guid EventId { get; }
    DateTime OccurredAt { get; }
}

public abstract record IntegrationEvent : IIntegrationEvent
{
    public Guid EventId { get; init; } = Guid.NewGuid();
    public DateTime OccurredAt { get; init; } = DateTime.UtcNow;
}

public sealed record UserRegistered(
    Guid UserId,
    string Handle,
    string Email
) : IntegrationEvent;

public sealed record ProfileUpdated(
    Guid UserId,
    string Handle,
    string? DisplayName,
    string? Bio,
    string? AvatarUrl,
    string Theme
) : IntegrationEvent;

public sealed record MessageReceived(
    Guid MessageId,
    Guid ReceiverId,
    string ReceiverHandle,
    string BodyPreview,
    DateTime ReceivedAt
) : IntegrationEvent;

public sealed record MessageRead(
    Guid MessageId,
    Guid ReceiverId,
    DateTime ReadAt
) : IntegrationEvent;

public sealed record InboxCounterChanged(
    Guid UserId,
    int UnreadDelta,
    int TotalDelta
) : IntegrationEvent;

public sealed record SagaCompensated(
    Guid SagaId,
    string SagaName,
    string Reason
) : IntegrationEvent;
