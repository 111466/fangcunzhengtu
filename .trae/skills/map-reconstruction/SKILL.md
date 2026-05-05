---
name: "map-reconstruction"
description: "Guides the AI to reconstruct and render a map using an exported map.json file. Invoke when user wants to load, render, or reconstruct a map in a game project using map.json."
---

# Map Reconstruction

此 Skill 用于指导 AI 在非地图编辑器的游戏项目中，利用导出的 JSON 数据重新生成和渲染等距/正视地图。

## 核心规范

1. **文件命名与位置**
   导出的地图 JSON 文件 **必须** 命名为 `map.json`，并且放置在项目的 `assets` 文件夹（资源根目录）下，如果检查到不存在文件，提醒用户创建。

2. **加载逻辑**
   导入 JSON 文件的逻辑 **必须** 严格使用以下代码参考：
   ```lua
   local path = "map.json"   -- assets/map.json（assets/ 是资源根目录）
   local f = cache:GetFile(path)
   if not f then
       print("ERROR: Failed to open " .. path .. " from ResourceCache")
       return
   end
   
   local jsonStr = f:ReadString()
   f:Close()
   local mapData = cjson.decode(jsonStr)
   ```

3. **数据结构重建与渲染逻辑**
   渲染逻辑必须参考代码。请阅读本 skill 目录下的参考文件：
   📄 `references/render_reference.lua`
   
   该文件包含了可直接复用到任何 Lua 游戏引擎的核心渲染算法，包括：
   - **等距/正视视角坐标转换公式 (`mapToScreen`)**：正视视角(topdown)采用 `(x-1)*w, (y-1)*h` 的标准正交网格映射，等距视角(iso)采用菱形映射。
   - **瓦片绘制与锚点对齐逻辑 (`drawImageTile`)**：正视模式下，平铺地面(flat/floor)为中心对齐，立体物体(vertical)的底部锚定到正方形网格的底边(`cy + tileH / 2`)；等距模式则锚定到菱形底点。
   - **包含双 Pass 策略与脚底点 (`footY`) 计算的深度排序 (Y-Sorting) 分层渲染算法**：
     - **脚底点计算**：正视模式下立体物体的 `footY` 为网格底边缘(`cy + tileH / 2`)。
     - **平铺地表特殊排序**：正视模式下，针对同一图层的平铺地表(flat/floor)，需按照贴图渲染的**实际底边 Y 坐标**（`cy + drawH / 2`）进行二次稳定排序，以确保下方的大尺寸地表能够正确遮盖上方的小尺寸地表。
   
   **特别注意数据映射关系**：
   在解析 `map.json` 时，`layers` 中的 `tile` 对象仅包含基础信息 `{x, y, id, flipH}`。与渲染相关的属性（如 `renderMode`, `scale`, `frames`, `rect`）必须通过 `tile.id` 去 JSON 根节点的 `imageRegistry`（图片注册表）中查找对应的 `tileType` 属性。
   
   **导出的 map.json 数据结构参考**：
   ```json
   {
     "version": 4,
     "width": 10,
     "height": 10,
     "imageRegistry": [
       {
         "id": 100,
         "name": "grass",
         "imagePath": "Tiles/grass.png",
         "renderMode": "flat",
         "scale": 1.0,
         "rect": {"x": 0, "y": 0, "w": 64, "h": 64}
       }
     ],
     "layers": [
       {
         "name": "地面",
         "visible": true,
         "opacity": 1.0,
         "tiles": [
           { "x": 1, "y": 1, "id": 100, "flipH": false }
         ]
       }
     ]
   }
   ```
   
   实现地图渲染时，**必须** 首先读取并参考该文件中的逻辑。

## 常见 Bug 总结与修复

### Bug 1：Module not found: cjson
- **错误信息**：`Module not found: cjson`
- **原因**：使用 `require("cjson")` 加载 cjson 模块。`cjson` 是引擎内置的全局变量，启动时自动注册，不需要也不能通过 `require` 加载。
- **解决办法**：删除 `require` 语句，直接使用 `cjson`。

```lua
-- ❌ 错误
local cjson = require("cjson")

-- ✅ 正确：cjson 是内置全局变量，直接用
local data = cjson.decode(jsonStr)
local str = cjson.encode(data)
```

### Bug 2：Undefined global JsonDecode
- **错误信息**：`Undefined global JsonDecode. [undefined-global]`
- **原因**：引擎中不存在 `JsonDecode` 这个全局函数，正确的 API 是 `cjson.decode()`。
- **解决办法**：使用 `cjson.decode()` 替代。

```lua
-- ❌ 错误：不存在此函数
mapData = JsonDecode(jsonStr)

-- ✅ 正确
mapData = cjson.decode(jsonStr)
```

### Bug 3：attempt to call a nil value (field 'Push')
- **错误信息**：`attempt to call a nil value (field 'Push')`
- **原因**：代码使用了 `graphics.Push()`、`graphics.Translate()`、`graphics.Scale()`、`graphics.Rotate()`、`graphics.Draw()` 等方法。UrhoX 中 `graphics` 是 Graphics 子系统（管理窗口和渲染设置），不是 Canvas 绘图 API，不存在这些方法。
- **解决办法**：使用 NanoVG API 替代，并将渲染事件从 `PostRenderUpdate` 改为 `NanoVGRender`。

| 错误用法 | NanoVG 替代 |
| --- | --- |
| `graphics.Push()` | `nvgSave(vg)` |
| `graphics.Pop()` | `nvgRestore(vg)` |
| `graphics.Translate(x, y)` | `nvgTranslate(vg, x, y)` |
| `graphics.Scale(sx, sy)` | `nvgScale(vg, sx, sy)` |
| `graphics.Rotate(angle)` | `nvgRotate(vg, angle)` |
| `graphics.Draw(texture, ...)` | `nvgImagePattern` + `nvgFill` |

```lua
-- ❌ 错误：graphics 没有绘图 API
SubscribeToEvent("PostRenderUpdate", "HandleRender")
function HandleRender()
    graphics.Push()
    graphics.Translate(100, 100)
    graphics.Draw(texture, 0, 0)
    graphics.Pop()
end

-- ✅ 正确：使用 NanoVG
local vg = nvgCreate(1)
SubscribeToEvent(vg, "NanoVGRender", "HandleRender")

function HandleRender()
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    nvgBeginFrame(vg, w / dpr, h / dpr, dpr)

    -- 矩阵变换
    nvgSave(vg)
    nvgTranslate(vg, 100, 100)

    -- 绘制图片
    local img = nvgCreateImage(vg, "Textures/tile.png", 0)  -- 只调用一次，缓存句柄
    local paint = nvgImagePattern(vg, 0, 0, 64, 64, 0, img, 1)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, 64, 64)
    nvgFillPaint(vg, paint)
    nvgFill(vg)

    nvgRestore(vg)
    nvgEndFrame(vg)
end
```

### 速查表

| Bug | 根因 | 一句话修复 |
| --- | --- | --- |
| `Module not found: cjson` | `require` 了内置全局变量 | 删掉 `require`，直接用 `cjson.decode()` |
| `Undefined global JsonDecode` | 函数名不存在 | 用 `cjson.decode()` |
| `field 'Push' is nil` | `graphics` 不是 Canvas API | 用 NanoVG (`nvgSave`/`nvgTranslate`/`nvgImagePattern`) |

