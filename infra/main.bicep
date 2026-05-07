targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
// microsoft.insights/components has restricted regions
@allowed([
  'eastus'
  'southcentralus'
  'northeurope'
  'westeurope'
  'southeastasia'
  'westus2'
  'uksouth'
  'canadacentral'
  'centralindia'
  'japaneast'
  'australiaeast'
  'koreacentral'
  'francecentral'
  'centralus'
  'eastus2'
  'eastasia'
  'westus'
  'southafricanorth'
  'northcentralus'
  'brazilsouth'
  'switzerlandnorth'
  'norwayeast'
  'norwaywest'
  'australiasoutheast'
  'australiacentral2'
  'germanywestcentral'
  'switzerlandwest'
  'uaecentral'
  'ukwest'
  'japanwest'
  'brazilsoutheast'
  'uaenorth'
  'australiacentral'
  'southindia'
  'westus3'
  'koreasouth'
  'swedencentral'
  'canadaeast'
  'jioindiacentral'
  'jioindiawest'
  'qatarcentral'
  'southafricawest'
  'germanynorth'
  'polandcentral'
  'israelcentral'
  'italynorth'
  'mexicocentral'
  'spaincentral'
  'newzealandnorth'
  'chilecentral'
  'indonesiacentral'
  'malaysiawest'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

param appServicePlanName string = '' // Set in main.parameters.json
param backendServiceName string = '' // Set in main.parameters.json
param resourceGroupName string = '' // Set in main.parameters.json

param applicationInsightsDashboardName string = '' // Set in main.parameters.json
param applicationInsightsName string = '' // Set in main.parameters.json
param logAnalyticsName string = '' // Set in main.parameters.json

param searchServiceName string = '' // Set in main.parameters.json
param searchServiceResourceGroupName string = '' // Set in main.parameters.json
param searchServiceLocation string = '' // Set in main.parameters.json
// The free tier does not support managed identity (required) or semantic search (optional)
@allowed(['free', 'basic', 'standard', 'standard2', 'standard3', 'storage_optimized_l1', 'storage_optimized_l2'])
param searchServiceSkuName string // Set in main.parameters.json
param searchIndexName string // Set in main.parameters.json
param knowledgeBaseName string = useAgenticKnowledgeBase ? '${searchIndexName}-agent-upgrade' : ''
param searchQueryLanguage string // Set in main.parameters.json
param searchQuerySpeller string // Set in main.parameters.json
param searchServiceSemanticRankerLevel string // Set in main.parameters.json
param searchFieldNameEmbedding string // Set in main.parameters.json
var actualSearchServiceSemanticRankerLevel = (searchServiceSkuName == 'free')
  ? 'disabled'
  : searchServiceSemanticRankerLevel
param searchServiceQueryRewriting string // Set in main.parameters.json
param storageAccountName string = '' // Set in main.parameters.json
param storageResourceGroupName string = '' // Set in main.parameters.json
param storageResourceGroupLocation string = location
param storageContainerName string = 'content'
param storageSkuName string // Set in main.parameters.json

param defaultReasoningEffort string // Set in main.parameters.json
@description('Controls the default retrieval reasoning effort for agentic retrieval (minimal, low, or medium).')
param defaultRetrievalReasoningEffort string = 'minimal'
param useAgenticKnowledgeBase bool // Set in main.parameters.json

param userStorageAccountName string = ''
param userStorageContainerName string = 'user-content'

param tokenStorageContainerName string = 'tokens'

param imageStorageContainerName string = 'images'

param appServiceSkuName string // Set in main.parameters.json

@allowed(['azure', 'openai', 'azure_custom'])
param openAiHost string // Set in main.parameters.json
param isAzureOpenAiHost bool = startsWith(openAiHost, 'azure')
param deployAzureOpenAi bool = openAiHost == 'azure'
param azureOpenAiCustomUrl string = ''
@secure()
param azureOpenAiApiKey string = ''
param azureOpenAiDisableKeys bool = true
param openAiServiceName string = ''
param openAiResourceGroupName string = ''

param speechServiceResourceGroupName string = ''
param speechServiceLocation string = ''
param speechServiceName string = ''
param speechServiceSkuName string // Set in main.parameters.json
param speechServiceVoice string = ''
param useMultimodal bool = false
param useEval bool = false
param useCloudIngestion bool = false

@description('Restore soft-deleted Cognitive Services accounts instead of creating new ones. Set to true after running azd down.')
param restoreCognitiveServices bool = false
param useCloudIngestionAcls bool = false
@description('Use an existing ADLS Gen2 storage account instead of provisioning a new one')
param useExistingAdlsStorage bool = false
// Must be specified when useExistingAdlsStorage is true. Bicep assert is experimental so we can't validate at compile-time yet.
param adlsStorageAccountName string = ''
param adlsStorageResourceGroupName string = ''

@allowed(['free', 'provisioned', 'serverless'])
param cosmosDbSkuName string // Set in main.parameters.json
param cosmodDbResourceGroupName string = ''
param cosmosDbLocation string = ''
param cosmosDbAccountName string = ''
param cosmosDbThroughput int = 400
param chatHistoryDatabaseName string = 'chat-database'

// HelpSphere — Story 06.5a Sessão 2.3 (Azure SQL Server)
param useSqlServer bool = true
param sqlServerName string = ''
param sqlDatabaseName string = 'helpsphere'
@description('Display name do grupo Entra que será AAD admin do SQL Server (turnover-resilient).')
param sqlAadAdminGroupName string = ''
@description('Object ID do grupo Entra acima.')
param sqlAadAdminGroupObjectId string = ''
@description('Carregar seeds (5 tenants Apex + 50 tickets pt-BR + 70 comments) automaticamente no postprovision.')
param loadSeedData bool = true

// =============================================================================
// SAAS-ONLY MODE (apex-helpsphere base)
// =============================================================================
// Master flag para desabilitar TUDO de IA. Default false (apex-helpsphere
// e SaaS base sem IA — IA provisiona-se nos labs Inter/Final/Avancado).
// Set true se quiser deploy completo do template upstream.
// =============================================================================
@description('Deploy IA stack (OpenAI, AI Search, Doc Intel, Vision, Speech, Cosmos chat). Default false para SaaS-only.')
param deployIaStack bool = false

@description('Pular criacao de role assignments (Storage MI grants, SQL MI, etc.). Use true quando deploy roda como SP sem permissao roleAssignments/write (ABAC condition). Aluno cria role assignments manualmente apos deploy via script gerado.')
param skipRoleAssignments bool = false
param chatHistoryContainerName string = 'chat-history-v2'
param chatHistoryVersion string = 'cosmosdb-v2'

// https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure?tabs=global-standard-aoai%2Cglobal-standard&pivots=azure-openai#models-by-deployment-type
@description('Location for the OpenAI resource group')
@allowed([
  'australiaeast'
  'brazilsouth'
  'canadaeast'
  'eastus'
  'eastus2'
  'francecentral'
  'germanywestcentral'
  'japaneast'
  'koreacentral'
  'northcentralus'
  'norwayeast'
  'polandcentral'
  'southafricanorth'
  'southcentralus'
  'southindia'
  'spaincentral'
  'swedencentral'
  'switzerlandnorth'
  'uaenorth'
  'uksouth'
  'westeurope'
  'westus'
  'westus3'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param openAiLocation string = 'eastus'

param openAiSkuName string = 'S0'

@secure()
param openAiApiKey string = ''
param openAiApiOrganization string = ''

param documentIntelligenceServiceName string = '' // Set in main.parameters.json
param documentIntelligenceResourceGroupName string = '' // Set in main.parameters.json

// Limited regions for new version:
// https://learn.microsoft.com/azure/ai-services/document-intelligence/concept-layout
@description('Location for the Document Intelligence resource group')
@allowed(['eastus', 'westus2', 'westeurope', 'australiaeast'])
@metadata({
  azd: {
    type: 'location'
  }
})
param documentIntelligenceResourceGroupLocation string = 'eastus'

param documentIntelligenceSkuName string // Set in main.parameters.json

param visionServiceName string = '' // Set in main.parameters.json
param visionResourceGroupName string = '' // Set in main.parameters.json
param visionResourceGroupLocation string = '' // Set in main.parameters.json

param contentUnderstandingServiceName string = '' // Set in main.parameters.json
param contentUnderstandingResourceGroupName string = '' // Set in main.parameters.json

param chatGptModelName string = ''
param chatGptDeploymentName string = ''
param chatGptDeploymentVersion string = ''
param chatGptDeploymentSkuName string = ''
param chatGptDeploymentCapacity int = 0

var chatGpt = {
  modelName: !empty(chatGptModelName) ? chatGptModelName : 'gpt-4.1-mini'
  deploymentName: !empty(chatGptDeploymentName) ? chatGptDeploymentName : 'gpt-4.1-mini'
  deploymentVersion: !empty(chatGptDeploymentVersion) ? chatGptDeploymentVersion : '2025-04-14'
  deploymentSkuName: !empty(chatGptDeploymentSkuName) ? chatGptDeploymentSkuName : 'GlobalStandard'
  deploymentCapacity: chatGptDeploymentCapacity != 0 ? chatGptDeploymentCapacity : 30
}

param embeddingModelName string = ''
param embeddingDeploymentName string = ''
param embeddingDeploymentVersion string = ''
param embeddingDeploymentSkuName string = ''
param embeddingDeploymentCapacity int = 0
param embeddingDimensions int = 0
var embedding = {
  modelName: !empty(embeddingModelName) ? embeddingModelName : 'text-embedding-3-large'
  deploymentName: !empty(embeddingDeploymentName) ? embeddingDeploymentName : 'text-embedding-3-large'
  deploymentVersion: !empty(embeddingDeploymentVersion) ? embeddingDeploymentVersion : (embeddingModelName == 'text-embedding-ada-002' ? '2' : '1')
  deploymentSkuName: !empty(embeddingDeploymentSkuName) ? embeddingDeploymentSkuName : (embeddingModelName == 'text-embedding-ada-002' ? 'Standard' : 'GlobalStandard')
  deploymentCapacity: embeddingDeploymentCapacity != 0 ? embeddingDeploymentCapacity : 200
  dimensions: embeddingDimensions != 0 ? embeddingDimensions : 3072
}

param evalModelName string = ''
param evalDeploymentName string = ''
param evalModelVersion string = ''
param evalDeploymentSkuName string = ''
param evalDeploymentCapacity int = 0
var eval = {
  modelName: !empty(evalModelName) ? evalModelName : 'gpt-4o'
  deploymentName: !empty(evalDeploymentName) ? evalDeploymentName : 'eval'
  deploymentVersion: !empty(evalModelVersion) ? evalModelVersion : '2024-08-06'
  deploymentSkuName: !empty(evalDeploymentSkuName) ? evalDeploymentSkuName : 'GlobalStandard' // Not backward-compatible
  deploymentCapacity: evalDeploymentCapacity != 0 ? evalDeploymentCapacity : 30
}

param knowledgeBaseModelName string = ''
param knowledgeBaseDeploymentName string = ''
param knowledgeBaseModelVersion string = ''
param knowledgeBaseDeploymentSkuName string = ''
param knowledgeBaseDeploymentCapacity int = 0
var knowledgeBase = {
  modelName: !empty(knowledgeBaseModelName) ? knowledgeBaseModelName : 'gpt-4.1-mini'
  deploymentName: !empty(knowledgeBaseDeploymentName) ? knowledgeBaseDeploymentName : 'knowledgebase'
  deploymentVersion: !empty(knowledgeBaseModelVersion) ? knowledgeBaseModelVersion : '2025-04-14'
  deploymentSkuName: !empty(knowledgeBaseDeploymentSkuName) ? knowledgeBaseDeploymentSkuName : 'GlobalStandard'
  deploymentCapacity: knowledgeBaseDeploymentCapacity != 0 ? knowledgeBaseDeploymentCapacity : 100
}


param tenantId string = tenant().tenantId
param authTenantId string = ''

// Used for the optional login and document level access control system
param useAuthentication bool = false
param enforceAccessControl bool = false
// Force using MSAL app authentication instead of built-in App Service authentication
// https://learn.microsoft.com/azure/app-service/overview-authentication-authorization
param disableAppServicesAuthentication bool = false
param enableGlobalDocuments bool = false
param enableUnauthenticatedAccess bool = false
param serverAppId string = ''
@secure()
param serverAppSecret string = ''
param clientAppId string = ''
@secure()
param clientAppSecret string = ''

// Used for optional CORS support for alternate frontends
param allowedOrigin string = '' // should start with https://, shouldn't end with a /

@allowed(['None', 'AzureServices'])
@description('If allowedIp is set, whether azure services are allowed to bypass the storage and AI services firewall.')
param bypass string = 'AzureServices'

@description('Public network access value for all deployed resources')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

@description('Add a private endpoints for network connectivity')
param usePrivateEndpoint bool = false

@description('Use a P2S VPN Gateway for secure access to the private endpoints')
param useVpnGateway bool = false

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Use Application Insights for monitoring and performance tracing')
param useApplicationInsights bool = false

@description('Enable language picker')
param enableLanguagePicker bool = false
@description('Use speech recognition feature in browser')
param useSpeechInputBrowser bool = false
@description('Use speech synthesis in browser')
param useSpeechOutputBrowser bool = false
@description('Use Azure speech service for reading out text')
param useSpeechOutputAzure bool = false
@description('Use chat history feature in browser')
param useChatHistoryBrowser bool = false
@description('Use chat history feature in CosmosDB')
param useChatHistoryCosmos bool = false
@description('Show options to use vector embeddings for searching in the app UI')
param useVectors bool = false
@description('Use Built-in integrated Vectorization feature of AI Search to vectorize and ingest documents')
param useIntegratedVectorization bool = false

@description('Use media description feature with Azure Content Understanding during ingestion')
param useMediaDescriberAzureCU bool = true

@description('Enable user document upload feature')
param useUserUpload bool = false
param useLocalPdfParser bool = false
param useLocalHtmlParser bool = false

@description('Use AI project')
param useAiProject bool = false

var abbrs = loadJsonContent('abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
// Token curto (4 chars) para appendar em recursos com unicidade global rigida
// (Storage, ACR, SQL Server) — mantem nome legivel mas evita colisao entre alunos.
var shortToken = take(resourceToken, 4)
// Slug do environmentName em lowercase sem hifens — para Storage/ACR que nao aceitam '-'
var envSlug = toLower(replace(environmentName, '-', ''))
var tags = { 'azd-env-name': environmentName }

var tenantIdForAuth = !empty(authTenantId) ? authTenantId : tenantId
var authenticationIssuerUri = '${environment().authentication.loginEndpoint}${tenantIdForAuth}/v2.0'

@description('Whether the deployment is running on GitHub Actions')
param runningOnGh string = ''

@description('Whether the deployment is running on Azure DevOps Pipeline')
param runningOnAdo string = ''

@description('Used by azd for containerapps deployment')
param webAppExists bool

@allowed(['Consumption', 'D4', 'D8', 'D16', 'D32', 'E4', 'E8', 'E16', 'E32', 'NC24-A100', 'NC48-A100', 'NC96-A100'])
param azureContainerAppsWorkloadProfile string

@allowed(['appservice', 'containerapps'])
param deploymentTarget string = 'appservice'

// RAG Configuration Parameters
@description('Whether to use text embeddings for RAG search')
param ragSearchTextEmbeddings bool = true
@description('Whether to use image embeddings for RAG search')
param ragSearchImageEmbeddings bool = true
@description('Whether to send text sources to LLM for RAG responses')
param ragSendTextSources bool = true
@description('Whether to send image sources to LLM for RAG responses')
param ragSendImageSources bool = true
@description('Whether to enable web sources for agentic retrieval')
param useWebSource bool = false
@description('Whether to enable SharePoint sources for agentic retrieval')
param useSharePointSource bool = false

param acaIdentityName string = deploymentTarget == 'containerapps' ? '${environmentName}-aca-identity' : ''
param acaManagedEnvironmentName string = deploymentTarget == 'containerapps' ? '${environmentName}-aca-env' : ''
param containerRegistryName string = deploymentTarget == 'containerapps'
  ? '${replace(toLower(environmentName), '-', '')}acr'
  : ''

// HelpSphere — Story 06.5c.3 (B-PRACTICAL): tickets-service hybrid microservice
// 2nd UMI distinta (Epic AC-4: 2 MIs scoped) + 2nd ACA app side-by-side com backend Python.
// Grants SQL scoped vão para Story 06.5c.4 (sql_init); Story 06.5c.5 traz workflow .NET CI.
param acaTicketsIdentityName string = deploymentTarget == 'containerapps' ? '${environmentName}-aca-tickets-identity' : ''
@description('Used by azd for tickets-service container app deployment')
param ticketsAppExists bool = false
param ticketsServiceName string = ''

// HelpSphere v2.1.0 (Sessão 9.5) — parametrização CI-first
// Decisões 4.1, 4.2, 4.3, 4.5 + Decisão #18 (autoPauseDelay parametrizado).
@description('Python runtime version for backend (default: 3.13 — wheels estaveis para todas as deps).')
param pythonVersion string = '3.13'

@description('CORS origins adicionais para tickets-service (alem do backend FQDN). Util para dev local.')
param additionalCorsOrigins array = []

// HelpSphere v2.1.0 (Sessão 9.5):
// - `skipPrepdocs`: declarado para visibilidade no parameters.json mas consumido APENAS
//   pelo wrapper `scripts/run_prepdocs.{ps1,sh}` que lê `azd env get-value SKIP_PREPDOCS`.
//   Linter "no-unused-params" é aceitável — a documentação do param justifica a presença.
// - `enableChat`: consumido em `appEnvVariables.ENABLE_CHAT` (linha ~620) → backend
//   `/auth_setup` → frontend hide/show da nav (Wave 3.F).
@description('Pula execucao do prepdocs.py no postdeploy (acelera azd up em ~3min mas chat/RAG nao funciona ate aluno rodar manual).')
#disable-next-line no-unused-params
param skipPrepdocs bool = false

@description('Habilita chat na UI. Default false — chat e ativado no Lab Intermediario.')
param enableChat bool = false

@description('Audience format aceito pelo tickets-service. v2 (GUID) e o default; "v1" (api://) so para compat com tokens legacy.')
@allowed(['v2', 'v1', 'both'])
param tokenAudienceFormat string = 'v2'

@description('SQL Database autoPauseDelay em minutos. -1 = sempre online. 60 = pausa apos 60min idle.')
param sqlAutoPauseDelay int = -1

// Configure CORS for allowing different web apps to use the backend
// For more information please see https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
var msftAllowedOrigins = [ 'https://portal.azure.com', 'https://ms.portal.azure.com' ]
var loginEndpoint = environment().authentication.loginEndpoint
var loginEndpointFixed = lastIndexOf(loginEndpoint, '/') == length(loginEndpoint) - 1 ? substring(loginEndpoint, 0, max(length(loginEndpoint) - 1, 0)) : loginEndpoint
var allMsftAllowedOrigins = !(empty(clientAppId)) ? union(msftAllowedOrigins, [ loginEndpointFixed ]) : msftAllowedOrigins
// Combine custom origins with Microsoft origins, remove any empty origin strings and remove any duplicate origins
var allowedOrigins = reduce(filter(union(split(allowedOrigin, ';'), allMsftAllowedOrigins), o => length(trim(o)) > 0), [], (cur, next) => union(cur, [next]))

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

resource openAiResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = if (!empty(openAiResourceGroupName)) {
  name: !empty(openAiResourceGroupName) ? openAiResourceGroupName : resourceGroup.name
}

resource documentIntelligenceResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = if (!empty(documentIntelligenceResourceGroupName)) {
  name: !empty(documentIntelligenceResourceGroupName) ? documentIntelligenceResourceGroupName : resourceGroup.name
}

resource visionResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = if (!empty(visionResourceGroupName)) {
  name: !empty(visionResourceGroupName) ? visionResourceGroupName : resourceGroup.name
}

resource contentUnderstandingResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = if (!empty(contentUnderstandingResourceGroupName)) {
  name: !empty(contentUnderstandingResourceGroupName) ? contentUnderstandingResourceGroupName : resourceGroup.name
}

resource searchServiceResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = if (!empty(searchServiceResourceGroupName)) {
  name: !empty(searchServiceResourceGroupName) ? searchServiceResourceGroupName : resourceGroup.name
}

resource storageResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = if (!empty(storageResourceGroupName)) {
  name: !empty(storageResourceGroupName) ? storageResourceGroupName : resourceGroup.name
}

resource speechResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = if (!empty(speechServiceResourceGroupName)) {
  name: !empty(speechServiceResourceGroupName) ? speechServiceResourceGroupName : resourceGroup.name
}

resource cosmosDbResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = if (!empty(cosmodDbResourceGroupName)) {
  name: !empty(cosmodDbResourceGroupName) ? cosmodDbResourceGroupName : resourceGroup.name
}

// ADLS resource group - defaults to main resource group if not specified
resource adlsStorageResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = {
  name: !empty(adlsStorageResourceGroupName) ? adlsStorageResourceGroupName : resourceGroup.name
}

// Monitor application with Azure Monitor
module monitoring 'core/monitor/monitoring.bicep' = if (useApplicationInsights) {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    applicationInsightsName: !empty(applicationInsightsName)
      ? applicationInsightsName
      : '${abbrs.insightsComponents}${environmentName}'
    logAnalyticsName: !empty(logAnalyticsName)
      ? logAnalyticsName
      : '${abbrs.operationalInsightsWorkspaces}${environmentName}'
    publicNetworkAccess: publicNetworkAccess
  }
}

module applicationInsightsDashboard 'backend-dashboard.bicep' = if (useApplicationInsights) {
  name: 'application-insights-dashboard'
  scope: resourceGroup
  params: {
    name: !empty(applicationInsightsDashboardName)
      ? applicationInsightsDashboardName
      : '${abbrs.portalDashboards}${environmentName}'
    location: location
    applicationInsightsName: useApplicationInsights ? monitoring!.outputs.applicationInsightsName : ''
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU
module appServicePlan 'core/host/appserviceplan.bicep' = if (deploymentTarget == 'appservice') {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: appServiceSkuName
      capacity: 1
    }
    kind: 'linux'
  }
}

// Determine which ADLS storage account name to use (existing or provisioned)
var adlsStorageAccountNameResolved = useExistingAdlsStorage ? existingAdlsStorage.name : (useCloudIngestionAcls ? adlsStorage!.outputs.name : '')

// For cloud ingestion with ACLs, use the ADLS Gen2 storage account; otherwise use the standard storage account
var cloudIngestionStorageAccount = useCloudIngestionAcls ? adlsStorageAccountNameResolved : storage.outputs.name

var appEnvVariables = {
  AZURE_STORAGE_ACCOUNT: storage.outputs.name
  AZURE_STORAGE_CONTAINER: storageContainerName
  AZURE_STORAGE_RESOURCE_GROUP: storageResourceGroup.name
  // Cloud ingestion uses ADLS Gen2 storage when ACLs are enabled for manual ACL extraction
  AZURE_CLOUD_INGESTION_STORAGE_ACCOUNT: cloudIngestionStorageAccount
  USE_CLOUD_INGESTION_ACLS: string(useCloudIngestionAcls)
  AZURE_SUBSCRIPTION_ID: subscription().subscriptionId
  AZURE_SEARCH_INDEX: searchIndexName
  AZURE_SEARCH_KNOWLEDGEBASE_NAME: knowledgeBaseName
  AZURE_SEARCH_SERVICE: deployIaStack ? searchService!.outputs.name : ''
  AZURE_SEARCH_SEMANTIC_RANKER: actualSearchServiceSemanticRankerLevel
  AZURE_SEARCH_QUERY_REWRITING: searchServiceQueryRewriting
  AZURE_VISION_ENDPOINT: useMultimodal ? vision!.outputs.endpoint : ''
  AZURE_SEARCH_QUERY_LANGUAGE: searchQueryLanguage
  AZURE_SEARCH_QUERY_SPELLER: searchQuerySpeller
  AZURE_SEARCH_FIELD_NAME_EMBEDDING: searchFieldNameEmbedding
  APPLICATIONINSIGHTS_CONNECTION_STRING: useApplicationInsights
    ? monitoring!.outputs.applicationInsightsConnectionString
    : ''
  AZURE_SPEECH_SERVICE_ID: useSpeechOutputAzure ? speech!.outputs.resourceId : ''
  AZURE_SPEECH_SERVICE_LOCATION: useSpeechOutputAzure ? speech!.outputs.location : ''
  AZURE_SPEECH_SERVICE_VOICE: useSpeechOutputAzure ? speechServiceVoice : ''
  ENABLE_LANGUAGE_PICKER: enableLanguagePicker
  USE_SPEECH_INPUT_BROWSER: useSpeechInputBrowser
  USE_SPEECH_OUTPUT_BROWSER: useSpeechOutputBrowser
  USE_SPEECH_OUTPUT_AZURE: useSpeechOutputAzure
  USE_AGENTIC_KNOWLEDGEBASE: useAgenticKnowledgeBase
  // Chat history settings
  USE_CHAT_HISTORY_BROWSER: useChatHistoryBrowser
  USE_CHAT_HISTORY_COSMOS: useChatHistoryCosmos
  AZURE_COSMOSDB_ACCOUNT: (useAuthentication && useChatHistoryCosmos) ? cosmosDb!.outputs.name : ''
  AZURE_CHAT_HISTORY_DATABASE: chatHistoryDatabaseName
  AZURE_CHAT_HISTORY_CONTAINER: chatHistoryContainerName
  AZURE_CHAT_HISTORY_VERSION: chatHistoryVersion
  // Shared by all OpenAI deployments
  OPENAI_HOST: openAiHost
  AZURE_OPENAI_EMB_MODEL_NAME: embedding.modelName
  AZURE_OPENAI_EMB_DIMENSIONS: embedding.dimensions
  AZURE_OPENAI_CHATGPT_MODEL: chatGpt.modelName
  AZURE_OPENAI_REASONING_EFFORT: defaultReasoningEffort
  AGENTIC_KNOWLEDGEBASE_REASONING_EFFORT: defaultRetrievalReasoningEffort
  // Specific to Azure OpenAI
  AZURE_OPENAI_SERVICE: isAzureOpenAiHost && deployAzureOpenAi && deployIaStack ? openAi!.outputs.name : ''
  AZURE_OPENAI_CHATGPT_DEPLOYMENT: chatGpt.deploymentName
  AZURE_OPENAI_EMB_DEPLOYMENT: embedding.deploymentName
  AZURE_OPENAI_knowledgeBase_MODEL: knowledgeBase.modelName
  AZURE_OPENAI_knowledgeBase_DEPLOYMENT: knowledgeBase.deploymentName
  AZURE_OPENAI_API_KEY_OVERRIDE: azureOpenAiApiKey
  AZURE_OPENAI_CUSTOM_URL: azureOpenAiCustomUrl
  // Used only with non-Azure OpenAI deployments
  OPENAI_API_KEY: openAiApiKey
  OPENAI_ORGANIZATION: openAiApiOrganization
  // Optional login and document level access control system
  AZURE_USE_AUTHENTICATION: useAuthentication
  AZURE_ENFORCE_ACCESS_CONTROL: enforceAccessControl
  AZURE_ENABLE_GLOBAL_DOCUMENT_ACCESS: enableGlobalDocuments
  AZURE_ENABLE_UNAUTHENTICATED_ACCESS: enableUnauthenticatedAccess
  AZURE_SERVER_APP_ID: serverAppId
  AZURE_CLIENT_APP_ID: clientAppId
  AZURE_TENANT_ID: tenantId
  AZURE_AUTH_TENANT_ID: tenantIdForAuth
  AZURE_AUTHENTICATION_ISSUER_URI: authenticationIssuerUri
  // CORS support, for frontends on other hosts
  ALLOWED_ORIGIN: join(allowedOrigins, ';')
  USE_VECTORS: useVectors
  USE_MULTIMODAL: useMultimodal
  USE_USER_UPLOAD: useUserUpload
  AZURE_USERSTORAGE_ACCOUNT: useUserUpload ? userStorage!.outputs.name : ''
  AZURE_USERSTORAGE_CONTAINER: useUserUpload ? userStorageContainerName : ''
  AZURE_IMAGESTORAGE_CONTAINER: useMultimodal ? imageStorageContainerName : ''
  AZURE_DOCUMENTINTELLIGENCE_SERVICE: deployIaStack ? documentIntelligence!.outputs.name : ''
  USE_LOCAL_PDF_PARSER: useLocalPdfParser
  USE_LOCAL_HTML_PARSER: useLocalHtmlParser
  USE_MEDIA_DESCRIBER_AZURE_CU: useMediaDescriberAzureCU
  AZURE_CONTENTUNDERSTANDING_ENDPOINT: useMediaDescriberAzureCU ? contentUnderstanding!.outputs.endpoint : ''
  RUNNING_IN_PRODUCTION: 'true'
  // HelpSphere — Story 06.5a Sessão 2.3 (SQL access)
  // Sessão 3.5: FQDN construído via environment().suffixes.sqlServerHostname
  // (módulo AVM sql/server:0.10.0 não expõe fullyQualifiedDomainName) — Decisão #9
  AZURE_SQL_SERVER: useSqlServer && !empty(sqlAadAdminGroupObjectId) ? '${sqlServer!.outputs.name}${environment().suffixes.sqlServerHostname}' : ''
  AZURE_SQL_DATABASE: useSqlServer ? sqlDatabaseName : ''
  // RAG Configuration
  RAG_SEARCH_TEXT_EMBEDDINGS: ragSearchTextEmbeddings
  RAG_SEARCH_IMAGE_EMBEDDINGS: ragSearchImageEmbeddings
  RAG_SEND_TEXT_SOURCES: ragSendTextSources
  RAG_SEND_IMAGE_SOURCES: ragSendImageSources
  USE_WEB_SOURCE: useWebSource
  USE_SHAREPOINT_SOURCE: useSharePointSource
  // HelpSphere v2.1.0 (Sessão 9.5, Wave 3.F)
  // ENABLE_CHAT: exposto pelo backend `/auth_setup` → frontend usa pra esconder
  // a aba "Chat" da nav quando false. Default false (aluno habilita no Lab Intermediário).
  // NOTA: `skipPrepdocs` NÃO é Container App env — é consumido apenas pelo wrapper
  // `scripts/run_prepdocs.{ps1,sh}` que lê de `azd env get-value SKIP_PREPDOCS`
  // durante o postprovision hook. Mapping no main.parameters.json basta.
  ENABLE_CHAT: enableChat
}

// App Service for the web application (Python Quart app with JS frontend)
module backend 'core/host/appservice.bicep' = if (deploymentTarget == 'appservice') {
  name: 'web'
  scope: resourceGroup
  params: {
    name: !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesAppService}backend-${resourceToken}'
    location: location
    tags: union(tags, { 'azd-service-name': 'backend' })
    // Need to check deploymentTarget again due to https://github.com/Azure/bicep/issues/3990
    appServicePlanId: deploymentTarget == 'appservice' ? appServicePlan!.outputs.id : ''
    runtimeName: 'python'
    // v2.1.0 (Decisão 4.5): Python pin único — Bicep + Dockerfile + .python-version.
    runtimeVersion: pythonVersion
    appCommandLine: 'python3 -m gunicorn main:app'
    scmDoBuildDuringDeployment: true
    managedIdentity: true
    virtualNetworkSubnetId: usePrivateEndpoint ? isolation!.outputs.appSubnetId : ''
    publicNetworkAccess: publicNetworkAccess
    allowedOrigins: allowedOrigins
    clientAppId: clientAppId
    serverAppId: serverAppId
    enableUnauthenticatedAccess: enableUnauthenticatedAccess
    disableAppServicesAuthentication: disableAppServicesAuthentication
    clientSecretSettingName: !empty(clientAppSecret) ? 'AZURE_CLIENT_APP_SECRET' : ''
    authenticationIssuerUri: authenticationIssuerUri
    use32BitWorkerProcess: appServiceSkuName == 'F1'
    alwaysOn: appServiceSkuName != 'F1'
    appSettings: union(appEnvVariables, {
      AZURE_SERVER_APP_SECRET: serverAppSecret
      AZURE_CLIENT_APP_SECRET: clientAppSecret
    })
  }
}

// Azure container apps resources (Only deployed if deploymentTarget is 'containerapps')

// User-assigned identity for pulling images from ACR
module acaIdentity 'core/security/aca-identity.bicep' = if (deploymentTarget == 'containerapps') {
  name: 'aca-identity'
  scope: resourceGroup
  params: {
    identityName: acaIdentityName
    location: location
  }
}

module containerApps 'core/host/container-apps.bicep' = if (deploymentTarget == 'containerapps') {
  name: 'container-apps'
  scope: resourceGroup
  params: {
    name: 'app'
    tags: tags
    location: location
    containerAppsEnvironmentName: acaManagedEnvironmentName
    containerRegistryName: 'acr${envSlug}${shortToken}'
    logAnalyticsWorkspaceName: useApplicationInsights ? monitoring!.outputs.logAnalyticsWorkspaceName : ''
    subnetResourceId: usePrivateEndpoint ? isolation!.outputs.appSubnetId : ''
    usePrivateIngress: usePrivateEndpoint
    workloadProfile: azureContainerAppsWorkloadProfile
  }
}

// Container Apps for the web application (Python Quart app with JS frontend)
module acaBackend 'core/host/container-app-upsert.bicep' = if (deploymentTarget == 'containerapps') {
  name: 'aca-web'
  scope: resourceGroup
  params: {
    name: !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesContainerApps}backend-${resourceToken}'
    location: location
    identityName: (deploymentTarget == 'containerapps') ? acaIdentityName : ''
    exists: webAppExists
    containerRegistryName: (deploymentTarget == 'containerapps') ? containerApps!.outputs.registryName : ''
    containerAppsEnvironmentName: (deploymentTarget == 'containerapps') ? containerApps!.outputs.environmentName : ''
    skipRoleAssignments: skipRoleAssignments
    tags: union(tags, { 'azd-service-name': 'backend' })
    targetPort: 8000
    containerCpuCoreCount: '1.0'
    containerMemory: '2Gi'
    containerMinReplicas: usePrivateEndpoint ? 1 : 0
    allowedOrigins: allowedOrigins
    env: union(appEnvVariables, {
      // For using managed identity to access Azure resources. See https://github.com/microsoft/azure-container-apps/issues/442
      AZURE_CLIENT_ID: (deploymentTarget == 'containerapps') ? acaIdentity!.outputs.clientId : ''
      // Story 06.5c.8 (Sessão 9.2): TICKETS_BACKEND_URI consumido por blueprints/tickets.py
      // para popular o header `Link: <successor-uri>; rel="successor-version"` (RFC 8288)
      // nos responses 410 Gone (AC-5 do epic 06.5c). Sem isso, Link header é omitido e o
      // body retorna `successor_uri: null` — viola RFC 5988/8288 e atrapalha auto-discovery
      // do tickets-service .NET pelos clientes legacy.
      TICKETS_BACKEND_URI: (deploymentTarget == 'containerapps') ? acaTickets!.outputs.uri : ''
    })
    secrets: useAuthentication ? {
      azureclientappsecret: clientAppSecret
      azureserverappsecret: serverAppSecret
    } : {}
    envSecrets: useAuthentication ? [
      {
        name: 'AZURE_CLIENT_APP_SECRET'
        secretRef: 'azureclientappsecret'
      }
      {
        name: 'AZURE_SERVER_APP_SECRET'
        secretRef: 'azureserverappsecret'
      }
    ] : []
  }
}

module acaAuth 'core/host/container-apps-auth.bicep' = if (deploymentTarget == 'containerapps' && !empty(clientAppId)) {
  name: 'aca-auth'
  scope: resourceGroup
  params: {
    name: acaBackend!.outputs.name
    clientAppId: clientAppId
    serverAppId: serverAppId
    clientSecretSettingName: !empty(clientAppSecret) ? 'azureclientappsecret' : ''
    authenticationIssuerUri: authenticationIssuerUri
    enableUnauthenticatedAccess: enableUnauthenticatedAccess
    blobContainerUri: 'https://${storageAccountName}.blob.${environment().suffixes.storage}/${tokenStorageContainerName}'
    appIdentityResourceId: (deploymentTarget == 'appservice') ? '' : acaBackend!.outputs.identityResourceId
  }
}

// ============================================================================
// HelpSphere — Story 06.5c.3 (B-PRACTICAL minimal hybrid wiring)
// 2nd ACA app: tickets-service (.NET 10 Minimal API + Dapper + MI auth)
// Story 06.5c.2 entrega skeleton + 5 endpoints; este Bicep entrega o host.
// ============================================================================

// v2.1.0 (Decisão 4.2): tickets audience parametrizado.
// Microsoft.Identity.Web aceita string única ou lista separada por espaço em ValidAudiences.
var ticketsAudience = !empty(serverAppId)
  ? (tokenAudienceFormat == 'v2'
      ? serverAppId
      : (tokenAudienceFormat == 'v1'
          ? 'api://${serverAppId}'
          : 'api://${serverAppId} ${serverAppId}'))
  : '00000000-0000-0000-0000-000000000000'

// v2.1.0 (Decisão 4.3): tickets-service CORS = backend FQDN auto-resolvido + portals MS + extras opt-in.
// `allowedOrigins` (var existente) já contém origins do portal Azure + clientes legacy via env.
// NOTA: não podemos usar `acaBackend.outputs.uri` aqui — `acaBackend` depende de `acaTickets`
// (env var TICKETS_BACKEND_URI), o que criaria ciclo. Construimos o FQDN deterministicamente
// a partir de `containerApps.outputs.defaultDomain` + `backendServiceName` (mesmo padrão do `name` em acaBackend).
var backendAcaName = !empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesContainerApps}backend-${resourceToken}'
var backendAcaFqdn = (deploymentTarget == 'containerapps') ? 'https://${backendAcaName}.${containerApps!.outputs.defaultDomain}' : ''
var ticketsAllowedOrigins = union(
  allowedOrigins,
  !empty(backendAcaFqdn) ? [ backendAcaFqdn ] : [],
  additionalCorsOrigins
)

// User-assigned identity DEDICADA ao tickets-service (Epic AC-4: 2 MIs scoped)
module acaTicketsIdentity 'core/security/aca-identity.bicep' = if (deploymentTarget == 'containerapps') {
  name: 'aca-tickets-identity'
  scope: resourceGroup
  params: {
    identityName: acaTicketsIdentityName
    location: location
  }
}

// Container App tickets-service — image será pushed pelo `azd deploy` (azure.yaml service entry).
// Default image (helloworld) usado ANTES do primeiro deploy; substituído ao primeiro `azd deploy`.
// Env vars mínimos: AZURE_CLIENT_ID (UMI MI auth), AzureAd__* (JWT bootstrap), AZURE_SQL_*
// (necessário só para /api/tickets/*; /health não toca SQL).
module acaTickets 'core/host/container-app-upsert.bicep' = if (deploymentTarget == 'containerapps') {
  name: 'aca-tickets'
  scope: resourceGroup
  params: {
    name: !empty(ticketsServiceName) ? ticketsServiceName : '${abbrs.webSitesContainerApps}tickets-${resourceToken}'
    location: location
    identityName: (deploymentTarget == 'containerapps') ? acaTicketsIdentityName : ''
    exists: ticketsAppExists
    containerRegistryName: (deploymentTarget == 'containerapps') ? containerApps!.outputs.registryName : ''
    containerAppsEnvironmentName: (deploymentTarget == 'containerapps') ? containerApps!.outputs.environmentName : ''
    skipRoleAssignments: skipRoleAssignments
    tags: union(tags, { 'azd-service-name': 'tickets-service' })
    targetPort: 8080
    containerCpuCoreCount: '0.5'
    containerMemory: '1.0Gi'
    containerMinReplicas: 0
    allowedOrigins: ticketsAllowedOrigins
    env: {
      // SqlConnectionFactory: MI auth em prod (UMI clientId), AAD Default em dev
      AZURE_CLIENT_ID: (deploymentTarget == 'containerapps') ? acaTicketsIdentity!.outputs.clientId : ''
      AZURE_SQL_SERVER: useSqlServer && !empty(sqlAadAdminGroupObjectId) ? '${sqlServer!.outputs.name}${environment().suffixes.sqlServerHostname}' : ''
      AZURE_SQL_DATABASE: useSqlServer ? sqlDatabaseName : ''
      // Microsoft.Identity.Web JWT bootstrap — usa serverAppId (o resource da API), nao clientAppId.
      // v2.1.0 (Decisão 4.2): audience format parametrizado — default v2 (GUID puro).
      // - v2 → tokens v2 nativos (aud = serverAppId GUID, sem prefix)
      // - v1 → compat legado (aud = api://{serverAppId})
      // - both → aceita ambos (Microsoft.Identity.Web ValidAudiences[] separado por espaço)
      AzureAd__Instance: environment().authentication.loginEndpoint
      AzureAd__TenantId: !empty(authTenantId) ? authTenantId : tenantId
      AzureAd__ClientId: !empty(serverAppId) ? serverAppId : '00000000-0000-0000-0000-000000000000'
      AzureAd__Audience: ticketsAudience
      ASPNETCORE_ENVIRONMENT: 'Production'
      ASPNETCORE_URLS: 'http://+:8080'
      // v2.1.0 (Decisão 4.1): Alpine .NET base image sem ICU full → NLS culture-invariant.
      // 'false' força .NET a usar ICU instalado (apk add icu-libs no Dockerfile) e evitar
      // crashes em culture lookups (ex: DateTime.Parse pt-BR, decimal separator, etc).
      DOTNET_SYSTEM_GLOBALIZATION_INVARIANT: 'false'
    }
  }
}

// Optional Azure Functions for document ingestion and processing
module functions 'app/functions.bicep' = if (useCloudIngestion) {
  name: 'functions'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    applicationInsightsName: useApplicationInsights ? monitoring!.outputs.applicationInsightsName : ''
    storageResourceGroupName: storageResourceGroup.name
    searchServiceResourceGroupName: searchServiceResourceGroup.name
    openAiResourceGroupName: openAiResourceGroup.name
    documentIntelligenceResourceGroupName: documentIntelligenceResourceGroup.name
    visionServiceName: useMultimodal ? vision!.outputs.name : ''
    visionResourceGroupName: useMultimodal ? visionResourceGroup.name : resourceGroup.name
    contentUnderstandingServiceName: useMediaDescriberAzureCU ? contentUnderstanding!.outputs.name : ''
    contentUnderstandingResourceGroupName: useMediaDescriberAzureCU ? contentUnderstandingResourceGroup.name : resourceGroup.name
    documentExtractorName: '${abbrs.webSitesFunctions}doc-extractor-${resourceToken}'
    figureProcessorName: '${abbrs.webSitesFunctions}figure-processor-${resourceToken}'
    textProcessorName: '${abbrs.webSitesFunctions}text-processor-${resourceToken}'
    openIdIssuer: authenticationIssuerUri
    appEnvVariables: appEnvVariables
    searchUserAssignedIdentityClientId: searchService.outputs.userAssignedIdentityClientId
  }
}

var defaultOpenAiDeployments = [
  {
    name: chatGpt.deploymentName
    model: {
      format: 'OpenAI'
      name: chatGpt.modelName
      version: chatGpt.deploymentVersion
    }
    sku: {
      name: chatGpt.deploymentSkuName
      capacity: chatGpt.deploymentCapacity
    }
  }
  {
    name: embedding.deploymentName
    model: {
      format: 'OpenAI'
      name: embedding.modelName
      version: embedding.deploymentVersion
    }
    sku: {
      name: embedding.deploymentSkuName
      capacity: embedding.deploymentCapacity
    }
  }
]

var openAiDeployments = concat(
  defaultOpenAiDeployments,
  useEval
    ? [
      {
        name: eval.deploymentName
        model: {
          format: 'OpenAI'
          name: eval.modelName
          version: eval.deploymentVersion
        }
        sku: {
          name: eval.deploymentSkuName
          capacity: eval.deploymentCapacity
        }
      }
    ] : [],
  useAgenticKnowledgeBase
    ? [
        {
          name: knowledgeBase.deploymentName
          model: {
            format: 'OpenAI'
            name: knowledgeBase.modelName
            version: knowledgeBase.deploymentVersion
          }
          sku: {
            name: knowledgeBase.deploymentSkuName
            capacity: knowledgeBase.deploymentCapacity
          }
        }
      ]
    : []
)

module openAi 'br/public:avm/res/cognitive-services/account:0.7.2' = if (isAzureOpenAiHost && deployAzureOpenAi && deployIaStack) {
  name: 'openai'
  scope: openAiResourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: openAiLocation
    tags: tags
    kind: 'OpenAI'
    customSubDomainName: !empty(openAiServiceName)
      ? openAiServiceName
      : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      bypass: bypass
    }
    sku: openAiSkuName
    deployments: openAiDeployments
    disableLocalAuth: azureOpenAiDisableKeys
    restore: restoreCognitiveServices
  }
}

// Formerly known as Form Recognizer
// Does not support bypass
module documentIntelligence 'br/public:avm/res/cognitive-services/account:0.7.2' = if (deployIaStack) {
  name: 'documentintelligence'
  scope: documentIntelligenceResourceGroup
  params: {
    name: !empty(documentIntelligenceServiceName)
      ? documentIntelligenceServiceName
      : '${abbrs.cognitiveServicesDocumentIntelligence}${resourceToken}'
    kind: 'FormRecognizer'
    customSubDomainName: !empty(documentIntelligenceServiceName)
      ? documentIntelligenceServiceName
      : '${abbrs.cognitiveServicesDocumentIntelligence}${resourceToken}'
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
    }
    location: documentIntelligenceResourceGroupLocation
    disableLocalAuth: true
    tags: tags
    sku: documentIntelligenceSkuName
    restore: restoreCognitiveServices
  }
}

module vision 'br/public:avm/res/cognitive-services/account:0.7.2' = if (useMultimodal && deployIaStack) {
  name: 'vision'
  scope: visionResourceGroup
  params: {
    name: !empty(visionServiceName)
      ? visionServiceName
      : '${abbrs.cognitiveServicesVision}${resourceToken}'
    kind: 'CognitiveServices'
    networkAcls: {
      defaultAction: 'Allow'
    }
    customSubDomainName: !empty(visionServiceName)
      ? visionServiceName
      : '${abbrs.cognitiveServicesVision}${resourceToken}'
    location: visionResourceGroupLocation
    tags: tags
    sku: 'S0'
    restore: restoreCognitiveServices
  }
}


module contentUnderstanding 'br/public:avm/res/cognitive-services/account:0.7.2' = if (useMediaDescriberAzureCU) {
  name: 'content-understanding'
  scope: contentUnderstandingResourceGroup
  params: {
    name: !empty(contentUnderstandingServiceName)
      ? contentUnderstandingServiceName
      : '${abbrs.cognitiveServicesContentUnderstanding}${resourceToken}'
    kind: 'AIServices'
    networkAcls: {
      defaultAction: 'Allow'
    }
    customSubDomainName: !empty(contentUnderstandingServiceName)
      ? contentUnderstandingServiceName
      : '${abbrs.cognitiveServicesContentUnderstanding}${resourceToken}'
    // Hard-coding to westus for now, due to limited availability and no overlap with Document Intelligence
    location: 'westus'
    tags: tags
    sku: 'S0'
    restore: restoreCognitiveServices
  }
}

module speech 'br/public:avm/res/cognitive-services/account:0.7.2' = if (useSpeechOutputAzure && deployIaStack) {
  name: 'speech-service'
  scope: speechResourceGroup
  params: {
    name: !empty(speechServiceName) ? speechServiceName : '${abbrs.cognitiveServicesSpeech}${resourceToken}'
    kind: 'SpeechServices'
    networkAcls: {
      defaultAction: 'Allow'
    }
    customSubDomainName: !empty(speechServiceName)
      ? speechServiceName
      : '${abbrs.cognitiveServicesSpeech}${resourceToken}'
    location: !empty(speechServiceLocation) ? speechServiceLocation : location
    tags: tags
    sku: speechServiceSkuName
    restore: restoreCognitiveServices
  }
}
module searchService 'core/search/search-services.bicep' = if (deployIaStack) {
  name: 'search-service'
  scope: searchServiceResourceGroup
  params: {
    name: !empty(searchServiceName) ? searchServiceName : 'gptkb-${resourceToken}'
    location: !empty(searchServiceLocation) ? searchServiceLocation : location
    tags: tags
    disableLocalAuth: true
    sku: {
      name: searchServiceSkuName
    }
    semanticSearch: actualSearchServiceSemanticRankerLevel
    publicNetworkAccess: publicNetworkAccess == 'Enabled'
      ? 'enabled'
      : (publicNetworkAccess == 'Disabled' ? 'disabled' : null)
    sharedPrivateLinkStorageAccounts: (usePrivateEndpoint && useIntegratedVectorization) ? [storage.outputs.id] : []
  }
}

module searchDiagnostics 'core/search/search-diagnostics.bicep' = if (useApplicationInsights && deployIaStack) {
  name: 'search-diagnostics'
  scope: searchServiceResourceGroup
  params: {
    searchServiceName: searchService.outputs.name
    workspaceId: useApplicationInsights ? monitoring!.outputs.logAnalyticsWorkspaceId : ''
  }
}

module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: storageResourceGroup
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${envSlug}${shortToken}'
    location: storageResourceGroupLocation
    tags: tags
    publicNetworkAccess: publicNetworkAccess
    bypass: bypass
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    sku: {
      name: storageSkuName
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 2
    }
    containers: [
      {
        name: storageContainerName
        publicAccess: 'None'
      }
      {
        name: imageStorageContainerName
        publicAccess: 'None'
      }
      {
        name: tokenStorageContainerName
        publicAccess: 'None'
      }
    ]
  }
}

module userStorage 'core/storage/storage-account.bicep' = if (useUserUpload) {
  name: 'user-storage'
  scope: storageResourceGroup
  params: {
    name: !empty(userStorageAccountName)
      ? userStorageAccountName
      : 'user${abbrs.storageStorageAccounts}${resourceToken}'
    location: storageResourceGroupLocation
    tags: tags
    publicNetworkAccess: publicNetworkAccess
    bypass: bypass
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    isHnsEnabled: true
    sku: {
      name: storageSkuName
    }
    containers: [
      {
        name: userStorageContainerName
        publicAccess: 'None'
      }
    ]
  }
}

// Reference existing ADLS Gen2 storage account when bringing your own
resource existingAdlsStorage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = if (useExistingAdlsStorage && !empty(adlsStorageAccountName)) {
  name: adlsStorageAccountName
  scope: adlsStorageResourceGroup
}

// ADLS Gen2 storage account for cloud ingestion with ACL support
// Only provision if using cloud ingestion ACLs AND not using an existing ADLS account
module adlsStorage 'core/storage/storage-account.bicep' = if (useCloudIngestionAcls && !useExistingAdlsStorage && deployIaStack) {
  name: 'adls-storage'
  scope: storageResourceGroup
  params: {
    name: 'adls${abbrs.storageStorageAccounts}${resourceToken}'
    location: storageResourceGroupLocation
    tags: tags
    publicNetworkAccess: publicNetworkAccess
    bypass: bypass
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    isHnsEnabled: true
    sku: {
      name: storageSkuName
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 2
    }
    containers: [
      {
        name: storageContainerName
        publicAccess: 'None'
      }
    ]
  }
}

// WARNING: Cosmos DB partition keys are immutable. If you originally deployed with the v1 container
// (chat-history with a single /userId partition key), re-deploying with the v2 container schema
// (chat-history-v2 with MultiHash /entra_oid + /session_id) will fail with:
//   "Document collection partition key cannot be changed."
// To migrate from v1 to v2, you must either:
//   1. Delete the old container manually (Azure Portal > Cosmos DB > Data Explorer) and re-deploy, OR
//   2. Override chatHistoryContainerName with a new name (e.g. 'chat-history-v3') via azd env set.
// This is an ARM/Cosmos DB platform limitation — Bicep cannot conditionally skip container updates.
module cosmosDb 'br/public:avm/res/document-db/database-account:0.6.1' = if (useAuthentication && useChatHistoryCosmos && deployIaStack) {
  name: 'cosmosdb'
  scope: cosmosDbResourceGroup
  params: {
    name: !empty(cosmosDbAccountName) ? cosmosDbAccountName : '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    location: !empty(cosmosDbLocation) ? cosmosDbLocation : location
    locations: [
      {
        locationName: !empty(cosmosDbLocation) ? cosmosDbLocation : location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    enableFreeTier: cosmosDbSkuName == 'free'
    capabilitiesToAdd: cosmosDbSkuName == 'serverless' ? ['EnableServerless'] : []
    networkRestrictions: {
      ipRules: []
      networkAclBypass: bypass
      publicNetworkAccess: publicNetworkAccess
      virtualNetworkRules: []
    }
    sqlDatabases: [
      {
        name: chatHistoryDatabaseName
        throughput: (cosmosDbSkuName == 'serverless') ? null : cosmosDbThroughput
        containers: [
          {
            name: chatHistoryContainerName
            kind: 'MultiHash'
            paths: [
              '/entra_oid'
              '/session_id'
            ]
            indexingPolicy: {
              indexingMode: 'consistent'
              automatic: true
              includedPaths: [
                {
                  path: '/entra_oid/?'
                }
                {
                  path: '/session_id/?'
                }
                {
                  path: '/timestamp/?'
                }
                {
                  path: '/type/?'
                }
              ]
              excludedPaths: [
                {
                  path: '/*'
                }
              ]
            }
          }
        ]
      }
    ]
  }
}

module ai 'core/ai/ai-environment.bicep' = if (useAiProject) {
  name: 'ai'
  scope: resourceGroup
  params: {
    // Limited region support: https://learn.microsoft.com/azure/ai-foundry/how-to/develop/evaluate-sdk#region-support
    location: 'eastus2'
    tags: tags
    hubName: 'aihub-${resourceToken}'
    projectName: 'aiproj-${resourceToken}'
    storageAccountId: storage.outputs.id
    applicationInsightsId: !useApplicationInsights ? '' : monitoring!.outputs.applicationInsightsId
  }
}


// ----------------------------------------------------------------------
// HelpSphere — Story 06.5a Sessão 2.3 — Azure SQL Server (AVM)
//
// Production-grade (Decisão #5 do DECISION-LOG):
// - SKU GP_S_Gen5_2 (Serverless com autoPause DESABILITADO — Decisão #18)
// - AAD admin via Entra Group (turnover-resilient, audit-friendly, CAF-aligned)
// - azureADOnlyAuthentication=true: SEM SQL auth tradicional, apenas Entra
// - publicNetworkAccess controlado pelo param geral (default Enabled, override
//   para Disabled quando usePrivateEndpoint=true via override no main)
// - GRANT roles à backend MI acontece via scripts/sql_init.py (postprovision hook)
// ----------------------------------------------------------------------
module sqlServer 'br/public:avm/res/sql/server:0.10.0' = if (useSqlServer && !empty(sqlAadAdminGroupObjectId)) {
  scope: resourceGroup
  name: 'sql-server'
  params: {
    name: !empty(sqlServerName) ? sqlServerName : '${abbrs.sqlServers}${environmentName}-${shortToken}'
    location: location
    administrators: {
      administratorType: 'ActiveDirectory'
      login: sqlAadAdminGroupName
      sid: sqlAadAdminGroupObjectId
      tenantId: tenant().tenantId
      principalType: 'Group'
      azureADOnlyAuthentication: true
    }
    // Decisão #15.5 (Sessão 5, opção B): SystemAssigned MI no SQL Server +
    // grant manual de Directory Reader (one-time). Necessário para que SQL
    // consiga resolver nomes de External Principals (User Managed Identities)
    // quando sql_init.py executa CREATE USER FROM EXTERNAL PROVIDER.
    // Sem isso: error 33134 "Server identity is not configured".
    // Após este Bicep deploy, manualmente:
    //   ./scripts/grant_sql_directory_reader.sh (ver script + DECISION-LOG #15.5)
    managedIdentities: {
      systemAssigned: true
    }
    minimalTlsVersion: '1.2'
    publicNetworkAccess: publicNetworkAccess
    databases: [
      {
        name: sqlDatabaseName
        sku: {
          name: 'GP_S_Gen5_2'
          tier: 'GeneralPurpose'
          capacity: 2
        }
        // Sessão 3.5: AVM sql/server:0.10.0 usa interface flat para DB props — Decisão #9
        // Sessão 9.2 (Decisão #18): autoPauseDelay default = -1 (DESABILITADO).
        // v2.1.0 (Sessão 9.5): parametrizado via `sqlAutoPauseDelay`.
        // Trade-off: ~$15-30/mês a mais vs interrupção do app durante demo.
        // Cold-start de Serverless paused leva 30-60s; backend Python (Connection
        // Timeout=60s) cobre, mas tickets-service .NET pode ter primeira request
        // lenta. Para ambiente de aula gravada, confiabilidade > FinOps savings.
        // Aluno em produção pode setar AZURE_SQL_AUTO_PAUSE_DELAY=60 (azd env) aceitando o trade-off.
        autoPauseDelay: sqlAutoPauseDelay
        minCapacity: '0.5'
        maxSizeBytes: 2147483648 // 2 GiB — suficiente para HelpSphere de aula
        // Sessão 4 (Decisão #11): zone redundancy explicitamente false.
        // Default do AVM em westus3 tenta criar com zone redundancy; sub Partner
        // não suporta na sub atual ("ProvisioningDisabled: Provisioning of zone
        // redundant database/pool is not supported for your current request").
        // Para ambientes prod com sub Enterprise + capacidade adequada, alterar para true.
        zoneRedundant: false
      }
    ]
    firewallRules: [
      {
        name: 'AllowAllAzureServices'
        startIpAddress: '0.0.0.0'
        endIpAddress: '0.0.0.0'
      }
    ]
    tags: tags
  }
}


// USER ROLES
var principalType = empty(runningOnGh) && empty(runningOnAdo) ? 'User' : 'ServicePrincipal'

module openAiRoleUser 'core/security/role.bicep' = if (isAzureOpenAiHost && deployAzureOpenAi && deployIaStack) {
  scope: openAiResourceGroup
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: principalType
  }
}

// For both Document Intelligence and AI vision
module cognitiveServicesRoleUser 'core/security/role.bicep' = if (deployIaStack) {
  scope: resourceGroup
  name: 'cognitiveservices-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: principalType
  }
}

module speechRoleUser 'core/security/role.bicep' = if (deployIaStack) {
  scope: speechResourceGroup
  name: 'speech-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'f2dc8367-1007-4938-bd23-fe263f013447' // Cognitive Services Speech User
    principalType: principalType
  }
}

module storageRoleUser 'core/security/role.bicep' = if (!skipRoleAssignments) {
  scope: storageResourceGroup
  name: 'storage-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
    principalType: principalType
  }
}

module storageContribRoleUser 'core/security/role.bicep' = if (!skipRoleAssignments) {
  scope: storageResourceGroup
  name: 'storage-contrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    principalType: principalType
  }
}

module storageOwnerRoleUser 'core/security/role.bicep' = if (useUserUpload && !skipRoleAssignments) {
  scope: storageResourceGroup
  name: 'storage-owner-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner
    principalType: principalType
  }
}

module searchRoleUser 'core/security/role.bicep' = if (deployIaStack) {
  scope: searchServiceResourceGroup
  name: 'search-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '1407120a-92aa-4202-b7e9-c0e197c71c8f' // Search Index Data Reader
    principalType: principalType
  }
}

module searchContribRoleUser 'core/security/role.bicep' = if (deployIaStack) {
  scope: searchServiceResourceGroup
  name: 'search-contrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7' // Search Index Data Contributor
    principalType: principalType
  }
}

module searchSvcContribRoleUser 'core/security/role.bicep' = if (deployIaStack) {
  scope: searchServiceResourceGroup
  name: 'search-svccontrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '7ca78c08-252a-4471-8644-bb5ff32d4ba0' // Search Service Contributor
    principalType: principalType
  }
}

module cosmosDbAccountContribRoleUser 'core/security/role.bicep' = if (useAuthentication && useChatHistoryCosmos && deployIaStack) {
  scope: cosmosDbResourceGroup
  name: 'cosmosdb-account-contrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: '5bd9cd88-fe45-4216-938b-f97437e15450'
    principalType: principalType
  }
}

// RBAC for Cosmos DB
// https://learn.microsoft.com/azure/cosmos-db/nosql/security/how-to-grant-data-plane-role-based-access
module cosmosDbDataContribRoleUser 'core/security/documentdb-sql-role.bicep' = if (useAuthentication && useChatHistoryCosmos && deployIaStack) {
  scope: cosmosDbResourceGroup
  name: 'cosmosdb-data-contrib-role-user'
  params: {
    databaseAccountName: (useAuthentication && useChatHistoryCosmos) ? cosmosDb!.outputs.name : ''
    principalId: principalId
    // Cosmos DB Built-in Data Contributor role
    roleDefinitionId: (useAuthentication && useChatHistoryCosmos)
      ? '/${subscription().id}/resourceGroups/${cosmosDb!.outputs.resourceGroupName}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDb!.outputs.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
      : ''
  }
}

// SYSTEM IDENTITIES
module openAiRoleBackend 'core/security/role.bicep' = if (isAzureOpenAiHost && deployAzureOpenAi && deployIaStack) {
  scope: openAiResourceGroup
  name: 'openai-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
}

module openAiRoleSearchService 'core/security/role.bicep' = if (isAzureOpenAiHost && deployAzureOpenAi && searchServiceSkuName != 'free' && deployIaStack) {
  scope: openAiResourceGroup
  name: 'openai-role-searchservice'
  params: {
    principalId: searchService.outputs.systemAssignedPrincipalId
    roleDefinitionId: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
    principalType: 'ServicePrincipal'
  }
}

module visionRoleSearchService 'core/security/role.bicep' = if (useMultimodal && searchServiceSkuName != 'free' && deployIaStack) {
  scope: visionResourceGroup
  name: 'vision-role-searchservice'
  params: {
    principalId: searchService.outputs.systemAssignedPrincipalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: 'ServicePrincipal'
  }
}

module storageRoleBackend 'core/security/role.bicep' = if (!skipRoleAssignments) {
  scope: storageResourceGroup
  name: 'storage-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
    principalType: 'ServicePrincipal'
  }
}

module storageOwnerRoleBackend 'core/security/role.bicep' = if (useUserUpload && !skipRoleAssignments) {
  scope: storageResourceGroup
  name: 'storage-owner-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner
    principalType: 'ServicePrincipal'
  }
}

// Search service needs blob read access for both integrated vectorization and cloud ingestion indexer data source
module storageRoleSearchService 'core/security/role.bicep' = if ((useIntegratedVectorization || useCloudIngestion) && searchServiceSkuName != 'free' && deployIaStack) {
  scope: storageResourceGroup
  name: 'storage-role-searchservice'
  params: {
    principalId: searchService.outputs.systemAssignedPrincipalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
    principalType: 'ServicePrincipal'
  }
}

module storageRoleContributorSearchService 'core/security/role.bicep' = if ((useIntegratedVectorization && useMultimodal) && searchServiceSkuName != 'free' && deployIaStack) {
  scope: storageResourceGroup
  name: 'storage-role-contributor-searchservice'
  params: {
    principalId: searchService.outputs.systemAssignedPrincipalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    principalType: 'ServicePrincipal'
  }
}

// ADLS Gen2 storage role assignments for cloud ingestion with ACLs
// These are scoped to the ADLS storage account itself, so they work for both
// provisioned and bring-your-own (BYO) ADLS storage accounts
module adlsStorageRoleSearchService 'core/security/storage-role.bicep' = if (useCloudIngestionAcls && searchServiceSkuName != 'free' && deployIaStack) {
  scope: adlsStorageResourceGroup
  name: 'adls-storage-role-searchservice'
  params: {
    storageAccountName: adlsStorageAccountNameResolved
    principalId: searchService.outputs.systemAssignedPrincipalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Owner on ADLS storage for user to manage ACLs
module adlsStorageOwnerRoleUser 'core/security/storage-role.bicep' = if (useCloudIngestionAcls && deployIaStack && !skipRoleAssignments) {
  scope: adlsStorageResourceGroup
  name: 'adls-storage-owner-role-user'
  params: {
    storageAccountName: adlsStorageAccountNameResolved
    principalId: principalId
    roleDefinitionId: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner
    principalType: principalType
  }
}

// Storage Blob Data Reader on ADLS storage for Azure Functions to read during cloud ingestion
// Note: This module requires useCloudIngestion=true because it references functions!.outputs.principalId.
// If useCloudIngestionAcls=true but useCloudIngestion=false, deployment will fail.
// Documentation states USE_CLOUD_INGESTION_ACLS requires USE_CLOUD_INGESTION to be true.
module adlsStorageRoleFunctions 'core/security/storage-role.bicep' = if (useCloudIngestionAcls && useCloudIngestion && deployIaStack && !skipRoleAssignments) {
  scope: adlsStorageResourceGroup
  name: 'adls-storage-role-functions'
  params: {
    storageAccountName: adlsStorageAccountNameResolved
    principalId: functions!.outputs.principalId
    roleDefinitionId: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1' // Storage Blob Data Reader
    principalType: 'ServicePrincipal'
  }
}

// Necessary for the Container Apps backend to store authentication tokens in the blob storage container
module storageRoleContributorBackend 'core/security/role.bicep' = if (deploymentTarget == 'containerapps' && !empty(clientAppId) && !skipRoleAssignments) {
  scope: storageResourceGroup
  name: 'storage-role-contributor-aca-backend'
  params: {
    principalId: acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    principalType: 'ServicePrincipal'
  }
}

// Used to issue search queries
// https://learn.microsoft.com/azure/search/search-security-rbac
module searchRoleBackend 'core/security/role.bicep' = if (deployIaStack) {
  scope: searchServiceResourceGroup
  name: 'search-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
    principalType: 'ServicePrincipal'
  }
}

module speechRoleBackend 'core/security/role.bicep' = if (deployIaStack) {
  scope: speechResourceGroup
  name: 'speech-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: 'f2dc8367-1007-4938-bd23-fe263f013447' // Cognitive Services Speech User
    principalType: 'ServicePrincipal'
  }
}

// RBAC for Cosmos DB
// https://learn.microsoft.com/azure/cosmos-db/nosql/security/how-to-grant-data-plane-role-based-access
module cosmosDbRoleBackend 'core/security/documentdb-sql-role.bicep' = if (useAuthentication && useChatHistoryCosmos && deployIaStack) {
  scope: cosmosDbResourceGroup
  name: 'cosmosdb-role-backend'
  params: {
    databaseAccountName: (useAuthentication && useChatHistoryCosmos) ? cosmosDb!.outputs.name : ''
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    // Cosmos DB Built-in Data Contributor role
    roleDefinitionId: (useAuthentication && useChatHistoryCosmos)
      ? '/${subscription().id}/resourceGroups/${cosmosDb!.outputs.resourceGroupName}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDb!.outputs.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
      : ''
  }
}

module isolation 'network-isolation.bicep' = if (usePrivateEndpoint) {
  name: 'networks'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    vnetName: '${abbrs.virtualNetworks}${resourceToken}'
    deploymentTarget: deploymentTarget
    useVpnGateway: useVpnGateway
    vpnGatewayName: useVpnGateway ? '${abbrs.networkVpnGateways}${resourceToken}' : ''
    dnsResolverName: useVpnGateway ? '${abbrs.privateDnsResolver}${resourceToken}' : ''
  }
}

var environmentData = environment()

var openAiPrivateEndpointConnection = (usePrivateEndpoint && isAzureOpenAiHost && deployAzureOpenAi)
  ? [
      {
        groupId: 'account'
        dnsZoneName: 'privatelink.openai.azure.com'
        resourceIds: [openAi!.outputs.resourceId]
      }
    ]
  : []

var cognitiveServicesPrivateEndpointConnection = (usePrivateEndpoint && (!useLocalPdfParser || useMultimodal || useMediaDescriberAzureCU))
  ? [
      {
        groupId: 'account'
        dnsZoneName: 'privatelink.cognitiveservices.azure.com'
        // Only include generic Cognitive Services-based resources (Form Recognizer / Vision / Content Understanding)
        // Azure OpenAI uses its own privatelink.openai.azure.com zone and already has a separate private endpoint above.
        resourceIds: concat(
          !useLocalPdfParser ? [documentIntelligence.outputs.resourceId] : [],
          useMultimodal ? [vision!.outputs.resourceId] : [],
          useMediaDescriberAzureCU ? [contentUnderstanding!.outputs.resourceId] : []
        )
      }
    ]
  : []

var containerAppsPrivateEndpointConnection = (usePrivateEndpoint && deploymentTarget == 'containerapps')
  ? [
      {
        groupId: 'managedEnvironments'
        dnsZoneName: 'privatelink.${location}.azurecontainerapps.io'
        resourceIds: [containerApps!.outputs.environmentId]
      }
    ]
  : []

var appServicePrivateEndpointConnection = (usePrivateEndpoint && deploymentTarget == 'appservice')
  ? [
      {
        groupId: 'sites'
        dnsZoneName: 'privatelink.azurewebsites.net'
        resourceIds: [backend!.outputs.id]
      }
    ]
  : []
var otherPrivateEndpointConnections = (usePrivateEndpoint)
  ? [
      {
        groupId: 'blob'
        dnsZoneName: 'privatelink.blob.${environmentData.suffixes.storage}'
        resourceIds: concat([storage.outputs.id], useUserUpload ? [userStorage!.outputs.id] : [])
      }
      {
        groupId: 'searchService'
        dnsZoneName: 'privatelink.search.windows.net'
        resourceIds: [searchService.outputs.id]
      }
      {
        groupId: 'sql'
        dnsZoneName: 'privatelink.documents.azure.com'
        resourceIds: (useAuthentication && useChatHistoryCosmos) ? [cosmosDb!.outputs.resourceId] : []
      }
    ]
  : []

var privateEndpointConnections = concat(otherPrivateEndpointConnections, openAiPrivateEndpointConnection, cognitiveServicesPrivateEndpointConnection, containerAppsPrivateEndpointConnection, appServicePrivateEndpointConnection)

module privateEndpoints 'private-endpoints.bicep' = if (usePrivateEndpoint) {
  name: 'privateEndpoints'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
    privateEndpointConnections: privateEndpointConnections
    applicationInsightsId: useApplicationInsights ? monitoring!.outputs.applicationInsightsId : ''
    logAnalyticsWorkspaceId: useApplicationInsights ? monitoring!.outputs.logAnalyticsWorkspaceId : ''
    vnetName: isolation!.outputs.vnetName
    vnetPeSubnetId: isolation!.outputs.backendSubnetId
  }
}

// Used to read index definitions (required when using authentication)
// https://learn.microsoft.com/azure/search/search-security-rbac
module searchReaderRoleBackend 'core/security/role.bicep' = if (useAuthentication && deployIaStack) {
  scope: searchServiceResourceGroup
  name: 'search-reader-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
    principalType: 'ServicePrincipal'
  }
}

// Used to add/remove documents from index (required for user upload feature)
module searchContribRoleBackend 'core/security/role.bicep' = if (useUserUpload && deployIaStack) {
  scope: searchServiceResourceGroup
  name: 'search-contrib-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
    principalType: 'ServicePrincipal'
  }
}

// For Azure AI Vision access by the backend
module visionRoleBackend 'core/security/role.bicep' = if (useMultimodal && deployIaStack) {
  scope: visionResourceGroup
  name: 'vision-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: 'ServicePrincipal'
  }
}

// For document intelligence access by the backend
module documentIntelligenceRoleBackend 'core/security/role.bicep' = if (useUserUpload && deployIaStack) {
  scope: documentIntelligenceResourceGroup
  name: 'documentintelligence-role-backend'
  params: {
    principalId: (deploymentTarget == 'appservice')
      ? backend!.outputs.identityPrincipalId
      : acaBackend!.outputs.identityPrincipalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908'
    principalType: 'ServicePrincipal'
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenantId
// Story 06.5c.3 (B-PRACTICAL): AZURE_AUTH_TENANT_ID removido para abrir slot
// para TICKETS_BACKEND_URI (max-outputs=64). Não usado em nosso flow com
// AZURE_USE_AUTHENTICATION=false. Re-adicionar se Story 06.5c.6 ativar auth real.
output AZURE_RESOURCE_GROUP string = resourceGroup.name

// Shared by all OpenAI deployments
output OPENAI_HOST string = openAiHost
output AZURE_OPENAI_EMB_MODEL_NAME string = embedding.modelName
output AZURE_OPENAI_EMB_DIMENSIONS int = embedding.dimensions
output AZURE_OPENAI_CHATGPT_MODEL string = chatGpt.modelName

// Specific to Azure OpenAI
output AZURE_OPENAI_SERVICE string = isAzureOpenAiHost && deployAzureOpenAi && deployIaStack ? openAi!.outputs.name : ''
output AZURE_OPENAI_ENDPOINT string = isAzureOpenAiHost && deployAzureOpenAi && deployIaStack ? openAi!.outputs.endpoint : ''
output AZURE_OPENAI_RESOURCE_GROUP string = isAzureOpenAiHost ? openAiResourceGroup.name : ''
output AZURE_OPENAI_CHATGPT_DEPLOYMENT string = isAzureOpenAiHost ? chatGpt.deploymentName : ''
output AZURE_OPENAI_CHATGPT_DEPLOYMENT_VERSION string = isAzureOpenAiHost ? chatGpt.deploymentVersion : ''
output AZURE_OPENAI_CHATGPT_DEPLOYMENT_SKU string = isAzureOpenAiHost ? chatGpt.deploymentSkuName : ''
output AZURE_OPENAI_EMB_DEPLOYMENT string = isAzureOpenAiHost ? embedding.deploymentName : ''
output AZURE_OPENAI_EMB_DEPLOYMENT_VERSION string = isAzureOpenAiHost ? embedding.deploymentVersion : ''
output AZURE_OPENAI_EMB_DEPLOYMENT_SKU string = isAzureOpenAiHost ? embedding.deploymentSkuName : ''
output AZURE_OPENAI_EVAL_DEPLOYMENT string = isAzureOpenAiHost && useEval ? eval.deploymentName : ''
output AZURE_OPENAI_EVAL_DEPLOYMENT_VERSION string = isAzureOpenAiHost && useEval ? eval.deploymentVersion : ''
// Story 06.5c.4: AZURE_OPENAI_EVAL_DEPLOYMENT_SKU removido (informational, redundante com deployment name).
// Surpresa #14 reiterada: ARM hard limit 64 outputs. Trade-off: workflows GH Actions consomem o SKU
// via GH `vars.AZURE_OPENAI_EVAL_DEPLOYMENT_SKU` (não via azd output), então CI permanece funcional.
// Devs locais executando eval podem setar AZURE_OPENAI_EVAL_DEPLOYMENT_SKU manualmente em .azure/env/.env.
output AZURE_OPENAI_EVAL_MODEL string = isAzureOpenAiHost && useEval ? eval.modelName : ''
output AZURE_OPENAI_KNOWLEDGEBASE_DEPLOYMENT string = isAzureOpenAiHost && useAgenticKnowledgeBase ? knowledgeBase.deploymentName : ''
output AZURE_OPENAI_KNOWLEDGEBASE_MODEL string = isAzureOpenAiHost && useAgenticKnowledgeBase ? knowledgeBase.modelName : ''
output AZURE_OPENAI_REASONING_EFFORT string  = defaultReasoningEffort
output AZURE_SEARCH_KNOWLEDGEBASE_RETRIEVAL_REASONING_EFFORT string = defaultRetrievalReasoningEffort
// Sessão 3.5: AZURE_SPEECH_SERVICE_ID/LOCATION removidos para ficar abaixo do limite Bicep de 64 outputs.
// Backend (app.py) usa os.getenv com guard `if useSpeechOutputAzure` (default false) — não quebra.
// Tests usam monkeypatch (independente). Decisão #9.

output AZURE_VISION_ENDPOINT string = useMultimodal ? vision!.outputs.endpoint : ''
output AZURE_CONTENTUNDERSTANDING_ENDPOINT string = useMediaDescriberAzureCU ? contentUnderstanding!.outputs.endpoint : ''

output AZURE_DOCUMENTINTELLIGENCE_SERVICE string = deployIaStack ? documentIntelligence!.outputs.name : ''
output AZURE_DOCUMENTINTELLIGENCE_RESOURCE_GROUP string = documentIntelligenceResourceGroup.name

output AZURE_SEARCH_INDEX string = searchIndexName
output AZURE_SEARCH_KNOWLEDGEBASE_NAME string = knowledgeBaseName
output AZURE_SEARCH_SERVICE string = deployIaStack ? searchService!.outputs.name : ''
output AZURE_SEARCH_SERVICE_RESOURCE_GROUP string = searchServiceResourceGroup.name
output AZURE_SEARCH_SEMANTIC_RANKER string = actualSearchServiceSemanticRankerLevel
output AZURE_SEARCH_FIELD_NAME_EMBEDDING string = searchFieldNameEmbedding
output AZURE_SEARCH_USER_ASSIGNED_IDENTITY_RESOURCE_ID string = deployIaStack ? searchService!.outputs.userAssignedIdentityResourceId : ''

output AZURE_COSMOSDB_ACCOUNT string = (useAuthentication && useChatHistoryCosmos) ? cosmosDb!.outputs.name : ''
output AZURE_CHAT_HISTORY_DATABASE string = chatHistoryDatabaseName
output AZURE_CHAT_HISTORY_CONTAINER string = chatHistoryContainerName
// Sessão 3.5: AZURE_CHAT_HISTORY_VERSION removido (constante hardcoded, não consumida) — Decisão #9

output AZURE_STORAGE_ACCOUNT string = storage.outputs.name
output AZURE_STORAGE_CONTAINER string = storageContainerName
output AZURE_STORAGE_RESOURCE_GROUP string = storageResourceGroup.name

output AZURE_ADLS_STORAGE_ACCOUNT string = useCloudIngestionAcls ? adlsStorageAccountNameResolved : ''
output AZURE_CLOUD_INGESTION_STORAGE_ACCOUNT string = useCloudIngestionAcls ? adlsStorageAccountNameResolved : storage.outputs.name
output AZURE_CLOUD_INGESTION_STORAGE_RESOURCE_GROUP string = useCloudIngestionAcls ? adlsStorageResourceGroup.name : storageResourceGroup.name
output USE_CLOUD_INGESTION_ACLS bool = useCloudIngestionAcls

output AZURE_USERSTORAGE_ACCOUNT string = useUserUpload ? userStorage!.outputs.name : ''
output AZURE_USERSTORAGE_CONTAINER string = userStorageContainerName
output AZURE_USERSTORAGE_RESOURCE_GROUP string = storageResourceGroup.name

output AZURE_IMAGESTORAGE_CONTAINER string = useMultimodal ? imageStorageContainerName : ''

// Cloud ingestion function skill endpoints & resource IDs
output DOCUMENT_EXTRACTOR_SKILL_ENDPOINT string = useCloudIngestion ? 'https://${functions!.outputs.documentExtractorUrl}/api/extract' : ''
output FIGURE_PROCESSOR_SKILL_ENDPOINT string = useCloudIngestion ? 'https://${functions!.outputs.figureProcessorUrl}/api/process' : ''
output TEXT_PROCESSOR_SKILL_ENDPOINT string = useCloudIngestion ? 'https://${functions!.outputs.textProcessorUrl}/api/process' : ''
// Identifier URI used as authResourceId for all custom skill endpoints
output DOCUMENT_EXTRACTOR_SKILL_AUTH_RESOURCE_ID string = useCloudIngestion ? functions!.outputs.documentExtractorAuthIdentifierUri : ''
output FIGURE_PROCESSOR_SKILL_AUTH_RESOURCE_ID string = useCloudIngestion ? functions!.outputs.figureProcessorAuthIdentifierUri : ''
output TEXT_PROCESSOR_SKILL_AUTH_RESOURCE_ID string = useCloudIngestion ? functions!.outputs.textProcessorAuthIdentifierUri : ''

// Sessão 3.5: AZURE_AI_PROJECT removido (zero consumers, useAiProject=false default) — Decisão #9

output AZURE_USE_AUTHENTICATION bool = useAuthentication

output BACKEND_URI string = deploymentTarget == 'appservice' ? backend!.outputs.uri : acaBackend!.outputs.uri

// HelpSphere — Story 06.5c.3 (B-PRACTICAL): tickets-service URI para smoke test
// Nota: AZURE_TICKETS_CLIENT_ID NÃO é exportado (max-outputs=64). UMI clientId já é
// passado via env var AZURE_CLIENT_ID dentro do ACA tickets (suficiente para MI auth).
output TICKETS_BACKEND_URI string = deploymentTarget == 'containerapps' ? acaTickets!.outputs.uri : ''
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = deploymentTarget == 'containerapps'
  ? containerApps!.outputs.registryLoginServer
  : ''

// Sessão 3.5: AZURE_VPN_CONFIG_DOWNLOAD_LINK removido (usado só em prepdocs.py log, fallback graceful) — Decisão #9

// HelpSphere — Story 06.5a Sessão 2.3 (SQL outputs consumidos por scripts/sql_init.py)
// Sessão 3.5: FQDN via environment().suffixes.sqlServerHostname — Decisão #9
output AZURE_SQL_SERVER string = useSqlServer && !empty(sqlAadAdminGroupObjectId) ? '${sqlServer!.outputs.name}${environment().suffixes.sqlServerHostname}' : ''
output AZURE_SQL_DATABASE string = useSqlServer ? sqlDatabaseName : ''
// Decisão #15.5: principalId do System MI do SQL Server, para grant manual de Directory Reader
output AZURE_SQL_SERVER_PRINCIPAL_ID string = useSqlServer && !empty(sqlAadAdminGroupObjectId) ? sqlServer!.outputs.systemAssignedMIPrincipalId : ''
output AZURE_SQL_BACKEND_MI_NAME string = useSqlServer
  ? ((deploymentTarget == 'containerapps')
      ? acaIdentityName
      : '${environmentName}-app-identity')
  : ''
// Story 06.5c.4: tickets MI display name para sql_init.py criar 2nd CREATE USER FROM EXTERNAL PROVIDER + scoped grants
output AZURE_SQL_TICKETS_MI_NAME string = useSqlServer && deploymentTarget == 'containerapps'
  ? acaTicketsIdentityName
  : ''
output AZURE_LOAD_SEED_DATA bool = loadSeedData

// HelpSphere v2.1.0 (Sessão 9.5) — params parametrizados (pythonVersion, additionalCorsOrigins,
// skipPrepdocs, enableChat, tokenAudienceFormat, sqlAutoPauseDelay) NÃO são exportados como outputs:
// limite ARM de 64 outputs já saturado. Hooks/scripts leem direto do azd env via SKIP_PREPDOCS,
// ENABLE_CHAT, TOKEN_AUDIENCE_FORMAT, etc. (mapeamento em main.parameters.json).
