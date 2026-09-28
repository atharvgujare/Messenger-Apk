using Messaging.Application.Common.Interfaces;
using Messaging.Application.Services;
using Messaging.Infrastructure.Data;
using Messaging.Infrastructure.Presence;
using Messaging.Infrastructure.Repositories;
using Messaging.Infrastructure.Security;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Messaging.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services, 
        IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection") ?? string.Empty;
        var isLinux = System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Linux);
        var explicitSqlite = string.Equals(configuration["UseSqlite"], "true", StringComparison.OrdinalIgnoreCase) || 
                             string.Equals(Environment.GetEnvironmentVariable("USE_SQLITE"), "true", StringComparison.OrdinalIgnoreCase);

        var useSqlite = explicitSqlite || isLinux || 
                        connectionString.Contains(".db", StringComparison.OrdinalIgnoreCase) ||
                        (connectionString.Contains("Data Source=", StringComparison.OrdinalIgnoreCase) && !connectionString.Contains("Server="));

        if (useSqlite && (string.IsNullOrWhiteSpace(connectionString) || connectionString.Contains("SQLEXPRESS", StringComparison.OrdinalIgnoreCase)))
        {
            connectionString = "Data Source=/app/messenger.db";
        }

        services.AddDbContext<AppDbContext>(options =>
        {
            if (useSqlite)
            {
                options.UseSqlite(connectionString, b =>
                    b.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName));
            }
            else
            {
                options.UseSqlServer(connectionString, b =>
                    b.MigrationsAssembly(typeof(AppDbContext).Assembly.FullName));
            }
        });


        services.AddScoped<IPasswordHasher, BCryptPasswordHasher>();
        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IConversationRepository, ConversationRepository>();
        services.AddScoped<IMessageRepository, MessageRepository>();
        services.AddScoped<IEmailService, Services.EmailService>();
        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IUserService, UserService>();
        services.AddScoped<IChatService, ChatService>();
        services.AddSingleton<IPresenceTracker, PresenceTracker>();

        return services;
    }
}

