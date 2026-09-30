namespace Messaging.Application.Common.Interfaces;

public interface IAgoraTokenService
{
    string GenerateRtcToken(string channelName, string userAccount, uint expireSeconds = 86400);
    string GetAppId();
}
