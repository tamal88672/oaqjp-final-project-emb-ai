using SecretAdmirer.Saga.Data;
using SecretAdmirer.Saga.Models;
using SecretAdmirer.Shared.Contracts;
using SecretAdmirer.Shared.MessageBus;

namespace SecretAdmirer.Saga.Services;

/// <summary>
/// Records saga lifecycle events from across the system so operators can
/// audit them later. The actual saga execution lives next to the service
/// that owns the steps (e.g. <c>SendMessageSaga</c> in MessageService) so
/// it can transact against that service's database; this orchestrator
/// stays write-only over the bus and never reaches back into the data
/// layer of other services.
/// </summary>
public sealed class SagaObserver : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly IMessageBus _bus;
    private readonly ILogger<SagaObserver> _log;
    private readonly List<IDisposable> _subs = new();

    public SagaObserver(IServiceProvider services, IMessageBus bus, ILogger<SagaObserver> log)
    {
        _services = services;
        _bus = bus;
        _log = log;
    }

    protected override Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _subs.Add(_bus.Subscribe<SagaCompensated>(OnCompensated));
        _log.LogInformation("SagaObserver listening for SagaCompensated");
        return Task.CompletedTask;
    }

    private async Task OnCompensated(SagaCompensated evt, CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<SagaDbContext>();
        db.SagaStates.Add(new SagaStateRow
        {
            Id = evt.SagaId == Guid.Empty ? Guid.NewGuid() : evt.SagaId,
            SagaName = evt.SagaName,
            Status = "compensated",
            LastError = evt.Reason
        });
        await db.SaveChangesAsync(ct);
        _log.LogWarning("Saga {Saga} compensated: {Reason}", evt.SagaName, evt.Reason);
    }

    public override void Dispose()
    {
        foreach (var s in _subs) s.Dispose();
        base.Dispose();
    }
}
