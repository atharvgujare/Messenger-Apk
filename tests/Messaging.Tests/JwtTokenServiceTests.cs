using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Messaging.Domain.Entities;
using Messaging.Infrastructure.Security;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace Messaging.Tests;

public class JwtTokenServiceTests
{
    private readonly JwtTokenService _tokenService;

    public JwtTokenServiceTests()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["JwtSettings:Secret"] = "MessengerTestSuperSecretKeyForJwtTokenSigning1234567890!",
                ["JwtSettings:Issuer"] = "MessengerTestIssuer",
                ["JwtSettings:Audience"] = "MessengerTestAudience",
                ["JwtSettings:AccessTokenExpirationMinutes"] = "60"
            })
            .Build();

        _tokenService = new JwtTokenService(config);
    }

    [Fact]
    public void GenerateAccessToken_ShouldProduceValidTokenWithUserClaims()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "atharv",
            Email = "atharv@example.com"
        };

        var (token, expiresAtUtc) = _tokenService.GenerateAccessToken(user);

        Assert.NotNull(token);
        Assert.NotEmpty(token);
        Assert.True(expiresAtUtc > DateTime.UtcNow);

        var principal = _tokenService.GetPrincipalFromToken(token, validateLifetime: true);
        Assert.NotNull(principal);

        var nameClaim = principal.FindFirst(ClaimTypes.Name)?.Value;
        var emailClaim = principal.FindFirst(ClaimTypes.Email)?.Value;
        var idClaim = principal.FindFirst(ClaimTypes.NameIdentifier)?.Value;

        Assert.Equal("atharv", nameClaim);
        Assert.Equal("atharv@example.com", emailClaim);
        Assert.Equal(user.Id.ToString(), idClaim);
    }

    [Fact]
    public void GenerateRefreshToken_ShouldProduceCryptographicallyRandomStrings()
    {
        var token1 = _tokenService.GenerateRefreshToken();
        var token2 = _tokenService.GenerateRefreshToken();

        Assert.NotNull(token1);
        Assert.NotNull(token2);
        Assert.NotEqual(token1, token2);
        Assert.True(token1.Length > 40);
    }
}
