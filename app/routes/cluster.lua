return function(router)

local model_cluster = require "app.model.cluster"

-- 查看所有节点数据
router:get("/list", function(c)
    local nodes = model_cluster.get_nodes()
    c:send_json({
        code = "OK",
        data = {
            nodes = nodes,
        },
    })
end)

-- 新增 cluster 节点
router:post("/add", function(c)
    local name = c.req.body.name
    local addr = c.req.body.addr
    local code, msg = model_cluster.add_node(name, addr)
    c:send_json({
        code = code,
        msg = msg,
    })
end)

-- 更新 cluster 节点
router:post("/update", function(c)
    local name = c.req.body.name
    local addr = c.req.body.addr
    local code, msg = model_cluster.update_node(name, addr)
    c:send_json({
        code = code,
        msg = msg,
    })
end)

-- 删除 cluster 节点
router:post("/del", function(c)
    local name = c.req.body.name
    local code, msg = model_cluster.del_node(name)
    c:send_json({
        code = code,
        msg = msg,
    })
end)

end
