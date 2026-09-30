using AgoraIO.Rtc;
using Messaging.Application.Common.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Messaging.Infrastructure.Services;

public class AgoraTokenService : IAgoraTokenService
{
    private readonly string _appId;
    private readonly string _appCertificate;
    private readonly ILogger<AgoraTokenService> _logger;

    public AgoraTokenService(IConfiguration configuration, ILogger<AgoraTokenService> logger)
    {
        _logger = logger;
        _appId = configuration["Agora:AppId"] ?? "3cc1781640d94e6daf791b7fca62088e";
        _appCertificate = configuration["Agora:AppCertificate"] ?? "26a908b6ed23406d8ebc99fbd6ad9813";
    }

    public string GetAppId() => _appId;

    public string GenerateRtcToken(string channelName, string userAccount, uint expireSeconds = 86400)
    {
        try
        {
            uint currentTimestamp = (uint)DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            uint privilegeExpireTs = currentTimestamp + expireSeconds;

            var builder = new RtcTokenBuilder();
            string token = builder.BuildToken(
                _appId,
                _appCertificate,
                channelName,
                true,
                privilegeExpireTs
            );

            return token;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to generate Agora RTC token for channel {ChannelName}, user {UserAccount}", channelName, userAccount);
            return string.Empty;
        }
    }
}
