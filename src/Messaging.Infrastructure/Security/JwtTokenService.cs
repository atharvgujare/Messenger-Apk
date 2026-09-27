using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Messaging.Application.Common.Interfaces;
using Messaging.Domain.Entities;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace Messaging.Infrastructure.Security;

public class JwtTokenService : IJwtTokenService
{
    private readonly IConfiguration _configuration;
    private readonly SymmetricSecurityKey _key;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _accessTokenExpirationMinutes;

    public JwtTokenService(IConfiguration configuration)
    {
        _configuration = configuration;
        var secret = _configuration["JwtSettings:Secret"] 
            ?? "MessengerSuperSecretKeyForJwtAuthenticationTokenSigning2026!";
        _key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        _issuer = _configuration["JwtSettings:Issuer"] ?? "MessengerApi";
        _audience = _configuration["JwtSettings:Audience"] ?? "MessengerClients";
        _accessTokenExpirationMinutes = int.TryParse(_configuration["JwtSettings:AccessTokenExpirationMinutes"], out var mins) 
            ? mins : 60;
    }

    public (string Token, DateTime ExpiresAtUtc) GenerateAccessToken(User user)
    {
        var expiresAtUtc = DateTime.UtcNow.AddMinutes(_accessTokenExpirationMinutes);

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.Username),
            new(ClaimTypes.Email, user.Email),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var creds = new SigningCredentials(_key, SecurityAlgorithms.HmacSha256);

        var tokenDescriptor = new SecurityTokenDescriptor
        {
            Subject = new ClaimsIdentity(claims),
            Expires = expiresAtUtc,
            Issuer = _issuer,
            Audience = _audience,
            SigningCredentials = creds
        };

        var tokenHandler = new JwtSecurityTokenHandler();
        var token = tokenHandler.CreateToken(tokenDescriptor);

        return (tokenHandler.WriteToken(token), expiresAtUtc);
    }

    public string GenerateRefreshToken()
    {
        var randomNumber = new byte[64];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(randomNumber);
        return Convert.ToBase64String(randomNumber);
    }

    public ClaimsPrincipal? GetPrincipalFromToken(string token, bool validateLifetime = false)
    {
        var tokenHandler = new JwtSecurityTokenHandler();
        var tokenValidationParameters = new TokenValidationParameters
        {
            ValidateAudience = true,
            ValidAudience = _audience,
            ValidateIssuer = true,
            ValidIssuer = _issuer,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = _key,
            ValidateLifetime = validateLifetime,
            ClockSkew = TimeSpan.Zero
        };

        try
        {
            var principal = tokenHandler.ValidateToken(token, tokenValidationParameters, out var securityToken);
            if (securityToken is not JwtSecurityToken jwtSecurityToken || 
                !jwtSecurityToken.Header.Alg.Equals(SecurityAlgorithms.HmacSha256, StringComparison.InvariantCultureIgnoreCase))
            {
                return null;
            }

            return principal;
        }
        catch
        {
            return null;
        }
    }
}
