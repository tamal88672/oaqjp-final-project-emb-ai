using Microsoft.EntityFrameworkCore;
using SecretAdmirer.Saga.Data;
using SecretAdmirer.Saga.Services;
using SecretAdmirer.Shared;

var builder = WebApplication.CreateBuilder(args);

var conn = builder.Configuration.GetConnectionString("SagaDb");
builder.Services.AddDbContext<SagaDbContext>(opt =>
{
    if (string.IsNullOrEmpty(conn)) opt.UseInMemoryDatabase("saga");
    else opt.UseSqlServer(conn);
});

builder.Services.AddSecretAdmirerBus();
builder.Services.AddHostedService<SagaObserver>();
builder.Services.AddControllers();

builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<SagaDbContext>();
    if (db.Database.IsRelational()) db.Database.Migrate();
    else db.Database.EnsureCreated();
}
app.UseCors();
app.MapControllers();
app.MapGet("/health", () => Results.Ok(new { service = "saga", status = "ok" }));
app.Run();
