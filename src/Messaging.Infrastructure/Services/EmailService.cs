using System.Net;
using System.Net.Http.Json;
using System.Net.Mail;
using Messaging.Application.Common.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Messaging.Infrastructure.Services;

public class EmailService : IEmailService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<EmailService> _logger;
    private static readonly HttpClient _httpClient = new();

    public EmailService(
        IConfiguration configuration, 
        ILogger<EmailService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SendOtpEmailAsync(string toEmail, string otpCode, CancellationToken ct = default)
    {
        var subject = $"Your Messenger Verification Code: {otpCode}";
        var htmlBody = $@"
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
</html>";

        await SendHtmlEmailAsync(toEmail, subject, htmlBody, ct);
    }

    public async Task SendPasswordResetEmailAsync(string toEmail, string otpCode, CancellationToken ct = default)
    {
        var subject = $"Reset Your Messenger Password: {otpCode}";
        var htmlBody = $@"
<!DOCTYPE html>
<html>
<body style='font-family: Arial, sans-serif; background-color: #f4f4f4; padding: 20px;'>
  <div style='max-width: 480px; margin: 0 auto; background: #ffffff; padding: 30px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);'>
    <h2 style='color: #00A884; margin-bottom: 8px;'>Password Reset Request</h2>
    <p style='color: #555; font-size: 15px;'>We received a request to reset your Messenger account password. Use the verification code below:</p>
    <div style='background: #f0fdf4; border: 2px dashed #00A884; border-radius: 8px; padding: 18px; text-align: center; margin: 24px 0;'>
      <span style='font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #111b21;'>{otpCode}</span>
    </div>
    <p style='color: #888; font-size: 13px;'>This code will expire in 10 minutes. If you did not request a password reset, please secure your account immediately.</p>
  </div>
</body>
</html>";

        await SendHtmlEmailAsync(toEmail, subject, htmlBody, ct);
    }

    private async Task SendHtmlEmailAsync(string toEmail, string subject, string htmlBody, CancellationToken ct)
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
        _logger.LogInformation(">>> [DISPATCHING EMAIL] <<<");
        _logger.LogInformation(">>> To: {Email}", toEmail);
        _logger.LogInformation(">>> Subject: {Subject}", subject);
        _logger.LogInformation("=================================================");

        // 1. Try Brevo REST API over HTTPS (port 443) if configured
        var brevoApiKey = _configuration["Brevo:ApiKey"] ?? Environment.GetEnvironmentVariable("BREVO_API_KEY");
        if (!string.IsNullOrWhiteSpace(brevoApiKey))
        {
            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.brevo.com/v3/smtp/email");
                request.Headers.Add("api-key", brevoApiKey);
                var payload = new
                {
                    sender = new { name = "Messenger", email = fromEmail },
                    to = new[] { new { email = toEmail } },
                    subject = subject,
                    htmlContent = htmlBody
                };
                request.Content = JsonContent.Create(payload);
                var response = await _httpClient.SendAsync(request, ct);
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation(">>> [EMAIL SENT VIA BREVO HTTPS API] to {Email}", toEmail);
                    return;
                }
                var err = await response.Content.ReadAsStringAsync(ct);
                _logger.LogWarning("Brevo API call failed: {Error}", err);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to send email via Brevo API.");
            }
        }

        // 2. Try Resend REST API over HTTPS (port 443) if configured
        var resendApiKey = _configuration["Resend:ApiKey"] ?? Environment.GetEnvironmentVariable("RESEND_API_KEY");
        if (!string.IsNullOrWhiteSpace(resendApiKey))
        {
            try
            {
                using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.resend.com/emails");
                request.Headers.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", resendApiKey);
                var payload = new
                {
                    from = "Messenger <onboarding@resend.dev>",
                    to = new[] { toEmail },
                    subject = subject,
                    html = htmlBody
                };
                request.Content = JsonContent.Create(payload);
                var response = await _httpClient.SendAsync(request, ct);
                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation(">>> [EMAIL SENT VIA RESEND HTTPS API] to {Email}", toEmail);
                    return;
                }
                var err = await response.Content.ReadAsStringAsync(ct);
                _logger.LogWarning("Resend API call failed: {Error}", err);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to send email via Resend API.");
            }
        }

        // 3. Fallback to SMTP (Works locally or on cloud providers without port 587 blocks)
        try
        {
            int port = int.TryParse(smtpPortStr, out var p) ? p : 587;
            using var client = new SmtpClient(smtpHost, port)
            {
                EnableSsl = true,
                Credentials = new NetworkCredential(smtpUser, smtpPass),
                Timeout = 3000
            };

            var mail = new MailMessage
            {
                From = new MailAddress(fromEmail, "Messenger"),
                Subject = subject,
                Body = htmlBody,
                IsBodyHtml = true
            };
            mail.To.Add(toEmail);

            using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(3));
            using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(ct, timeoutCts.Token);
            await client.SendMailAsync(mail, linkedCts.Token);
            _logger.LogInformation(">>> [EMAIL SENT SUCCESSFULLY VIA SMTP] to {Email}", toEmail);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to send SMTP email to {Email}. Notice: Render Free Tier blocks outbound SMTP ports 25/465/587.", toEmail);
        }
    }
}
