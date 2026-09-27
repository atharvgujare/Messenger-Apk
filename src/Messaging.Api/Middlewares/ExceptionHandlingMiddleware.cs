using System.Net;
using System.Text.Json;
using Messaging.Application.Common.Exceptions;

namespace Messaging.Api.Middlewares;

public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        var statusCode = HttpStatusCode.InternalServerError;
        var response = new Dictionary<string, object?>
        {
            ["timestamp"] = DateTime.UtcNow,
            ["path"] = context.Request.Path.Value
        };

        switch (exception)
        {
            case ValidationException valEx:
                statusCode = HttpStatusCode.BadRequest;
                response["type"] = "https://messenger.app/errors/validation";
                response["title"] = "Validation Error";
                response["status"] = (int)statusCode;
                response["detail"] = valEx.Message;
                response["errors"] = valEx.Errors;
                break;

            case UnauthorizedException unauthEx:
                statusCode = HttpStatusCode.Unauthorized;
                response["type"] = "https://messenger.app/errors/unauthorized";
                response["title"] = "Unauthorized";
                response["status"] = (int)statusCode;
                response["detail"] = unauthEx.Message;
                break;

            case NotFoundException notFoundEx:
                statusCode = HttpStatusCode.NotFound;
                response["type"] = "https://messenger.app/errors/not-found";
                response["title"] = "Resource Not Found";
                response["status"] = (int)statusCode;
                response["detail"] = notFoundEx.Message;
                break;

            case ConflictException conflictEx:
                statusCode = HttpStatusCode.Conflict;
                response["type"] = "https://messenger.app/errors/conflict";
                response["title"] = "Conflict";
                response["status"] = (int)statusCode;
                response["detail"] = conflictEx.Message;
                break;

            default:
                _logger.LogError(exception, "Unhandled exception occurred while processing request.");
                response["type"] = "https://messenger.app/errors/internal-server-error";
                response["title"] = "Internal Server Error";
                response["status"] = (int)statusCode;
                response["detail"] = "An unexpected error occurred. Please try again later.";
                break;
        }

        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)statusCode;

        var json = JsonSerializer.Serialize(response, new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        await context.Response.WriteAsync(json);
    }
}
