require('expl3.lua')
local char    = string.char
local byte    = string.byte
local utfchar = utf8.char
local utfbyte = utf8.codepoint

local function fake_utf_read(buf)
    return utfchar(byte(buf, 1, -1))
end

local function fake_utf_write(buf)
    return char(utfbyte(buf, 1, -1))
end

luatexbase.add_to_callback('process_output_buffer', fake_utf_write, "utf8 writing")
luatexbase.add_to_callback('process_input_buffer', fake_utf_read, "utf8 reading")


-- Emulate TeX--XeT
local function add_dir_node(dir, t)
  return function(func)
    local mode = tex.nest.top.mode
    if mode < 0 then mode = -mode end
    if tex.getmodevalues()[mode] == 'vertical' then
      token.put_next(token.new(func, token.command_id'lua_call'))
      tex.forcehmode()
      return
    end
    local n = node.new'dir'
    n.dir = dir
    node.write(n)
  end
end

local func = luatexbase.new_luafunction'beginL'
token.set_lua('beginL', func, 'protected')
lua.get_functions_table()[func] = add_dir_node'+TLT'

func = luatexbase.new_luafunction'beginR'
token.set_lua('beginR', func, 'protected')
lua.get_functions_table()[func] = add_dir_node'+TRT'

func = luatexbase.new_luafunction'endL'
token.set_lua('endL', func, 'protected')
lua.get_functions_table()[func] = add_dir_node'-TLT'

func = luatexbase.new_luafunction'endR'
token.set_lua('endR', func, 'protected')
lua.get_functions_table()[func] = add_dir_node'-TRT'

local traverse = node.traverse
local function process(head, direction)
  local stack = {}
  for n, id, sub in traverse(head) do
    if id == node.id'hlist' or id == node.id'vlist' then
      n.direction = direction -- There should be some special case related to math here...
      process(n.head, direction)
    elseif id == node.id'dir' then
      print(#stack, direction, n)
      if sub == 0 then
        stack[#stack + 1], direction = direction, n.direction
      else
        if #stack == 0 or direction ~= n.direction then
          print(direction, n.direction, #stack)
        end
        stack[#stack], direction = nil, stack[#stack]
      end
    end
    -- Missing case: leaders, (local_par Doesn't seem necessary) {others?)
  end
end

local texxetstate_id = token.create'TeXXeTstate'.index
--[[
luatexbase.add_to_callback('pre_shipout_filter', function(n)
  if tex.count[texxetstate_id] > 0 then
    process(n.head, 0)
    n.direction = 0
  end
  return true
end, 'TeXXeT')
luatexbase.add_to_callback('post_mlist_to_hlist_filter', function(n)
  if tex.count[texxetstate_id] <= 0 then return true end
  local beginL = node.new'dir'
  beginL.dir = '+TLT'
  local endL = node.new'dir'
  endL.dir = '-TLT'
  return (node.insert_after(node.insert_before(n, n, beginL), nil, endL))
end, 'TeXXeT')
]]
