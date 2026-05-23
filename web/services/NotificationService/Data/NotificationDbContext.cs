using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Notifications.Models;

namespace SecretAdmirer.Notifications.Data;

public class NotificationDbContext : DbContext
{
    public NotificationDbContext(DbContextOptions<NotificationDbContext> options) : base(options) { }

    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<Notification>(e =>
        {
            e.ToTable("notifications");
            e.HasKey(n => n.Id);
            e.HasIndex(n => new { n.UserId, n.CreatedAt });
            e.Property(n => n.Type).HasMaxLength(40).IsRequired();
            e.Property(n => n.Title).HasMaxLength(120).IsRequired();
            e.Property(n => n.Body).HasMaxLength(280);
        });
        mb.Entity<DeviceToken>(e =>
        {
            e.ToTable("device_tokens");
            e.HasKey(t => t.Id);
            e.HasIndex(t => t.UserId);
            e.Property(t => t.Platform).HasMaxLength(20);
            e.Property(t => t.Token).HasMaxLength(512);
        });
    }
}
