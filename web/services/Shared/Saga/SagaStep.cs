namespace SecretAdmirer.Shared.Saga;

/// <summary>
/// A single step in a saga: a forward action and the compensating action
/// that must run if a later step fails. Both are async and may consult /
/// mutate the shared <typeparamref name="TContext"/>.
/// </summary>
public sealed class SagaStep<TContext>
{
    public string Name { get; }
    public Func<TContext, CancellationToken, Task> Forward { get; }
    public Func<TContext, CancellationToken, Task> Compensate { get; }

    public SagaStep(
        string name,
        Func<TContext, CancellationToken, Task> forward,
        Func<TContext, CancellationToken, Task> compensate)
    {
        Name = name ?? throw new ArgumentNullException(nameof(name));
        Forward = forward ?? throw new ArgumentNullException(nameof(forward));
        Compensate = compensate ?? throw new ArgumentNullException(nameof(compensate));
    }

    public static SagaStep<TContext> Of(
        string name,
        Func<TContext, CancellationToken, Task> forward,
        Func<TContext, CancellationToken, Task>? compensate = null)
        => new(name, forward, compensate ?? ((_, _) => Task.CompletedTask));
}
