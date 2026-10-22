-- Procedural die and tray; no external art or copied game assets.
return function(H,g,col)
    local R={}
    local rawcol=col; local opacity=1
    col=function(c,a) rawcol(c,(a or 1)*opacity) end
    local numbers={}; local numberfont
    local function number(value)
        if numbers[value] then return numbers[value] end
        g.push('all')
        -- Steamodded 26.1002.0 dereferences a nil backbuffer in its getCanvas
        -- wrapper. Protect this local query; never alter the loader globally.
        local ok,previous=pcall(g.getCanvas); if not ok then previous=nil end
        local canvas=g.newCanvas(128,128)
        g.setCanvas(canvas); g.clear(0,0,0,0); g.origin(); g.setShader(); g.setScissor()
        numberfont=numberfont or g.newFont('resources/fonts/m6x11plus.ttf',48)
        g.setFont(numberfont); g.setColor(1,0.95,0.82,1); g.printf(tostring(value),0,53,128,'center')
        g.setCanvas(previous); g.pop(); numbers[value]=canvas; return canvas
    end
    function R.warm() if not R.warmed then for i=1,20 do number(i) end; R.warmed=true end end
    local camera={0,-0.6,0.8}
    local function project(v,cx,cy,scale) return cx+v[1]*scale,cy-(v[2]*0.8+v[3]*0.6)*scale end
    local function world(q,v,p)
        local r=H.rotate(q,v); return {r[1]+p.x,r[2]+p.y,r[3]+p.z}
    end
    local function polygon(points,cx,cy,scale)
        local values={}; for _,v in ipairs(points) do local x,y=project(v,cx,cy,scale); values[#values+1]=x; values[#values+1]=y end
        return values
    end
    function R.tray(cx,cy,scale)
        local a,b=H.LENGTH,H.WIDTH
        col({0.015,0.04,0.055}); g.polygon('fill',polygon({{-a-0.3,-b-0.3,-0.2},{a+0.3,-b-0.3,-0.2},{a+0.3,b+0.3,-0.2},{-a-0.3,b+0.3,-0.2}},cx,cy,scale))
        col({0.10,0.29,0.27}); g.polygon('fill',polygon({{-a,-b,0},{a,-b,0},{a,b,0},{-a,b,0}},cx,cy,scale))
        for i=-5,5 do col({0.13,0.34,0.31},0.35); local x1,y1=project({i,-b,0},cx,cy,scale); local x2,y2=project({i,b,0},cx,cy,scale); g.line(x1,y1,x2,y2) end
        col({0.30,0.71,0.63}); g.setLineWidth(3); g.polygon('line',polygon({{-a,-b,0},{a,-b,0},{a,b,0},{-a,b,0}},cx,cy,scale))
        col({0.22,0.41,0.38}); g.setLineWidth(9); local x1,y1=project({-a,b,0},cx,cy,scale); local x2,y2=project({a,b,0},cx,cy,scale); g.line(x1,y1,x2,y2)
    end
    local pips={{{0,0}},{{-0.48,-0.48},{0.48,0.48}},{{-0.48,-0.48},{0,0},{0.48,0.48}},
        {{-0.48,-0.48},{0.48,-0.48},{-0.48,0.48},{0.48,0.48}},
        {{-0.48,-0.48},{0.48,-0.48},{0,0},{-0.48,0.48},{0.48,0.48}},
        {{-0.48,-0.5},{-0.48,0},{-0.48,0.5},{0.48,-0.5},{0.48,0},{0.48,0.5}}}
    function R.die(p,color,cx,cy,scale,alpha)
        opacity=alpha or 1
        local join=g.getLineJoin(); g.setLineJoin('bevel')
        local x,y=project({p.x,p.y,0},cx,cy,scale)
        col({0,0,0},0.24/(1+math.max(0,p.z-1)*0.2)); g.ellipse('fill',x,y+4,scale*(1.38+math.max(0,p.z-1)*0.12),scale*0.63)
        local faces={}
        for _,f in ipairs((H.shapes[color] or H.shapes.gold).faces) do
            local normal=H.rotate(p.q,f.n); local facing=normal[1]*camera[1]+normal[2]*camera[2]+normal[3]*camera[3]
            if facing>0 then
                local points={}
                if f.vertices then for _,v in ipairs(f.vertices) do points[#points+1]=world(p.q,v,p) end
                else for _,uv in ipairs({{-1,-1},{1,-1},{1,1},{-1,1}}) do
                    local v={}; for k=1,3 do v[k]=f.n[k]+f.u[k]*uv[1]+f.v[k]*uv[2] end
                    points[#points+1]=world(p.q,v,p)
                end end
                faces[#faces+1]={face=f,points=points,depth=normal[2]*camera[2]+normal[3]*camera[3],normal=normal}
            end
        end
        table.sort(faces,function(a,b) return a.depth<b.depth end)
        for _,surface in ipairs(faces) do
            local f=surface.face; local brightness=0.62+0.38*math.max(0,surface.normal[3]*0.8-surface.normal[2]*0.4-surface.normal[1]*0.3)
            local base=color=='red' and {0.94,0.20,0.29} or {1,0.74,0.22}
            col({base[1]*brightness,base[2]*brightness,base[3]*brightness}); local outline=polygon(surface.points,cx,cy,scale); g.polygon('fill',outline)
            col(color=='red' and {0.41,0.06,0.10} or {0.46,0.53,0.53}); g.setLineWidth(2); g.polygon('line',outline)
            if f.vertices then
                local vertices={{outline[1],outline[2],0.5,0,1,1,1,1},{outline[3],outline[4],0,1,1,1,1,1},{outline[5],outline[6],1,1,1,1,1,1}}
                R.mesh=R.mesh or g.newMesh(vertices,'triangles','stream'); R.mesh:setVertices(vertices)
                R.mesh:setTexture(number(f.value)); col({1,1,1}); g.draw(R.mesh)
            else for _,pip in ipairs(pips[f.value]) do
                local points={}
                for i=1,16 do
                    local angle=i*math.pi/8; local u,v=pip[1]+math.cos(angle)*0.125,pip[2]+math.sin(angle)*0.125
                    local point={}; for k=1,3 do point[k]=f.n[k]*1.002+f.u[k]*u+f.v[k]*v end
                    points[#points+1]=world(p.q,point,p)
                end
                col({0.16,0.10,0.035}); g.polygon('fill',polygon(points,cx,cy,scale))
            end end
        end
        opacity=1
        if join then g.setLineJoin(join) end
    end
    return R
end
