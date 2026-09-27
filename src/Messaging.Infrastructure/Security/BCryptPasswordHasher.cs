using Messaging.Application.Common.Interfaces;

namespace Messaging.Infrastructure.Security;

public class BCryptPasswordHasher : IPasswordHasher
{
    public string HashPassword(string password)
    {
        return BCrypt.Net.BCrypt.EnhancedHashPassword(password, workFactor: 11);
    }

    public bool VerifyPassword(string password, string passwordHash)
    {
        try
        {
            return BCrypt.Net.BCrypt.EnhancedVerify(password, passwordHash);
        }
        catch
        {
            return false;
        }
    }
}
