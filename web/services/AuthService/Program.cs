using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Auth.Data;
using SecretAdmirer.Auth.Services;
using SecretAdmirer.Shared;

var builder = WebApplication.CreateBuilder(args);

var jwt = new JwtSettings();
builder.Configuration.GetSection("Jwt").Bind(jwt);

builder.Services.AddSingleton(jwt);
builder.Services.AddSingleton<JwtTokenService>();
builder.Services.AddSecretAdmirerBus();

var conn = builder.Configuration.GetConnectionString("AuthDb");
builder.Services.AddDbContext<AuthDbContext>(opt =>
{
    if (string.IsNullOrEmpty(conn))
        opt.UseInMemoryDatabase("auth"); // dev fallback
    else
        opt.UseSqlServer(conn);
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(opt =>
    {
        var tokenSvc = new JwtTokenService(jwt);
        opt.TokenValidationParameters = tokenSvc.ValidationParameters();
    });
builder.Services.AddAuthorization();

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AuthDbContext>();
    if (db.Database.IsRelational())
        db.Database.Migrate();
    else
        db.Database.EnsureCreated();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/health", () => Results.Ok(new { service = "auth", status = "ok" }));

app.Run();
