--
--Shop controller
--allows you to sell things using different currencies
--------------------------------------
--  ~  digiline
--  b  button
--  C  luacontroller (this)
--  w  vacuum tube
--  t  digiline detecting tube
--  =  pneumatic tube
--  H  chest
--  >  digiline fulter-injector (channel: "flt")
--  l  LCD (channel: "lcd")
--------------------------------------
--   l~
--  bCb~
--  wt=H>=
--------------------------------------
--digilines must connect luacontroller with detecting tube, LCD and digiline filter-injector.
--------------------------------------

--what we sell - you can place here any items
--"name" is what player will see on the lcd
--"item" is itemstack string
--"stock" is how much you have it in the chest
--"price" is price
--don't forget to place your goods into the chest
local gds = {
  {name = "Mining laser mk3", item = "technic:laser_mk3", stock = 3, price = 60},
  {name = "Mining drill mk2", item = "technic:mining_drill_mk2", stock = 9, price = 30},
  {name = "Prospector", item = "technic:prospector", stock = 4, price = 30},
  {name = "Vacuum Cleaner", item = "technic:vacuum", stock = 4, price = 30},
  {name = "Chainsaw", item = "technic:chainsaw", stock = 4, price = 30},
}

--what we buy for
--describe your money instead of thesea
local money = {
  ["default:diamond"] = 1,
  ["default:diamondblock"] = 9,
  ["technic:uranium_lump"] = 2,
  ["crimeaion:coin5"] = 5,
  ["crimeaion:coin10"] = 10,
  ["crimeaion:coin25"] = 25,
  ["crimeaion:bag"] = 100,
  ["crimeaion:bag5"] = 500,
  ["crimeaion:bag10"] = 1000,
  ["crimeaion:box50"] = 5000,
  ["crimeaion:bag100"] = 10000
}

pin_left = "D"  --button
pin_right = "B" --button
return_time = 5 --depends on the tube length

local update_lcd = function()
  if #mem.var.gds == 0 then
    digiline_send("lcd", "Everything sold. Shop is CLOSED")
  else
    if mem.var.current > #mem.var.gds then
      mem.var.current = 1
    end
    local product = mem.var.gds[mem.var.current]
    digiline_send("lcd", product.name .. ", price: " .. product.price .. ", paid: " .. mem.var.payment)
  end
end

--initializing
if event.type == "program" then
  mem.var = {
    gds = gds,
    inserted = {},
    current = 1,
    payment = 0,
    was = 0,
    returns = {},
  }
  digiline_send("lcd", "Shop ready, " .. tostring(event))
  interrupt(1, "ready")
end

--presssing buttons
if event.type == "on" then
  if #mem.var.gds == 0 then return end
  --reset and return any payment
  for i, v in pairs(mem.var.inserted) do
    table.insert(mem.var.returns, v)
  end
  mem.var.inserted = {}
  mem.var.payment = mem.var.was
  interrupt(return_time, "return")

  --select next product
  if event.pin.name == pin_left then
    mem.var.current = mem.var.current - 1
    if mem.var.current <= 0 then
      mem.var.current = #mem.var.gds
    end
  elseif event.pin.name == pin_right then
    mem.var.current = mem.var.current + 1
    if mem.var.current > #mem.var.gds then
      mem.var.current = 1
    end    
  end
  update_lcd()
end

--something is in the pipe
if event.type == "digiline" and event.channel == "item" then
  if #mem.var.gds == 0 then
    table.insert(mem.var.returns, event.msg)
    interrupt(return_time, "return")
    return
  end

  local item = event.msg
  local count = tonumber(event.msg:sub(-2))
  if count == nil then count = 1 end
  if count > 9 then
    item = event.msg:sub(1, -4)
  elseif count > 1 then
    item = event.msg:sub(1, -3)
  end
  local payment = money[item]

--incorrect money
  if payment == nil then
    table.insert(mem.var.returns, event.msg)
    interrupt(return_time, "return")
    interrupt(1, "incorrect")


    local itemname = event.msg
    local length = itemname:len()
    local position = 12--itemname:find(":")
    local output = itemname:sub(1, position) .. "\n"
        while position < length do
        output = output .. itemname:sub(position + 1, position + 12) .. "\n"
        position = position + 12
        end
    digiline_send("lcd", "incorrect item: " .. output)

--correct money
  else
    table.insert(mem.var.inserted, event.msg)
    payment = payment * count
    mem.var.payment = mem.var.payment + payment
    local product = mem.var.gds[mem.var.current]
    local quantity = math.floor(mem.var.payment / product.price)
    if product.stock < quantity then quantity = product.stock end

  --enough, let's buy
    if quantity >= 1 then
      --buy 1 right now
      mem.var.payment = mem.var.payment - product.price * quantity
      digiline_send("flt", product.item)
      product.stock = product.stock - quantity

    --buy more later
      if quantity > 1 then
        for i = 1, quantity - 1 do
          table.insert(mem.var.returns, product.item)
        end
        interrupt(1, "return")
      end

    --change internal storage data
      if product.stock <= 0 then
        table.remove(mem.var.gds, mem.var.current)
      end
      mem.var.inserted = {}
      mem.var.was = mem.var.payment
      digiline_send("lcd", "SOLD!")
      interrupt(2, "sold")
  --not enough
    else
      update_lcd()
    end
  end
end


if event.type == "interrupt" then
--turning on
  if event.iid == "ready" then
    mem.var.current = 1
    update_lcd()

--reset after the incorrect item was inserted
  elseif event.iid == "incorrect" then
    update_lcd()

--return anything
  elseif event.iid == "return" then
    if #mem.var.returns > 0 then
      digiline_send("flt", mem.var.returns[1])
      table.remove(mem.var.returns, 1)
      if #mem.var.returns > 0 then
        interrupt(return_time/2, "return")
      end
    end

--reset after sale
  elseif event.iid == "sold" then
    if mem.var.current > #mem.var.gds then
      mem.var.current = 1
    end
    update_lcd()
  end
end
