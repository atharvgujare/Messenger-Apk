using System.Text;
using Messaging.Api.Hubs;
using Messaging.Api.Middlewares;
using Messaging.Application.Common.Interfaces;
using Messaging.Domain.Entities;
using Messaging.Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// Render dynamic PORT binding (if PORT is set by Render)
var port = Environment.GetEnvironmentVariable("PORT");
if (!string.IsNullOrEmpty(port))
{
    builder.WebHost.UseUrls($"http://+:{port}");
}

// 1. Add Infrastructure Services (EF Core, Repositories, AuthService, PasswordHasher, TokenService)
builder.Services.AddInfrastructureServices(builder.Configuration);

// 2. Add JWT Authentication
var jwtSecret = builder.Configuration["JwtSettings:Secret"] 
    ?? "MessengerSuperSecretKeyForJwtAuthenticationTokenSigning2026!";
var jwtIssuer = builder.Configuration["JwtSettings:Issuer"] ?? "MessengerApi";
var jwtAudience = builder.Configuration["JwtSettings:Audience"] ?? "MessengerClients";

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = false;
    options.SaveToken = true;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecret)),
        ValidateIssuer = true,
        ValidIssuer = jwtIssuer,
        ValidateAudience = true,
        ValidAudience = jwtAudience,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero
    };

    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
    };
});

builder.Services.AddAuthorization();

// 3. Add CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.SetIsOriginAllowed(_ => true)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

// 4. Add SignalR
builder.Services.AddSignalR();

// 5. Add Controllers
builder.Services.AddControllers();

// 6. Swagger / OpenAPI Configuration
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Messenger API",
        Version = "v1",
        Description = "Production Real-Time Messaging API Engine"
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Example: \"Authorization: Bearer {token}\"",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
app.UseForwardedHeaders(new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
});

app.UseMiddleware<ExceptionHandlingMiddleware>();

app.UseCors("AllowAll");
app.UseStaticFiles();

// Auto-migrate or ensure database exists on startup (crucial for Docker / Render)
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var context = services.GetRequiredService<Messaging.Infrastructure.Data.AppDbContext>();
        if (context.Database.IsSqlite())
        {
            context.Database.EnsureCreated();

            // Safe schema migrations for SQLite databases created prior to new feature additions
            try
            {
                context.Database.ExecuteSqlRaw(@"
                    CREATE TABLE IF NOT EXISTS ""UserFollows"" (
                        ""Id"" TEXT NOT NULL CONSTRAINT ""PK_UserFollows"" PRIMARY KEY,
                        ""FollowerId"" TEXT NOT NULL,
                        ""FolloweeId"" TEXT NOT NULL,
                        ""Status"" INTEGER NOT NULL,
                        ""CreatedAtUtc"" TEXT NOT NULL,
                        CONSTRAINT ""FK_UserFollows_Users_FolloweeId"" FOREIGN KEY (""FolloweeId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE,
                        CONSTRAINT ""FK_UserFollows_Users_FollowerId"" FOREIGN KEY (""FollowerId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE
                    );
                    CREATE INDEX IF NOT EXISTS ""IX_UserFollows_FolloweeId"" ON ""UserFollows"" (""FolloweeId"");
                    CREATE INDEX IF NOT EXISTS ""IX_UserFollows_FollowerId_FolloweeId"" ON ""UserFollows"" (""FollowerId"", ""FolloweeId"");

                    CREATE TABLE IF NOT EXISTS ""Snaps"" (
                        ""Id"" TEXT NOT NULL CONSTRAINT ""PK_Snaps"" PRIMARY KEY,
                        ""SenderId"" TEXT NOT NULL,
                        ""RecipientId"" TEXT NOT NULL,
                        ""MediaUrl"" TEXT NOT NULL,
                        ""Caption"" TEXT NULL,
                        ""TimerSeconds"" INTEGER NOT NULL,
                        ""IsViewOnce"" INTEGER NOT NULL,
                        ""CreatedAtUtc"" TEXT NOT NULL,
                        ""ExpiresAtUtc"" TEXT NOT NULL,
                        ""OpenedAtUtc"" TEXT NULL,
                        ""IsOpened"" INTEGER NOT NULL,
                        CONSTRAINT ""FK_Snaps_Users_RecipientId"" FOREIGN KEY (""RecipientId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE,
                        CONSTRAINT ""FK_Snaps_Users_SenderId"" FOREIGN KEY (""SenderId"") REFERENCES ""Users"" (""Id"") ON DELETE CASCADE
                    );
                    CREATE INDEX IF NOT EXISTS ""IX_Snaps_RecipientId"" ON ""Snaps"" (""RecipientId"");
                    CREATE INDEX IF NOT EXISTS ""IX_Snaps_SenderId"" ON ""Snaps"" (""SenderId"");

                    CREATE TABLE IF NOT EXISTS ""SnapStreaks"" (
                        ""Id"" TEXT NOT NULL CONSTRAINT ""PK_SnapStreaks"" PRIMARY KEY,
                        ""User1Id"" TEXT NOT NULL,
                        ""User2Id"" TEXT NOT NULL,
                        ""StreakCount"" INTEGER NOT NULL,
                        ""LastSnapUser1Utc"" TEXT NULL,
                        ""LastSnapUser2Utc"" TEXT NULL,
                        ""LastStreakIncrementUtc"" TEXT NULL
                    );
                    CREATE INDEX IF NOT EXISTS ""IX_SnapStreaks_User1Id_User2Id"" ON ""SnapStreaks"" (""User1Id"", ""User2Id"");
                ");

                try
                {
                    context.Database.ExecuteSqlRaw(@"ALTER TABLE ""UserProfiles"" ADD COLUMN ""IsPrivate"" INTEGER NOT NULL DEFAULT 0;");
                }
                catch { /* Column already exists */ }
            }
            catch { /* Migrations completed or already up to date */ }
        }
        else
        {
            try
            {
                context.Database.Migrate();
            }
            catch
            {
                context.Database.EnsureCreated();
            }
        }

        // Seed default accounts if database has no users
        if (!context.Users.Any())
        {
            var hasher = services.GetRequiredService<IPasswordHasher>();
            var atharv = new User
            {
                Id = Guid.NewGuid(),
                Username = "atharv",
                Email = "atharv@example.com",
                PasswordHash = hasher.HashPassword("Password123!"),
                IsActive = true,
                IsEmailVerified = true,
                CreatedAtUtc = DateTime.UtcNow,
                Profile = new UserProfile
                {
                    DisplayName = "Atharv Gujare",
                    Bio = "Building real-time Messenger 🚀",
                    IsOnline = false
                }
            };

            var rahul = new User
            {
                Id = Guid.NewGuid(),
                Username = "rahul",
                Email = "rahul@example.com",
                PasswordHash = hasher.HashPassword("Password123!"),
                IsActive = true,
                IsEmailVerified = true,
                CreatedAtUtc = DateTime.UtcNow,
                Profile = new UserProfile
                {
                    DisplayName = "Rahul Sharma",
                    Bio = "Hey there! I am using Messenger.",
                    IsOnline = false
                }
            };

            context.Users.AddRange(atharv, rahul);
            context.SaveChanges();
        }
    }
    catch (Exception ex)
    {
        var logger = services.GetRequiredService<ILogger<Program>>();
        logger.LogWarning(ex, "Database migration/initialization notice.");
    }
}

if (app.Environment.IsDevelopment() || builder.Configuration.GetValue<bool>("EnableSwagger", true))
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Messenger API v1");
        c.RoutePrefix = "swagger";
    });
}

app.UseAuthentication();
app.UseAuthorization();

// Root endpoint - shows API status in browser
app.MapGet("/", () => Results.Ok(new 
{ 
    app = "Messenger API",
    status = "Online 🚀",
    version = "1.0.0",
    docs = "/swagger",
    health = "/health",
    timestamp = DateTime.UtcNow 
}));

// Render Health Check endpoint
app.MapGet("/health", () => Results.Ok(new 
{ 
    status = "healthy", 
    service = "Messenger API",
    timestamp = DateTime.UtcNow 
}));

app.MapControllers();
app.MapHub<ChatHub>("/hubs/chat");

app.Run();
