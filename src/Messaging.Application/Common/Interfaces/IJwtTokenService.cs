using System.Security.Claims;
using Messaging.Domain.Entities;

namespace Messaging.Application.Common.Interfaces;

public interface IJwtTokenService
{
    (string Token, DateTime ExpiresAtUtc) GenerateAccessToken(User user);
    string GenerateRefreshToken();
    ClaimsPrincipal? GetPrincipalFromToken(string token, bool validateLifetime = false);
}
