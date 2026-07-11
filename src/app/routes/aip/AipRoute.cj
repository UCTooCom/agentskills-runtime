/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.aip

import magic.app.core.router.Router
import magic.app.controllers.aip.{AipIdentityController, AipDescriptionController, AipDiscoveryController, AipInteractionController, AipConfigController, AipHealthController}

public class AipRoute {
    private var router: Router
    private var identityController: AipIdentityController
    private var descriptionController: AipDescriptionController
    private var discoveryController: AipDiscoveryController
    private var interactionController: AipInteractionController
    private var configController: AipConfigController
    private var healthController: AipHealthController

    public init(router: Router) {
        this.router = router
        this.identityController = AipIdentityController()
        this.descriptionController = AipDescriptionController()
        this.discoveryController = AipDiscoveryController()
        this.interactionController = AipInteractionController()
        this.configController = AipConfigController()
        this.healthController = AipHealthController()
    }

    public func register(): Unit {
        router.post("/api/v1/uctoo/aip/identity/register-local", identityController.registerLocal)
        router.post("/api/v1/uctoo/aip/identity/agent-login", identityController.agentLogin)
        router.get("/api/v1/uctoo/aip/identity/:agentId", identityController.getIdentity)
        router.get("/api/v1/uctoo/aip/identities/:page/:size", identityController.listIdentities)
        router.post("/api/v1/uctoo/aip/identity/:agentId/disable", identityController.disableAgent)
        router.post("/api/v1/uctoo/aip/identity/:agentId/enable", identityController.enableAgent)
        router.post("/api/v1/uctoo/aip/identity/register-interconnection", identityController.registerInterconnection)
        router.post("/api/v1/uctoo/aip/identity/:agentId/update", identityController.updateIdentity)
        router.post("/api/v1/uctoo/aip/identity/:agentId/lock", identityController.lockIdentity)
        router.post("/api/v1/uctoo/aip/identity/:agentId/unlock", identityController.unlockIdentity)
        router.post("/api/v1/uctoo/aip/identity/:agentId/revoke", identityController.revokeIdentity)

        router.post("/api/v1/uctoo/aip/description/register-local", descriptionController.registerLocal)
        router.get("/api/v1/uctoo/aip/description/:agentId", descriptionController.getDescription)
        router.post("/api/v1/uctoo/aip/description/register-interconnection", descriptionController.registerInterconnection)
        router.post("/api/v1/uctoo/aip/description/publish", descriptionController.publishDescription)
        router.post("/api/v1/uctoo/aip/description/update", descriptionController.updateInterconnection)

        router.post("/api/v1/uctoo/aip/discovery/local", discoveryController.discoverLocal)
        router.post("/api/v1/uctoo/aip/discovery/interconnection", discoveryController.discoverInterconnection)
        router.get("/api/v1/uctoo/aip/discovery/cache/:queryHash", discoveryController.getDiscoveryCache)
        router.post("/api/v1/uctoo/aip/discovery/cache/clean-expired", discoveryController.cleanExpiredCache)
        router.post("/api/v1/uctoo/aip/discovery/cache/:queryHash/refresh", discoveryController.refreshCache)

        router.post("/api/v1/uctoo/aip/interaction/session/local", interactionController.createLocalSession)
        router.post("/api/v1/uctoo/aip/interaction/message/local", interactionController.sendLocalMessage)
        router.get("/api/v1/uctoo/aip/interaction/session/:sessionId/messages/:limit/:page", interactionController.getSessionMessages)
        router.post("/api/v1/uctoo/aip/interaction/session/:sessionId/close", interactionController.closeSession)
        router.post("/api/v1/uctoo/aip/interaction/session/interconnection", interactionController.createInterconnectionSession)
        router.post("/api/v1/uctoo/aip/interaction/message/interconnection", interactionController.sendInterconnectionMessage)
        router.post("/api/v1/uctoo/aip/interaction/session/:sessionId/close-interconnection", interactionController.closeInterconnectionSession)

        router.get("/api/v1/uctoo/aip/config", configController.getConfig)
        router.get("/api/v1/uctoo/aip/config/mode", configController.getMode)
        router.post("/api/v1/uctoo/aip/config/mode/switch", configController.switchMode)

        router.get("/api/v1/uctoo/aip/health/local", healthController.healthLocal)
        router.get("/api/v1/uctoo/aip/health/interconnection", healthController.healthInterconnection)
    }
}