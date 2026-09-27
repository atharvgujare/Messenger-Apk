namespace Messaging.Domain.Enums;

public enum MessageType : byte
{
    Text = 1,
    Image = 2,
    Video = 3,
    File = 4,
    Voice = 5,
    Location = 6,
    Contact = 7,
    System = 8
}
