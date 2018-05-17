pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

function _init()
 t=0
 ship = {
  sp=1,
  x=60,
  y=60,
  h=3,
  p=0,
  box={x1=0,y1=0,x2=7,y2=7}
 }
 bullets = {}
 enemies = {}
 for i=1,10 do
  add(enemies, {
   sp=16,
   m_x=i*16,
   m_y=60-i*8,
   x=-32,
   y=-32,
   r=12,
   box={x1=0,y1=0,x2=7,y2=7}
  })
 end
end

function fire()
 local b = {
  sp=2,
  x=ship.x,
  y=ship.y,
  dx=0,
  dy=-3,
  box={x1=2,y1=2,x2=5,y2=4}
 }
 add(bullets,b)
end

function abs_box(s)
  local box = {}
  box.x1 = s.box.x1 + s.x
  box.y1 = s.box.y1 + s.y
  box.x2 = s.box.x2 + s.x
  box.y2 = s.box.y2 + s.y
  return box
end

function coll(a,b)
 box_a = abs_box(a)
 box_b = abs_box(b)
end

function _update()
 t+=1

 for e in all(enemies) do
  e.x=e.r*sin(t/50)+e.m_x
  e.y=e.r*cos(t/50)+e.m_y
  if coll(ship,e) then
   --todo
  end
 end

 for b in all(bullets) do
  b.x+=b.dx
  b.y+=b.dy
  if b.x < 0 or b.x > 128 or
   b.y < 0 or b.y > 128 then
   del(bullets,b)
  end
  for e in all(enemies) do
   if coll(b,e) then
    del(enemies, e)
    ship.p+=1
   end
  end
 end

 if(t%6<3) then
  ship.sp=0
 else
  ship.sp=1
 end

 if btn(0) then ship.x-=1 end
 if btn(1) then ship.x+=1 end
 if btn(2) then ship.y-=1 end
 if btn(3) then ship.y+=1 end
 if btnp(4) then fire() end
end

function _draw()
 cls()
 print(ship.p, 9)
 spr(ship.sp,ship.x,ship.y)
 for b in all(bullets) do
  spr(b.sp,b.x,b.y)
 end
 for e in all(enemies) do
  spr(e.sp,e.x,e.y)
 end
 for i=1,4 do
  if i<=ship.h then
   spr(32,95+i*6,122)
  else
   spr(33,95+i*6,122)
  end
 end
end
__gfx__
00800800008008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800800008008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800008888000099000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08811880088118800099000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
088cc880088cc8800099000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08088080080880800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000a00000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000a000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00bbb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bb70b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bb77b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0bb77b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0bbb0b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b000b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08080000060600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888000666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08880000066600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
