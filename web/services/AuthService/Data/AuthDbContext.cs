using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Auth.Models;

namespace SecretAdmirer.Auth.Data;

public class AuthDbContext : DbContext
{
    public AuthDbContext(DbContextOptions<AuthDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    protected override void OnModelCreating(ModelBuilder mb)
    {
        mb.Entity<User>(e =>
        {
            e.ToTable("users");
            e.HasKey(u => u.Id);
            e.HasIndex(u => u.Handle).IsUnique();
            e.HasIndex(u => u.Email).IsUnique();
            e.Property(u => u.Handle).HasMaxLength(40).IsRequired();
            e.Property(u => u.Email).HasMaxLength(256).IsRequired();
            e.Property(u => u.PasswordHash).HasMaxLength(512).IsRequired();
            e.Property(u => u.PasswordSalt).HasMaxLength(128).IsRequired();
            e.Property(u => u.Status).HasMaxLength(20).HasDefaultValue("active");
        });

        mb.Entity<RefreshToken>(e =>
        {
            e.ToTable("refresh_tokens");
            e.HasKey(r => r.Id);
            e.HasIndex(r => r.UserId);
            e.Property(r => r.TokenHash).HasMaxLength(256).IsRequired();
        });
    }
}
