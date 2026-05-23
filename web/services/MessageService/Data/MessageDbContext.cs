using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Messages.Models;

namespace SecretAdmirer.Messages.Data;

public class MessageDbContext : DbContext
{
    public MessageDbContext(DbContextOptions<MessageDbContext> options) : base(options) { }

    public DbSet<Message> Messages => Set<Message>();
    public DbSet<InboxCounter> InboxCounters => Set<InboxCounter>();
    public DbSet<SendQuota> SendQuotas => Set<SendQuota>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<Message>(e =>
        {
            e.ToTable("messages");
            e.HasKey(m => m.Id);
            e.HasIndex(m => new { m.ReceiverId, m.ReceivedAt });
            e.Property(m => m.Body).HasMaxLength(500).IsRequired();
            e.Property(m => m.SenderFingerprint).HasMaxLength(128).IsRequired();
        });
        mb.Entity<InboxCounter>(e =>
        {
            e.ToTable("inbox_counters");
            e.HasKey(c => c.UserId);
        });
        mb.Entity<SendQuota>(e =>
        {
            e.ToTable("send_quotas");
            e.HasKey(q => new { q.Fingerprint, q.DayBucket });
            e.Property(q => q.Fingerprint).HasMaxLength(128);
        });
    }
}
