using Microsoft.Extensions.Logging;

namespace SecretAdmirer.Shared.Saga;

public sealed record SagaResult(Guid SagaId, SagaOutcome Outcome, string? Error, IReadOnlyList<SagaStepRecord> Log);
public sealed record SagaStepRecord(string Step, SagaDirection Direction, SagaStepStatus Status, string? Detail);

public enum SagaOutcome { Completed, Compensated, Failed }
public enum SagaDirection { Forward, Compensate }
public enum SagaStepStatus { Ok, Failed }

/// <summary>
/// Executes a list of <see cref="SagaStep{TContext}"/> instances in order.
/// On any forward-step failure, walks back through the steps that already
/// succeeded and runs their compensating actions in reverse. Records each
/// transition so the orchestrator can persist saga state.
/// </summary>
public sealed class SagaRunner<TContext>
{
    private readonly ILogger _log;

    public SagaRunner(ILogger log) => _log = log;

    public async Task<SagaResult> RunAsync(
        ISaga<TContext> saga,
        TContext context,
        CancellationToken ct = default)
    {
        var sagaId = Guid.NewGuid();
        var log = new List<SagaStepRecord>();
        var completed = new Stack<SagaStep<TContext>>();

        _log.LogInformation("Saga {Saga} ({SagaId}) starting with {Steps} steps",
            saga.Name, sagaId, saga.Steps.Count);

        for (int i = 0; i < saga.Steps.Count; i++)
        {
            var step = saga.Steps[i];
            try
            {
                await step.Forward(context, ct);
                completed.Push(step);
                log.Add(new SagaStepRecord(step.Name, SagaDirection.Forward, SagaStepStatus.Ok, null));
                _log.LogDebug("Saga {Saga} step {Step} ok", saga.Name, step.Name);
            }
            catch (Exception ex)
            {
                log.Add(new SagaStepRecord(step.Name, SagaDirection.Forward, SagaStepStatus.Failed, ex.Message));
                _log.LogWarning(ex, "Saga {Saga} step {Step} failed — compensating", saga.Name, step.Name);

                await CompensateAsync(completed, context, log, ct);
                return new SagaResult(sagaId, SagaOutcome.Compensated, ex.Message, log);
            }
        }

        _log.LogInformation("Saga {Saga} ({SagaId}) completed", saga.Name, sagaId);
        return new SagaResult(sagaId, SagaOutcome.Completed, null, log);
    }

    private async Task CompensateAsync(
        Stack<SagaStep<TContext>> completed,
        TContext context,
        List<SagaStepRecord> log,
        CancellationToken ct)
    {
        while (completed.Count > 0)
        {
            var step = completed.Pop();
            try
            {
                await step.Compensate(context, ct);
                log.Add(new SagaStepRecord(step.Name, SagaDirection.Compensate, SagaStepStatus.Ok, null));
            }
            catch (Exception ex)
            {
                // A failing compensation is logged but does not stop the rollback
                // of earlier steps. Operators must hand-resolve these from the log.
                log.Add(new SagaStepRecord(step.Name, SagaDirection.Compensate, SagaStepStatus.Failed, ex.Message));
                _log.LogError(ex, "Saga compensation for {Step} failed; continuing rollback", step.Name);
            }
        }
    }
}
