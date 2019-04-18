-- luacheck: globals vim

local client = {}
client.mapping = {}
client.buffer ={}

local utils = {}
utils.random = function(sz)
  local gen = {
    [[head -c 100 /dev/urandom]],
    [[md5sum]],
    [[awk '{print toupper($1)}']],
    [[xargs -I{} echo "obase=10; ibase=16; {}"]],
    [[bc]] ,
    [[tr '\n' ' ']],
    [[sed 's/\\* //g']],
  }

  local random = vim.api.nvim_call_function("system", {
      table.concat(gen, " | ")
    })

  return tonumber(random:sub(1, sz))
end

client.call = function(handler, cmd, id)
  id = id or utils.random(5)
  local handler_name = "NecromancerClient" .. id

  client.buffer[id] = {stdout = {}, stderr = {}}
  client.mapping[id] = function(args)

    if args[3] == "exit" then
      --vim.api.nvim_command("delfunction! " .. handler_name)
      handler(client.buffer[id])
    else
      for _, v in ipairs(args[2]) do
        if v ~= "" then
          table.insert(client.buffer[id][args[3]], v)
        end
      end
    end
  end
  vim.api.nvim_call_function("execute", {{
      "function! ".. handler_name .. "(...)",
        [[call luaeval("require('necromancer.client').mapping[]].. id .. [[](_A)", a:000)]],
      "endfunction"
  }})

  local ret = vim.api.nvim_call_function('jobstart', {
      cmd , {
        on_stdout = handler_name,
        on_stderr = handler_name,
        on_exit = handler_name
      }
    })

   if ret <= 0 then
     -- TODO log, inform..
     return
   end

   return id
end

client.cmd_builder = function(map)
  return setmetatable(map, {__index = function(tbl, key)
    table.insert(tbl, key)
    return client.cmd_builder(tbl)
    end,
    __call = function(tbl, handler, args)
      return client.call(handler, table.concat(tbl, " ") .. ((args and " " ..args) or ""))
    end
  })
end

client.aws = client.cmd_builder({"aws"})
return client
