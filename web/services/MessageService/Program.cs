using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using SecretAdmirer.Messages.Data;
using SecretAdmirer.Messages.Services;
using SecretAdmirer.Shared;

var builder = WebApplication.CreateBuilder(args);

var conn = builder.Configuration.GetConnectionString("MessageDb");
builder.Services.AddDbContext<MessageDbContext>(opt =>
{
    if (string.IsNullOrEmpty(conn)) opt.UseInMemoryDatabase("messages");
    else opt.UseSqlServer(conn);
});

builder.Services.AddSecretAdmirerBus();
builder.Services.AddScoped<SendMessageSaga>();

builder.Services.AddHttpClient<HandleResolver>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["Services:Profile"] ?? "http://localhost:5102");
});

var jwtKey = builder.Configuration["Jwt:SigningKey"] ?? "REPLACE-WITH-A-256-BIT-SECRET-IN-PRODUCTION";
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
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
builder.Services.AddControllers();
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<MessageDbContext>();
    if (db.Database.IsRelational()) db.Database.Migrate();
    else db.Database.EnsureCreated();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/health", () => Results.Ok(new { service = "messages", status = "ok" }));
app.Run();
