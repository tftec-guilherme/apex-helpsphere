metadata description = 'Creates an Azure Container Apps Auth Config using Microsoft Entra as Identity Provider.'

@description('The name of the container apps resource within the current resource group scope')
param name string

param additionalScopes array = []
param additionalAllowedAudiences array = []
param allowedApplications array = []

param clientAppId string = ''
param serverAppId string = ''
@secure()
param clientSecretSettingName string = ''
param authenticationIssuerUri string = ''
param enableUnauthenticatedAccess bool = false
param blobContainerUri string = ''
param appIdentityResourceId string = ''

// .default must be the 1st scope for On-Behalf-Of-Flow combined consent to work properly
// Please see https://learn.microsoft.com/entra/identity-platform/v2-oauth2-on-behalf-of-flow#default-and-combined-consent
var requiredScopes = [ 'api://${serverAppId}/.default', 'openid', 'profile', 'email', 'offline_access' ]
// Easy Auth must accept BOTH audience formats:
//   - 'api://${serverAppId}' (Microsoft Identity Platform v1 / App ID URI)
//   - serverAppId             (Microsoft Identity Platform v2 emits bare GUID as `aud` claim)
// See Surpresa pedagogica #46 (Story 06.10 AC3) — runtime fix that the recording applied
// via `az containerapp auth microsoft update --allowed-audiences` is now permanent here.
var requiredAudiences = [ 'api://${serverAppId}', serverAppId ]

resource app 'Microsoft.App/containerApps@2023-05-01' existing = {
  name: name
}

resource auth 'Microsoft.App/containerApps/authConfigs@2024-10-02-preview' = {
  parent: app
  name: 'current'
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      redirectToProvider: 'azureactivedirectory'
      unauthenticatedClientAction: enableUnauthenticatedAccess ? 'AllowAnonymous' : 'RedirectToLoginPage'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: clientAppId
          clientSecretSettingName: clientSecretSettingName
          openIdIssuer: authenticationIssuerUri
        }
        login: {
          loginParameters: [ 'scope=${join(union(requiredScopes, additionalScopes), ' ')}' ]
        }
        validation: {
          allowedAudiences: union(requiredAudiences, additionalAllowedAudiences)
          defaultAuthorizationPolicy: {
            allowedApplications: allowedApplications
          }
        }
      }
    }
    login: {
      // https://learn.microsoft.com/azure/container-apps/token-store
      tokenStore: {
        enabled: true
        azureBlobStorage: {
          blobContainerUri: blobContainerUri
          managedIdentityResourceId: appIdentityResourceId
        }
      }
    }
  }
}
