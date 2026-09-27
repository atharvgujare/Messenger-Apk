namespace Messaging.Domain.Enums;

public enum MessageStatus : byte
{
    Sending = 0,
    Sent = 1,
    Delivered = 2,
    Read = 3,
    Failed = 4
}
