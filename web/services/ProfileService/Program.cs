using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using SecretAdmirer.Profile.Data;
using SecretAdmirer.Profile.Services;
using SecretAdmirer.Shared;

var builder = WebApplication.CreateBuilder(args);

var conn = builder.Configuration.GetConnectionString("ProfileDb");
builder.Services.AddDbContext<ProfileDbContext>(opt =>
{
    if (string.IsNullOrEmpty(conn)) opt.UseInMemoryDatabase("profile");
    else opt.UseSqlServer(conn);
});

builder.Services.AddSecretAdmirerBus();
builder.Services.AddHostedService<ProfileProvisioner>();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

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

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ProfileDbContext>();
    if (db.Database.IsRelational()) db.Database.Migrate();
    else db.Database.EnsureCreated();
}

var uploads = builder.Configuration["Uploads:Path"] ?? "./uploads";
Directory.CreateDirectory(uploads);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(Path.GetFullPath(uploads)),
    RequestPath = builder.Configuration["Uploads:PublicBase"] ?? "/uploads"
});

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/health", () => Results.Ok(new { service = "profile", status = "ok" }));
app.Run();
