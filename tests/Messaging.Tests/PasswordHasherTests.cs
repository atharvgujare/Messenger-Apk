using Messaging.Infrastructure.Security;
using Xunit;

namespace Messaging.Tests;

public class PasswordHasherTests
{
    private readonly BCryptPasswordHasher _hasher = new();

    [Fact]
    public void HashPassword_ShouldGenerateNonEmptyHashDifferentFromPlaintext()
    {
        var password = "SecurePassword123!";
        var hash = _hasher.HashPassword(password);

        Assert.NotNull(hash);
        Assert.NotEmpty(hash);
        Assert.NotEqual(password, hash);
    }

    [Fact]
    public void VerifyPassword_ShouldReturnTrue_ForCorrectPassword()
    {
        var password = "CorrectPassword2026!";
        var hash = _hasher.HashPassword(password);

        var isValid = _hasher.VerifyPassword(password, hash);

        Assert.True(isValid);
    }

    [Fact]
    public void VerifyPassword_ShouldReturnFalse_ForWrongPassword()
    {
        var password = "CorrectPassword2026!";
        var wrongPassword = "WrongPassword999!";
        var hash = _hasher.HashPassword(password);

        var isValid = _hasher.VerifyPassword(wrongPassword, hash);

        Assert.False(isValid);
    }
}
