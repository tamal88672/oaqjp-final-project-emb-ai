namespace SecretAdmirer.Saga.Models;

public class SagaStateRow
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string SagaName { get; set; } = string.Empty;
    public string Status { get; set; } = "running"; // running | completed | compensated | failed
    public int CurrentStep { get; set; }
    public string PayloadJson { get; set; } = "{}";
    public string? LastError { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class SagaStepLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid SagaId { get; set; }
    public int StepIndex { get; set; }
    public string StepName { get; set; } = string.Empty;
    public string Direction { get; set; } = "forward";
    public string Status { get; set; } = "ok";
    public string? Detail { get; set; }
    public DateTime OccurredAt { get; set; } = DateTime.UtcNow;
}
