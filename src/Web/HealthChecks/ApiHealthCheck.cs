using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using BlazorShared;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Options;

namespace Microsoft.eShopWeb.Web.HealthChecks;

public class ApiHealthCheck : IHealthCheck
{
    private readonly BaseUrlConfiguration _baseUrlConfiguration;

    public ApiHealthCheck(IOptions<BaseUrlConfiguration> baseUrlConfiguration)
    {
        _baseUrlConfiguration = baseUrlConfiguration.Value;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default(CancellationToken))
    {
        string myUrl = _baseUrlConfiguration.ApiBase + "catalog-items";
        var client = new HttpClient();
        var response = await client.GetAsync(myUrl);

        //This is a very basic check just to see if the API is responding and returning expected content. 
        // In production, you would want to make this more robust and check for specific status codes, response times, etc.
        // I API responds with 200 Ok, the service is considered healthy. If it responds with any other status code, it's considered unhealthy.
        if (response.IsSuccessStatusCode)
        {
            return HealthCheckResult.Healthy("The check indicates a healthy result.");
        }

        var pageContents = await response.Content.ReadAsStringAsync();
        if (pageContents.Contains(".NET Bot Black Sweatshirt"))
        {
            return HealthCheckResult.Healthy("The check indicates a healthy result.");
        }

        return HealthCheckResult.Unhealthy("The check indicates an unhealthy result.");
    }
}
