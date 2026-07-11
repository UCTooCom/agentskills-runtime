package magic.app.services.aip.model

import magic.app.core.response.APIResult

public type MqMessageCallbackFunc = (String, String, String, String, String, ?String) -> APIResult<Bool>