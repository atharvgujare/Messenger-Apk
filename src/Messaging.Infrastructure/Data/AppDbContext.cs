using Messaging.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace Messaging.Infrastructure.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<UserProfile> UserProfiles => Set<UserProfile>();
    public DbSet<UserSession> UserSessions => Set<UserSession>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User Configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(u => u.Id);

            entity.Property(u => u.Username)
                .IsRequired()
                .HasMaxLength(30);

            entity.HasIndex(u => u.Username)
                .IsUnique();

            entity.Property(u => u.Email)
                .IsRequired()
                .HasMaxLength(256);

            entity.HasIndex(u => u.Email)
                .IsUnique();

            entity.Property(u => u.PasswordHash)
                .IsRequired()
                .HasMaxLength(255);

            entity.Property(u => u.CreatedAtUtc)
                .IsRequired();

            entity.HasOne(u => u.Profile)
                .WithOne(p => p.User)
                .HasForeignKey<UserProfile>(p => p.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasMany(u => u.Sessions)
                .WithOne(s => s.User)
                .HasForeignKey(s => s.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // UserProfile Configuration
        modelBuilder.Entity<UserProfile>(entity =>
        {
            entity.HasKey(p => p.UserId);

            entity.Property(p => p.DisplayName)
                .IsRequired()
                .HasMaxLength(100);

            entity.Property(p => p.Bio)
                .HasMaxLength(500);

            entity.Property(p => p.AvatarUrl)
                .HasMaxLength(1024);

            entity.Property(p => p.LastSeenPrivacy)
                .HasConversion<byte>();

            entity.Property(p => p.AvatarPrivacy)
                .HasConversion<byte>();
        });

        // UserSession Configuration
        modelBuilder.Entity<UserSession>(entity =>
        {
            entity.HasKey(s => s.Id);

            entity.Property(s => s.RefreshToken)
                .IsRequired()
                .HasMaxLength(255);

            entity.HasIndex(s => s.RefreshToken)
                .IsUnique();

            entity.Property(s => s.DeviceInfo)
                .HasMaxLength(255);

            entity.Property(s => s.IpAddress)
                .HasMaxLength(45);

            entity.Property(s => s.ReplacedByToken)
                .HasMaxLength(255);

            entity.HasIndex(s => new { s.UserId, s.ExpiresAtUtc });
        });
    }
}
