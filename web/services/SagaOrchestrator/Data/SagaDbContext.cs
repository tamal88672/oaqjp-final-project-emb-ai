using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Saga.Models;

namespace SecretAdmirer.Saga.Data;

public class SagaDbContext : DbContext
{
    public SagaDbContext(DbContextOptions<SagaDbContext> options) : base(options) { }

    public DbSet<SagaStateRow> SagaStates => Set<SagaStateRow>();
    public DbSet<SagaStepLog> SagaStepLogs => Set<SagaStepLog>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<SagaStateRow>(e =>
        {
            e.ToTable("saga_state");
            e.HasKey(s => s.Id);
            e.Property(s => s.SagaName).HasMaxLength(80).IsRequired();
            e.Property(s => s.Status).HasMaxLength(30).IsRequired();
        });
        mb.Entity<SagaStepLog>(e =>
        {
            e.ToTable("saga_step_log");
            e.HasKey(l => l.Id);
            e.HasIndex(l => l.SagaId);
            e.Property(l => l.StepName).HasMaxLength(80);
            e.Property(l => l.Direction).HasMaxLength(20);
            e.Property(l => l.Status).HasMaxLength(20);
        });
    }
}
