local M = {}

local function split_path_segments(path)
  local segments = {}
  for segment in string.gmatch(path, "[^/\\\\]+") do
    table.insert(segments, segment)
  end
  return segments
end

local function find_unique_segment(segments, other_paths)
  for i = 1, #segments - 1 do
    local segment = segments[i]
    local is_unique = true

    for _, other_segments in ipairs(other_paths) do
      for j = 1, #other_segments - 1 do
        if other_segments[j] == segment then
          is_unique = false
          break
        end
      end
      if not is_unique then
        break
      end
    end

    if is_unique then
      return segment
    end
  end
  return nil
end

local function generate_display_path(segments, filename)
  local segment_count = #segments
  if segment_count > 3 then
    return segments[segment_count - 2] .. "/" .. segments[segment_count - 1] .. "/" .. filename
  elseif segment_count > 2 then
    return segments[segment_count - 1] .. "/" .. filename
  end
  return nil
end

local function process_duplicate_files(buffers_group, filename)
  local path_segments = {}
  for _, buffer in ipairs(buffers_group) do
    path_segments[buffer.buf] = split_path_segments(buffer.name)
  end

  for i, buffer in ipairs(buffers_group) do
    local segments = path_segments[buffer.buf]
    local other_paths = {}
    for j, other_buffer in ipairs(buffers_group) do
      if i ~= j then
        table.insert(other_paths, path_segments[other_buffer.buf])
      end
    end

    local unique_segment = find_unique_segment(segments, other_paths)
    if unique_segment then
      buffer.filename = unique_segment .. "/" .. filename
    else
      local display_path = generate_display_path(segments, filename)
      buffer.filename = display_path or vim.fn.fnamemodify(buffer.name, ":~:.")
    end
  end
end

--- Prefix buffers that share a file name with enough of their path to tell them apart
--- @param buffer_list table[] Entries with buf, name and filename; filename is updated in place
function M.apply(buffer_list)
  local counts = {}
  for _, buffer in ipairs(buffer_list) do
    counts[buffer.filename] = (counts[buffer.filename] or 0) + 1
  end

  local duplicate_groups = {}
  for _, buffer in ipairs(buffer_list) do
    if counts[buffer.filename] > 1 then
      duplicate_groups[buffer.filename] = duplicate_groups[buffer.filename] or {}
      table.insert(duplicate_groups[buffer.filename], buffer)
    end
  end

  for filename, group in pairs(duplicate_groups) do
    process_duplicate_files(group, filename)
  end
end

return M
