using System.Security.Claims;
using Messaging.Application.Common.Exceptions;
using Messaging.Application.Common.Interfaces;
using Messaging.Application.DTOs.Snaps;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Messaging.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class SnapsController : ControllerBase
{
    private readonly IUserService _userService;

    public SnapsController(IUserService userService)
    {
        _userService = userService;
    }

    [HttpPost]
    [ProducesResponseType(typeof(SnapDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> SendSnap([FromBody] CreateSnapRequest request, CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var snap = await _userService.SendSnapAsync(currentUserId, request, ct);
        return Ok(snap);
    }

    [HttpGet("active")]
    [ProducesResponseType(typeof(IReadOnlyList<SnapDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetActiveSnaps(CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var snaps = await _userService.GetActiveSnapsAsync(currentUserId, ct);
        return Ok(snaps);
    }

    [HttpPost("{id:guid}/open")]
    [ProducesResponseType(typeof(SnapDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> OpenSnap(Guid id, CancellationToken ct)
    {
        var currentUserId = GetCurrentUserId();
        var snap = await _userService.OpenSnapAsync(currentUserId, id, ct);
        if (snap == null)
        {
            return NotFound(new { message = "Snap not found or already opened." });
        }
        return Ok(snap);
    }

    [HttpPost("media")]
    [Consumes("multipart/form-data")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> UploadSnapMedia(IFormFile file, CancellationToken ct)
    {
        if (file == null || file.Length == 0)
        {
            return BadRequest(new { message = "No file uploaded." });
        }

        if (file.Length > 25 * 1024 * 1024) // 25 MB max
        {
            return BadRequest(new { message = "Snap file size must not exceed 25MB." });
        }

        var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
        var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".webp", ".mp4" };
        if (!allowedExtensions.Contains(ext))
        {
            return BadRequest(new { message = "Invalid snap media format. Allowed: .jpg, .jpeg, .png, .webp, .mp4" });
        }

        var uploadsFolder = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot", "snaps");
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
        var mediaUrl = $"{requestBase}/snaps/{uniqueFileName}";

        return Ok(new { mediaUrl });
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
