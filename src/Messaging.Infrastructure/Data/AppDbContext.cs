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
    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<ConversationMember> ConversationMembers => Set<ConversationMember>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<MessageReaction> MessageReactions => Set<MessageReaction>();
    public DbSet<MessageUserDeletion> MessageUserDeletions => Set<MessageUserDeletion>();
    public DbSet<EmailVerificationOtp> EmailVerificationOtps => Set<EmailVerificationOtp>();

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

        // Conversation Configuration
        modelBuilder.Entity<Conversation>(entity =>
        {
            entity.HasKey(c => c.Id);

            entity.Property(c => c.Type)
                .HasConversion<byte>();

            entity.Property(c => c.Title)
                .HasMaxLength(150);

            entity.Property(c => c.AvatarUrl)
                .HasMaxLength(1024);

            entity.HasOne(c => c.LastMessage)
                .WithMany()
                .HasForeignKey(c => c.LastMessageId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasMany(c => c.Members)
                .WithOne(m => m.Conversation)
                .HasForeignKey(m => m.ConversationId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasMany(c => c.Messages)
                .WithOne(m => m.Conversation)
                .HasForeignKey(m => m.ConversationId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // ConversationMember Configuration
        modelBuilder.Entity<ConversationMember>(entity =>
        {
            entity.HasKey(m => new { m.ConversationId, m.UserId });

            entity.HasOne(m => m.User)
                .WithMany()
                .HasForeignKey(m => m.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(m => new { m.UserId, m.IsArchived, m.IsPinned });
        });

        // Message Configuration
        modelBuilder.Entity<Message>(entity =>
        {
            entity.HasKey(m => m.Id);

            entity.Property(m => m.Type)
                .HasConversion<byte>();

            entity.Property(m => m.Status)
                .HasConversion<byte>();

            entity.HasOne(m => m.Sender)
                .WithMany()
                .HasForeignKey(m => m.SenderId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(m => m.ReplyToMessage)
                .WithMany()
                .HasForeignKey(m => m.ReplyToMessageId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(m => new { m.ConversationId, m.CreatedAtUtc });
            entity.HasIndex(m => m.SenderId);
        });

        // MessageReaction Configuration
        modelBuilder.Entity<MessageReaction>(entity =>
        {
            entity.HasKey(r => r.Id);

            entity.Property(r => r.Emoji)
                .IsRequired()
                .HasMaxLength(32);

            entity.HasIndex(r => new { r.MessageId, r.UserId, r.Emoji })
                .IsUnique();

            entity.HasOne(r => r.Message)
                .WithMany(m => m.Reactions)
                .HasForeignKey(r => r.MessageId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(r => r.User)
                .WithMany()
                .HasForeignKey(r => r.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // MessageUserDeletion Configuration (Delete for Me)
        modelBuilder.Entity<MessageUserDeletion>(entity =>
        {
            entity.HasKey(d => new { d.MessageId, d.UserId });

            entity.HasOne(d => d.Message)
                .WithMany(m => m.UserDeletions)
                .HasForeignKey(d => d.MessageId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(d => d.User)
                .WithMany()
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // EmailVerificationOtp Configuration
        modelBuilder.Entity<EmailVerificationOtp>(entity =>
        {
            entity.HasKey(o => o.Id);

            entity.Property(o => o.Email)
                .IsRequired()
                .HasMaxLength(256);

            entity.Property(o => o.OtpCode)
                .IsRequired()
                .HasMaxLength(10);

            entity.HasIndex(o => new { o.Email, o.ExpiresAtUtc, o.IsUsed });
        });
    }
}

