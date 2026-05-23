using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

var jwtKey = builder.Configuration["Jwt:SigningKey"] ?? "REPLACE-WITH-A-256-BIT-SECRET-IN-PRODUCTION";
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        opt.RequireHttpsMetadata = false;
        opt.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"] ?? "secretadmirer.auth",
            ValidAudience = builder.Configuration["Jwt:Audience"] ?? "secretadmirer.api",
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

// Decorate each forwarded request with the resolved user id so downstream
// services don't have to revalidate the JWT.
app.Use(async (ctx, next) =>
{
    if (ctx.User.Identity?.IsAuthenticated == true)
    {
        var sub = ctx.User.FindFirst("sub")?.Value
                  ?? ctx.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value;
        if (!string.IsNullOrEmpty(sub)) ctx.Request.Headers["X-User-Id"] = sub;
        var handle = ctx.User.FindFirst("unique_name")?.Value;
        if (!string.IsNullOrEmpty(handle)) ctx.Request.Headers["X-User-Handle"] = handle;
    }
    await next();
});

app.MapGet("/health", () => Results.Ok(new
{
    service = "gateway",
    status = "ok",
    routes = new[] { "/auth/*", "/profile/*", "/messages/*", "/notifications/*", "/sagas/*" }
}));

app.MapReverseProxy();
app.Run();
