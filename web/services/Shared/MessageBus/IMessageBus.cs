using SecretAdmirer.Shared.Contracts;

namespace SecretAdmirer.Shared.MessageBus;

public interface IMessageBus
{
    Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct = default)
        where TEvent : class, IIntegrationEvent;

    IDisposable Subscribe<TEvent>(Func<TEvent, CancellationToken, Task> handler)
        where TEvent : class, IIntegrationEvent;
}
