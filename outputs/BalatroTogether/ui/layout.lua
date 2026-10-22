local L={}
-- All HUD geometry derives from height, so 32:9 does not stretch text/panels.
function L.compute(w,h,scale,top)
    local s=math.max(0.45,math.min(h/1080*scale,1.7))
    s=math.min(s,(w-24)/760)
    local width=744*s; local height=66*s
    return {s=s,x=(w-width)/2,y=top and 12*s or h-height-12*s,w=width,h=height,
        score_h=67*s,panel_y=0,panel_h=66*s,gap=8*s,
        self_w=204*s,peer_w=172*s}
end
return L
