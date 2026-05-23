using SecretAdmirer.Notifications.Models;

namespace SecretAdmirer.Notifications.Services;

public interface IPushSender
{
    Task SendAsync(DeviceToken token, Notification notification, CancellationToken ct);
}

/// <summary>
/// Logs the push instead of dispatching it. Replace with an APNs/WebPush
/// implementation in production. We deliberately do nothing if the device
/// table is empty — there is no "demo" mode that fakes notifications.
/// </summary>
public sealed class LoggingPushSender : IPushSender
{
    private readonly ILogger<LoggingPushSender> _log;
    public LoggingPushSender(ILogger<LoggingPushSender> log) => _log = log;

    public Task SendAsync(DeviceToken token, Notification notification, CancellationToken ct)
    {
        _log.LogInformation("[push:{Platform}] user={User} title={Title} messageId={MessageId}",
            token.Platform, token.UserId, notification.Title, notification.MessageId);
        return Task.CompletedTask;
    }
}
