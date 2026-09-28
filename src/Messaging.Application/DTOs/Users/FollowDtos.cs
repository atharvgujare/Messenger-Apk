namespace Messaging.Application.DTOs.Users;

public class FollowRequestDto
{
    public Guid Id { get; set; }
    public Guid FollowerId { get; set; }
    public string FollowerUsername { get; set; } = string.Empty;
    public string FollowerDisplayName { get; set; } = string.Empty;
    public string? FollowerAvatarUrl { get; set; }
    public DateTime CreatedAtUtc { get; set; }
}

public class FollowUserDto
{
    public Guid UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string? AvatarUrl { get; set; }
    public bool IsOnline { get; set; }
}

public class FollowResponseDto
{
    public string Status { get; set; } = string.Empty; // "accepted", "pending"
    public string Message { get; set; } = string.Empty;
}
