local user_router = require("app.routes.user")
local cluster_router = require("app.routes.cluster")

return function(app)
    user_router(app:group("/user"))
    cluster_router(app:group("/cluster"))
end
