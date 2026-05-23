using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Profile.Data;
using SecretAdmirer.Shared.Contracts;
using SecretAdmirer.Shared.MessageBus;

namespace SecretAdmirer.Profile.Services;

/// <summary>
/// Subscribes to <see cref="UserRegistered"/> on the bus and creates a
/// default profile row. Idempotent — if a profile already exists for the
/// user, the event is ignored.
/// </summary>
public sealed class ProfileProvisioner : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly IMessageBus _bus;
    private readonly ILogger<ProfileProvisioner> _log;
    private IDisposable? _sub;

    public ProfileProvisioner(IServiceProvider services, IMessageBus bus, ILogger<ProfileProvisioner> log)
    {
        _services = services;
        _bus = bus;
        _log = log;
    }

    protected override Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _sub = _bus.Subscribe<UserRegistered>(OnUserRegistered);
        _log.LogInformation("ProfileProvisioner subscribed to UserRegistered");
        return Task.CompletedTask;
    }

    private async Task OnUserRegistered(UserRegistered evt, CancellationToken ct)
    {
        using var scope = _services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ProfileDbContext>();
        if (await db.Profiles.AnyAsync(p => p.UserId == evt.UserId, ct))
        {
            _log.LogDebug("Profile already exists for {UserId}, ignoring", evt.UserId);
            return;
        }
        db.Profiles.Add(new Models.Profile
        {
            UserId = evt.UserId,
            Handle = evt.Handle,
            DisplayName = evt.Handle,
            Theme = "velvet",
        });
        await db.SaveChangesAsync(ct);
        _log.LogInformation("Provisioned profile for {UserId} ({Handle})", evt.UserId, evt.Handle);
    }

    public override void Dispose()
    {
        _sub?.Dispose();
        base.Dispose();
    }
}
