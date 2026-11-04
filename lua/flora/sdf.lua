-- Signed-distance shapes for the painted animals (painted_bird.lua,
-- painted_bee.lua): primitives, a smooth union, an intersection (the max of
-- two fields) and an outline tracer that turns a field into a polygon.

package.path = "./lua/?.lua;" .. package.path
local G = require("flora.geom")

local S = {}
local sqrt, max, min, abs, cos, sin = math.sqrt, math.max, math.min, math.abs, math.cos, math.sin

-- Primitives: functions (x, y) -> signed distance, negative inside.
function S.circle(cx, cy, r)
  return function(x, y) return sqrt((x - cx) ^ 2 + (y - cy) ^ 2) - r end
end

function S.ellipse(cx, cy, rx, ry, rot)
  local c, s = cos(rot or 0), sin(rot or 0)
  local m = min(rx, ry)
  return function(x, y)
    local dx, dy = x - cx, y - cy
    local u, v = (dx * c + dy * s) / rx, (-dx * s + dy * c) / ry
    return (sqrt(u * u + v * v) - 1) * m
  end
end

-- A capsule from a to b whose radius runs ra -> rb (circles along a spine).
function S.capsule(ax, ay, bx, by, ra, rb)
  local dx, dy = bx - ax, by - ay
  local len2 = dx * dx + dy * dy
  return function(x, y)
    local t = max(0, min(1, ((x - ax) * dx + (y - ay) * dy) / len2))
    local px, py = ax + dx * t, ay + dy * t
    return sqrt((x - px) ^ 2 + (y - py) ^ 2) - (ra + (rb - ra) * t)
  end
end

-- Smooth minimum: a union whose join is rounded over distance k.
function S.smin(a, b, k)
  if k <= 0 then return min(a, b) end
  local h = max(k - abs(a - b), 0) / k
  return min(a, b) - h * h * k * 0.25
end

function S.union(parts, k)
  return function(x, y)
    local d = parts[1](x, y)
    for i = 2, #parts do d = S.smin(d, parts[i](x, y), k) end
    return d
  end
end

-- Marching squares: the longest closed outline of f < 0 inside the box,
-- sampled every h. Returns a list of {x, y}.
function S.trace(f, x0, y0, x1, y1, h)
  local nx, ny = math.ceil((x1 - x0) / h), math.ceil((y1 - y0) / h)
  local val = {}
  for j = 0, ny do
    for i = 0, nx do val[j * (nx + 1) + i] = f(x0 + i * h, y0 + j * h) end
  end
  local function v(i, j) return val[j * (nx + 1) + i] end
  local function cross(i, j, i2, j2)
    local a, b = v(i, j), v(i2, j2)
    local t = a / (a - b)
    return { x0 + (i + (i2 - i) * t) * h, y0 + (j + (j2 - j) * t) * h }
  end
  local adj, pts = {}, {}
  local function link(ka, pa, kb, pb)
    pts[ka], pts[kb] = pa, pb
    adj[ka] = adj[ka] or {}
    adj[kb] = adj[kb] or {}
    table.insert(adj[ka], kb)
    table.insert(adj[kb], ka)
  end
  for j = 0, ny - 1 do
    for i = 0, nx - 1 do
      local a, b, c, d = v(i, j) < 0, v(i + 1, j) < 0, v(i + 1, j + 1) < 0, v(i, j + 1) < 0
      local e = {}
      if a ~= b then e[#e + 1] = { "h" .. i .. "," .. j, cross(i, j, i + 1, j) } end
      if b ~= c then e[#e + 1] = { "v" .. (i + 1) .. "," .. j, cross(i + 1, j, i + 1, j + 1) } end
      if d ~= c then e[#e + 1] = { "h" .. i .. "," .. (j + 1), cross(i, j + 1, i + 1, j + 1) } end
      if a ~= d then e[#e + 1] = { "v" .. i .. "," .. j, cross(i, j, i, j + 1) } end
      if #e == 2 then
        link(e[1][1], e[1][2], e[2][1], e[2][2])
      elseif #e == 4 then
        link(e[1][1], e[1][2], e[2][1], e[2][2])
        link(e[3][1], e[3][2], e[4][1], e[4][2])
      end
    end
  end
  local seen, best = {}, {}
  for start in pairs(adj) do
    if not seen[start] then
      local loop, k, prev = {}, start, nil
      while k and not seen[k] do
        seen[k] = true
        loop[#loop + 1] = pts[k]
        local nxt
        for _, n in ipairs(adj[k]) do if n ~= prev and not seen[n] then nxt = n break end end
        prev, k = k, nxt
      end
      if #loop > #best then best = loop end
    end
  end
  return best
end

-- The outline of f, resampled to `n` points: the traced loop has hundreds,
-- almost all redundant on a smooth curve.
function S.outline(f, box, h, n)
  return G.resample(S.trace(f, box[1], box[2], box[3], box[4], h or 0.3), n or 56)
end

return S
