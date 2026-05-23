using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Profile.Models;

namespace SecretAdmirer.Profile.Data;

public class ProfileDbContext : DbContext
{
    public ProfileDbContext(DbContextOptions<ProfileDbContext> options) : base(options) { }

    public DbSet<Models.Profile> Profiles => Set<Models.Profile>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<Models.Profile>(e =>
        {
            e.ToTable("profiles");
            e.HasKey(p => p.UserId);
            e.HasIndex(p => p.Handle).IsUnique();
            e.Property(p => p.Handle).HasMaxLength(40).IsRequired();
            e.Property(p => p.DisplayName).HasMaxLength(80);
            e.Property(p => p.Bio).HasMaxLength(280);
            e.Property(p => p.AvatarUrl).HasMaxLength(512);
            e.Property(p => p.Theme).HasMaxLength(20).HasDefaultValue("velvet");
        });
    }
}
