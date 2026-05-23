namespace SecretAdmirer.Shared.Saga;

public interface ISaga<TContext>
{
    string Name { get; }
    IReadOnlyList<SagaStep<TContext>> Steps { get; }
}
