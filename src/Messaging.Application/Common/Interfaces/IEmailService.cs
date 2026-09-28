namespace Messaging.Application.Common.Interfaces;

public interface IEmailService
{
    Task SendOtpEmailAsync(string toEmail, string otpCode, CancellationToken ct = default);
    Task SendPasswordResetEmailAsync(string toEmail, string otpCode, CancellationToken ct = default);
}
