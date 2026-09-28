namespace Messaging.Application.Common.Exceptions;

public abstract class AppException : Exception
{
    public int StatusCode { get; }

    protected AppException(string message, int statusCode = 400) : base(message)
    {
        StatusCode = statusCode;
    }
}

public class ValidationException : AppException
{
    public IDictionary<string, string[]> Errors { get; }

    public ValidationException(IDictionary<string, string[]> errors) 
        : base("One or more validation errors occurred.", 400)
    {
        Errors = errors;
    }

    public ValidationException(string field, string error)
        : base(error, 400)
    {
        Errors = new Dictionary<string, string[]>
        {
            { field, new[] { error } }
        };
    }
}

public class UnauthorizedException : AppException
{
    public UnauthorizedException(string message = "Invalid credentials or unauthorized access.") 
        : base(message, 401)
    {
    }
}

public class NotFoundException : AppException
{
    public NotFoundException(string message) : base(message, 404)
    {
    }
}

public class ConflictException : AppException
{
    public ConflictException(string message) : base(message, 409)
    {
    }
}

public class ForbiddenException : AppException
{
    public ForbiddenException(string message = "You do not have permission to perform this action.") 
        : base(message, 403)
    {
    }
}

