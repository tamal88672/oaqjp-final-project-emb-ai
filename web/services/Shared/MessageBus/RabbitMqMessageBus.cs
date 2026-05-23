using SecretAdmirer.Shared.Contracts;

namespace SecretAdmirer.Shared.MessageBus;

/// <summary>
/// Production transport stub. Wire to RabbitMQ via the <c>RabbitMQ.Client</c>
/// package: declare a topic exchange per service, bind queues by event name,
/// serialize as JSON with the event's CLR type written into the AMQP
/// <c>type</c> header so subscribers can route by it.
///
/// Left as a stub here so the in-process bus stays the default for local dev
/// without dragging in a broker dependency.
/// </summary>
public sealed class RabbitMqMessageBus : IMessageBus
{
    public Task PublishAsync<TEvent>(TEvent @event, CancellationToken ct = default)
        where TEvent : class, IIntegrationEvent
        => throw new NotImplementedException("Wire a RabbitMQ.Client.IConnection here.");

    public IDisposable Subscribe<TEvent>(Func<TEvent, CancellationToken, Task> handler)
        where TEvent : class, IIntegrationEvent
        => throw new NotImplementedException("Declare a queue + consumer here.");
}
