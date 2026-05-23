using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;
using SecretAdmirer.Auth.Models;

namespace SecretAdmirer.Auth.Services;

public sealed class JwtSettings
{
    public string Issuer { get; set; } = "secretadmirer.auth";
    public string Audience { get; set; } = "secretadmirer.api";
    public string SigningKey { get; set; } = "dev-only-do-not-use-in-production-please-rotate-this-key";
    public int AccessTtlMinutes { get; set; } = 15;
    public int RefreshTtlDays { get; set; } = 30;
}

public sealed class IssuedTokens
{
    public string AccessToken { get; init; } = "";
    public string RefreshToken { get; init; } = "";
    public int ExpiresIn { get; init; }
}

public sealed class JwtTokenService
{
    private readonly JwtSettings _settings;
    private readonly SigningCredentials _credentials;

    public JwtTokenService(JwtSettings settings)
    {
        _settings = settings;
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(settings.SigningKey));
        _credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
    }

    public IssuedTokens Issue(User user)
    {
        var now = DateTime.UtcNow;
        var accessExp = now.AddMinutes(_settings.AccessTtlMinutes);

        var jwt = new JwtSecurityToken(
            issuer: _settings.Issuer,
            audience: _settings.Audience,
            claims: new[]
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
                new Claim(JwtRegisteredClaimNames.UniqueName, user.Handle),
                new Claim("email", user.Email),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
            },
            notBefore: now,
            expires: accessExp,
            signingCredentials: _credentials);

        var access = new JwtSecurityTokenHandler().WriteToken(jwt);
        var refresh = GenerateRefreshToken();
        return new IssuedTokens
        {
            AccessToken = access,
            RefreshToken = refresh,
            ExpiresIn = (int)TimeSpan.FromMinutes(_settings.AccessTtlMinutes).TotalSeconds
        };
    }

    public TokenValidationParameters ValidationParameters()
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_settings.SigningKey));
        return new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = _settings.Issuer,
            ValidAudience = _settings.Audience,
            IssuerSigningKey = key,
            ClockSkew = TimeSpan.FromSeconds(15)
        };
    }

    public DateTime RefreshExpiry() => DateTime.UtcNow.AddDays(_settings.RefreshTtlDays);

    private static string GenerateRefreshToken()
    {
        var bytes = RandomNumberGenerator.GetBytes(48);
        return Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }
}
