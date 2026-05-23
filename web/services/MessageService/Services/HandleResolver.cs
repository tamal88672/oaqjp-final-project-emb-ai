using System.Net.Http.Json;

namespace SecretAdmirer.Messages.Services;

/// <summary>
/// Resolves a public handle to a user id by calling ProfileService. This is
/// the only cross-service synchronous call MessageService makes — needed
/// because we don't keep a local copy of every handle. In production it
/// would be cached in Redis with a short TTL.
/// </summary>
public sealed class HandleResolver
{
    private readonly HttpClient _http;
    private readonly ILogger<HandleResolver> _log;

    public HandleResolver(HttpClient http, ILogger<HandleResolver> log)
    {
        _http = http;
        _log = log;
    }

    public sealed record ResolvedHandle(Guid UserId, string Handle, bool AllowReplies);

    public async Task<ResolvedHandle?> ResolveAsync(string handle, CancellationToken ct)
    {
        try
        {
            var dto = await _http.GetFromJsonAsync<InternalProfileDto>($"/internal/profile/by-handle/{handle}", ct);
            return dto is null ? null : new ResolvedHandle(dto.UserId, dto.Handle, dto.AllowReplies);
        }
        catch (HttpRequestException ex)
        {
            _log.LogWarning(ex, "Profile lookup failed for {Handle}", handle);
            return null;
        }
    }

    private sealed record InternalProfileDto(Guid UserId, string Handle, bool AllowReplies);
}
