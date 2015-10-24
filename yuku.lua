dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')
local item_thread = os.getenv('item_thread')

local downloaded = {}
local addedtolist = {}

local replyids = {}

for ignore in io.open("ignore-list", "r"):lines() do
  downloaded[ignore] = true
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  
  if downloaded[url] == true or addedtolist[url] == true then
    return false
  end
  
  if downloaded[url] ~= true and addedtolist[url] ~= true then
    if (string.match(url, "^https?://[^/]*"..item_value) and ((item_type == "10threads" and string.match(url, "[^0-9]"..item_thread.."[0-9]") and not string.match(url, "[^0-9]"..item_thread.."[0-9][0-9]")) or (item_type == "thread" and string.match(url, "[^0-9]"..item_thread) and not string.match(url, "[^0-9]"..item_thread.."[0-9]")))) or html == 0 then
      addedtolist[url] = true
      return true
    else
      return false
    end
  end
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true
  
  local function check(urla, origurl)
    local url = string.match(urla, "^([^#]+)")
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and string.match(url, "^https?://[^/]*"..item_value) and ((item_type == "10threads" and string.match(url, "[^0-9]"..item_thread.."[0-9]") and not string.match(url, "[^0-9]"..item_thread.."[0-9][0-9]")) or (item_type == "thread" and string.match(url, "[^0-9]"..item_thread) and not string.match(url, "[^0-9]"..item_thread.."[0-9]")) or string.match(url, "https?://[^/]+/forum/[^/]+/id/") or string.match(url, "https?://[^/]+/s?reply/")) then
      if string.match(url, "&amp;") then
        table.insert(urls, { url=string.gsub(url, "&amp;", "&") })
        addedtolist[url] = true
        addedtolist[string.gsub(url, "&amp;", "&")] = true
      else
        table.insert(urls, { url=url })
        addedtolist[url] = true
      end
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "^https?://") then
      check(newurl, url)
    elseif string.match(newurl, "^//") then
      check("http:"..newurl, url)
    elseif string.match(newurl, "^/") then
      check(string.match(url, "^(https?://[^/]+)")..newurl, url)
    elseif string.match(newurl, "^"..item_value.."%.yuku%.com") then
      check("http://"..newurl, url)
    end
  end
  
  if string.match(url, "^https?://[^/]*"..item_value) and ((item_type == "10threads" and string.match(url, "[^0-9]"..item_thread.."[0-9]") and not string.match(url, "[^0-9]"..item_thread.."[0-9][0-9]")) or (item_type == "thread" and string.match(url, "[^0-9]"..item_thread) and not string.match(url, "[^0-9]"..item_thread.."[0-9]")) or string.match(url, "https?://[^/]+/forum/[^/]+/id/") or string.match(url, "https?://[^/]+/s?reply/")) then
    html = read_file(file)
    for newurl in string.gmatch(html, '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">([^<]+)") do
      checknewurl(newurl)
    end
    if string.match(url, "%?") then
      check(string.match(url, "^(https?://[^%?]+)%?"))
    end
  end
  
  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if downloaded[url["url"]] == true then
    return wget.actions.EXIT
  end

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end

  if string.match(url["url"], "^https?://[^/]+/forum/previous/topic/") or string.match(url["url"], "^https?://[^/]+/forum/next/topic/") then
    return wget.actions.EXIT
  end

  if status_code == 301 and (string.match(url["url"], "^https?://[^%.]+%.yuku%.com/forum/.....reply/id/[0-9]+")) then
    return wget.actions.EXIT
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403) then
    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 1")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if string.match(url["url"], "^https?://[^/]*"..item_value) then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then
    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()
    os.execute("sleep 10")
    tries = tries + 1
    if tries >= 5 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if string.match(url["url"], "^https?://[^/]*"..item_value) then
        return wget.actions.ABORT
      else
        return wget.actions.EXIT
      end
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
