using System.Collections.Concurrent;
using Microsoft.Extensions.Logging;
using SecretAdmirer.Shared.Contracts;

namespace SecretAdmirer.Shared.MessageBus;

/// <summary>
/// Process-local pub/sub. Each service instance has its own bus; for
/// cross-service delivery, swap in <see cref="RabbitMqMessageBus"/>.
///
/// Delivery is at-least-once within a process: every subscriber for the
/// event's runtime type is invoked. Failures inside a handler are logged
/// but do not block other handlers — the bus is fan-out, not transactional.
/// </summary>
public sealed class InMemoryMessageBus : IMessageBus
{
    private readonly ILogger<InMemoryMessageBus> _log;
    private readonly ConcurrentDictionary<Type, List<Delegate>> _handlers = new();
    private readonly object _gate = new();

    public InMemoryMessageBus(ILogger<InMemoryMessageBus> log) => _log = log;

    public async Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct = default)
        where TEvent : class, IIntegrationEvent
    {
        if (!_handlers.TryGetValue(typeof(TEvent), out var list))
        {
            _log.LogDebug("No subscribers for {EventType}", typeof(TEvent).Name);
            return;
        }

        Delegate[] snapshot;
        lock (_gate) { snapshot = list.ToArray(); }

        foreach (var d in snapshot)
        {
            var handler = (Func<TEvent, CancellationToken, Task>)d;
            try
            {
                await handler(@event, ct);
            }
            catch (Exception ex)
            {
                _log.LogError(ex, "Subscriber threw while handling {EventType} ({EventId})",
                    typeof(TEvent).Name, @event.EventId);
            }
        }
    }

    public IDisposable Subscribe<TEvent>(Func<TEvent, CancellationToken, Task> handler)
        where TEvent : class, IIntegrationEvent
    {
        var list = _handlers.GetOrAdd(typeof(TEvent), _ => new List<Delegate>());
        lock (_gate) { list.Add(handler); }
        return new Subscription(() =>
        {
            lock (_gate) { list.Remove(handler); }
        });
    }

    private sealed class Subscription : IDisposable
    {
        private Action? _dispose;
        public Subscription(Action dispose) => _dispose = dispose;
        public void Dispose() { _dispose?.Invoke(); _dispose = null; }
    }
}
