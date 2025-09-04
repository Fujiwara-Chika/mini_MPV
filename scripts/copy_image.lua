--[[
    copy-image.lua   —— 跨平台复制当前图片 # 仅在 macOS 上测试通过，其余平台未测试
    快捷键：c   （可在 input.conf 中覆盖）
--]]
local mp    = require 'mp'
local msg   = require 'mp.msg'
local utils = require 'mp.utils'

----------------------------------------------------------------
-- 1. 用户配置
----------------------------------------------------------------
local DEST_DIR = {
    macOS  = os.getenv("HOME") .. "/Desktop/Twitter",
    Linux  = os.getenv("HOME") .. "/Desktop/",
    Windows = (os.getenv("USERPROFILE") or "") .. "\\Desktop\\",
}
----------------------------------------------------------------

-- 判断操作系统
local OS = (function()
    local home = os.getenv("HOME")
    if home and home:sub(1,6) == "/Users" then return "macOS"  end
    if home then return "Linux" end
    return "Windows"
end)()

-- 目标目录
local DEST = DEST_DIR[OS]

-- 支持的图片扩展名
local IMAGE_EXTS = {
    jpg = true, jpeg = true, png = true, gif = true,
    bmp = true, webp = true, tif = true, tiff = true,
    jxl = true, avif = true, heic = true, heif = true
}

-- 创建目录
local function ensure_dir(path)
    if OS == "Windows" then
        os.execute('mkdir "' .. path .. '" >nul 2>&1')
    else
        os.execute('mkdir -p "' .. path .. '"')
    end
end

-- 复制命令
local function copy_cmd(src, dst_dir)
    if OS == "macOS" then
        return { "ditto", src, dst_dir }
    elseif OS == "Linux" then
        return { "cp", "--archive", "--reflink=auto", src, dst_dir }
    else -- Windows
        -- robocopy 语法：robocopy <源目录> <目标目录> <文件名> /COPYALL
        local dir, name = utils.split_path(src)
        return { "robocopy", dir, dst_dir, name, "/COPYALL", "/R:1", "/W:1", "/NFL", "/NDL", "/NJH", "/NJS" }
    end
end

-- 主函数
local function copy_current_image()
    local path = mp.get_property("path")
    if not path then return end

    local ext = path:lower():match("%.([^%.]+)$")
    if not IMAGE_EXTS[ext] then
        mp.osd_message("当前不是支持的图片格式", 2)
        return
    end

    ensure_dir(DEST)

    local cmd = copy_cmd(path, DEST)
    local ret = utils.subprocess({ args = cmd, cancellable = false })

    -- robocopy 返回码 ≤7 都算成功
    local ok = (OS == "Windows" and ret.status <= 7) or (ret.status == 0)

    if ok then
        local name = utils.split_path(path)
        mp.osd_message("已复制" , 2)
    else
        mp.osd_message("复制失败！请查看终端日志", 3)
        msg.error("复制命令返回码: " .. tostring(ret.status))
    end
end

-- 绑定快捷键（若 input.conf 中已定义同名绑定，则那里的优先级更高）
mp.add_key_binding("c", "copy-current-image", copy_current_image)