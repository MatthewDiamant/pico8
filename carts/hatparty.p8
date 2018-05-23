pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- hat party
-- by husky butler

--sfx
snd=
{
  jump=0,
  small_gun=1,
  tiny_gun=2,
  boom_gun=3,
  sniper_rifle=4,
  flame_thrower=5,
  death=6,
}

--music tracks
mus=
{

}

--math
--------------------------------

--point to box intersection.
function intersects_point_box(px,py,x,y,w,h)
	if flr(px)>=flr(x) and flr(px)<flr(x+w) and
				flr(py)>=flr(y) and flr(py)<flr(y+h) then
		return true
	else
		return false
	end
end

--box to box intersection
function intersects_box_box(
	x1,y1,
	w1,h1,
	x2,y2,
	w2,h2)

	local xd=x1-x2
	local xs=w1*0.5+w2*0.5
	if abs(xd)>=xs then return false end

	local yd=y1-y2
	local ys=h1*0.5+h2*0.5
	if abs(yd)>=ys then return false end

	return true
end

--check if pushing into side tile and resolve.
--requires self.dx,self.x,self.y, and
--assumes tile flag 0 == solid
--assumes sprite size of 8x8
function collide_side(self)

	local offset=self.w/3
	for i=-(self.w/3),(self.w/3),2 do
	--if self.dx>0 then
		if fget(map_get((self.x+(offset))/8,(self.y+i)/8),0) then
			self.dx=0
			self.x=(flr(((self.x+(offset))/8))*8)-(offset)
			return true
		end
	--elseif self.dx<0 then
		if fget(map_get((self.x-(offset))/8,(self.y+i)/8),0) then
			self.dx=0
			self.x=(flr((self.x-(offset))/8)*8)+8+(offset)
			return true
		end
--	end
	end
	--didn't hit a solid tile.
	return false
end

--check if pushing into floor tile and resolve.
--requires self.dx,self.x,self.y,self.grounded,self.airtime and
--assumes tile flag 0 or 1 == solid
function collide_floor(self)
	--only check for ground when falling.
	if self.dy<0 then
		return false
	end
	local landed=false
	--check for collision at multiple points along the bottom
	--of the sprite: left, center, and right.
	for i=-(self.w/3),(self.w/3),2 do
		local tile=map_get((self.x+i)/8,(self.y+(self.h/2))/8)
		if fget(tile,0) or (fget(tile,1) and self.dy>=0) then
			self.dy=0
			self.y=(flr((self.y+(self.h/2))/8)*8)-(self.h/2)
			self.grounded=true
			self.airtime=0
			landed=true
		end
	end
	return landed
end

--check if pushing into roof tile and resolve.
--requires self.dy,self.x,self.y, and
--assumes tile flag 0 == solid
function collide_roof(self)
	--check for collision at multiple points along the top
	--of the sprite: left, center, and right.
	for i=-(self.w/3),(self.w/3),2 do
		if fget(map_get((self.x+i)/8,(self.y-(self.h/2))/8),0) then
			self.dy=0
			self.y=flr((self.y-(self.h/2))/8)*8+8+(self.h/2)
			self.jump_hold_time=0
		end
	end
end

function collide_bullet(self, bullet, player)
  if (intersects_point_box(bullet.x, bullet.y, player.x, player.y, player.w, player.h)) then
    player.health -= self.weapon.damage
    del(self.bullets, bullet)
    for i=1,self.weapon.blood do
      add(blood.spurts, {
        x = bullet.x,
        y = bullet.y,
        dx = bullet.dx / 3 * rnd(2),
        dy = -1 * rnd(1.5),
        moving = true,
      })
    end
  end
end

--make 2d vector
function m_vec(x,y)
	local v=
	{
		x=x,
		y=y,

  --get the length of the vector
		get_length=function(self)
			return sqrt(self.x^2+self.y^2)
		end,

  --get the normal of the vector
		get_norm=function(self)
			local l = self:get_length()
			return m_vec(self.x / l, self.y / l),l;
		end,
	}
	return v
end

--square root.
function sqr(a) return a*a end

--round to the nearest whole number.
function round(a) return flr(a+0.5) end

--offset mget in relation to level
function map_get(x, y)
  return mget(x + (level_select - 1) * 40, y)
end

--objects
--------------------------------

function m_anims(is_cpu)
  --animation definitions.
  --use with set_anim()
  player_anims=
  {
    ["stand"]=
    {
      ticks=1,--how long is each frame shown.
      frames={2},--what frames are shown.
    },
    ["walk"]=
    {
      ticks=5,
      frames={3,4,5,6},
    },
    ["jump"]=
    {
      ticks=1,
      frames={1},
    },
    ["slide"]=
    {
      ticks=1,
      frames={7},
    },
  }

  cpu_anims=
  {
    ["stand"]=
    {
      ticks=1,--how long is each frame shown.
      frames={18},--what frames are shown.
    },
    ["walk"]=
    {
      ticks=5,
      frames={19,20,21,22},
    },
    ["jump"]=
    {
      ticks=1,
      frames={17},
    },
    ["slide"]=
    {
      ticks=1,
      frames={23},
    },
  }

  local anims= player_anims
  if is_cpu then anims= cpu_anims end
  return anims
end

--make the player
function m_player(x, y, is_cpu, lives)

	--todo: refactor with m_vec.
	local p=
	{
		x=x,
		y=y,

		dx=0,
		dy=0,

		w=7,
    h=7,

    death_timer=0,
    max_health=health_options[health_select],
    health=health_options[health_select],
    cooldown=0,

		max_dx=1,--max x speed
		max_dy=2,--max y speed

		jump_speed=-1.75,--jump veloclity
		acc=0.05,--acceleration
		dcc=0.8,--decceleration
		air_dcc=1,--air decceleration
		grav=0.15,

		--helper for more complex
		--button press tracking.
		--todo: generalize button index.
		jump_button=
		{
			update=function(self)
				--start with assumption
				--that not a new press.
        self.is_pressed=false
        local j = btn(5)
        if is_cpu then j= cpu.j end
				if j then
					if not self.is_down then
						self.is_pressed=true
					end
					self.is_down=true
					self.ticks_down+=1
				else
					self.is_down=false
					self.is_pressed=false
					self.ticks_down=0
				end
			end,
			--state
			is_pressed=false,--pressed this frame
			is_down=false,--currently down
			ticks_down=0,--how long down
		},

		jump_hold_time=0,--how long jump is held
		min_jump_press=5,--min time jump can be held
		max_jump_press=15,--max time jump can be held

		jump_btn_released=true,--can we jump again?
		grounded=false,--on ground

		airtime=0,--time since grounded

		--animation definitions.
		--use with set_anim()
		anims= m_anims(is_cpu),

		curanim="walk",--currently playing animation
		curframe=1,--curent frame of animation.
		animtick=0,--ticks until next frame should show.
		flipx=false,--show sprite be flipped.

		--request new animation to play.
		set_anim=function(self,anim)
			if(anim==self.curanim)return--early out.
			local a=self.anims[anim]
			self.animtick=a.ticks--ticks count down.
			self.curanim=anim
			self.curframe=1
    end,

    weapon= weapons.handgun,
    bullets= {},
    muzzle_flashes= {},
    explosions= {},
    lives= lives,

		--call once per tick.
    update=function(self)

      if self.death_timer > 0 then return end

			--track button presses
      local bl= btn(0) --left
      if is_cpu then bl= cpu.bl end
      local br=btn(1) --right
      if is_cpu then br= cpu.br end

			--move left/right
			if bl==true then
				self.dx-=self.acc
				br=false--handle double press
			elseif br==true then
				self.dx+=self.acc
			else
				if self.grounded then
					self.dx*=self.dcc
				else
					self.dx*=self.air_dcc
				end
			end

			--limit walk speed
			self.dx=mid(-self.max_dx,self.dx,self.max_dx)

			--move in x
			self.x+=self.dx

			--hit walls
			collide_side(self)

			--jump buttons
			self.jump_button:update()

			--jump is complex.
			--we allow jump if:
			--	on ground
			--	recently on ground
			--	pressed btn right before landing
			--also, jump velocity is
			--not instant. it applies over
			--multiple frames.
			if self.jump_button.is_down then
				--is player on ground recently.
				--allow for jump right after
				--walking off ledge.
				local on_ground=(self.grounded or self.airtime<5)
				--was btn presses recently?
				--allow for pressing right before
				--hitting ground.
				local new_jump_btn=self.jump_button.ticks_down<10
				--is player continuing a jump
				--or starting a new one?
				if self.jump_hold_time>0 or (on_ground and new_jump_btn) then
					if(self.jump_hold_time==0)sfx(snd.jump)--new jump snd
					self.jump_hold_time+=1
					--keep applying jump velocity
					--until max jump time.
					if self.jump_hold_time<self.max_jump_press then
						self.dy=self.jump_speed--keep going up while held
					end
				end
			else
				self.jump_hold_time=0
			end

			--move in y
			self.dy+=self.grav
			self.dy=mid(-self.max_dy,self.dy,self.max_dy)
			self.y+=self.dy

			--floor
			if not collide_floor(self) then
				self:set_anim("jump")
				self.grounded=false
				self.airtime+=1
			end

			--roof
			collide_roof(self)

			--handle playing correct animation when
			--on the ground.
			if self.grounded then
				if br then
					if self.dx<0 then
						--pressing right but still moving left.
						self:set_anim("slide")
					else
						self:set_anim("walk")
					end
				elseif bl then
					if self.dx>0 then
						--pressing left but still moving right.
						self:set_anim("slide")
					else
						self:set_anim("walk")
					end
				else
					self:set_anim("stand")
				end
			end

			--flip
			if br then
				self.flipx=false
			elseif bl then
				self.flipx=true
			end

			--anim tick
			self.animtick-=1
			if self.animtick<=0 then
				self.curframe+=1
				local a=self.anims[self.curanim]
				self.animtick=a.ticks--reset timer
				if self.curframe>#a.frames then
					self.curframe=1--loop
				end
      end

      --shoot weapon
      local f = btn(4)
      if is_cpu then f = cpu.f end
      self.cooldown = max(self.cooldown - 1, 0)
      if f and self.cooldown == 0 then
        local direction = self.flipx and -1 or 1
        for i=1,self.weapon.bullets_in_shot do
          add(self.bullets, {
            x= self.x + ((3 + self.weapon.x_offset) * direction),
            y= self.y,
            dx= (self.weapon.vel + rnd(self.weapon.spread_x)) * direction,
            dy= rnd(self.weapon.spread_y) - (self.weapon.spread_y / 2),
            grav= self.weapon.grav,
            spr=self.weapon.spr,
          })
        end
        self.cooldown = self.weapon.cooldown
        if not is_cpu then
          cam:shake(15,self.weapon.shake)
        end
        self.dx += self.weapon.recoil * -direction
        add(self.muzzle_flashes, {
          x = self.x,
          y = self.y,
          direction = direction,
        })
        if self.weapon.sfx then
          sfx(self.weapon.sfx)
        end
      end

      --update bullets
      for b in all(self.bullets) do
        b.x += b.dx
        b.dy += b.grav
        b.y += b.dy
        --collide with solid tile
        if fget(map_get(b.x / 8, b.y / 8), 0) then
          add(self.explosions, {
            x = b.x,
            y = b.y,
          })
          del(self.bullets, b)
        end
        --collide with players
        collide_bullet(self, b, p1)
        collide_bullet(self, b, p2)
      end

		end,

		--draw the player
    draw=function(self)

      if self.death_timer > 0 then return end

			local a=self.anims[self.curanim]
			local frame=a.frames[self.curframe]
			spr(frame,
				self.x-(self.w/2),
				self.y-(self.h/2),
				self.w/8,self.h/8,
				self.flipx,
        false)

      --draw bullets
      for b in all(self.bullets) do
        spr(b.spr, b.x, b.y)
      end

      for m in all(self.muzzle_flashes) do
        spr(37, m.x + m.direction * 5 - 4, m.y - 2, 1, 1, m.direction == -1)
        del(self.muzzle_flashes, m)
      end

      for e in all(self.explosions) do
        circfill(e.x, e.y, 2, 7)
        del(self.explosions, e)
      end
    end,

    draw_hud=function(self)
      local bar_offset_x = 0
      if is_cpu then bar_offset_x = 76 end
      for i = 1,50 do
        local health_bar_color = 11
        if i > self.health / self.max_health * 50 then health_bar_color = 13 end
        pset(bar_offset_x + i, 125, health_bar_color)
      end
      for i = 1,50 do
        local cooldown_bar_color = 9
        if i < self.cooldown / self.weapon.cooldown * 50 then cooldown_bar_color = 13 end
        pset(bar_offset_x + i, 127, cooldown_bar_color)
      end
      print(self.weapon.name, bar_offset_x + 1, 119, 7)
      local lives_offset_x = 58
      if is_cpu then lives_offset_x = 67 end
      print(self.lives, lives_offset_x, 121, 7)
    end
	}

	return p
end

--make the camera.
function m_cam(target)
	local c=
	{
		tar=target,--target to follow.
		pos=m_vec(target.x,target.y),

		--how far from center of screen target must
		--be before camera starts following.
		--allows for movement in center without camera
		--constantly moving.
		pull_threshold=16,

		--min and max positions of camera.
		--the edges of the level.
		pos_min=m_vec(8*8,8*8),
		pos_max=m_vec(8*32,8*15),

		shake_remaining=0,
		shake_force=0,

		update=function(self)

			self.shake_remaining=max(0,self.shake_remaining-1)

			--follow target outside of
			--pull range.
			if self:pull_max_x()<self.tar.x then
				self.pos.x+=min(self.tar.x-self:pull_max_x(),4)
			end
			if self:pull_min_x()>self.tar.x then
				self.pos.x+=min((self.tar.x-self:pull_min_x()),4)
			end
			if self:pull_max_y()<self.tar.y then
				self.pos.y+=min(self.tar.y-self:pull_max_y(),4)
			end
			if self:pull_min_y()>self.tar.y then
				self.pos.y+=min((self.tar.y-self:pull_min_y()),4)
			end

			--lock to edge
			if(self.pos.x<self.pos_min.x)self.pos.x=self.pos_min.x
			if(self.pos.x>self.pos_max.x)self.pos.x=self.pos_max.x
			if(self.pos.y<self.pos_min.y)self.pos.y=self.pos_min.y
			if(self.pos.y>self.pos_max.y)self.pos.y=self.pos_max.y
		end,

		cam_pos=function(self)
			--calculate camera shake.
			local shk=m_vec(0,0)
			if self.shake_remaining>0 then
				shk.x=rnd(self.shake_force)-(self.shake_force/2)
				shk.y=rnd(self.shake_force)-(self.shake_force/2)
			end
			return self.pos.x-64+shk.x,self.pos.y-64+shk.y
		end,

		pull_max_x=function(self)
			return self.pos.x+self.pull_threshold
		end,

		pull_min_x=function(self)
			return self.pos.x-self.pull_threshold
		end,

		pull_max_y=function(self)
			return self.pos.y+self.pull_threshold
		end,

		pull_min_y=function(self)
			return self.pos.y-self.pull_threshold
		end,

		shake=function(self,ticks,force)
			self.shake_remaining=ticks
			self.shake_force=force
		end
	}

	return c
end

function m_blood()
  return {
    spurts = {},
    chunks = {},
    gravity = 0.1,
    update=function(self)
      for s in all(self.spurts) do
        if s.moving then
          s.dy = s.dy + self.gravity
          s.y += s.dy
          s.x += s.dx
          --collide with solid tile
          if fget(map_get(s.x / 8, s.y / 8), 0) then
            s.moving = false
          end
        end
      end
      --cap blood spurts
      if (#self.spurts > 1000) then
        local sliced = {}
        for i = #self.spurts - 1000, #self.spurts do
          sliced[#sliced+1] = self.spurts[i]
        end
        self.spurts = sliced
      end
      for c in all(self.chunks) do
        if c.moving then
          c.dy = c.dy + self.gravity
          c.y += c.dy
          c.x += c.dx
          --collide with solid tile
          if fget(map_get((c.x + 2) / 8, (c.y + 2) / 8), 0) then
            c.moving = false
          end
        end
      end
    end,
    draw=function(self)
      for s in all(self.spurts) do
        pset(s.x, s.y, 8)
      end
      for c in all(self.chunks) do
        spr(36, c.x, c.y)
      end
    end,
  }
end

function m_packages()
  local packages = {
    packages = {},
    gravity = 0.1,
    ticks = 0,
    create_health_package=function(self)
      add(self.packages, {
        x = rnd(8*38) + 8,
        y = rnd(8*18) + 8,
        dy = 0.1,
        h = 5,
        w = 7,
        spr = 34,
        type = "health",
      })
    end,
    collide_package=function(self, player, package)
      if intersects_box_box(
        player.x, player.y, player.w, player.h,
        package.x, package.y, package.w, package.h
      ) then
        if package.type == "health" then
          player.health = min(player.health + 50, player.max_health)
        end
        if package.type == "weapon" then
          player.weapon = package.weapon
        end
        del(self.packages, package)
      end
    end,
    create_weapon_package=function(self)
      local weapon_contents = weapon_types[flr(rnd(#weapon_types)) + 1]
      add(self.packages, {
        x = rnd(8*36) + 8*2,
        y = rnd(8*17) + 8*2,
        dy = 0.1,
        h = 5,
        w = 7,
        spr = 33,
        type = "weapon",
        weapon = weapon_contents,
      })
    end,
    update=function(self)
      self.ticks += 1
      if self.ticks % (60 * 10) == 0 then
        if rnd(1) < 0.25 then
          self:create_health_package()
        else
          self:create_weapon_package()
        end
      end
      for p in all(self.packages) do
        p.dy += self.gravity
        p.y += p.dy
        collide_floor(p)
        self:collide_package(p1, p)
        self:collide_package(p2, p)
      end
    end,
    draw=function(self)
      for p in all(self.packages) do
        spr(p.spr, p.x, p.y)
        if p.type == "weapon" then
          print(p.weapon.name, p.x - #p.weapon.name / 2 * 4 + p.w / 2, p.y - p.h - 1, 7)
        end
      end
    end,
  }
  return packages
end

function player_explode(p)
  for i=1,100 do
    add(blood.spurts, {
      x = p.x,
      y = p.y,
      dx = rnd(5) - 2.5,
      dy = rnd(5) - 5,
      moving = true,
    })
  end
  for i=1,5 do
    add(blood.chunks, {
      x = p.x,
      y = p.y - 2,
      dx = rnd(3) - 1.5,
      dy = rnd(3) - 1.5,
      moving = true,
    })
  end
end

function check_death()
  if p1.health <= 0 and p1.death_timer == 0 then
    player_explode(p1)
    sfx(snd.death)
    p1.death_timer = 120
    p1.lives -= 1
  end
  if p2.health <= 0 and p2.death_timer == 0  then
    player_explode(p2)
    sfx(snd.death)
    p2.death_timer = 120
    p2.lives -= 1
  end
  if p1.death_timer > 0 then
    p1.death_timer -= 1
    if p1.death_timer == 0 then
      if p1.lives <= 0 then
        game_state = "title"
      else
        p1 = m_player(8*18, 8*3, false, p1.lives)
        p1:set_anim("walk")
        cam=m_cam(p1)
      end
    end
  end
  if p2.death_timer > 0 then
    p2.death_timer -= 1
    if p2.death_timer == 0 then
      if p2.lives <= 0 then
        game_state = "title"
      else
        p2 = m_player(8*22, 8*3, true, p2.lives)
      end
    end
  end
end

function game_over()
  if p1.lives <= 0 or p2.lives <= 0 then
    rectfill(36, 51, 92, 76, 0)
    print_centered("game over", 61, 7)
  end
end

function game_background()
  local level_backgrounds = {0, 12}
  rectfill(0, 0, 128, 128, level_backgrounds[level_select])
end

--game flow
--------------------------------

function print_centered(str, y, color)
  print(str, (128 - #str * 4) / 2, y, color)
end

option_select = 0

level_select = 1
level_options = {1, 2}

health_select = 3
health_options = {50, 100, 200, 400}

enemy_style_select = 1
enemy_style_options = {"pacifist", "idiot", "run & gun", "aggro"}

xc_pause = 0

function title_update()
  if btn(4) and btn(5) then
    xc_pause = 120
    game_state = "option"
  end
end

function option_update()
  xc_pause -= 1
  if option_select == 0 then
    if btnp(0) then
      level_select = max(level_select - 1, 1)
    end
    if btnp(1) then
      level_select = min(level_select + 1, #level_options)
    end
  end
  if option_select == 1 then
    if btnp(0) then
      health_select = max(health_select - 1, 1)
    end
    if btnp(1) then
      health_select = min(health_select + 1, #health_options)
    end
  end
  if option_select == 2 then
    if btnp(0) then
      enemy_style_select = max(enemy_style_select - 1, 1)
    end
    if btnp(1) then
      enemy_style_select = min(enemy_style_select + 1, #enemy_style_options)
    end
  end

  if btnp(2) then
    option_select = max(option_select - 1, 0)
  end
  if btnp(3) then
    option_select = min(option_select + 1, 2)
  end

  if btn(4) and btn(5) and xc_pause <= 0 then
    reset_game()
    game_state = "game"
  end
end

function title_draw()
  print_centered("husky butler presents", 5, 7)
  local title_offset_x = 27
  local title_offset_y = 35
  spr(128, 0 + title_offset_x, title_offset_y)
  spr(129, 8 + title_offset_x, title_offset_y)
  spr(130, 16 + title_offset_x, title_offset_y)
  spr(131, 32 + title_offset_x, title_offset_y)
  spr(129, 40 + title_offset_x, title_offset_y)
  spr(132, 48 + title_offset_x, title_offset_y)
  spr(130, 56 + title_offset_x, title_offset_y)
  spr(133, 64 + title_offset_x, title_offset_y)

  print_centered("press z + x", 80, 7)
end

function option_draw()
  print("level: ", 40, 20, 7)
  print(level_select, 76, 20, 7)
  if option_select == 0 and ticks % 30 > 15 then
    if level_select > 1 then
      spr(144, 64, 20, 1, 1, true)
    end
    if level_select < #level_options then
      spr(144, 83, 20, 1, 1, false)
    end
  end

  print("health: ", 36, 28, 7)
  print(health_options[health_select], 76, 28, 7)
  if option_select == 1 and ticks % 30 > 15 then
    if health_select > 1 then
      spr(144, 64, 28, 1, 1, true)
    end
    if health_select < #health_options then
      spr(144, 91, 28, 1, 1, false)
    end
  end

  print("enemy style: ", 16, 36, 7)
  print(enemy_style_options[enemy_style_select], 76, 36, 7)
  if option_select == 2 and ticks % 30 > 15 then
    if enemy_style_select > 1 then
      spr(144, 64, 36, 1, 1, true)
    end
    if enemy_style_select < #enemy_style_options then
      spr(144, 115, 36, 1, 1, false)
    end
  end

  print_centered("press z + x", 110, 7)
end

function reset_game()
  p1=m_player(8*18,8*3,false, 5)
  p2=m_player(8*22,8*3,true, 5)
  blood=m_blood()
  packages=m_packages()
  cpu=m_cpu()
	p1:set_anim("walk")
	cam=m_cam(p1)
end

function game_update()
  p1:update()
  cpu:update()
  p2:update()
  blood:update()
  packages:update()
  cam:update()
  check_death()
end

function game_draw()
  game_background()
	camera(cam:cam_pos())
	map((level_select - 1) * 40, 0, 0, 0, 128, 128)
  p1:draw()
  p2:draw()
  blood:draw()
  packages:draw()
	camera(0,0)
  p1:draw_hud()
  p2:draw_hud()
  game_over()
  print(cpu.lust_timer, 0, 0)
  print(cpu.lust_left, 0, 10)
  print(cpu.lust_right, 0, 20)
end


--p8 functions
--------------------------------

game_state = "title"

function _init()
	ticks=0
end

function _update60()
	ticks+=1
  if game_state == "title" then
    title_update()
  elseif game_state == "option" then
    option_update()
  elseif game_state == "game" then
    game_update()
  end
end

function _draw()
  cls(0)
  if game_state == "title" then
    title_draw()
  elseif game_state == "option" then
    option_draw()
  elseif game_state == "game" then
    game_draw()
  end
end

-->8
--todo knockback, clip size

weapons={
  handgun = {
    name="handgun",
    sfx=snd.small_gun,
    vel= 4,
    grav= 0.01,
    damage=10,
    cooldown=15,
    spread_x=0,
    spread_y=0.3,
    spr=32,
    bullets_in_shot=1,
    shake=0,
    recoil=0,
    x_offset=0,
    blood=5,
  },
  minigun = {
    name="minigun",
    sfx=snd.tiny_gun,
    vel= 4,
    grav= 0.01,
    damage=2,
    cooldown=2,
    spread_x=1,
    spread_y=0.3,
    spr=35,
    bullets_in_shot=1,
    shake=1,
    recoil=0.5,
    x_offset=0,
    blood=5,
  },
  ak47 = {
    name="ak47",
    sfx=snd.small_gun,
    vel= 3,
    grav= 0.01,
    damage=4,
    cooldown=8,
    spread_x=0,
    spread_y=0.3,
    spr=35,
    bullets_in_shot=1,
    shake=0,
    recoil=0.1,
    x_offset=1,
    blood=5,
  },
  shotgun = {
    name="shotgun",
    sfx=snd.boom_gun,
    vel= 4,
    grav= 0.01,
    damage=1,
    cooldown=30,
    spread_x=1.5,
    spread_y=1.5,
    spr=32,
    bullets_in_shot=20,
    shake=2,
    recoil=10,
    x_offset=0,
    blood=5,
  },
  super_shotgun = {
    name="super shotgun",
    sfx=snd.boom_gun,
    vel= 4,
    grav= 0.01,
    damage=1,
    cooldown=60,
    spread_x=2,
    spread_y=2,
    spr=32,
    bullets_in_shot=40,
    shake=4,
    recoil=20,
    x_offset=0,
    blood=5,
  },
  sniper_rifle = {
    name="sniper rifle",
    sfx=snd.sniper_rifle,
    vel= 6,
    grav= 0,
    damage=20,
    cooldown=60,
    spread_x=0,
    spread_y=0,
    spr=35,
    bullets_in_shot=1,
    shake=0,
    recoil=3,
    x_offset=0,
    blood=50,
  },
  flame_thrower = {
    name="flame thrower",
    sfx=snd.flame_thrower,
    vel= 2,
    grav= 0,
    damage=5,
    cooldown=2,
    spread_x=0,
    spread_y=2,
    spr=48,
    bullets_in_shot=1,
    shake=0,
    recoil=0,
    x_offset=2,
    blood=5,
  },
}

weapon_types={
  weapons.handgun,
  weapons.ak47,
  weapons.minigun,
  weapons.shotgun,
  weapons.super_shotgun,
  weapons.sniper_rifle,
  weapons.flame_thrower,
}

-->8
function m_cpu()
  local cpu=
  {
    br=true,
    bl=false,
    j=false,
    f=false,
    ticks=0,
    j_timer=0,
    lust_timer=0,
    lust_left=0,
    lust_right=8*40,
    closest_package={
      distance = 999,
    },

    laps=function(self)
      if p2.x > 8*38 then
        self:run_left()
      end
      if p2.x < 8*2 then
        self:run_right()
      end
    end,

    jump_to_ledges=function(self, frequency)
      if self.j_timer > 0 then
        self.j_timer -= 1
      else
        self.j= false
        if p2.flipx then
          if fget(map_get((p2.x - 3*8) / 8, (p2.y - 2*8) / 8 ), 1) then
            if rnd(1) < frequency then
              self.j= true
              self.j_timer = 30
            end
          end
        else
          if fget(map_get((p2.x + 3*8) / 8, (p2.y - 2*8) / 8 ), 1) then
            if rnd(1) < frequency then
              self.j= true
              self.j_timer = 30
            end
          end
        end
      end
    end,

    run_left=function(self)
      self.bl= true
      self.br= false
      self.lust_right = p2.x
    end,

    run_right=function(self)
      self.br= true
      self.bl= false
      self.lust_left = p2.x
    end,

    run_towards_object=function(self, object)
      if object.x - p2.x > 0 then
        self:run_right()
      else
        self:run_left()
      end
    end,

    jump_towards_object=function(self, object)
      if p1.y < p2.y then
        self:jump_to_ledges(1)
      end
    end,

    get_out_from_blocked_object=function(self, object)
      if abs(object.y - p2.y) > 2*8 and
         abs(object.x - p2.x) < (8*4 + (self.lust_timer / 60)) then
          self:run_right()
      end
    end,

    calculate_lust=function(self)
      if abs(self.lust_right - self.lust_left) < 8*4 then
        self.lust_timer += 1
      else
        self.lust_timer = 0
      end
    end,

    shoot_in_range=function(self)
      if abs(p1.y - p2.y) < 20 then
        self.f= true
      else
        self.f= false
      end
    end,

    shoot_on_sight=function(self)
      if (abs(p1.y - p2.y) < 20) then
        self.f= true
        if (p1.x - p2.x > 0) then
          self:run_right()
        else
          self:run_left()
        end
      else
        self.f= false
      end
    end,

    calculate_closest_package=function(self)
      local closest = {
        distance = 999,
      }
      for p in all(packages.packages) do
        local distance = m_vec(p2.x - p.x, p2.y - p.y):get_length()
        if distance < closest.distance then
          p.distance = distance
          closest = p
        end
      end
      self.closest_package = closest
    end,

    item_lust=function(self)
      if (self.closest_package.distance < 999) then
        self:run_towards_object(self.closest_package)
        self:jump_towards_object(self.closest_package)
        self:get_out_from_blocked_object(self.closest_package)
      else
        self:pacifist()
      end
    end,

    idiot=function(self)
      if self.ticks%30 == 0 then
        self.br= rnd(1) < 0.5
        self.bl= not self.br
        self.j= rnd(1) < 0.5
        self.f= rnd(1) < 0.5
      end
    end,

    pacifist=function(self)
      self:laps()
      self:jump_to_ledges(0.2)
    end,

    run_and_gun=function(self)
      self:laps()
      self:jump_to_ledges(0.2)
      self:shoot_on_sight()
    end,

    aggro=function(self)
      self:run_towards_object(p1)
      self:jump_towards_object(p1)
      self:shoot_in_range()
    end,

    update=function(self)
      self.ticks+=1

      local enemy_style = enemy_style_options[enemy_style_select]

      if enemy_style == "pacifist" then
        self:pacifist()
      elseif enemy_style == "idiot" then
        self:idiot()
      elseif enemy_style == "run & gun" then
        self:run_and_gun()
      elseif enemy_style == "aggro" then
        self:aggro()
      end

      self:calculate_lust()
      if ticks % 60 == 0 then
        self:calculate_closest_package()
      end
    end,
  }

  return cpu
end

__gfx__
00000000022220000222200002222000022220000222200002222000022220000000000000000000000000000000000000000000000000000000000000000000
00000000222222002222220022222200222222002222220022222200222222000000000000000000000000000000000000000000000000000000000000000000
00000000fffff000fffff000fffff000fffff000fffff000fffff000fffff0000000000000000000000000000000000000000000000000000000000000000000
00000000f1ff1000f1ff1000f1ff1000f1ff1000f1ff1000f1ff1000f1ff10000000000000000000000000000000000000000000000000000000000000000000
00000000fffff000fffff000fffff000fffff000fffff000fffff000fffff0000000000000000000000000000000000000000000000000000000000000000000
00000000cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc00000000000000000000000000000000000000000000000000000000000000000000
00000000f11f0000f11f0000f11f0000f11f0000f11f0000f11f0000f11f00000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666660099990000999900009999000099990000999900009999000099990000000000000000000000000000000000000000000000000000000000000000000
66666664999999009999990099999900999999009999990099999900999999000000000000000000000000000000000000000000000000000000000000000000
66446444fffff000fffff000fffff000fffff000fffff000fffff000fffff0000000000000000000000000000000000000000000000000000000000000000000
46444444f3ff3000f3ff3000f3ff3000f3ff3000f3ff3000f3ff3000f3ff30000000000000000000000000000000000000000000000000000000000000000000
44444554fffff000fffff000fffff000fffff000fffff000fffff000fffff0000000000000000000000000000000000000000000000000000000000000000000
55445445cccc0000cccc0000cccc0000cccc0000cccc0000cccc0000cccc00000000000000000000000000000000000000000000000000000000000000000000
55544555f11f0000f11f0000f11f0000f11f0000f11f0000f11f0000f11f00000000000000000000000000000000000000000000000000000000000000000000
05555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0000000444a4440777777706000000000e800000090000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000444a444077787770000000000e8800000977000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000aaaaaaa07788877000000000e88800009777700000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000444a444077787770000000000e8000000990000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000444a44407777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
90090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9aa99000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9aaa9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99a99000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03000b000000b0006770000000670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00b0b300030b00305d67000000d66700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
003033000303303005d60000055d6600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0b0b00b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30300303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b0bb00bb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3bb3bb3b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33444344000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
34444334000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44443434000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04044040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06666660b0bb00bb0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
666666643bb3bb3b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66446444333333330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
46444444334443440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444554344443340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55445445444434340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55544555444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555550040440400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08800880000880000888888008888800088888000880088000000000000000000000000000000000000000000000000000000000000000000000000000000000
08800880008888000888888008888800088008000880088000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888880008008000008800008800800088888000888888000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888880088008800008800008888800088880000088880000000000000000000000000000000000000000000000000000000000000000000000000000000000
08800880088888800008800008800000088008000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000
08800880088008800008800008800000088008000008800000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000664
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000464
00000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000000000000000444
00000000000000000000077777770000000006770000003000b00000000000000000000000000000000000000000000000000000000000000000000003000554
00000000000000000000077787770000000005d67000000b0b3000000000000000000000000000000000000000000000000000000000000000000b0b0b00b555
000000000000000000000778887700000000005d6000000303300000000000000000000000000000000000000000000000000000000000000000030300303055
00000000000000000000077787770066666600666666006666660000000000000000000000000000000000000000000000000066666600666666006666660066
00000000000000000000077777774666666646666666466666664000000000000000000000000000000000000000000000000666666646666666466666664666
00000000000000000000066446444664464446644644466446444000000000000000000000000000000000000000000000000664464446644644466446444664
00000000000000000000046444444464444444644444446444444000000000000000000000000000000000000000000000000464444444644444446444444464
00000000000000000000044444554444445544444455444444554000000000000000000000000000000000000000000000000444445544444455444444554444
00000000000000000000055445445554454455544544555445445000000000000000000000000000000000000000000000000554454455544544555445445554
00000000000000000000055544555555445555554455555544555000000000000000000000000000000000000000000000000555445555554455555544555555
00000000000000000000005555550055555500555555005555550000000000000000000000000000000000000000000000000055555500555555005555550055
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000664
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000464
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000554
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555
00000000000000000000000000000000000000000000000000000000000000000000007707700777077707770777000007770777077707000777000000000055
00000000000000000000000000000000000000000000000000000000000000000000070007070070070707000707000007070070070007000700000000000066
00000000000000000000000000000000000000000000000000000000000000000000077707070070077707700770000007700070077007000770000000000666
00000000000000000000000000000000000000000000000000000000000000000000000707070070070007000707000007070070070007000700000000000664
00000000000000000000000000000000000000000000000000000000000000000000077007070777070007770707000007070777070007770777000000000464
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444
70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b444a4440000000000000000000000000000554
6670000000000000000000000000000000000000000000000000000000000000000000000000000000000030b0444a4440000000000000000000000000000555
d66000000000000000000000000000000000000000000000000000000000000000000000000000000000003033aaaaaaa0000000000000000000000000000055
686600000000000000000000000000000000000000000000000000000000000000000066666600666666006666444a4440000000000000000000000000000066
666640000000000000000000000000000000000000000000000000000000000000000666666646666666466666444a4440000000000000000000000000000666
46444000000000000000000000000000000000000000000000000000000000000000066446444664464446644644400000000000000000000000000000000664
44444000000000000000000000000000000000000000000000000000000000000000046444444464444444644444400000000000000000000000000000000464
44554000000000000000000000000000000000000000000000000000000000000000044444554444445544444455400000000000000000000000000000000444
45445000000000000000000000000000000000000000000000000000000000000000055445445554454455544544500000000000000000000000000000000554
44585000000000000000000000000000000000000000000000000000000000000000055544555555445555554455500000000000000000000000000000000555
55550000000000000000000000000000000000000000000000000000000000000000005555550055555500555555000000000000000000000000000000000055
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000664
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000464
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000554
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000664
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000464
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444
00000000000000000000000000000000000000000000000000000000000000000000000003000000030000000000000670000000000000000000000000000554
000000000000000000000000000000000000000000000000000000000000000000000b0b0b00bb0b0b00b0000000000d66700000000000000000000000000555
000000000000000000000000000000000000000000000000000000000000000000000303003033030030300000000055d6600000000000000000000000000055
00000000000000000000000000000000000000000000000000000066666600666666006666660066666600666666006666660000000000000000000000000066
00000000000000000000000000000000000000000000000000000666666646666666466666664666666646666666466666664000000000000000000000000666
00000000000000000000000000000000000000000000000000000664464446644644466446444664464446644644466446444000000000000000000000000664
00000000000000000000000000000000000000000000000000000464444444644444446444444464444444644444446444444000000000000000000000000464
00000000000000000000000000000000000000000000000000000444445544444455448444554484448544444455444444554000000000000000000000000444
00000000000000000000000000000000000000000000000000000554454458548544555445448854454455548544555845445000000000000000000000000554
00000000000000000000000000000000000000000000000000000555845585554855555584555858445555554855555544555000000000000000000000000555
00000000000000000000000000000000000000000000000000000055585588585588808855580855558500588555005588550000000000000000000000000055
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000664
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000464
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000554
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000555
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000055
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000664
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000464
00000000000000000003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030444
000000000000003000b00000000000000b0000000000000000000000000000000000000000000000000000000000000000000000000000000000003000b00554
000000000000000b0b30000000000030b00300000000000000000000000000000000000000000000000000000000000000000000000000000000000b0b300585
00000000000000030330000000000030330300000000000000000000000000000000000000000000000000000000000000000000000000000000000303300055
00000866666800666666006666660066666600000000000000000000000000000000000000000000000000000000000000000000000000866668006666660066
00000666666646666666466666864666666640000000000000000000000000000000000000000000000000000000000000000000000006666666466666664666
00000664464446644644466446444664464440000000000000000000000000000000000000000000000000000000000000000000000006644644466446444664
00000464444444644444446444444464444777000000000000000000000000000000000000000000000000000000000000000000000004644444446444444464
00000444445544444455444444554444447777700000000000000000000000000000000000000000000000000000000000000000000008444455444444554444
00000554454455547777755445445554477777700000000000000000000000000000000000000000000000000000000000000000000005544544555445445554
00000555445555577777775544555555777787700000000000000000000000000000000000000000000000000000000000000000000008554455555544555555
00000055555500577777775555550055777777000000000000000000000000000000000000000000000000000000000000000000000000555555005555550055
00000000000000077777770000000000777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066
000000000000000077777000000000000777a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000666
0000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000664
0000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000464
00000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444
00000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000554
00000000000000000000000000000080000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000555
0000000000000000000a000000000000000000000000000808008000000000000000000000000000000000000000000000000000000000000000000000000055
00000000000000000000000000000000000008008000000080000000000000000000000000000000000000000000000000000000000000000000000000000066
00000000000000000000a00000000000000000000000000228800000000000000000000000000000000000000000000000000000000000000009999000000666
00000000000000000000000000000000000000000080002222220800000000000000000000000000000000000000000000000000000000000099999900000664
00000000000000000000000000a0000000000000080080ff88f0000000000000000000000000000000000000000000000000000000000000000fffff00000484
0000000000000000000000000000000000000000000000f1ff108000000000000003000000000000000000000000000000000000000000000003ff3f00000444
000000000000000000000000000000000000067700000088ff8800000000003000b0000003000006700000000000000000000677000000000b0fffff00000554
00000000000000000000000000000000000005d67000008ccc8808000000e80be8300b0b0b00e88d6670000000000000000005d670000030b003cccc00000555
000000000000000000000000000000000080005d600008f11f800000000e880e88300303003e8885d6600000000000000000005d600000303303f11f00000055
8668888688680068866600868686806888860068688680868866808668e888e88866006688e88886666600866866006868860866686880668686086666660066
66684666666846666666466686664666666646666686866666884666666e888e86864666666e8866666846666886466866864686866646686666466666664666
46444664464446644644466446444664464446644644466446444664464446644644468446444664464446644644466846444664464446644644466446444664
44444464444444644444446444444464444444644444446444444464444444644444446444444464444444644444446444444464444444644444446444444464
44554444445544444455444444554444445544444455444444554444445544444455444444554444445544444455444444554444445544444455444444554444
45445554454455544544555445445554454455544544555445445554454455544544555445445554454455544544555445445554454455544544555445445554
44555555445555554455555544555555445555554455555544555555445555554455555544555555445555554455555544555555445555554455555544555555
55550055555500555555005555550055555500555555005555550055555500555555005555550055555500555555005555550055555500555555005555550055
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07770777077007770077070707700000000000000000000000000000000000000000000000000077070707770777077700000077070700770777007707070770
07770070070700700700070707070000000000000000000000000000000000000000000000000700070707070700070700000700070707070070070007070707
07070070070700700700070707070000000000000000000000000000007770000007070000000777070707770770077000000777077707070070070007070707
07070070070700700707070707070000000000000000000000000000007000000007070000000007070707000700070700000007070707070070070707070707
07070777070707770777007707070000000000000000000000000000007770000007770000000770007707000777070700000770070707700070077700770707
00000000000000000000000000000000000000000000000000000000000070000000070000000000000000000000000000000000000000000000000000000000
0bbbbbbbbbbbbbbbbbbbddddddddddddddddddddddddddddddd00000007770000000070000000bbdddddddddddddddddddddddddddddddddddddddddddddddd0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09999999999999999999999999999999999999999999999999900000000000000000000000000dddddddddddddddddddddddddddddddddddd999999999999990

__gff__
0000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000003030000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
1010101010101010101010101010101010101010101010101010101010101010101010101010101060606060606060606060606060606060606060606060606060606060606060606060606060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000000000000000000000000000000000000000000000000000000000000000000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000000000000000000000000000000000000000000000000000000000000000000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000000000000000000000000000000000000000000000000000000000000000000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000004000000000000000000000414000004341000000000000000000410043000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000701070000000000000000000701010101070000000000000000000701070000000001060000000000000000000000000000000716060606060607100000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000000000000000000000000000000000000000000000000000000000000000000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1043004100000000000042500000000000000000000000000000000042400000000000000000501060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010107000000000000070101070000000000000000000000000701010700000000000007010101060606060607100000000000071606060607100000000716060606071000000000000716060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000000000000000000000000000000000000000000000000000000000000000000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000005000000000000000000050000000000000430000000000000000000041000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000007070000000000000000070700000000070700000000000000000701070000000001060606060606060606071000000000000007160606060710000000000000071606060606060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000000000000000000000000000000000000000000000000000000000000000000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000430040410000000000000000004142004100000000000000000000505000430000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000070101010107000000000000000701010101070000000000000007010101010700000001060606060710000000000000071607100000000000000000000716071000000000000007160606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000000000000000000000000000000000000000000000000000000000000000000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1050000000000000000000005050004000000000000000000040004100000000000000000000401060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010700000000000000000007010107000000000000000007010107000000000000000000070101060000000000000716071000000000000007160606060710000000000000071607100000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1000000000000000000000000000000000000000000000000000000000000000000000000000001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1042000041434000000000424100000050000000430050000000000042000040504300004241001060000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1010101010101010101010101010101010101010101010101010101010101010101010101010101060606060606060606060606060606060606060606060606060606060606060606060606060606060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
00010000000000f7500f7500e7500e7500e7500e7500e7500d7500b750087500775003750037500175002750027500275003750067500a7500c7500f750127501375012750117500f7500b750057500175001750
00060000000003f610236102960030600306003060030600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200003f6503e600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500000b670126701b670166700e67007670046700167001670016600165001640016300b600036000460000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300003d65039650366503465032650306502e6502c6502b650286502565022640216401f6401d6401b64019630166301463013630116300f6200d6200c6200a62008620056100561003610016100161001610
000800000164001600016000160001600016000160001600016000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300003f7703b6703f770336703f7702c6703e760256603d760246503c750206403b7301d6303a7301b6203972019620387101661015610116100e6100c6100000000000000000000000000000000000000000
