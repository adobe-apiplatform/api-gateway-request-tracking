package = "api-gateway-request-tracking"
version = "1.1.3-1"
source = {
   url = "git+https://github.com/adobe-apiplatform/api-gateway-request-tracking.git",
   tag = "api-gateway-request-tracking-1.1.3"
}
description = {
   summary = "Lua Module providing a request tracking framework in the API Gateway.",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   platforms = {
      haiku = {
         modules = {
            ["api-gateway.tracking.RequestTrackingManager"] = "src/lua/api-gateway/tracking/RequestTrackingManager.lua",
            ["api-gateway.tracking.RequestVariableManager"] = "src/lua/api-gateway/tracking/RequestVariableManager.lua",
            ["api-gateway.tracking.factory"] = "src/lua/api-gateway/tracking/factory.lua",
            ["api-gateway.tracking.log.trackingRulesLogger"] = "src/lua/api-gateway/tracking/log/trackingRulesLogger.lua",
            ["api-gateway.tracking.validator.blockingRulesValidator"] = "src/lua/api-gateway/tracking/validator/blockingRulesValidator.lua",
            ["api-gateway.tracking.validator.delayingRulesValidator"] = "src/lua/api-gateway/tracking/validator/delayingRulesValidator.lua",
            ["api-gateway.tracking.validator.rewritingRulesValidator"] = "src/lua/api-gateway/tracking/validator/rewritingRulesValidator.lua"
         }
      },
      macosx = {
         modules = {
            ["api-gateway.tracking.RequestTrackingManager"] = "src/lua/api-gateway/tracking/RequestTrackingManager.lua",
            ["api-gateway.tracking.RequestVariableManager"] = "src/lua/api-gateway/tracking/RequestVariableManager.lua",
            ["api-gateway.tracking.factory"] = "src/lua/api-gateway/tracking/factory.lua",
            ["api-gateway.tracking.log.trackingRulesLogger"] = "src/lua/api-gateway/tracking/log/trackingRulesLogger.lua",
            ["api-gateway.tracking.validator.blockingRulesValidator"] = "src/lua/api-gateway/tracking/validator/blockingRulesValidator.lua",
            ["api-gateway.tracking.validator.delayingRulesValidator"] = "src/lua/api-gateway/tracking/validator/delayingRulesValidator.lua",
            ["api-gateway.tracking.validator.rewritingRulesValidator"] = "src/lua/api-gateway/tracking/validator/rewritingRulesValidator.lua"
         }
      },
      mingw32 = {
         modules = {
            ["api-gateway.tracking.RequestTrackingManager"] = "src/lua/api-gateway/tracking/RequestTrackingManager.lua",
            ["api-gateway.tracking.RequestVariableManager"] = "src/lua/api-gateway/tracking/RequestVariableManager.lua",
            ["api-gateway.tracking.factory"] = "src/lua/api-gateway/tracking/factory.lua",
            ["api-gateway.tracking.log.trackingRulesLogger"] = "src/lua/api-gateway/tracking/log/trackingRulesLogger.lua",
            ["api-gateway.tracking.validator.blockingRulesValidator"] = "src/lua/api-gateway/tracking/validator/blockingRulesValidator.lua",
            ["api-gateway.tracking.validator.delayingRulesValidator"] = "src/lua/api-gateway/tracking/validator/delayingRulesValidator.lua",
            ["api-gateway.tracking.validator.rewritingRulesValidator"] = "src/lua/api-gateway/tracking/validator/rewritingRulesValidator.lua"
         }
      },
      unix = {
         modules = {
            ["api-gateway.tracking.RequestTrackingManager"] = "src/lua/api-gateway/tracking/RequestTrackingManager.lua",
            ["api-gateway.tracking.RequestVariableManager"] = "src/lua/api-gateway/tracking/RequestVariableManager.lua",
            ["api-gateway.tracking.factory"] = "src/lua/api-gateway/tracking/factory.lua",
            ["api-gateway.tracking.log.trackingRulesLogger"] = "src/lua/api-gateway/tracking/log/trackingRulesLogger.lua",
            ["api-gateway.tracking.validator.blockingRulesValidator"] = "src/lua/api-gateway/tracking/validator/blockingRulesValidator.lua",
            ["api-gateway.tracking.validator.delayingRulesValidator"] = "src/lua/api-gateway/tracking/validator/delayingRulesValidator.lua",
            ["api-gateway.tracking.validator.rewritingRulesValidator"] = "src/lua/api-gateway/tracking/validator/rewritingRulesValidator.lua"
         }
      },
      win32 = {
         modules = {
            ["api-gateway.tracking.RequestTrackingManager"] = "src/lua/api-gateway/tracking/RequestTrackingManager.lua",
            ["api-gateway.tracking.RequestVariableManager"] = "src/lua/api-gateway/tracking/RequestVariableManager.lua",
            ["api-gateway.tracking.factory"] = "src/lua/api-gateway/tracking/factory.lua",
            ["api-gateway.tracking.log.trackingRulesLogger"] = "src/lua/api-gateway/tracking/log/trackingRulesLogger.lua",
            ["api-gateway.tracking.validator.blockingRulesValidator"] = "src/lua/api-gateway/tracking/validator/blockingRulesValidator.lua",
            ["api-gateway.tracking.validator.delayingRulesValidator"] = "src/lua/api-gateway/tracking/validator/delayingRulesValidator.lua",
            ["api-gateway.tracking.validator.rewritingRulesValidator"] = "src/lua/api-gateway/tracking/validator/rewritingRulesValidator.lua"
         }
      }
   }
}
