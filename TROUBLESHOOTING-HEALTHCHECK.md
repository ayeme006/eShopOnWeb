# Post-Mortem: Resolving 503 Service Unavailable in Blue-Green Deployments

## 📝 Executive Summary

During deployment of the eShopWeb application to Azure App Service staging slots, the Smoke Test phase failed consistently with `503 Service Unavailable`.

**Root cause:** the application attempted internal API health checks using `localhost:5200`. In Azure App Service container hosting, `localhost` refers to the container loopback, and the API was not exposed on that port. This produced a `SocketException` (`Cannot assign requested address`).

## 🛠 The Solution: Dynamic Infrastructure-as-Code (IaC)

To resolve this permanently and prevent configuration drift during slot swaps, we implemented dynamic configuration using Bicep.

### 1) Options Pattern mapping

The application uses a POCO class (`BaseUrlConfiguration`) for API endpoints. We mapped JSON hierarchy to Azure environment variables with double underscore syntax.

- JSON key: `baseUrls:apiBase`
- Azure environment variable: `baseUrls__apiBase`

### 2) Dynamic URL generation in Bicep

Instead of hardcoding URLs, the Bicep template computes the correct URI based on deployment slot.

```bicep
var stagingApiUrl = 'https://${appServiceName}-${stagingSlotName}.azurewebsites.net/api/'
var productionApiUrl = 'https://${appServiceName}.azurewebsites.net/api/'
```

### 3) Sticky slot settings

To ensure the staging slot always points to the staging API (even after swap), we implemented `slotConfigNames`. This prevents production URL settings from being overwritten during blue-green promotion.

```bicep
resource slotConfig 'Microsoft.Web/sites/config@2022-03-01' = {
  name: 'slotConfigNames'
  parent: webApp
  properties: {
    appSettingNames: [
      'baseUrls__apiBase'
    ]
  }
}
```

## 🚀 Corrected Pipeline Flow

1. **Infra deployment:** Bicep sets dynamic, sticky `baseUrls__apiBase`.
2. **App deployment:** Docker image is pushed to the staging slot.
3. **Validation:** `/health` is called and resolves the Azure-native URL correctly.
4. **Manual approval:** Administrator reviews healthy status.
5. **Slot swap:** Azure swaps images while sticky settings remain slot-specific.

## 💡 Key Insights for Future Reference

- **Avoid localhost in cloud:** Any `localhost` or fixed internal ports (for example `5200`) in `appsettings.json` must be overridden by cloud environment variables.
- **Use `union()` effectively:** Merge shared settings (telemetry/App Insights) with slot-specific overrides.
- **Deep health checks help:** A failing self-API health check prevented a broken release from reaching production.
- **Apply slot-sticky logic:** Mark environment-dependent settings (URLs, connection strings) in `slotConfigNames`.

## ✅ Final Verification Result

After these changes, the health check returns:

```json
{
  "status": "Healthy",
  "errors": [
    { "key": "api_health_check", "value": "Healthy" },
    { "key": "home_page_health_check", "value": "Healthy" }
  ]
}
```