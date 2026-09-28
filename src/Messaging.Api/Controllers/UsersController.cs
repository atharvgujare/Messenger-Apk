using System.Security.Claims;
using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Auth;
using Messaging.Application.DTOs.Users;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Messaging.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;

    public UsersController(IUserService userService)
    {
        _userService = userService;
    }

    [HttpGet("search")]
    [ProducesResponseType(typeof(IReadOnlyList<UserSearchResultDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> Search([FromQuery] string? q, [FromQuery] int limit = 20, CancellationToken ct = default)
    {
        var currentUserId = GetCurrentUserId();
        var results = await _userService.SearchUsersAsync(q ?? string.Empty, currentUserId, limit, ct);
        return Ok(results);
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(UserProfileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetUserById(Guid id, CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var profile = await _userService.GetProfileByIdAsync(id, currentUserId, ct);
        return Ok(profile);
    }

    [HttpPut("me")]
    [ProducesResponseType(typeof(UserProfileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest request, CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var updatedProfile = await _userService.UpdateProfileAsync(currentUserId, request, ct);
        return Ok(updatedProfile);
    }

    [HttpPost("me/avatar")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(typeof(UserProfileDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> UploadAvatar(IFormFile file, CancellationToken ct)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "No image file uploaded." });
        }

        if (file.Length > 10 * 1024 * 1024)
        {
            return BadRequest(new { message = "Image file size must not exceed 10MB." });
        }

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp" };
        if (!allowedExtensions.Contains(ext))
        {
            return BadRequest(new { message = "Invalid image format. Allowed: .jpg, .jpeg, .png, .webp" });
        }

        var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "avatars");
        if (!Directory.Exists(uploadsFolder))
        {
            Directory.CreateDirectory(uploadsFolder);
        }

        var currentUserId = GetCurrentUserId();
        var uniqueFileName = $"{currentUserId}_{DateTime.UtcNow.Ticks}{ext}";
        var filePath = Path.Combine(uploadsFolder, uniqueFileName);

        using (var stream = new FileStream(filePath, FileMode.Create))
        {
            await file.CopyToAsync(stream, ct);
        }

        var scheme = Request.Headers.TryGetValue("X-Forwarded-Proto", out var proto) && !string.IsNullOrWhiteSpace(proto)
            ? proto.ToString()
            : (Request.Host.Host.Contains("onrender.com") || !Request.Host.Host.Contains("localhost") ? "https" : Request.Scheme);
        var requestBase = $"{scheme}://{Request.Host}";
        var avatarUrl = $"{requestBase}/avatars/{uniqueFileName}";

        var currentProfile = await _userService.GetProfileByIdAsync(currentUserId, currentUserId, ct);
        var updateRequest = new UpdateProfileRequest
        {
            DisplayName = currentProfile.DisplayName,
            Bio = currentProfile.Bio,
            AvatarUrl = avatarUrl
        };

        var updated = await _userService.UpdateProfileAsync(currentUserId, updateRequest, ct);
        return Ok(updated);
    }

    [HttpDelete("me")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> DeleteAccount(CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        await _userService.DeleteAccountPermanentlyAsync(currentUserId, ct);
        return Ok(new { message = "Account permanently deleted successfully." });
    }

    [HttpPost("{id:guid}/follow")]
    [ProducesResponseType(typeof(FollowResponseDto), StatusCodes.Status200OK)]
    public async Task<IActionResult> FollowUser(Guid id, CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var result = await _userService.FollowUserAsync(currentUserId, id, ct);
        return Ok(result);
    }

    [HttpPost("{id:guid}/unfollow")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> UnfollowUser(Guid id, CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var result = await _userService.UnfollowUserAsync(currentUserId, id, ct);
        return Ok(new { success = result });
    }

    [HttpGet("follow-requests")]
    [ProducesResponseType(typeof(IReadOnlyList<FollowRequestDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetPendingFollowRequests(CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var requests = await _userService.GetPendingFollowRequestsAsync(currentUserId, ct);
        return Ok(requests);
    }

    [HttpPost("follow-requests/{id:guid}/accept")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> AcceptFollowRequest(Guid id, CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var result = await _userService.AcceptFollowRequestAsync(currentUserId, id, ct);
        return Ok(new { success = result });
    }

    [HttpPost("follow-requests/{id:guid}/reject")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> RejectFollowRequest(Guid id, CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var result = await _userService.RejectFollowRequestAsync(currentUserId, id, ct);
        return Ok(new { success = result });
    }

    [HttpGet("{id:guid}/followers")]
    [ProducesResponseType(typeof(IReadOnlyList<FollowUserDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetFollowers(Guid id, CancellationToken ct)
    {
        var followers = await _userService.GetFollowersAsync(id, ct);
        return Ok(followers);
    }

    [HttpGet("{id:guid}/following")]
    [ProducesResponseType(typeof(IReadOnlyList<FollowUserDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetFollowing(Guid id, CancellationToken ct)
    {
        var following = await _userService.GetFollowingAsync(id, ct);
        return Ok(following);
    }


    private Guid GetCurrentUserId()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
        {
            throw new UnauthorizedException("User identity not found in token claims.");
        }
        return userId;
    }
}
