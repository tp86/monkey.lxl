-- mod-version:3
local core = require "core"
local command = require "core.command"
local docview = require "core.docview"

local function positioncompare(position1, position2)
  if position1.line < position2.line then
    return -1
  elseif position1.line > position2.line then
    return 1
  elseif position1.column < position2.column then
    return -1
  elseif position1.column > position2.column then
    return 1
  else
    return 0
  end
end

local range = {}
function range.new(line1, column1, line2, column2)
  return {
    from = { line = line1, column = column1 },
    to = { line = line2, column = column2 },
  }
end
function range.fromnode(node)
  local nodestart = node:start_point()
  local nodeend = node:end_point()
  return range.new(nodestart.row + 1, nodestart.column + 1, nodeend.row + 1, nodeend.column + 1)
end
function range.within(range1, range2)
  return positioncompare(range1.from, range2.from) >= 0 and positioncompare(range1.to, range2.to) <= 0
end
function range.same(range1, range2)
  return positioncompare(range1.from, range2.from) == 0 and positioncompare(range1.to, range2.to) == 0
end

local function getcurrentnode(doc)
  local tree = doc.ts.tree:root()
  local node = tree
  local parent
  local selection = range.new(doc:get_selection(true))
  repeat
    local foundchildwithin = false
    for childnode in tree:children() do
      local childrange = range.fromnode(childnode)
      if range.within(selection, childrange) then
        local treerange = range.fromnode(tree)
        if not range.same(childrange, treerange) then
          parent = tree
        end
        node = childnode
        tree = childnode
        foundchildwithin = true
        break
      end
    end
  until not foundchildwithin
  return node, parent
end

local function selectnode(doc, node)
  local nodestart = node:start_point()
  local nodeend = node:end_point()
  doc:set_selection(nodestart.row + 1, nodestart.column + 1, nodeend.row + 1, nodeend.column + 1)
end

local function selectcurrentnode(doc)
  local currentnode = getcurrentnode(doc)
  selectnode(doc, currentnode)
end

local function selectparentnode(doc)
  local _, parent = getcurrentnode(doc)
  if parent then
    selectnode(doc, parent)
  end
end

local function selectchildnode(doc)
  local node = getcurrentnode(doc)
  local child = node:child(0)
  if child then
    selectnode(doc, child)
  end
end

local function selectsibling(which)
  local methodname = which .. "_sibling"
  return function(doc)
    local node, parent = getcurrentnode(doc)
    local sibling = node[methodname](node)
    if not sibling then
      local noderange = range.fromnode(node)
      for childnode in parent:children() do
        local childrange = range.fromnode(childnode)
        if range.same(childrange, noderange) then
          sibling = childnode[methodname](childnode)
          break
        end
      end
    end
    if sibling then
      selectnode(doc, sibling)
    end
  end
end

local selectnextsibling = selectsibling("next")
local selectprevioussibling = selectsibling("prev")

local function treesitteddoc()
  local view = core.active_view
  if view:is(docview) then
    local doc = view.doc
    return doc.treesit, doc
  end
end

command.add(treesitteddoc, {
  ["monkey:select-current-node"] = selectcurrentnode,
  ["monkey:select-parent-node"] = selectparentnode,
  ["monkey:select-child-node"] = selectchildnode,
  ["monkey:select-next-sibling-node"] = selectnextsibling,
  ["monkey:select-previous-sibling-node"] = selectprevioussibling,
})

