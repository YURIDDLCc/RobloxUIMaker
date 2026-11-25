local rgbasupported = getrawmetatable and setrawmetatable and newcclosure and not string.find(identifyexecutor(), "Solara")

local firsttabsignal

local drawing = {} do
	local services = setmetatable({}, {
		__index = function(self, key)
			if key == "InputService" then
				key = "UserInputService"
			end

			if not rawget(self, key) then
				local service = game:GetService(key)
				rawset(self, service, service)

				return service
			end

			return rawget(self, key)
		end
	})

	local HttpService = game:GetService("HttpService")

	local ENABLE_TRACEBACK = false

	local Signal = {}
	Signal.__index = Signal
	Signal.ClassName = "Signal"

	--[=[
		Returns whether a class is a signal
		@param value any
		@return boolean
	]=]
	function Signal.isSignal(value)
		return type(value) == "table"
			and getmetatable(value) == Signal
	end

	--[=[
		Constructs a new signal.
		@return Signal<T>
	]=]
	function Signal.new()
		local self = setmetatable({}, Signal)

		self._bindableEvent = Instance.new("BindableEvent")
		self._argMap = {}
		self._source = ENABLE_TRACEBACK and debug.traceback() or ""

		-- Events in Roblox execute in reverse order as they are stored in a linked list and
		-- new connections are added at the head. This event will be at the tail of the list to
		-- clean up memory.
		self._bindableEvent.Event:Connect(function(key)
			self._argMap[key] = nil

			-- We've been destroyed here and there's nothing left in flight.
			-- Let's remove the argmap too.
			-- This code may be slower than leaving this table allocated.
			if (not self._bindableEvent) and (not next(self._argMap)) then
				self._argMap = nil
			end
		end)

		return self
	end

	--[=[
		Fire the event with the given arguments. All handlers will be invoked. Handlers follow
		@param ... T -- Variable arguments to pass to handler
	]=]
	function Signal:Fire(...)
		if not self._bindableEvent then
			warn(("Signal is already destroyed. %s"):format(self._source))
			return
		end

		local args = table.pack(...)

		-- TODO: Replace with a less memory/computationally expensive key generation scheme
		local key = HttpService:GenerateGUID(false)
		self._argMap[key] = args

		-- Queues each handler onto the queue.
		self._bindableEvent:Fire(key)
	end

	--[=[
		Connect a new handler to the event. Returns a connection object that can be disconnected.
		@param handler (... T) -> () -- Function handler called when `:Fire(...)` is called
		@return RBXScriptConnection
	]=]
	function Signal:Connect(handler)
		if not (type(handler) == "function") then
			error(("connect(%s)"):format(typeof(handler)), 2)
		end

		return self._bindableEvent.Event:Connect(function(key)
			-- note we could queue multiple events here, but we'll do this just as Roblox events expect
			-- to behave.

			local args = self._argMap[key]
			if args then
				handler(table.unpack(args, 1, args.n))
			else
				error("Missing arg data, probably due to reentrance.")
			end
		end)
	end

	--[=[
		Wait for fire to be called, and return the arguments it was given.
		@yields
		@return T
	]=]
	function Signal:Wait()
		local key = self._bindableEvent.Event:Wait()
		local args = self._argMap[key]
		if args then
			return table.unpack(args, 1, args.n)
		else
			error("Missing arg data, probably due to reentrance.")
			return nil
		end
	end

	--[=[
		Disconnects all connected events to the signal. Voids the signal as unusable.
		Sets the metatable to nil.
	]=]
	function Signal:Destroy()
		if self._bindableEvent then
			-- This should disconnect all events, but in-flight events should still be
			-- executed.

			self._bindableEvent:Destroy()
			self._bindableEvent = nil
		end

		-- Do not remove the argmap. It will be cleaned up by the cleanup connection.

		setmetatable(self, nil)
	end

	local signal = Signal

	local function ismouseover(obj)
		local posX, posY = obj.Position.X, obj.Position.Y
		local sizeX, sizeY = posX + obj.Size.X, posY + obj.Size.Y
		local mousepos = services.InputService:GetMouseLocation()

		if mousepos.X >= posX and mousepos.Y >= posY and mousepos.X <= sizeX and mousepos.Y <= sizeY then
			return true
		end

		return false
	end

	local function udim2tovector2(udim2, vec2)
		local xscalevector2 = vec2.X * udim2.X.Scale
		local yscalevector2 = vec2.Y * udim2.Y.Scale

		local newvec2 = Vector2.new(xscalevector2 + udim2.X.Offset, yscalevector2 + udim2.Y.Offset)

		return newvec2
	end

	-- totally not skidded from devforum (trust)
	local function istouching(pos1, size1, pos2, size2)
		local top = pos2.Y - pos1.Y
		local bottom = pos2.Y + size2.Y - (pos1.Y + size1.Y)
		local left = pos2.X - pos1.X
		local right = pos2.X + size2.X - (pos1.X + size1.X)

		local touching = true

		if top > 0 then
			touching = false
		elseif bottom < 0 then
			touching = false
		elseif left > 0 then
			touching = false
		elseif right < 0 then
			touching = false
		end

		return touching
	end

	local objchildren = {}
	local objmts = {}
	local objvisibles = {}
	local mtobjs = {}
	local udim2posobjs = {}
	local udim2sizeobjs = {}
	local objpositions = {}
	local listobjs = {}
	local listcontents = {}
	local listchildren = {}
	local listadds = {}
	local objpaddings = {}
	local scrollobjs = {}
	local listindexes = {}
	local custompropertysets = {}
	local custompropertygets = {}
	local objconnections = {}
	local objmtchildren = {}
	local scrollpositions = {}
	local currentcanvasposobjs = {}
	local childrenposupdates = {}
	local childrenvisupdates = {}
	local squares = {}
	local objsignals = {}
	local objexists = {}

	local function mouseoverhighersquare(obj)
		for _, square in next, squares do
			if square.Visible == true and square.ZIndex > obj.ZIndex then
				if ismouseover(square) then
					return true
				end
			end
		end
	end

	services.InputService.InputEnded:Connect(function(input, gpe)
		for obj, signals in next, objsignals do
			if objexists[obj] then
				if signals.inputbegan[input] then
					signals.inputbegan[input] = false

					if signals.InputEnded then
						signals.InputEnded:Fire(input, gpe)
					end
				end

				if obj.Visible then
					if ismouseover(obj) then
						if input.UserInputType == Enum.UserInputType.MouseButton1 and not mouseoverhighersquare(obj) then
							if signals.MouseButton1Up then
								signals.MouseButton1Up:Fire()
							end

							if signals.mouse1down and signals.MouseButton1Click then
								signals.mouse1down = false
								signals.MouseButton1Click:Fire()
							end
						end

						if input.UserInputType == Enum.UserInputType.MouseButton2 and not mouseoverhighersquare(obj) then
							if signals.MouseButton2Clicked then
								signals.MouseButton2Clicked:Fire()
							end

							if signals.MouseButton2Up then
								signals.MouseButton2Up:Fire()
							end
						end
					end
				end
			end
		end
	end)

	services.InputService.InputChanged:Connect(function(input, gpe)
		for obj, signals in next, objsignals do
			if objexists[obj] and obj.Visible and (signals.MouseEnter or signals.MouseMove or signals.InputChanged or signals.MouseLeave) then
				if ismouseover(obj) then
					if not signals.mouseentered then
						signals.mouseentered = true

						if signals.MouseEnter then
							signals.MouseEnter:Fire(input.Position)
						end

						if signals.MouseMoved then
							signals.MouseMoved:Fire(input.Position)
						end
					end

					if signals.InputChanged then
						signals.InputChanged:Fire(input, gpe)
					end
				elseif signals.mouseentered then
					signals.mouseentered = false

					if signals.MouseLeave then
						signals.MouseLeave:Fire(input.Position)
					end
				end
			end
		end
	end)

	services.InputService.InputBegan:Connect(function(input, gpe)
		for obj, signals in next, objsignals do
			if objexists[obj] then
				if obj.Visible then
					if ismouseover(obj) and not mouseoverhighersquare(obj) then
						signals.inputbegan[input] = true

						if signals.InputBegan then
							signals.InputBegan:Fire(input, gpe)
						end

						if input.UserInputType == Enum.UserInputType.MouseButton1 and (not mouseoverhighersquare(obj) or obj.Transparency == 0) then
							signals.mouse1down = true

							if signals.MouseButton1Down then
								signals.MouseButton1Down:Fire()
							end
						end

						if input.UserInputType == Enum.UserInputType.MouseButton2 and (not mouseoverhighersquare(obj) or obj.Transparency == 0) then
							if signals.MouseButton2Down then
								signals.MouseButton2Down:Fire()
							end
						end
					end
				end
			end
		end
	end)

	function drawing:new(shape)
		local obj = Drawing.new(shape)
		objexists[obj] = true
		pcall(setrenderproperty, obj, "Visible", false)--obj.Visible = false -- I hate solara pt2
		local signalnames = {}

		local listfunc
		local scrollfunc
		local refreshscrolling

		objconnections[obj] = {}

		if shape == "Square" then
			table.insert(squares, obj)

			signalnames = {
				MouseButton1Click = signal.new(),
				MouseButton1Up = signal.new(),
				MouseButton1Down = signal.new(),
				MouseButton2Click = signal.new(),
				MouseButton2Up = signal.new(),
				MouseButton2Down = signal.new(),
				InputBegan = signal.new(),
				InputEnded = signal.new(),
				InputChanged = signal.new(),
				MouseEnter = signal.new(),
				MouseLeave = signal.new(),
				MouseMoved = signal.new()
			}

			local attemptedscrollable = false

			scrollfunc = function(self)
				if listobjs[self] then
					scrollpositions[self] = 0
					scrollobjs[self] = true

					self.ClipsDescendants = true

					local function scroll(amount)
						local viewport = mtobjs[self]
						local maxscroll = math.max(0, listcontents[self] - viewport.Size.Y)
						local current = scrollpositions[self] or 0
						local target = current
						local padding = objpaddings[self] or 0

						if maxscroll <= 0 then
							return false
						end

						if padding == 12 then
							local viewportTop = -current

							if amount > 0 then
								local nextIndex
								for i, baseY in next, listindexes[self] do
									if baseY > viewportTop + 0.5 then
										nextIndex = i
										break
									end
								end

								if nextIndex then
									target = math.max(-listindexes[self][nextIndex], -maxscroll)
								else
									target = -maxscroll
								end
							else
								local previousIndex
								for i = #listindexes[self], 1, -1 do
									if listindexes[self][i] < viewportTop - 0.5 then
										previousIndex = i
										break
									end
								end

								if previousIndex then
									target = math.min(-listindexes[self][previousIndex], 0)
								else
									target = 0
								end
							end
						else
							local step = 40
							if amount > 0 then
								target = math.max(current - step, -maxscroll)
							else
								target = math.min(current + step, 0)
							end
						end

						local poschange = target - current

						if poschange == 0 then
							return false
						end

						scrollpositions[self] = target

						for i = #objchildren[self], 1, -1 do
							local object = objchildren[self][i]
							local objectmt = object and objmts[object]
							if object and objectmt and objexists[object] and object.Position and object.Size then
								local newpos = object.Position + Vector2.new(0, poschange)
								local posupdate = childrenposupdates[objectmt]
								if posupdate then
									posupdate(objectmt, newpos)
								end
								object.Position = newpos

								if custompropertygets[viewport]("ClipsDescendants") then
									local visible = istouching(newpos, object.Size, viewport.Position, viewport.Size) and objvisibles[object] or false
									object.Visible = visible
									local visupdate = childrenvisupdates[objectmt]
									if visupdate then
										visupdate(objectmt, visible)
									end
								end
							else
								table.remove(objchildren[self], i)
							end
						end

						return true
					end

					refreshscrolling = function()
						repeat
						until
							not scroll(-1)
					end

					self.InputChanged:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseWheel then
							if input.Position.Z < 0 then
								scroll(1)
							elseif input.Position.Z > 0 then
								scroll(-1)
							end
						end
					end)
				else
					attemptedscrollable = true
				end
			end

			listfunc = function(self, padding)
				objpaddings[self] = padding
				listcontents[self] = 0
				listchildren[self] = {}
				listindexes[self] = {}
				listadds[self] = {}

				listobjs[self] = true

				for i, object in next, objchildren[self] do
					table.insert(listchildren[self], object)
					table.insert(listindexes[self], listcontents[self] + (#listchildren[self] == 1 and 0 or padding))

					local newpos = mtobjs[self].Position + Vector2.new(0, listcontents[self] + (#listchildren[self] == 1 and 0 or padding))
					object.Position = newpos

					childrenposupdates[object](objmts[object], newpos)

					custompropertysets[object]("AbsolutePosition", newpos)

					listadds[self][object] = object.Size.Y + (#listchildren[self] == 1 and 0 or padding)
					listcontents[self] = listcontents[self] + object.Size.Y + (#listchildren[self] == 1 and 0 or padding)
				end

				if attemptedscrollable then
					scrollfunc(self)
				end
			end
		end

		local customproperties = {
			Parent = nil,
			AbsolutePosition = nil,
			AbsoluteSize = nil,
			ClipsDescendants = false
		}

		custompropertysets[obj] = function(k, v)
			customproperties[k] = v
		end

		custompropertygets[obj] = function(k)
			return customproperties[k]
		end

		local mt = setmetatable({exists = true}, {
			__index = function(self, k)
				if k == "Parent" then
					return customproperties.Parent
				end

				if k == "Visible" then
					return objvisibles[obj]
				end

				if k == "Position" then
					return udim2posobjs[obj] or objpositions[obj] or obj[k]
				end

				if k == "Size" then
					return udim2sizeobjs[obj] or obj[k]
				end

				if k == "AddListLayout" and listfunc then
					return listfunc
				end

				if k == "MakeScrollable" and scrollfunc then
					return scrollfunc
				end

				if k == "RefreshScrolling" and refreshscrolling then
					return refreshscrolling
				end

				if k == "AbsoluteContentSize" then
					return listcontents[self]
				end

				if k == "GetChildren" then
					return function(self)
						return objmtchildren[self]
					end
				end

				if k == "Remove" then
					return function(self)
						rawset(self, "exists", false)
						objexists[obj] = false

						if customproperties.Parent and listobjs[customproperties.Parent] then
							local objindex = table.find(objchildren[customproperties.Parent], obj)

							listcontents[customproperties.Parent] = listcontents[customproperties.Parent] - listadds[customproperties.Parent][obj]

							for i, object in next, objchildren[customproperties.Parent] do
								if i > objindex then
									object.Position = object.Position - Vector2.new(0, listadds[customproperties.Parent][obj])
								end
							end

							if table.find(listchildren[customproperties.Parent], obj) then
								table.remove(listchildren[customproperties.Parent], table.find(listchildren[customproperties.Parent], obj))
							end

							local childindex = table.find(objchildren[customproperties.Parent], obj)
							if childindex then
								table.remove(objchildren[customproperties.Parent], childindex)
								if listindexes[customproperties.Parent] then
									table.remove(listindexes[customproperties.Parent], childindex)
								end
							end
						end

						if table.find(squares, mtobjs[self]) then
							table.remove(squares, table.find(squares, mtobjs[self]))
						end

						for _, object in next, objchildren[self] do
							if objexists[object] then
								table.remove(objsignals, table.find(objsignals, object))
								objmts[object]:Remove()
							end
						end

						table.remove(objsignals, table.find(objsignals, obj))
						obj:Remove()
					end
				end

				if signalnames and signalnames[k] then
					objsignals[obj] = objsignals[obj] or {}

					if not objsignals[obj][k] then
						objsignals[obj][k] = signalnames[k]
					end

					objsignals[obj].inputbegan = objsignals[obj].inputbegan or {}
					objsignals[obj].mouseentered = objsignals[obj].mouseentered or {}
					objsignals[obj].mouse1down = objsignals[obj].mouse1down or {}

					return signalnames[k]
				end

				return customproperties[k] or obj[k]
			end,

			__newindex = function(self, k, v)
				local changechildrenvis
				changechildrenvis = function(parent, vis)
					if objchildren[parent] then
						for _, object in next, objchildren[parent] do
							if (custompropertygets[mtobjs[parent]]("ClipsDescendants") and not istouching(object.Position, object.Size, mtobjs[parent].Position, mtobjs[parent].Size)) then
								object.Visible = false
								changechildrenvis(objmts[object], false)
							else
								object.Visible = vis and objvisibles[object] or false
								changechildrenvis(objmts[object], vis and objvisibles[object] or false)
							end
						end
					end
				end

				childrenvisupdates[self] = changechildrenvis

				if k == "Visible" then
					objvisibles[obj] = v

					if customproperties.Parent and (not mtobjs[customproperties.Parent].Visible or (custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") and not istouching(obj.Position, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size))) then
						v = false
						changechildrenvis(self, v)
					else
						changechildrenvis(self, v)
					end
				end

				if k == "ClipsDescendants" then
					customproperties.ClipsDescendants = v

					for _, object in next, objchildren[self] do
						object.Visible = v and (istouching(object.Position, object.Size, obj.Position, obj.Size) and objvisibles[object] or false) or objvisibles[object]
					end

					return
				end

				local changechildrenpos
				changechildrenpos = function(parent, val)
					if objchildren[parent] then
						if listobjs[parent] then
							for i, object in next, objchildren[parent] do
								local newpos = val + Vector2.new(0, listindexes[parent][i])

								if scrollobjs[parent] then
									newpos = val + Vector2.new(0, listindexes[parent][i] + scrollpositions[parent])
								end

								newpos = Vector2.new(math.floor(newpos.X), math.floor(newpos.Y))

								object.Position = newpos
								custompropertysets[object]("AbsolutePosition", newpos)

								changechildrenpos(objmts[object], newpos)
							end
						else
							for _, object in next, objchildren[parent] do
								local newpos = val + objpositions[object]
								newpos = Vector2.new(math.floor(newpos.X), math.floor(newpos.Y))

								object.Position = newpos

								custompropertysets[object]("AbsolutePosition", newpos)

								changechildrenpos(objmts[object], newpos)
							end
						end
					end
				end

				childrenposupdates[self] = changechildrenpos

				if k == "Position" then
					if typeof(v) == "UDim2" then
						udim2posobjs[obj] = v

						if customproperties.Parent then
							objpositions[obj] = udim2tovector2(v, mtobjs[customproperties.Parent].Size)

							if listobjs[customproperties.Parent] then
								return
							else
								v = mtobjs[customproperties.Parent].Position + udim2tovector2(v, mtobjs[customproperties.Parent].Size)
							end
						else
							local newpos = udim2tovector2(v, workspace.CurrentCamera.ViewportSize)
							objpositions[obj] = newpos
							v = udim2tovector2(v, workspace.CurrentCamera.ViewportSize)
						end

						customproperties.AbsolutePosition = v

						if customproperties.Parent and custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") then
							obj.Visible = istouching(v, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false
							changechildrenvis(self, istouching(v, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false)
						end

						changechildrenpos(self, v)
					else
						objpositions[obj] = v

						if customproperties.Parent then
							if listobjs[customproperties.Parent] then
								return
							else
								v = mtobjs[customproperties.Parent].Position + v
							end
						end

						customproperties.AbsolutePosition = v

						if customproperties.Parent and custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") then
							obj.Visible = istouching(v, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false
							changechildrenvis(self, istouching(v, obj.Size, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false)
						end

						changechildrenpos(self, v)
					end

					v = v
				end

				local changechildrenudim2pos
				changechildrenudim2pos = function(parent, val)
					if objchildren[parent] and not listobjs[parent] then
						for _, object in next, objchildren[parent] do
							if udim2posobjs[object] then
								local newpos = mtobjs[parent].Position + udim2tovector2(udim2posobjs[object], val)
								newpos = Vector2.new(math.floor(newpos.X), math.floor(newpos.Y))

								if not listobjs[parent] then
									object.Position = newpos
								end

								custompropertysets[object]("AbsolutePosition", newpos)
								objpositions[object] = udim2tovector2(udim2posobjs[object], val)
								changechildrenpos(objmts[object], newpos)
							end
						end
					end
				end

				local changechildrenudim2size
				changechildrenudim2size = function(parent, val)
					if objchildren[parent] then
						for _, object in next, objchildren[parent] do
							if udim2sizeobjs[object] then
								local newsize = udim2tovector2(udim2sizeobjs[object], val)
								object.Size = newsize

								if custompropertygets[mtobjs[parent]]("ClipsDescendants") then
									object.Visible = istouching(object.Position, object.Size, mtobjs[parent].Position, mtobjs[parent].Size) and objvisibles[object] or false
								end

								custompropertysets[object]("AbsoluteSize", newsize)

								changechildrenudim2size(objmts[object], newsize)
								changechildrenudim2pos(objmts[object], newsize)
							end
						end
					end
				end

				if k == "Size" then
					if typeof(v) == "UDim2" then
						udim2sizeobjs[obj] = v

						if customproperties.Parent then
							v = udim2tovector2(v, mtobjs[customproperties.Parent].Size)
						else
							v = udim2tovector2(v, workspace.CurrentCamera.ViewportSize)
						end

						if customproperties.Parent and listobjs[customproperties.Parent] then
							local oldsize = obj.Size.Y
							local sizediff = v.Y - oldsize

							local objindex = table.find(objchildren[customproperties.Parent], obj)

							listcontents[customproperties.Parent] = listcontents[customproperties.Parent] + sizediff
							listadds[customproperties.Parent][obj] = listadds[customproperties.Parent][obj] + sizediff

							for i, object in next, objchildren[customproperties.Parent] do
								if i > objindex then
									object.Position = object.Position + Vector2.new(0, sizediff)
									listindexes[customproperties.Parent][i] = listindexes[customproperties.Parent][i] + sizediff
								end
							end
						end

						customproperties.AbsoluteSize = v

						changechildrenudim2size(self, v)
						changechildrenudim2pos(self, v)

						if customproperties.ClipsDescendants then
							for _, object in next, objchildren[self] do
								object.Visible = istouching(object.Position, object.Size, obj.Position, v) and objvisibles[object] or false
							end
						end

						if customproperties.Parent and custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") then
							obj.Visible = istouching(obj.Position, v, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false
							changechildrenvis(self, istouching(obj.Position, v, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false)
						end
					else
						if customproperties.Parent and listobjs[customproperties.Parent] then
							local oldsize = obj.Size.Y
							local sizediff = v.Y - oldsize

							local objindex = table.find(objchildren[customproperties.Parent], obj)

							listcontents[customproperties.Parent] = listcontents[customproperties.Parent] + sizediff
							listadds[customproperties.Parent][obj] = listadds[customproperties.Parent][obj] + sizediff

							for i, object in next, objchildren[customproperties.Parent] do
								if i > objindex then
									object.Position = object.Position + Vector2.new(0, sizediff)
									listindexes[customproperties.Parent][i] = listindexes[customproperties.Parent][i] + sizediff
								end
							end
						end

						customproperties.AbsoluteSize = v

						changechildrenudim2size(self, v)
						changechildrenudim2pos(self, v)

						if customproperties.ClipsDescendants then
							for _, object in next, objchildren[self] do
								object.Visible = istouching(object.Position, object.Size, obj.Position, v) and objvisibles[object] or false
							end
						end

						if customproperties.Parent and custompropertygets[mtobjs[customproperties.Parent]]("ClipsDescendants") then
							obj.Visible = istouching(obj.Position, v, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false
							changechildrenvis(self, istouching(obj.Position, v, mtobjs[customproperties.Parent].Position, mtobjs[customproperties.Parent].Size) and objvisibles[obj] or false)
						end
					end

					if typeof(v) == "Vector2" then
						v = Vector2.new(math.floor(v.X), math.floor(v.Y))
					end
				end

				if k == "Parent" then
					assert(type(v) == "table", "Invalid type " .. type(v) .. " for parent")

					table.insert(objchildren[v], obj)
					table.insert(objmtchildren[v], self)

					changechildrenvis(v, mtobjs[v].Visible)

					if udim2sizeobjs[obj] then
						local newsize = udim2tovector2(udim2sizeobjs[obj], mtobjs[v].Size)
						obj.Size = newsize

						if custompropertygets[mtobjs[v]]("ClipsDescendants") then
							obj.Visible = istouching(obj.Position, newsize, mtobjs[v].Position, mtobjs[v].Size) and objvisibles[obj] or false
						end

						changechildrenudim2pos(self, newsize)
					end

					if listobjs[v] then
						table.insert(listchildren[v], obj)
						table.insert(listindexes[v], listcontents[v] + (#listchildren[v] == 1 and 0 or objpaddings[v]))

						local newpos = Vector2.new(0, listcontents[v] + (#listchildren[v] == 1 and 0 or objpaddings[v]))

						if scrollobjs[v] then
							newpos = Vector2.new(0, listcontents[v] + (#listchildren[v] == 1 and 0 or objpaddings[v]) + scrollpositions[v])
						end

						listadds[v][obj] = obj.Size.Y + (#listchildren[v] == 1 and 0 or objpaddings[v])

						listcontents[v] = listcontents[v] + obj.Size.Y + (#listchildren[v] == 1 and 0 or objpaddings[v])

						obj.Position = newpos

						customproperties.AbsolutePosition = newpos

						changechildrenpos(self, newpos)
					end

					if udim2posobjs[obj] then
						local newpos = mtobjs[v].Position + udim2tovector2(udim2posobjs[obj], mtobjs[v].Size)
						objpositions[obj] = udim2tovector2(udim2posobjs[obj], mtobjs[v].Size)
						obj.Position = newpos
						customproperties.AbsolutePosition = newpos

						if custompropertygets[mtobjs[v]]("ClipsDescendants") then
							obj.Visible = istouching(newpos, obj.Size, mtobjs[v].Position, mtobjs[v].Size) and objvisibles[obj] or false
						end

						changechildrenpos(self, newpos)
					elseif shape ~= "Line" and shape ~= "Quad" and shape ~= "Triangle" then
						local newpos = mtobjs[v].Position + obj.Position
						obj.Position = newpos
						customproperties.AbsolutePosition = newpos

						if custompropertygets[mtobjs[v]]("ClipsDescendants") then
							obj.Visible = istouching(newpos, obj.Size, mtobjs[v].Position, mtobjs[v].Size) and objvisibles[obj] or false
						end

						changechildrenpos(self, newpos)
					end

					if custompropertygets[mtobjs[v]]("ClipsDescendants") then
						obj.Visible = istouching(obj.Position, obj.Size, mtobjs[v].Position, mtobjs[v].Size) and objvisibles[obj] or false
					end

					customproperties.Parent = v
					return
				end

				obj[k] = v
			end
		})

		objmts[obj] = mt
		mtobjs[mt] = obj
		objchildren[mt] = {}
		objmtchildren[mt] = {}

		if shape ~= "Line" and shape ~= "Quad" and shape ~= "Triangle" then
			mt.Position = Vector2.new(0, 0)
		end

		mt.Visible = true

		return mt
	end
end

-- // UI LIBRARY

local services = setmetatable({}, {
	__index = function(_, k)
		k = (k == "InputService" and "UserInputService") or k
		return game:GetService(k)
	end
})

local client = services.Players.LocalPlayer

local utility = {}

function utility.dragify(object, dragoutline)
	local start, objectposition, dragging, currentpos

	object.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			start = input.Position
			--dragoutline.Visible = true
			objectposition = object.Position
		end
	end)

	utility.connect(services.InputService.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
			currentpos = UDim2.new(objectposition.X.Scale, objectposition.X.Offset + (input.Position - start).X, objectposition.Y.Scale, objectposition.Y.Offset + (input.Position - start).Y)
			object.Position = currentpos
			--dragoutline.Position = currentpos
		end
	end)

	utility.connect(services.InputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
			dragging = false
			--dragoutline.Visible = false
			object.Position = currentpos
		end
	end)
end

function utility.textlength(str, font, fontsize)
	local text = Drawing.new("Text")
	text.Text = str
	text.Font = font
	text.Size = fontsize

	local textbounds = text.TextBounds
	text:Remove()

	return textbounds
end

function utility.getcenter(sizeX, sizeY)
	return UDim2.new(0.5, -(sizeX / 2), 0.5, -(sizeY / 2))
end

function utility.table(tbl, usemt)
	tbl = tbl or {}

	local oldtbl = table.clone(tbl)
	table.clear(tbl)

	for i, v in next, oldtbl do
		if type(i) == "string" then
			tbl[i:lower()] = v
		else
			tbl[i] = v
		end
	end

	if usemt == true then
		setmetatable(tbl, {
			__index = function(t, k)
				return rawget(t, k:lower()) or rawget(t, k)
			end,

			__newindex = function(t, k, v)
				if type(k) == "string" then
					rawset(t, k:lower(), v)
				else
					rawset(t, k, v)
				end
			end
		})
	end

	return tbl
end

function utility.colortotable(color)
	local r, g, b = math.floor(color.R * 255),  math.floor(color.G * 255), math.floor(color.B * 255)
	return {r, g, b}
end

function utility.tabletocolor(tbl)
	return Color3.fromRGB(unpack(tbl))
end

function utility.round(number, float)
	return float * math.floor(number / float)
end

function utility.getrgb(color)
	local r = color.R * 255
	local g = color.G * 255
	local b = color.B * 255

	return r, g, b
end

function utility.changecolor(color, number)
	local r, g, b = utility.getrgb(color)
	r, g, b = math.clamp(r + number, 0, 255), math.clamp(g + number, 0, 255), math.clamp(b + number, 0, 255)
	return Color3.fromRGB(r, g, b)
end

local totalunnamedflags = 0

function utility.nextflag()
	totalunnamedflags = totalunnamedflags + 1
	return string.format("%.14g", totalunnamedflags)
end

function utility.rgba(r, g, b, alpha)
	local rgb = Color3.fromRGB(r, g, b)

	if rgbasupported then
		local mt = table.clone(getrawmetatable(rgb))

		setreadonly(mt, false)
		local old = mt.__index

		mt.__index = newcclosure(function(self, key)
			if key:lower() == "a" then
				return alpha
			end

			return old(self, key)
		end)

		setrawmetatable(rgb, mt)
	else
		--[[
		return setmetatable({
			R = r,
			G = g,
			B = b,
			a = alpha,
			__type = "Color3"
		}, {
			__index = newcclosure(function(self, key)
				return rgb[key]
			end),

			__tostring = newcclosure(function(self, key)
				return string.format("%s, %s, %s", r / 255, g / 255, b / 255) -- Imitate Color3.new
			end)
		})]]
	end

	return rgb
end

local themes = {
	Default = {
		["Accent"] = Color3.fromRGB(113, 93, 133),
		["Window Background"] = Color3.fromRGB(30, 30, 30),
		["Window Border"] = Color3.fromRGB(45, 45, 45),
		["Tab Background"] = Color3.fromRGB(20, 20, 20),
		["Tab Border"] = Color3.fromRGB(45, 45, 45),
		["Tab Toggle Background"] = Color3.fromRGB(28, 28, 28),
		["Section Background"] = Color3.fromRGB(18, 18, 18),
		["Section Border"] = Color3.fromRGB(35, 35, 35),
		["Text"] = Color3.fromRGB(200, 200, 200),
		["Disabled Text"] = Color3.fromRGB(110, 110, 110),
		["Object Background"] = Color3.fromRGB(25, 25, 25),
		["Object Border"] = Color3.fromRGB(35, 35, 35),
		["Dropdown Option Background"] = Color3.fromRGB(19, 19, 19)
	},

	Midnight = {
		["Accent"] = Color3.fromRGB(100, 59, 154),
		["Window Background"] = Color3.fromRGB(30, 30, 36),
		["Window Border"] = Color3.fromRGB(45, 45, 49),
		["Tab Background"] = Color3.fromRGB(20, 20, 24),
		["Tab Border"] = Color3.fromRGB(45, 45, 55),
		["Tab Toggle Background"] = Color3.fromRGB(28, 28, 32),
		["Section Background"] = Color3.fromRGB(18, 18, 22),
		["Section Border"] = Color3.fromRGB(35, 35, 45),
		["Text"] = Color3.fromRGB(180, 180, 190),
		["Disabled Text"] = Color3.fromRGB(100, 100, 110),
		["Object Background"] = Color3.fromRGB(25, 25, 29),
		["Object Border"] = Color3.fromRGB(35, 35, 39),
		["Dropdown Option Background"] = Color3.fromRGB(19, 19, 23)
	},

	AirHub = {
		["Accent"] = Color3.fromRGB(150, 100, 150),
		["Window Background"] = Color3.fromRGB(35, 30, 35),
		["Window Border"] = Color3.fromRGB(50, 45, 50),
		["Tab Background"] = Color3.fromRGB(25, 20, 25),
		["Tab Border"] = Color3.fromRGB(65, 45, 65),
		["Tab Toggle Background"] = Color3.fromRGB(35, 30, 35),
		["Section Background"] = Color3.fromRGB(25, 20, 25),
		["Section Border"] = Color3.fromRGB(55, 35, 55),
		["Text"] = Color3.fromRGB(200, 180, 200),
		["Disabled Text"] = Color3.fromRGB(120, 100, 120),
		["Object Background"] = Color3.fromRGB(30, 25, 30),
		["Object Border"] = Color3.fromRGB(40, 35, 40),
		["Dropdown Option Background"] = Color3.fromRGB(25, 20, 25)
	}
}

local themeobjects = {}

local library = utility.table({theme = table.clone(themes.AirHub), folder = "AirHub V2", extension = "cfg", flags = {}, open = false, keybind = Enum.KeyCode.RightShift, mousestate = services.InputService.MouseIconEnabled, cursor = nil, holder = nil, connections = {}}, true)
local decode = string.find(identifyexecutor(), "MacSploit") and base64.decode or (syn and syn.crypt.base64.decode) or (crypt and crypt.base64decode) or (base64 and base64.decode) or base64_decode
library.gradient = decode("iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+9AAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAABuSURBVChTxY9BDoAgDASLGD2ReOYNPsR/+BAfroI7hibe9OYmky2wbUPIOdsXdc1f9WMwppQm+SDGBnUvomAQBH49qzhFEag25869ElzaIXDhD4JGbyoEVxUedN8FKwnfmwhucgKICc+pNB1mZhdCdhsa2ky0FAAAAABJRU5ErkJggg==")
library.utility = utility

function utility.outline(obj, color)
	local outline = drawing:new("Square")
	outline.Parent = obj
	outline.Size = UDim2.new(1, 2, 1, 2)
	outline.Position = UDim2.new(0, -1, 0, -1)
	outline.ZIndex = obj.ZIndex - 1

	if typeof(color) == "Color3" then
		outline.Color = color
	else
		outline.Color = library.theme[color]
		themeobjects[outline] = color
	end

	outline.Parent = obj
	outline.Filled = true
	outline.Thickness = 0

	return outline
end

function utility.create(class, properties)
	if not type(properties.Visible) == "boolean" then
		properties.Visible = false
	end
	
	if class == "Text" then -- I hate solara
		properties.OutlineColor = Color3.fromRGB(0, 0, 0)
	end

	local obj = drawing:new(class)

	for prop, v in next, properties do
		if prop == "Theme" then
			themeobjects[obj] = v
			obj.Color = library.theme[v]
		else
			obj[prop] = v
		end
	end

	return obj
end

function utility.changeobjecttheme(object, color)
	themeobjects[object] = color
	object.Color = library.theme[color]
end

function utility.connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(library.connections, connection)

	return connection
end

function utility.disconnect(connection)
	local index = table.find(library.connections, connection)
	connection:Disconnect()

	if index then
		table.remove(library.connections, index)
	end
end

function utility.hextorgb(hex)
	return Color3.fromRGB(tonumber("0x" .. hex:sub(1, 2)), tonumber("0x" .. hex:sub(3, 4)), tonumber("0x"..hex:sub(5, 6)))
end

local accentobjs = {}

local flags = {}

local configignores = {}

local coloralphas = {}

local colorvalues = {}

local function normalizeconfigname(name, extension)
	if type(name) ~= "string" then
		return nil
	end

	name = name:gsub("^%s+", ""):gsub("%s+$", "")
	name = name:gsub("%s", "_")
	name = name:gsub("[\\/]", "")
	name = name:gsub("%." .. extension .. "$", "")

	if name == "" then
		return nil
	end

	return name
end

function library:SaveConfig(name)
	assert(self.folder, "No folder specified")
	assert(self.extension, "No file extension specified")

	name = normalizeconfigname(name, self.extension)
	if not name then
		return false, "improper name"
	end

	local configtbl = {}

	for flag, colorvalue in next, colorvalues do
		if not table.find(configignores, flag) then
			configtbl[flag] = {
				color = colorvalue.color:ToHex(),
				alpha = tonumber(colorvalue.alpha) or 1
			}
		end
	end

	for flag, value in next, library.flags do
		if not colorvalues[flag] and not table.find(configignores, flag) then
			if typeof(value) == "EnumItem" then
				configtbl[flag] = tostring(value)
			elseif typeof(value) == "Color3" then
				configtbl[flag] = {
					color = value:ToHex(),
					alpha = 1 --rgbasupported and value.A or tonumber(coloralphas[flag]) or 1
				}
			else
				configtbl[flag] = value
			end
		end
	end

	local config = services.HttpService:JSONEncode(configtbl)
	local folderpath = string.format("%s", self.folder)

	if not isfolder(folderpath) then
		makefolder(folderpath)
	end

	local filepath = string.format("%s//%s.%s", folderpath, name, self.extension)
	writefile(filepath, config)
	return true
end

function library:ConfigIgnore(flag)
	table.insert(configignores, flag)
end

function library:DeleteConfig(name)
	assert(self.folder, "No folder specified")
	assert(self.extension, "No file extension specified")

	name = normalizeconfigname(name, self.extension)
	if not name or not isfolder(self.folder) then
		return false
	end

	local filepath = string.format("%s//%s.%s", self.folder, name, self.extension)

	if isfile(filepath) then
		delfile(filepath)
		return true
	end

	return false
end

function library:LoadConfig(name)
	assert(self.folder, "No folder specified")
	assert(self.extension, "No file extension specified")

	name = normalizeconfigname(name, self.extension)
	if not name or not isfolder(self.folder) then
		return false
	end

	local filepath = string.format("%s//%s.%s", self.folder, name, self.extension)

	if not isfile(filepath) then
		return false
	end

	local ok, config = pcall(function()
		return services.HttpService:JSONDecode(readfile(filepath))
	end)

	if not ok or type(config) ~= "table" then
		return false
	end

	for flag, v in next, config do
		local func = flags[flag]
		if func then
			pcall(func, v)
		end
	end

	return true
end

function library:GetConfigs()
	assert(self.folder, "No folder specified")
	assert(self.extension, "No file extension specified")

	local configs = {}
	local extension = "." .. self.extension

	if not isfolder(self.folder) then
		return configs
	end

	for _, filepath in next, listfiles(self.folder) do
		local filename = filepath:match("([^\\/]+)$")
		if filename and filename:sub(-#extension) == extension then
			table.insert(configs, filename:sub(1, #filename - #extension))
		end
	end

	return configs
end

function library:Close()
	self.open = not self.open
	
	if self.holder then
		self.holder.Visible = self.open
	end

	if self.cursor and (identifyexecutor() ~= "Solara" or identifyexecutor() ~= "Xeno") then
		self.cursor.Visible = self.open
		services.InputService.MouseIconEnabled = not self.open and self.mousestate or false
	end
end

function library:ChangeThemeOption(option, color)
	self.theme[option] = color

	for obj, theme in next, themeobjects do
		if rawget(obj, "exists") == true and theme == option then
			obj.Color = color
		end
	end
end

function library:OverrideTheme(tbl)
	for option, color in next, tbl do
		self.theme[option] = color
	end

	for object, color in next, themeobjects do
		if rawget(object, "exists") == true then
			object.Color = self.theme[color]
		end
	end
end

function library:SetTheme(theme)
	self.currenttheme = theme

	if themes[theme] then
		self.theme = table.clone(themes[theme])

		for object, color in next, themeobjects do
			if rawget(object, "exists") == true then
				object.Color = self.theme[color]
			end
		end
	else
		assert(self.folder, "No folder specified")
		assert(self.extension, "No file extension specified")

		local folderpath = string.format("%s//themes", self.folder)
		local filepath = string.format("%s//%s.cfg", folderpath, theme)

		if isfolder(folderpath) and isfile(filepath) then
			local themetbl = services.HttpService:JSONDecode(readfile(filepath))

			for option, color in next, themetbl do
				themetbl[option] = utility.hextorgb(color)
			end

			library:OverrideTheme(themetbl)
		end
	end
end

function library:GetThemes()
	local themes = {"Default", "Midnight", "AirHub"}

	local folderpath = string.format("%s//themes", self.folder)

	if isfolder(folderpath) then
		for _, theme in next, listfiles(folderpath) do
			local name = theme:gsub(folderpath .. "\\", "")
			name = name:gsub(".cfg", "")
			table.insert(themes, name)
		end
	end

	return themes
end

function library:SaveCustomTheme(name)
	if type(name) == "string" and name:find("%S+") and name:len() > 1 then
		if themes[name] then
			name = name .. "1"
		end

		assert(self.folder, "No folder specified")

		local themetbl = {}

		for option, color in next, self.theme do
			themetbl[option] = color:ToHex()
		end

		local theme = services.HttpService:JSONEncode(themetbl)
		local folderpath = string.format("%s//themes", self.folder)

		if not isfolder(folderpath) then
			makefolder(folderpath)
		end

		local filepath = string.format("%s//%s.cfg", folderpath, name)
		writefile(filepath, theme)

		return true
	end

	return false
end

function library:Unload()
	services.ContextActionService:UnbindAction("disablekeyboard")
	services.ContextActionService:UnbindAction("disablemousescroll")

	if self.open then
		library:Close()
	end

	if self.holder then
		self.holder:Remove()
	end

	if self.cursor then
		self.cursor:Remove()
	end

	if self.watermarkobject then
		self.watermarkobject:Remove()
	end

	for _, connection in next, self.connections do
		connection:Disconnect()
	end

	table.clear(self.connections)
	table.clear(self.flags)
	table.clear(flags)
end

local allowedcharacters = {}
local shiftcharacters = {
	["1"] = "!",
	["2"] = "@",
	["3"] = "#",
	["4"] = "$",
	["5"] = "%",
	["6"] = "^",
	["7"] = "&",
	["8"] = "*",
	["9"] = "(",
	["0"] = ")",
	["-"] = "_",
	["="] = "+",
	["["] = "{",
	["\\"] = "|",
	[";"] = ":",
	["'"] = "\"",
	[","] = "<",
	["."] = ">",
	["/"] = "?",
	["`"] = "~"
}

for i = 32, 126 do
	table.insert(allowedcharacters, utf8.char(i))
end

function library.createbox(box, text, callback, finishedcallback)
	box.MouseButton1Click:Connect(function()
		services.ContextActionService:BindActionAtPriority("disablekeyboard", function() return Enum.ContextActionResult.Sink end, false, 3000, Enum.UserInputType.Keyboard)

		local connection
		local backspaceconnection

		local keyqueue = 0

		if not connection then
			connection = utility.connect(services.InputService.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode ~= Enum.KeyCode.Backspace then
						local str = services.InputService:GetStringForKeyCode(input.KeyCode)

						if table.find(allowedcharacters, str) then
							keyqueue = keyqueue + 1
							local currentqueue = keyqueue

							if not services.InputService:IsKeyDown(Enum.KeyCode.RightShift) and not services.InputService:IsKeyDown(Enum.KeyCode.LeftShift) then
								text.Text = text.Text .. str:lower()
								callback(text.Text)

								local ended = false

								coroutine.wrap(function()
									task.wait(0.5)

									while services.InputService:IsKeyDown(input.KeyCode) and currentqueue == keyqueue  do
										text.Text = text.Text .. str:lower()
										callback(text.Text)

										task.wait(0.02)
									end
								end)()
							else
								text.Text = text.Text .. (shiftcharacters[str] or str:upper())
								callback(text.Text)

								coroutine.wrap(function()
									task.wait(0.5)

									while services.InputService:IsKeyDown(input.KeyCode) and currentqueue == keyqueue  do
										text.Text = text.Text .. (shiftcharacters[str] or str:upper())
										callback(text.Text)

										task.wait(0.02)
									end
								end)()
							end
						end
					end

					if input.KeyCode == Enum.KeyCode.Return then
						services.ContextActionService:UnbindAction("disablekeyboard")
						utility.disconnect(backspaceconnection)
						utility.disconnect(connection)
						finishedcallback(text.Text)
					end
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
					services.ContextActionService:UnbindAction("disablekeyboard")
					utility.disconnect(backspaceconnection)
					utility.disconnect(connection)
					finishedcallback(text.Text)
				end
			end)

			local backspacequeue = 0

			backspaceconnection = utility.connect(services.InputService.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Backspace then
					backspacequeue = backspacequeue + 1

					text.Text = text.Text:sub(1, -2)
					callback(text.Text)

					local currentqueue = backspacequeue

					coroutine.wrap(function()
						task.wait(0.5)

						if backspacequeue == currentqueue then
							while services.InputService:IsKeyDown(Enum.KeyCode.Backspace) do
								text.Text = text.Text:sub(1, -2)
								callback(text.Text)

								task.wait(0.02)
							end
						end
					end)()
				end
			end)
		end
	end)
end

function library.createdropdown(holder, content, flag, callback, default, max, scrollable, scrollingmax, islist, section, sectioncontent)
	local dropdown = utility.create("Square", {
		Filled = true,
		Visible = not islist,
		Thickness = 0,
		Theme = "Object Background",
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.new(0, 0, 1, -14),
		ZIndex = 7,
		Parent = holder
	})

	utility.outline(dropdown, "Object Border")

	utility.create("Image", {
		Size = UDim2.new(1, 0, 1, 0),
		Transparency = 0.5,
		ZIndex = 8,
		Parent = dropdown,
		Data = library.gradient
	})

	local value = utility.create("Text", {
		Text = "NONE",
		Font = Drawing.Fonts.Plex,
		Size = 15,
		Position = UDim2.new(0, 6, 0, 0),
		Theme = "Disabled Text",
		ZIndex = 9,
		Outline = true,
		Parent = dropdown
	})

	local icon = utility.create("Text", {
		Text = "+",
		Font = Drawing.Fonts.Plex,
		Size = 15,
		Position = UDim2.new(1, -13, 0, 0),
		Theme = "Text",
		ZIndex = 9,
		Outline = true,
		Parent = dropdown
	})

	local contentframe = utility.create("Square", {
		Filled = true,
		Visible = islist or false,
		Thickness = 0,
		Theme = "Object Background",
		Size = UDim2.new(1, 0, 0, 0),
		Position = islist and UDim2.new(0, 0, 0, 14) or UDim2.new(0, 0, 1, 6),
		ZIndex = 12,
		Parent = islist and holder or dropdown
	})

	utility.outline(contentframe, "Object Border")

	utility.create("Image", {
		Size = UDim2.new(1, 0, 1, 0),
		Transparency = 0.5,
		ZIndex = 13,
		Parent = contentframe,
		Data = library.gradient
	})


	local contentholder = utility.create("Square", {
		Transparency = 0,
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.new(0, 3, 0, 3),
		Parent = contentframe
	})

	if scrollable then
		contentholder:MakeScrollable()
	end

	contentholder:AddListLayout(3)

	local mouseover = false

	dropdown.MouseEnter:Connect(function()
		mouseover = true
		dropdown.Color = utility.changecolor(library.theme["Object Background"], 3)
	end)

	dropdown.MouseLeave:Connect(function()
		mouseover = false
		dropdown.Color = library.theme["Object Background"]
	end)

	dropdown.MouseButton1Down:Connect(function()
		dropdown.Color = utility.changecolor(library.theme["Object Background"], 6)
	end)

	dropdown.MouseButton1Up:Connect(function()
		dropdown.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
	end)

	local opened = false

	if not islist then
		dropdown.MouseButton1Click:Connect(function()
			opened = not opened
			contentframe.Visible = opened
			icon.Text = opened and "-" or "+"
		end)
	end

	local optioninstances = {}
	local count = 0
	local countindex = {}

	local function createoption(name)
		optioninstances[name] = {}

		countindex[name] = count + 1

		local button = utility.create("Square", {
			Filled = true,
			Transparency = 0,
			Thickness = 0,
			Theme = "Dropdown Option Background",
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 14,
			Parent = contentholder
		})

		optioninstances[name].button = button

		local title = utility.create("Text", {
			Text = name,
			Font = Drawing.Fonts.Plex,
			Size = 15,
			Position = UDim2.new(0, 8, 0, 1),
			Theme = "Disabled Text",
			ZIndex = 15,
			Outline = true,
			Parent = button
		})

		optioninstances[name].text = title

		if scrollable then
			if count < scrollingmax then
				contentframe.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 6)

				if islist then
					holder.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 20)
				end
			end
		else
			contentframe.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 6)

			if islist then
				holder.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 20)
			end
		end

		if islist then
			section.Size = UDim2.new(1, 0, 0, sectioncontent.AbsoluteContentSize + 28)
			library.holder.Position = library.holder.Position
		end

		count = count + 1

		return button, title
	end

	local chosen = max and {}

	local function handleoptionclick(option, button, text)
		button.MouseButton1Click:Connect(function()
			if max then
				if table.find(chosen, option) then
					table.remove(chosen, table.find(chosen, option))

					local textchosen = {}
					local cutobject = false

					for _, opt in next, chosen do
						table.insert(textchosen, opt)

						if utility.textlength(table.concat(textchosen, ", ") .. ", ...", Drawing.Fonts.Plex, 13).X > (dropdown.AbsoluteSize.X - 18) then
							cutobject = true
							table.remove(textchosen, #textchosen)
						end
					end

					value.Text = #chosen == 0 and "NONE" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
					utility.changeobjecttheme(value, #chosen == 0 and "Disabled Text" or "Text")

					button.Transparency = 0
					utility.changeobjecttheme(text, "Disabled Text")

					library.flags[flag] = chosen
					callback(chosen)
				else
					if #chosen == max then
						optioninstances[chosen[1]].button.Transparency = 0
						utility.changeobjecttheme(optioninstances[chosen[1]].text, "Disabled Text")

						table.remove(chosen, 1)
					end

					table.insert(chosen, option)

					local textchosen = {}
					local cutobject = false

					for _, opt in next, chosen do
						table.insert(textchosen, opt)

						if utility.textlength(table.concat(textchosen, ", ") .. ", ...", Drawing.Fonts.Plex, 13).X > (dropdown.AbsoluteSize.X - 18) then
							cutobject = true
							table.remove(textchosen, #textchosen)
						end
					end

					value.Text = #chosen == 0 and "NONE" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
					utility.changeobjecttheme(value, #chosen == 0 and "Disabled Text" or "Text")

					button.Transparency = 1
					utility.changeobjecttheme(text, "Text")

					library.flags[flag] = chosen
					callback(chosen)
				end
			else
				for opt, tbl in next, optioninstances do
					if opt ~= option then
						tbl.button.Transparency = 0
						utility.changeobjecttheme(tbl.text, "Disabled Text")
					end
				end

				if chosen == option then
					chosen = nil

					value.Text = "NONE"
					utility.changeobjecttheme(value, "Disabled Text")

					button.Transparency = 0

					utility.changeobjecttheme(text, "Disabled Text")

					library.flags[flag] = nil
					callback(nil)
				else
					chosen = option

					value.Text = option
					utility.changeobjecttheme(value, "Text")

					button.Transparency = 1
					utility.changeobjecttheme(text, "Text")

					library.flags[flag] = option
					callback(option)
				end
			end
		end)
	end

	local function createoptions(tbl)
		for _, option in next, tbl do
			local button, text = createoption(option)
			handleoptionclick(option, button, text)
		end
	end

	createoptions(content)

	local set
	set = function(option)
		if max then
			option = type(option) == "table" and option or {}
			table.clear(chosen)

			for opt, tbl in next, optioninstances do
				if not table.find(option, opt) then
					tbl.button.Transparency = 0
					utility.changeobjecttheme(tbl.text, "Disabled Text")
				end
			end

			for i, opt in next, option do
				if table.find(content, opt) and #chosen < max then
					table.insert(chosen, opt)
					optioninstances[opt].button.Transparency = 1
					utility.changeobjecttheme(optioninstances[opt].text, "Text")
				end
			end

			local textchosen = {}
			local cutobject = false

			for _, opt in next, chosen do
				table.insert(textchosen, opt)

				if utility.textlength(table.concat(textchosen, ", ") .. ", ...", Drawing.Fonts.Plex, 13).X > (dropdown.AbsoluteSize.X - 6) then
					cutobject = true
					table.remove(textchosen, #textchosen)
				end
			end

			value.Text = #chosen == 0 and "NONE" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
			utility.changeobjecttheme(value, #chosen == 0 and "Disabled Text" or "Text")

			library.flags[flag] = chosen
			callback(chosen)
		end

		if not max then
			for opt, tbl in next, optioninstances do
				if opt ~= option then
					tbl.button.Transparency = 0
					utility.changeobjecttheme(tbl.text, "Disabled Text")
				end
			end

			if table.find(content, option) then
				chosen = option

				value.Text = option
				utility.changeobjecttheme(value, "Text")

				optioninstances[option].button.Transparency = 1
				utility.changeobjecttheme(optioninstances[option].text, "Text")

				library.flags[flag] = chosen
				callback(chosen)
			else
				chosen = nil

				value.Text = "NONE"
				utility.changeobjecttheme(value, "Disabled Text")

				library.flags[flag] = chosen
				callback(chosen)
			end
		end
	end

	flags[flag] = set

	set(default)

	local dropdowntypes = utility.table({}, true)

	function dropdowntypes:Set(option)
		set(option)
	end

	function dropdowntypes:Refresh(tbl)
		content = table.clone(tbl)
		count = 0

		for _, opt in next, optioninstances do
			coroutine.wrap(function()
				opt.button:Remove()
			end)()
		end

		table.clear(optioninstances)

		createoptions(tbl)

		if scrollable then
			contentholder:RefreshScrolling()
		end

		value.Text = "NONE"
		utility.changeobjecttheme(value, "Disabled Text")

		if max then
			table.clear(chosen)
		else
			chosen = nil
		end

		library.flags[flag] = chosen
		callback(chosen)
	end

	function dropdowntypes:Add(option)
		table.insert(content, option)
		local button, text = createoption(option)
		handleoptionclick(option, button, text)
	end

	function dropdowntypes:Remove(option)
		if optioninstances[option] then
			count = count - 1

			optioninstances[option].button:Remove()

			if scrollable then
				contentframe.Size = UDim2.new(1, 0, 0, math.clamp(contentholder.AbsoluteContentSize, 0, (scrollingmax * 16) + ((scrollingmax - 1) * 3)) + 6)
			else
				contentframe.Size = UDim2.new(1, 0, 0, contentholder.AbsoluteContentSize + 6)
			end

			optioninstances[option] = nil

			if max then
				if table.find(chosen, option) then
					table.remove(chosen, table.find(chosen, option))

					local textchosen = {}
					local cutobject = false

					for _, opt in next, chosen do
						table.insert(textchosen, opt)

						if utility.textlength(table.concat(textchosen, ", ") .. ", ...", Drawing.Fonts.Plex, 13).X > (dropdown.AbsoluteSize.X - 6) then
							cutobject = true
							table.remove(textchosen, #textchosen)
						end
					end

					value.Text = #chosen == 0 and "NONE" or table.concat(textchosen, ", ") .. (cutobject and ", ..." or "")
					utility.changeobjecttheme(value, #chosen == 0 and "Disabled Text" or "Text")

					library.flags[flag] = chosen
					callback(chosen)
				end
			else
				if chosen == option then
					chosen = nil

					value.Text = "NONE"
					utility.changeobjecttheme(value, "Disabled Text")

					library.flags[flag] = chosen
					callback(chosen)
				end
			end
		end
	end

	return dropdowntypes
end

function library.createslider(min, max, parent, text, default, float, flag, callback)
	local slider = utility.create("Square", {
		Filled = true,
		Thickness = 0,
		Theme = "Object Background",
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 1, -10),
		ZIndex = 7,
		Parent = parent
	})

	utility.outline(slider, "Object Border")

	utility.create("Image", {
		Size = UDim2.new(1, 0, 1, 0),
		Transparency = 0.5,
		ZIndex = 9,
		Parent = slider,
		Data = library.gradient
	})

	local fill = utility.create("Square", {
		Filled = true,
		Thickness = 0,
		Theme = "Accent",
		Size = UDim2.new(0, 0, 1, 0),
		ZIndex = 8,
		Parent = slider
	})

	local valuetext = utility.create("Text", {
		Font = Drawing.Fonts.Plex,
		Size = 14,
		Position = UDim2.new(0.5, 0, 0, -2),
		Theme = "Text",
		Center = true,
		ZIndex = 10,
		Outline = true,
		Parent = slider
	})

	local function set(value)
		value = math.clamp(utility.round(value, float), min, max)

		valuetext.Text = text:gsub("%[value%]", string.format("%.14g", value))

		local sizeX = ((value - min) / (max - min))
		fill.Size = UDim2.new(sizeX, 0, 1, 0)

		library.flags[flag] = value
		callback(value)
	end

	set(default)

	local sliding = false

	local mouseover = false

	slider.MouseEnter:Connect(function()
		mouseover = true
		if not sliding then
			slider.Color = utility.changecolor(library.theme["Object Background"], 3)
		end
	end)

	slider.MouseLeave:Connect(function()
		mouseover = false
		if not sliding then
			slider.Color = library.theme["Object Background"]
		end
	end)

	local function slide(input)
		local sizeX = (input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X
		local value = ((max - min) * sizeX) + min

		set(value)
	end

	utility.connect(slider.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			slider.Color = utility.changecolor(library.theme["Object Background"], 6)
			slide(input)
		end
	end)

	utility.connect(slider.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = false
			slider.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
		end
	end)

	utility.connect(fill.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			slider.Color = utility.changecolor(library.theme["Object Background"], 6)
			slide(input)
		end
	end)

	utility.connect(fill.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = false
			slider.Color = mouseover and utility.changecolor(library.theme["Object Background"], 3) or library.theme["Object Background"]
		end
	end)

	utility.connect(services.InputService.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if sliding then
				slide(input)
			end
		end
	end)

	flags[flag] = set

	local slidertypes = utility.table({}, true)

	function slidertypes:Set(value)
		set(value)
	end

	return slidertypes
end

local pickers = {}

function library.createcolorpicker(default, defaultalpha, parent, count, flag, callback)
	if typeof(default) ~= "Color3" then
		default = Color3.fromRGB(255, 255, 255)
	end
	defaultalpha = tonumber(defaultalpha) or 1
	if flag then
		coloralphas[flag] = defaultalpha
		colorvalues[flag] = {color = default, alpha = defaultalpha}
		library.flags[flag] = default
	end

	local icon = utility.create("Square", {
		Filled = true,
		Thickness = 0,
		Color = default,
		Parent = parent,
		Transparency = defaultalpha,
		Size = UDim2.new(0, 18, 0, 10),
		Position = UDim2.new(1, -18 - (count * 18) - (count * 6), 0, 2),
		ZIndex = 8
	})

	local alphaicon = utility.create("Image", {
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 9,
		Parent = icon,
		Data = decode("iVBORw0KGgoAAAANSUhEUgAAABIAAAAKBAMAAABLZROSAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAGUExURb+/v////5nD/3QAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAVSURBVBjTY2AQhEIkliAWSLY6QQYAknwC7Za+1vYAAAAASUVORK5CYII=")
	})

	utility.outline(icon, "Object Border")

	utility.create("Image", {
		Size = UDim2.new(1, 0, 1, 0),
		Transparency = 0.5,
		ZIndex = 10,
		Parent = icon,
		Data = library.gradient
	})

	local window = utility.create("Square", {
		Filled = true,
		Thickness = 0,
		Parent = icon,
		Theme = "Object Background",
		Size = UDim2.new(0, 192, 0, 158),
		Visible = false,
		Position = UDim2.new(1, -192 + (count * 18) + (count * 6), 1, 6),
		ZIndex = 11
	})

	table.insert(pickers, window)

	utility.outline(window, "Object Border")

	utility.create("Image", {
		Size = UDim2.new(1, 0, 1, 0),
		Transparency = 0.5,
		ZIndex = 12,
		Parent = window,
		Data = library.gradient
	})

	local saturation = utility.create("Square", {
		Filled = true,
		Thickness = 0,
		Parent = window,
		Color = default,
		Size = UDim2.new(0, 164, 0, 110),
		Position = UDim2.new(0, 6, 0, 6),
		ZIndex = 14
	})

	utility.outline(saturation, "Object Border")

	utility.create("Image", {
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 15,
		Parent = saturation,
		Data = decode("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
