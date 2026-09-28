using System.Net;
using System.Net.Mail;
using Messaging.Application.Common.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Messaging.Infrastructure.Services;

public class EmailService : IEmailService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;

    public EmailService(IConfiguration configuration, ILogger<EmailService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendOtpEmailAsync(string toEmail, string otpCode, CancellationToken ct = default)
    {
        var smtpHost = _configuration["Smtp:Host"] 
            ?? Environment.GetEnvironmentVariable("SMTP_HOST") 
            ?? "smtp.gmail.com";

        var smtpPortStr = _configuration["Smtp:Port"] 
            ?? Environment.GetEnvironmentVariable("SMTP_PORT") 
            ?? "587";

        var smtpUser = _configuration["Smtp:Username"] 
            ?? Environment.GetEnvironmentVariable("SMTP_USERNAME") 
            ?? "atharvgujare.riyality@gmail.com";

        var smtpPass = _configuration["Smtp:Password"] 
            ?? Environment.GetEnvironmentVariable("SMTP_PASSWORD") 
            ?? "ydiq yvyu ucrr xlgr";

        var fromEmail = _configuration["Smtp:FromEmail"] 
            ?? Environment.GetEnvironmentVariable("SMTP_FROM_EMAIL") 
            ?? "atharvgujare.riyality@gmail.com";

        _logger.LogInformation("=================================================");
        _logger.LogInformation(">>> [EMAIL OTP VERIFICATION] <<<");
        _logger.LogInformation(">>> Recipient: {Email}", toEmail);
        _logger.LogInformation(">>> Verification Code: {Code}", otpCode);
        _logger.LogInformation("=================================================");

        if (string.IsNullOrWhiteSpace(smtpHost) || string.IsNullOrWhiteSpace(smtpUser))
        {
            // Development or unconfigured SMTP mode - Code is safely logged above
            return;
        }

        try
        {
            int port = int.TryParse(smtpPortStr, out var p) ? p : 587;
            using var client = new SmtpClient(smtpHost, port)
            {
                EnableSsl = true,
                Credentials = new NetworkCredential(smtpUser, smtpPass)
            };

            var mail = new MailMessage
            {
                From = new MailAddress(fromEmail, "Messenger"),
                Subject = $"Your Messenger Verification Code: {otpCode}",
                Body = $@"
<!DOCTYPE html>
<html>
<body style='font-family: Arial, sans-serif; background-color: #f4f4f4; padding: 20px;'>
  <div style='max-width: 480px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color: #00A884; margin-bottom: 8px;'>Messenger Verification</h2>
    <p style='color: #555; font-size: 15px;'>Welcome! Use the one-time code below to verify your email address:</p>
    <div style='background: #f0fdf4; border: 2px dashed #00A884; border-radius: 8px; padding: 18px; text-align: center; margin: 24px 0;'>
      <span style='font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #111b21;'>{otpCode}</span>
    </div>
    <p style='color: #888; font-size: 13px;'>This code will expire in 10 minutes. If you did not request this, please ignore this email.</p>
  </div>
</body>
</html>",
                IsBodyHtml = true
            };
            mail.To.Add(toEmail);

            await client.SendMailAsync(mail, ct);
            _logger.LogInformation(">>> [EMAIL SENT SUCCESSFULLY] to {Email}", toEmail);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to send SMTP email to {Email}.", toEmail);
            throw new InvalidOperationException($"Could not send verification email to {toEmail}: {ex.Message}", ex);
        }
    }
}
