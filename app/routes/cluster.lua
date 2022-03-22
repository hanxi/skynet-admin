return function(router)

local model_cluster = require "app.model.cluster"

-- 查看所有节点数据
router:get("/list", function(c)
    local nodes = model_cluster.get_nodes_status()
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

-- 查看节点详情
router:get("/detail/{name}", function(c)
    local name = c.params.name
    local code, data = model_cluster.get_node_detail(name)
    c:send_json({
        code = code,
        data = data,
    })
end)

-- 重新连接节点
router:post("/reload", function(c)
    local code, msg = model_cluster.reload()
    c:send_json({
        code = code,
        msg = msg,
    })
end)

end
