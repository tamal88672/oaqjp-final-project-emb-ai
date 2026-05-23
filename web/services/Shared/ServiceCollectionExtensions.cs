using Microsoft.Extensions.DependencyInjection;
using SecretAdmirer.Shared.MessageBus;

namespace SecretAdmirer.Shared;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddSecretAdmirerBus(this IServiceCollection services)
    {
        services.AddSingleton<IMessageBus, InMemoryMessageBus>();
        return services;
    }
}
