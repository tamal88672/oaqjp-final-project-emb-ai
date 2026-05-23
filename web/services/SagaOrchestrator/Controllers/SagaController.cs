using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Saga.Data;

namespace SecretAdmirer.Saga.Controllers;

[ApiController]
[Route("sagas")]
public sealed class SagaController : ControllerBase
{
    private readonly SagaDbContext _db;
    public SagaController(SagaDbContext db) => _db = db;

    [HttpGet("")]
    public async Task<IActionResult> List([FromQuery] string? status, CancellationToken ct)
    {
        var q = _db.SagaStates.AsQueryable();
        if (!string.IsNullOrEmpty(status)) q = q.Where(s => s.Status == status);
        var items = await q.OrderByDescending(s => s.UpdatedAt).Take(100).ToListAsync(ct);
        return Ok(items);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var saga = await _db.SagaStates.FindAsync(new object[] { id }, ct);
        if (saga is null) return NotFound();
        var log = await _db.SagaStepLogs.Where(l => l.SagaId == id).OrderBy(l => l.OccurredAt).ToListAsync(ct);
        return Ok(new { saga, log });
    }
}
