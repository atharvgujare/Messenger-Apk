namespace Messaging.Domain.Entities;

public enum FollowStatus : byte
{
    Pending = 1,
    Accepted = 2,
    Rejected = 3
}

public class UserFollow
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid FollowerId { get; set; }
    public Guid FolloweeId { get; set; }
    public FollowStatus Status { get; set; } = FollowStatus.Accepted;
    public DateTime CreatedAtUtc { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAtUtc { get; set; }

    public User Follower { get; set; } = null!;
    public User Followee { get; set; } = null!;
}
