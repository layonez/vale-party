local M={}
function M.draw(items, selected, x, y, w) for i,it in ipairs(items) do local yy=y+(i-1)*72; love.graphics.setColor(i==selected and {1,.86,.32} or {.95,.95,.9}); love.graphics.rectangle("fill",x,yy,w,56,18); love.graphics.setColor(.12,.16,.2); love.graphics.setLineWidth(5); love.graphics.rectangle("line",x,yy,w,56,18); love.graphics.printf(it.label,x,yy+13,w,"center") end end
return M
